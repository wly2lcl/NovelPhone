/// 协作守则与 AI 套话黑名单（ENH-44）。
///
/// 作者可以为单部作品手写写作守则、标记不想再看到的套话；
/// 被整篇放弃并标记为「太 AI」的产出会本地留存摘要，用于发现高频套话。
library;

import 'dart:convert';

/// 内置的常见 AI 套话候选（仅用于本地提示，不会自动加入黑名单）。
class AiCliche {
  const AiCliche._();

  /// 按长度从长到短匹配，避免「仿佛」抢先匹配「空气仿佛凝固」。
  static const List<String> curated = <String>[
    '空气仿佛凝固',
    '倒吸一口凉气',
    '不知过了多久',
    '再也无法抑制',
    '眼底闪过一丝',
    '嘴角勾起一抹',
    '轻轻地叹了口气',
    '不由自主',
    '心中一颤',
    '心头一紧',
    '眼神深邃',
    '意味深长',
    '不易察觉',
    '几不可闻',
    '似笑非笑',
    '若有所思',
    '仿佛',
    '宛如',
  ];

  /// 统计 [text] 中出现的套话次数；每个候选最多计一次，避免重复刷权重。
  static Map<String, int> count(String text) {
    final result = <String, int>{};
    if (text.trim().isEmpty) return result;
    for (final phrase in curated) {
      final count = phrase.allMatches(text).length;
      if (count > 0) result[phrase] = count;
    }
    return result;
  }

  /// 从被放弃的 AI 产出中发现套话，按出现次数降序；已加入黑名单的不再提示。
  static List<String> suggest({
    required List<String> rejectedTexts,
    required List<String> banned,
    int limit = 6,
  }) {
    final totals = <String, int>{};
    for (final text in rejectedTexts) {
      for (final entry in count(text).entries) {
        totals[entry.key] = (totals[entry.key] ?? 0) + entry.value;
      }
    }
    final lowerBanned = banned.map((e) => e.trim()).toSet();
    final candidates =
        totals.entries
            .where((entry) => !lowerBanned.contains(entry.key))
            .toList()
          ..sort((a, b) {
            final byCount = b.value.compareTo(a.value);
            if (byCount != 0) return byCount;
            return b.key.length.compareTo(a.key.length);
          });
    return candidates.take(limit).map((entry) => entry.key).toList();
  }
}

/// 作品级协作守则 + 套话黑名单。
class CollaborationRules {
  const CollaborationRules({
    this.rules = const <String>[],
    this.banned = const <String>[],
  });

  final List<String> rules;
  final List<String> banned;

  static const int maxRules = 10;
  static const int maxRuleChars = 120;
  static const int maxBanned = 20;
  static const int maxBannedChars = 40;

  /// 本地最多留存的「太 AI」放弃片段数与单条字数。
  static const int maxRejected = 5;
  static const int maxRejectedChars = 300;

  bool get isEmpty => rules.isEmpty && banned.isEmpty;

  static CollaborationRules sanitize({
    Iterable<String> rules = const <String>[],
    Iterable<String> banned = const <String>[],
  }) {
    return CollaborationRules(
      rules: sanitizeList(rules, maxItems: maxRules, maxChars: maxRuleChars),
      banned: sanitizeList(
        banned,
        maxItems: maxBanned,
        maxChars: maxBannedChars,
      ),
    );
  }

  static List<String> sanitizeList(
    Iterable<String> items, {
    required int maxItems,
    required int maxChars,
  }) {
    final result = <String>[];
    final seen = <String>{};
    for (final item in items) {
      final text = _clip(item.trim(), maxChars);
      if (text.isEmpty || !seen.add(text)) continue;
      result.add(text);
      if (result.length >= maxItems) break;
    }
    return result;
  }

  static List<String> parseList(
    String? raw, {
    required int maxItems,
    required int maxChars,
  }) {
    if (raw == null || raw.trim().isEmpty) return const <String>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <String>[];
      return sanitizeList(
        decoded.whereType<String>(),
        maxItems: maxItems,
        maxChars: maxChars,
      );
    } catch (_) {
      // 容忍历史脏数据。
      return const <String>[];
    }
  }

  static String encodeList(Iterable<String> items) =>
      jsonEncode(items.toList());

  /// 新条目置顶并去重；空串或超限时原样返回。
  static List<String> add(
    List<String> existing,
    String item, {
    required int maxItems,
    required int maxChars,
  }) {
    return sanitizeList(
      <String>[item, ...existing],
      maxItems: maxItems,
      maxChars: maxChars,
    );
  }

  /// 生成注入 system 的协作守则文本；无内容时返回空串。
  static String promptBlock({
    required List<String> rules,
    required List<String> banned,
  }) {
    final cleanRules = sanitizeList(
      rules,
      maxItems: maxRules,
      maxChars: maxRuleChars,
    );
    final cleanBanned = sanitizeList(
      banned,
      maxItems: maxBanned,
      maxChars: maxBannedChars,
    );
    if (cleanRules.isEmpty && cleanBanned.isEmpty) return '';
    final buffer = StringBuffer('【协作守则】');
    if (cleanRules.isNotEmpty) {
      buffer.writeln('作者为本作品设定了以下硬性要求，必须遵守：');
      for (final rule in cleanRules) {
        buffer.writeln('- $rule');
      }
    }
    if (cleanBanned.isNotEmpty) {
      buffer.writeln(
        '以下词句被作者标记为 AI 套话，生成时避免直接使用；'
        '相近含义请改写为具体的动作、对话或感官描写：',
      );
      buffer.writeln(cleanBanned.map((e) => '「$e」').join('、'));
    }
    return buffer.toString().trim();
  }

  /// 截断到 [maxChars] 个字符，末尾加省略号。
  static String clip(String text, int maxChars) => _clip(text, maxChars);

  static String _clip(String text, int maxChars) {
    final runes = text.runes;
    if (runes.length <= maxChars) return text;
    return '${String.fromCharCodes(runes.take(maxChars))}…';
  }
}
