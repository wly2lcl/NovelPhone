/// 一致性冲突忽略记忆（ENH-41）：作者确认「有意保留」的差异按作品记住，
/// 后续检查不再重复报告，并在上下文里告诉模型跳过。
///
/// 指纹以冲突原文 + 来源为主；模型换一种来源写法时，同一原文仍视为已忽略，
/// 避免同一处差异因 source 标签波动反复打扰。
library;

import 'dart:convert';

import 'structured_response.dart';

class ContinuitySuppression {
  const ContinuitySuppression({
    required this.fingerprint,
    required this.quote,
    this.source = '',
    this.reason = '',
    this.createdAt,
  });

  factory ContinuitySuppression.fromIssue(
    ContinuityIssue issue, {
    String reason = '',
    DateTime? createdAt,
  }) {
    return ContinuitySuppression(
      fingerprint: ContinuitySuppressions.fingerprint(issue),
      quote: issue.quote.trim(),
      source: issue.source.trim(),
      reason: reason.trim(),
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  final String fingerprint;
  final String quote;
  final String source;

  /// 作者填写的保留原因（可选），会随忽略清单一并注入检查上下文。
  final String reason;
  final DateTime? createdAt;

  bool matches(ContinuityIssue issue) {
    if (fingerprint == ContinuitySuppressions.fingerprint(issue)) return true;
    // 原文相同、来源标签不同：视为同一处差异。
    final stored = ContinuitySuppressions.normalizeQuote(quote);
    return stored.isNotEmpty &&
        stored == ContinuitySuppressions.normalizeQuote(issue.quote);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'fingerprint': fingerprint,
    'quote': quote,
    if (source.isNotEmpty) 'source': source,
    if (reason.isNotEmpty) 'reason': reason,
    if (createdAt != null) 'at': createdAt!.toIso8601String(),
  };

  static ContinuitySuppression? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final quote = (raw['quote'] as String?)?.trim() ?? '';
    final source = (raw['source'] as String?)?.trim() ?? '';
    if (quote.isEmpty) return null;
    final stored = (raw['fingerprint'] as String?)?.trim() ?? '';
    return ContinuitySuppression(
      fingerprint: stored.isEmpty
          ? ContinuitySuppressions.fingerprintFor(quote, source)
          : stored,
      quote: quote,
      source: source,
      reason: (raw['reason'] as String?)?.trim() ?? '',
      createdAt: DateTime.tryParse((raw['at'] as String?) ?? ''),
    );
  }
}

class ContinuitySuppressions {
  const ContinuitySuppressions._();

  /// 本地最多保留的忽略项数。
  static const int maxEntries = 50;

  /// 注入检查上下文的条数上限。
  static const int maxPromptEntries = 20;

  /// 注入时单条原文的最大字数。
  static const int promptQuoteChars = 80;

  static String storageKey(int workId) => 'ai_continuity_ignored_$workId';

  /// 去掉空白与引号、统一小写；保留标点以避免不同句子被合并。
  static String normalizeQuote(String value) =>
      value.trim().replaceAll(RegExp(r'''[\s「」『』“”"'‘’]+'''), '').toLowerCase();

  /// 来源只保留文字与数字，抹平「角色卡·沈砚 / 角色卡-沈砚」这类写法差异。
  static String normalizeSource(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^\u4e00-\u9fa5a-z0-9]'), '');

  static String fingerprint(ContinuityIssue issue) {
    final base = issue.quote.trim().isNotEmpty ? issue.quote : issue.detail;
    return fingerprintFor(base, issue.source);
  }

  static String fingerprintFor(String quote, String source) =>
      '${normalizeQuote(quote)}|${normalizeSource(source)}';

  static List<ContinuitySuppression> parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return <ContinuitySuppression>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <ContinuitySuppression>[];
      final result = <ContinuitySuppression>[];
      final seen = <String>{};
      for (final item in decoded) {
        final entry = ContinuitySuppression.tryParse(item);
        if (entry == null || !seen.add(entry.fingerprint)) continue;
        result.add(entry);
        if (result.length >= maxEntries) break;
      }
      return result;
    } catch (_) {
      // 容忍历史脏数据。
      return <ContinuitySuppression>[];
    }
  }

  static String encode(List<ContinuitySuppression> entries) => jsonEncode(
    entries.take(maxEntries).map((entry) => entry.toJson()).toList(),
  );

  /// 新忽略项置顶、按指纹去重并限制条数。
  static List<ContinuitySuppression> add(
    List<ContinuitySuppression> existing,
    ContinuitySuppression entry,
  ) {
    if (entry.quote.trim().isEmpty) return existing;
    return <ContinuitySuppression>[
      entry,
      ...existing.where(
        (item) =>
            item.fingerprint != entry.fingerprint &&
            !item.matches(
              ContinuityIssue(quote: entry.quote, source: entry.source),
            ),
      ),
    ].take(maxEntries).toList(growable: false);
  }

  static List<ContinuitySuppression> remove(
    List<ContinuitySuppression> existing,
    String fingerprint,
  ) => existing
      .where((entry) => entry.fingerprint != fingerprint)
      .toList(growable: false);

  static ({List<ContinuityIssue> issues, int ignored}) filterIssues(
    List<ContinuityIssue> issues,
    List<ContinuitySuppression> suppressions,
  ) {
    if (suppressions.isEmpty) return (issues: issues, ignored: 0);
    final visible = <ContinuityIssue>[];
    var ignored = 0;
    for (final issue in issues) {
      if (suppressions.any((entry) => entry.matches(issue))) {
        ignored++;
      } else {
        visible.add(issue);
      }
    }
    return (issues: visible, ignored: ignored);
  }

  static ContinuityCheckResult filterResult(
    ContinuityCheckResult result,
    List<ContinuitySuppression> suppressions,
  ) {
    if (suppressions.isEmpty || result.parseFailed || result.issues.isEmpty) {
      return result;
    }
    final filtered = filterIssues(result.issues, suppressions);
    if (filtered.ignored == 0) return result;
    return ContinuityCheckResult(
      summary: result.summary,
      issues: filtered.issues,
      rawText: result.rawText,
      parseFailed: result.parseFailed,
    );
  }

  /// 生成注入一致性检查上下文的忽略清单；没有忽略项时返回空串。
  static String promptBlock(List<ContinuitySuppression> suppressions) {
    if (suppressions.isEmpty) return '';
    final buffer = StringBuffer();
    buffer.writeln('作者已确认以下差异是有意保留的，检查时直接跳过，不要再次报告：');
    for (final entry in suppressions.take(maxPromptEntries)) {
      final source = entry.source.isEmpty ? '' : '｜来源：${entry.source}';
      final reason = entry.reason.isEmpty ? '' : '｜原因：${entry.reason}';
      buffer.writeln(
        '- 「${_clip(entry.quote, promptQuoteChars)}」$source$reason',
      );
    }
    return buffer.toString().trim();
  }

  static String _clip(String text, int maxChars) {
    final oneLine = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final runes = oneLine.runes;
    if (runes.length <= maxChars) return oneLine;
    return '${String.fromCharCodes(runes.take(maxChars))}…';
  }
}
