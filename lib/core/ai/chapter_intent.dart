/// 本章写作目标（ENH-51）：作者写给 AI 的「这一章要完成什么」。
///
/// 只保存在本地 `CHAPTER.intent`，续写 / 改写时作为独立资料段注入；
/// 不参与一致性判断，也不会被 AI 自动改写。
library;

import 'dart:convert';

/// 结构化的本章写作目标：核心目标、按顺序的关键节拍、明确避免的内容。
class ChapterIntent {
  const ChapterIntent({
    this.goal = '',
    this.beats = const <String>[],
    this.avoid = const <String>[],
  });

  /// 核心目标（一句话）。
  final String goal;

  /// 关键节拍（按顺序发生的事件）。
  final List<String> beats;

  /// 本章不要出现的内容 / 写法。
  final List<String> avoid;

  static const int maxGoalChars = 120;
  static const int maxBeats = 8;
  static const int maxBeatChars = 80;
  static const int maxAvoid = 5;
  static const int maxAvoidChars = 60;

  bool get isEmpty => goal.trim().isEmpty && beats.isEmpty && avoid.isEmpty;

  /// 仅保留非空字段的 JSON；空目标编码为空串，避免库里出现 `{}`。
  String encode() {
    if (isEmpty) return '';
    return jsonEncode(<String, dynamic>{
      if (goal.trim().isNotEmpty) 'goal': goal.trim(),
      if (beats.isNotEmpty) 'beats': beats,
      if (avoid.isNotEmpty) 'avoid': avoid,
    });
  }

  /// 容错解析：旧数据或手写纯文本按核心目标处理，字段超限时截断。
  static ChapterIntent parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return const ChapterIntent();
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        return ChapterIntent(
          goal: _clip((decoded['goal'] as String?) ?? '', maxGoalChars),
          beats: _cleanList(
            decoded['beats'],
            maxCount: maxBeats,
            maxChars: maxBeatChars,
          ),
          avoid: _cleanList(
            decoded['avoid'],
            maxCount: maxAvoid,
            maxChars: maxAvoidChars,
          ),
        );
      }
    } on FormatException {
      // 非 JSON：按纯文本核心目标兼容。
    }
    return ChapterIntent(goal: _clip(text, maxGoalChars));
  }

  /// 用户消息中的注入文本；空目标返回空串。
  String toPromptText() {
    if (isEmpty) return '';
    final buffer = StringBuffer('【本章写作目标】');
    if (goal.trim().isNotEmpty) {
      buffer.write('\n核心目标：${goal.trim()}');
    }
    if (beats.isNotEmpty) {
      buffer.write('\n关键节拍（按顺序）：');
      for (var i = 0; i < beats.length; i++) {
        buffer.write('\n${i + 1}. ${beats[i]}');
      }
    }
    if (avoid.isNotEmpty) {
      buffer.write('\n避免（本章不要出现）：');
      for (final item in avoid) {
        buffer.write('\n- $item');
      }
    }
    return buffer.toString();
  }

  static List<String> _cleanList(
    Object? raw, {
    required int maxCount,
    required int maxChars,
  }) {
    final source = raw is List ? raw : const <Object?>[];
    final result = <String>[];
    for (final item in source) {
      if (item is! String) continue;
      final text = _clip(item.trim(), maxChars);
      if (text.isEmpty || result.contains(text)) continue;
      result.add(text);
      if (result.length >= maxCount) break;
    }
    return List<String>.unmodifiable(result);
  }

  /// 按码点截断，避免劈开 emoji（与导入标题的处理口径一致）。
  static String _clip(String text, int max) {
    if (text.runes.length <= max) return text;
    return String.fromCharCodes(text.runes.take(max));
  }
}

/// 把弹窗里的多行文本切成条目（忽略空行，保留作者顺序）。
List<String> splitIntentLines(
  String text, {
  int maxCount = ChapterIntent.maxBeats,
  int maxChars = ChapterIntent.maxBeatChars,
}) {
  final result = <String>[];
  for (final line in text.split('\n')) {
    final item = line.trim();
    if (item.isEmpty || result.contains(item)) continue;
    result.add(
      item.runes.length <= maxChars
          ? item
          : String.fromCharCodes(item.runes.take(maxChars)),
    );
    if (result.length >= maxCount) break;
  }
  return result;
}
