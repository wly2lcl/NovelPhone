/// 协作守则与 AI 套话黑名单（ENH-44 / ENH-48 / ENH-49 / ENH-50）。
///
/// 作者可以为单部作品手写写作守则、标记不想再看到的套话；
/// 被整篇放弃并标记为「太 AI」的产出会本地留存摘要，用于发现高频套话。
/// 守则可限定作用任务（续写 / 改写 / 灵感 / 章纲 / 剧情推演），
/// 生成结果还能在面板内做一次本地守则自检。
library;

import 'dart:convert';

import '../ai_flavor_rules.dart';
import '../flavor_lexicon.dart';

/// 守则作用任务（ENH-49）。空作用域表示对所有任务生效。
class CollabRuleTask {
  const CollabRuleTask._();

  static const String all = 'all';
  static const String continueWriting = 'continue';
  static const String rewrite = 'rewrite';
  static const String inspire = 'inspire';
  static const String outline = 'outline';
  static const String plot = 'plan';

  static const List<String> selectable = <String>[
    continueWriting,
    rewrite,
    inspire,
    outline,
    plot,
  ];

  static String labelKey(String task) => task;
}

/// 内置的常见 AI 套话候选（仅用于本地提示，不会自动加入黑名单）。
class AiCliche {
  const AiCliche._();

  /// 作者常用、语义完整的强套话；词库其余高权重词条会自动并入候选。
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

  /// ENH-50：把手写候选与内置 200 条词库里的中高权重词条合并，
  /// 只用于本地推荐，不会自动写入黑名单。
  static final List<String> candidates = _buildCandidates();

  static List<String> _buildCandidates() {
    final seen = <String>{};
    final result = <String>[];
    void add(String word) {
      final text = word.trim();
      if (text.isEmpty || !seen.add(text)) return;
      result.add(text);
    }

    for (final word in curated) {
      add(word);
    }
    for (final entry in flavorLexicon) {
      if (entry.weight >= FlavorSeverity.medium) add(entry.word);
    }
    return List<String>.unmodifiable(result);
  }

  /// 统计 [text] 中出现的套话次数；每个候选最多计一次，避免重复刷权重。
  static Map<String, int> count(String text) {
    final result = <String, int>{};
    if (text.trim().isEmpty) return result;
    for (final phrase in candidates) {
      final count = phrase.allMatches(text).length;
      if (count > 0) result[phrase] = count;
    }
    return result;
  }

  /// 词库里的直接替换建议（空串表示建议删除）；没有则返回 null。
  static String? replacementOf(String phrase) => flavorReplacements[phrase];

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
    // 只折叠二字短词（「仿佛」在「空气仿佛凝固」已提示时不再单列）；
    // 四字以上的具体套话即便互相包含也保留，避免丢掉更精确的写法。
    final picked = <String>[];
    for (final entry in candidates) {
      if (entry.key.runes.length <= 2 &&
          picked.any((longer) => longer.contains(entry.key))) {
        continue;
      }
      picked.add(entry.key);
      if (picked.length >= limit) break;
    }
    return picked;
  }
}

/// 一条守则自检命中（ENH-48）。
class RuleCheckIssue {
  const RuleCheckIssue({
    required this.phrase,
    required this.count,
    required this.kind,
    this.replacement,
    this.matchedRule,
  });

  final String phrase;
  final int count;

  /// banned / quoted / cliche / repetition。
  final String kind;
  final String? replacement;

  /// 命中的手写守则原文（仅 quoted）。
  final String? matchedRule;

  bool get isBanned => kind == 'banned';
  bool get isCliche => kind == 'cliche' || kind == 'repetition';
}

/// 生成结果的本地守则自检结果。
class RuleCheckResult {
  const RuleCheckResult({
    this.issues = const <RuleCheckIssue>[],
    this.total = 0,
  });

  final List<RuleCheckIssue> issues;

  /// 全部命中次数（含未展示的短词）。
  final int total;

  bool get isEmpty => total == 0;
}

/// 两条守则可能互相冲突（ENH-49），仅提示不阻断。
class RuleConflict {
  const RuleConflict(this.first, this.second);

  final String first;
  final String second;
}

/// 作品级协作守则 + 套话黑名单 + 逐条任务作用域。
class CollaborationRules {
  const CollaborationRules({
    this.rules = const <String>[],
    this.banned = const <String>[],
    this.scopes = const <String, List<String>>{},
  });

  final List<String> rules;
  final List<String> banned;

  /// 守则 → 作用任务；没有记录表示全部任务。
  final Map<String, List<String>> scopes;

  static const int maxRules = 10;
  static const int maxRuleChars = 120;
  static const int maxBanned = 20;
  static const int maxBannedChars = 40;

  /// 本地最多留存的「太 AI」放弃片段数与单条字数。
  static const int maxRejected = 5;
  static const int maxRejectedChars = 300;

  /// ENH-50：大改样本只做本地分析，单独留档，最多 10 组。
  static const int maxAnalysisSamples = 10;

  bool get isEmpty => rules.isEmpty && banned.isEmpty;

  bool get hasScopes => scopes.values.any((e) => e.isNotEmpty);

  /// 守则 [rule] 的作用任务；空列表表示全部。
  List<String> scopesFor(String rule) =>
      List<String>.unmodifiable(scopes[rule] ?? const <String>[]);

  static CollaborationRules sanitize({
    Iterable<String> rules = const <String>[],
    Iterable<String> banned = const <String>[],
    Map<String, List<String>> scopes = const <String, List<String>>{},
  }) {
    final cleanRules = sanitizeList(
      rules,
      maxItems: maxRules,
      maxChars: maxRuleChars,
    );
    return CollaborationRules(
      rules: cleanRules,
      banned: sanitizeList(
        banned,
        maxItems: maxBanned,
        maxChars: maxBannedChars,
      ),
      scopes: sanitizeScopes(scopes, rules: cleanRules),
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

  /// ENH-49：解析逐条作用域；未知任务、孤立条目会被丢弃。
  static Map<String, List<String>> parseScopes(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const <String, List<String>>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const <String, List<String>>{};
      final result = <String, List<String>>{};
      for (final entry in decoded.entries) {
        final key = entry.key.toString().trim();
        final value = entry.value;
        if (key.isEmpty || value is! List) continue;
        final clean = sanitizeScopeList(value.whereType<String>());
        if (clean.isNotEmpty) result[key] = clean;
      }
      return result;
    } catch (_) {
      return const <String, List<String>>{};
    }
  }

  static String encodeScopes(Map<String, List<String>> scopes) {
    final clean = <String, List<String>>{};
    for (final entry in scopes.entries) {
      final list = sanitizeScopeList(entry.value);
      if (list.isNotEmpty) clean[entry.key] = list;
    }
    return jsonEncode(clean);
  }

  static List<String> sanitizeScopeList(Iterable<String> items) {
    final result = <String>[];
    for (final item in items) {
      if (!CollabRuleTask.selectable.contains(item)) continue;
      if (result.contains(item)) continue;
      result.add(item);
    }
    return result;
  }

  static Map<String, List<String>> sanitizeScopes(
    Map<String, List<String>> scopes, {
    required List<String> rules,
  }) {
    final result = <String, List<String>>{};
    for (final rule in rules) {
      final list = sanitizeScopeList(scopes[rule] ?? const <String>[]);
      if (list.isNotEmpty) result[rule] = list;
    }
    return result;
  }

  /// 当前任务是否适用这条守则（未限定作用域 = 全部任务）。
  static bool appliesTo(List<String>? scopes, String? task) {
    if (task == null || task.isEmpty || task == CollabRuleTask.all) return true;
    final list = sanitizeScopeList(scopes ?? const <String>[]);
    return list.isEmpty || list.contains(task);
  }

  /// 生成注入 system 的协作守则文本；无内容时返回空串。
  static String promptBlock({
    required List<String> rules,
    required List<String> banned,
    String? task,
    Map<String, List<String>> scopes = const <String, List<String>>{},
  }) {
    final cleanRules = sanitizeList(
      rules,
      maxItems: maxRules,
      maxChars: maxRuleChars,
    );
    final applicable = cleanRules
        .where((rule) => appliesTo(scopes[rule], task))
        .toList(growable: false);
    final cleanBanned = sanitizeList(
      banned,
      maxItems: maxBanned,
      maxChars: maxBannedChars,
    );
    if (applicable.isEmpty && cleanBanned.isEmpty) return '';
    final buffer = StringBuffer('【协作守则】');
    if (applicable.isNotEmpty) {
      buffer.writeln('作者为本作品设定了以下硬性要求，必须遵守：');
      for (final rule in applicable) {
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

  /// ENH-49：识别几条常见但方向相反的守则组合。
  static List<RuleConflict> conflicts(
    List<String> rules, {
    Map<String, List<String>> scopes = const <String, List<String>>{},
  }) {
    const groups = <List<List<String>>>[
      <List<String>>[
        <String>['压缩', '精简', '简洁', '简练', '删去'],
        <String>['展开', '详细', '补充', '扩写', '丰富'],
      ],
      <List<String>>[
        <String>['增加对话', '多写对白', '对白为主', '对话为主'],
        <String>['减少对话', '少写对白', '少用对话'],
      ],
      <List<String>>[
        <String>['短段', '拆短', '简短', '零碎'],
        <String>['长段', '合并段落', '连贯长段', '大段'],
      ],
    ];
    final result = <RuleConflict>[];
    for (var i = 0; i < rules.length; i++) {
      for (var j = i + 1; j < rules.length; j++) {
        final a = rules[i];
        final b = rules[j];
        final overlap = _shareScope(scopes[a], scopes[b]);
        if (!overlap) continue;
        for (final group in groups) {
          final aFirst = group[0].any(a.contains);
          final aSecond = group[1].any(a.contains);
          final bFirst = group[0].any(b.contains);
          final bSecond = group[1].any(b.contains);
          if ((aFirst && bSecond) || (aSecond && bFirst)) {
            result.add(RuleConflict(a, b));
            break;
          }
        }
      }
    }
    return result;
  }

  static bool _shareScope(List<String>? a, List<String>? b) {
    final left = sanitizeScopeList(a ?? const <String>[]);
    final right = sanitizeScopeList(b ?? const <String>[]);
    if (left.isEmpty || right.isEmpty) return true;
    return left.any(right.contains);
  }

  /// ENH-48：生成结果本地自检——黑名单 / 守则引号词 / 词库套话。
  static RuleCheckResult inspectText(
    String text, {
    List<String> rules = const <String>[],
    List<String> banned = const <String>[],
    int maxIssues = 6,
  }) {
    if (text.trim().isEmpty) return const RuleCheckResult();
    final issues = <RuleCheckIssue>[];
    final seen = <String>{};
    var total = 0;

    for (final phrase in sanitizeList(
      banned,
      maxItems: maxBanned,
      maxChars: maxBannedChars,
    )) {
      final count = phrase.allMatches(text).length;
      if (count <= 0) continue;
      total += count;
      seen.add(phrase);
      issues.add(
        RuleCheckIssue(
          phrase: phrase,
          count: count,
          kind: 'banned',
          replacement: AiCliche.replacementOf(phrase),
        ),
      );
    }

    // 手写守则里用「」/“”标出的具体禁用词也会检查。
    for (final rule in sanitizeList(
      rules,
      maxItems: maxRules,
      maxChars: maxRuleChars,
    )) {
      for (final match in RegExp(r'[「“]([^」”]{1,20})[」”]').allMatches(rule)) {
        final phrase = match.group(1)?.trim() ?? '';
        if (phrase.isEmpty || seen.contains(phrase)) continue;
        final count = phrase.allMatches(text).length;
        if (count <= 0) continue;
        total += count;
        seen.add(phrase);
        issues.add(
          RuleCheckIssue(
            phrase: phrase,
            count: count,
            kind: 'quoted',
            matchedRule: rule,
            replacement: AiCliche.replacementOf(phrase),
          ),
        );
      }
    }

    // 手写候选里有几条组合式套话不在大词库中，单独扫一遍。
    for (final phrase in AiCliche.curated) {
      if (seen.contains(phrase)) continue;
      final count = phrase.allMatches(text).length;
      if (count <= 0) continue;
      total += count;
      seen.add(phrase);
      issues.add(
        RuleCheckIssue(
          phrase: phrase,
          count: count,
          kind: 'cliche',
          replacement: AiCliche.replacementOf(phrase),
        ),
      );
    }

    final flavor = runFlavorRules(text, maxIssues: 60);
    final byWord = <String, ({int count, int severity, String? replacement})>{};
    for (final issue in flavor.issues) {
      if (issue.type != FlavorType.cliche &&
          issue.type != FlavorType.repetition) {
        continue;
      }
      final word = issue.excerpt.trim();
      if (word.isEmpty || seen.contains(word)) continue;
      final current = byWord[word];
      byWord[word] = (
        count: (current?.count ?? 0) + 1,
        severity: issue.severity > (current?.severity ?? 0)
            ? issue.severity
            : (current?.severity ?? 0),
        replacement: current?.replacement ?? issue.replacement,
      );
    }
    final clicheEntries = byWord.entries.toList()
      ..sort((a, b) {
        final bySeverity = b.value.severity.compareTo(a.value.severity);
        if (bySeverity != 0) return bySeverity;
        return b.value.count.compareTo(a.value.count);
      });
    for (final entry in clicheEntries) {
      total += entry.value.count;
      issues.add(
        RuleCheckIssue(
          phrase: entry.key,
          count: entry.value.count,
          kind: 'cliche',
          replacement: entry.value.replacement,
        ),
      );
    }

    return RuleCheckResult(
      issues: issues.take(maxIssues).toList(growable: false),
      total: total,
    );
  }

  /// 截断到 [maxChars] 个字符，末尾加省略号。
  static String clip(String text, int maxChars) => _clip(text, maxChars);

  static String _clip(String text, int maxChars) {
    final runes = text.runes;
    if (runes.length <= maxChars) return text;
    return '${String.fromCharCodes(runes.take(maxChars))}…';
  }
}
