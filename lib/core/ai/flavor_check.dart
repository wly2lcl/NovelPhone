import 'dart:convert';

import '../../data/db.dart';
import '../ai_flavor_rules.dart';
import '../word_count.dart';

/// 检查范围中的一章：记录该章在拼接文本中的起始偏移，供问题定位回跳到章内位置。
class CheckScopeSegment {
  const CheckScopeSegment({
    required this.chapterId,
    required this.title,
    required this.start,
    required this.text,
  });

  final int chapterId;
  final String title;
  final int start;
  final String text;
}

/// 检查范围（单章或整作拼接结果）。
class CheckScope {
  const CheckScope({
    required this.segments,
    required this.text,
    required this.wordCount,
  });

  final List<CheckScopeSegment> segments;
  final String text;
  final int wordCount;

  bool get isEmpty => text.trim().isEmpty;

  /// 全局偏移 → 章节与章内偏移（M4-10 点击定位）。
  ({int chapterId, int offsetInChapter})? locate(int offset) {
    for (final segment in segments) {
      final end = segment.start + segment.text.length;
      if (offset >= segment.start && offset <= end) {
        return (
          chapterId: segment.chapterId,
          offsetInChapter: offset - segment.start,
        );
      }
    }
    if (segments.isEmpty) return null;
    final last = segments.last;
    return (chapterId: last.chapterId, offsetInChapter: last.text.length);
  }
}

/// 由章节列表构造检查范围（PRD 5.7：范围可选当前章或整部作品）。
CheckScope buildCheckScope(List<Chapter> chapters) {
  final buffer = StringBuffer();
  final segments = <CheckScopeSegment>[];
  for (final chapter in chapters) {
    segments.add(
      CheckScopeSegment(
        chapterId: chapter.id,
        title: chapter.title,
        start: buffer.length,
        text: chapter.content,
      ),
    );
    buffer.write(chapter.content);
    buffer.write('\n');
  }
  final text = buffer.toString();
  return CheckScope(
    segments: segments,
    text: text,
    wordCount: countWords(text),
  );
}

/// 一个送检分段（M4-06）。
class DeepCheckSegment {
  const DeepCheckSegment({required this.start, required this.text});

  final int start;
  final String text;
}

/// 默认分段长度（字符 ≈ token，ARCHITECTURE 5.3 的中文近似口径）。
const int deepCheckSegmentChars = 2000;

/// 分段送检（M4-06）：按段长切分，尽量落在段落边界，避免把一句话切断。
List<DeepCheckSegment> splitDeepCheckSegments(
  String text, {
  int maxChars = deepCheckSegmentChars,
}) {
  final segments = <DeepCheckSegment>[];
  var cursor = 0;
  while (cursor < text.length) {
    var end = (cursor + maxChars).clamp(0, text.length);
    if (end < text.length) {
      final newline = text.lastIndexOf('\n', end);
      if (newline > cursor + maxChars ~/ 2) end = newline + 1;
    }
    final piece = text.substring(cursor, end);
    if (piece.trim().isNotEmpty) {
      segments.add(DeepCheckSegment(start: cursor, text: piece));
    }
    cursor = end;
  }
  return segments;
}

/// 深检系统指令（M4-06）：类型枚举 + 严重度 + 原文片段 + 建议，要求 JSON 输出。
String buildDeepCheckSystem() => '''
你是中文网络小说的文字编辑，专门识别"AI 味"。请检查给出的正文，找出以下五类问题：
- 套话：陈词滥调与模板化表达（不禁、仿佛、嘴角勾起、五味杂陈等）
- 句式重复：句式雷同、同结构段落连续出现、对话标签模式化
- 翻译腔：欧化长句、被动式、动词名词化（如此…以至于、对于…来说、被认为是…等）
- 过度总结：段落结尾强行升华、说教式感悟
- 节奏拖沓：省略号/破折号泛滥、长短句失衡、信息密度过低
只标记问题，不要重写全文；每条问题给出最小可替换片段。
严格输出 JSON，不要输出解释文字或 markdown 代码块标记，格式：
{"issues":[{"type":"套话","severity":"高","quote":"不禁","suggestion":"删除该词"}]}
severity 只取 高/中/低；quote 必须是原文中出现过的连续片段；没有问题时输出 {"issues":[]}。''';

/// 深检解析结果（M4-07）：解析失败时降级为纯文本展示。
class FlavorDeepCheckOutcome {
  const FlavorDeepCheckOutcome({
    required this.issues,
    this.parseFailed = false,
    this.fallbackText,
  });

  final List<FlavorIssue> issues;
  final bool parseFailed;

  /// JSON 解析失败时的原始输出，面板按纯文本展示。
  final String? fallbackText;
}

const Map<String, String> _typeAliases = <String, String>{
  '套话': FlavorType.cliche,
  '陈词滥调': FlavorType.cliche,
  '口头禅': FlavorType.cliche,
  '句式重复': FlavorType.repetition,
  '重复': FlavorType.repetition,
  '句式雷同': FlavorType.repetition,
  '翻译腔': FlavorType.translationese,
  '欧化': FlavorType.translationese,
  '过度总结': FlavorType.oversummary,
  '总结': FlavorType.oversummary,
  '升华': FlavorType.oversummary,
  '说教': FlavorType.oversummary,
  '节奏拖沓': FlavorType.pacing,
  '拖沓': FlavorType.pacing,
  '节奏': FlavorType.pacing,
};

/// 解析深检返回（M4-06 / M4-07）。
///
/// [segmentText] / [segmentOffset] 用于把模型返回的原文片段还原为全局偏移；
/// 片段无法定位时按不可定位处理（start == end）。
FlavorDeepCheckOutcome parseDeepCheckResponse(
  String raw, {
  required String segmentText,
  required int segmentOffset,
}) {
  final decoded = _extractJson(raw);
  if (decoded == null) {
    final trimmed = raw.trim();
    return FlavorDeepCheckOutcome(
      issues: const <FlavorIssue>[],
      parseFailed: true,
      fallbackText: trimmed.isEmpty ? null : trimmed,
    );
  }

  final rawItems = <dynamic>[];
  if (decoded is List) {
    rawItems.addAll(decoded);
  } else if (decoded is Map) {
    final issues = decoded['issues'] ?? decoded['问题'] ?? decoded['问题列表'];
    if (issues is List) rawItems.addAll(issues);
  }

  final issues = <FlavorIssue>[];
  final seen = <String>{};
  for (final item in rawItems) {
    if (item is! Map) continue;
    final type = _normalizeType(
      _readString(item, const ['type', '类型', '问题类型']),
    );
    final quote = _readString(item, const ['quote', '原文', '片段', '原文片段']);
    final suggestion = _readString(item, const ['suggestion', '建议', '修改建议']);
    if (type.isEmpty && quote.isEmpty) continue;
    final severity = _normalizeSeverity(
      _readString(item, const ['severity', '严重度']),
    );

    var start = segmentText.indexOf(quote);
    if (start == -1 && quote.isNotEmpty) {
      start = segmentText.indexOf(
        quote.replaceAll('“', '').replaceAll('”', ''),
      );
    }
    final absoluteStart = start == -1 ? segmentOffset : segmentOffset + start;
    final absoluteEnd = start == -1
        ? absoluteStart
        : absoluteStart + quote.length;
    final key = '$type|$absoluteStart|$absoluteEnd|$quote';
    if (!seen.add(key)) continue;

    issues.add(
      FlavorIssue(
        type: type.isEmpty ? FlavorType.cliche : type,
        severity: severity,
        start: absoluteStart,
        end: absoluteEnd,
        excerpt: quote,
        message: type.isEmpty ? '深检问题' : type,
        suggestion: suggestion.isEmpty ? null : suggestion,
        source: FlavorSource.llm,
      ),
    );
  }
  return FlavorDeepCheckOutcome(issues: issues);
}

/// 从模型输出中抽取 JSON：容忍代码块包裹与前后解释文字。
dynamic _extractJson(String raw) {
  final cleaned = raw
      .replaceAll('```json', '')
      .replaceAll('```JSON', '')
      .replaceAll('```', '')
      .trim();
  if (cleaned.isEmpty) return null;
  final direct = _tryDecode(cleaned);
  if (direct != null) return direct;

  final objectStart = cleaned.indexOf('{');
  final objectEnd = cleaned.lastIndexOf('}');
  if (objectStart != -1 && objectEnd > objectStart) {
    final decoded = _tryDecode(cleaned.substring(objectStart, objectEnd + 1));
    if (decoded != null) return decoded;
  }
  final arrayStart = cleaned.indexOf('[');
  final arrayEnd = cleaned.lastIndexOf(']');
  if (arrayStart != -1 && arrayEnd > arrayStart) {
    return _tryDecode(cleaned.substring(arrayStart, arrayEnd + 1));
  }
  return null;
}

dynamic _tryDecode(String text) {
  try {
    return jsonDecode(text);
  } catch (_) {
    return null;
  }
}

String _readString(Map<dynamic, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return '';
}

String _normalizeType(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  return _typeAliases[trimmed] ?? trimmed;
}

int _normalizeSeverity(String raw) {
  final value = raw.trim().toLowerCase();
  if (value.contains('高') || value == 'high' || value == '3') {
    return FlavorSeverity.high;
  }
  if (value.contains('低') || value == 'low' || value == '1') {
    return FlavorSeverity.low;
  }
  return FlavorSeverity.medium;
}
