/// AI 协作偏好（ENH-27）：忽略原因、采纳片段与 prompt 注入文本。
///
/// 纯逻辑模块，便于单测；存储由 `SettingsRepository` 负责，只保存在本机。
library;

import 'dart:convert';

/// 作者放弃 AI 结果时选择的原因。
class AiFeedbackReason {
  const AiFeedbackReason._();

  static const String tooAi = 'too_ai';
  static const String offCharacter = 'off_character';
  static const String slowPace = 'slow_pace';
  static const String offSetting = 'off_setting';
  static const String other = 'other';

  static const List<String> all = <String>[
    tooAi,
    offCharacter,
    slowPace,
    offSetting,
    other,
  ];

  /// 原因对应的写作约束；[other] 不参与 prompt。
  static String? rule(String reason) {
    switch (reason) {
      case tooAi:
        return '避免空泛抒情、排比和总结式套话，多用具体动作、对话与感官细节推进。';
      case offCharacter:
        return '严格贴合相关角色卡的性格、身份与说话方式，避免角色出戏（OOC）。';
      case slowPace:
        return '加快叙事节奏，删减重复铺垫与解释，直接进入事件、冲突或转折。';
      case offSetting:
        return '严格遵守设定集中的世界观、地点、道具与既有事实，不新增冲突设定。';
      default:
        return null;
    }
  }

  /// 反馈计入 prompt 的最低次数：单次放弃可能只是偶然。
  static const int minPromptCount = 2;
}

/// 最近被作者采纳的 AI 片段（本地样本，用于参考语气与节奏）。
class AdoptedSample {
  const AdoptedSample({required this.text, required this.task, this.createdAt});

  final String text;
  final String task;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'text': text,
    'task': task,
    if (createdAt != null) 'at': createdAt!.toIso8601String(),
  };

  static AdoptedSample? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final text = (raw['text'] as String?)?.trim() ?? '';
    if (text.isEmpty) return null;
    return AdoptedSample(
      text: text,
      task: (raw['task'] as String?)?.trim() ?? '',
      createdAt: DateTime.tryParse((raw['at'] as String?) ?? ''),
    );
  }
}

/// 偏好与样本的解析、裁剪与注入文本生成。
class WritingPreferences {
  const WritingPreferences._();

  static String feedbackKey(int workId) => 'ai_feedback_$workId';
  static String adoptedSamplesKey(int workId) => 'ai_adopted_samples_$workId';
  static String enabledKey(int workId) => 'ai_preferences_enabled_$workId';

  /// 作品永久删除时一并清理的偏好键。
  static List<String> keysFor(int workId) => <String>[
    feedbackKey(workId),
    adoptedSamplesKey(workId),
    enabledKey(workId),
  ];

  /// 本地最多保留的采纳片段数。
  static const int maxSamples = 5;

  /// 单条采纳片段的最大存储字数。
  static const int maxSampleChars = 600;

  /// 注入 prompt 时最多参考的片段数与单条字数。
  static const int promptSampleCount = 3;
  static const int promptSampleChars = 200;

  static Map<String, int> parseReasonCounts(String? raw) {
    if (raw == null || raw.trim().isEmpty) return <String, int>{};
    try {
      final decoded = jsonDecode(raw);
      final map = decoded is Map && decoded['counts'] is Map
          ? decoded['counts'] as Map
          : decoded;
      if (map is! Map) return <String, int>{};
      final result = <String, int>{};
      for (final reason in AiFeedbackReason.all) {
        final value = map[reason];
        final count = value is int ? value : int.tryParse('$value');
        if (count != null && count > 0) result[reason] = count;
      }
      return result;
    } catch (_) {
      // 容忍历史脏数据。
      return <String, int>{};
    }
  }

  static String encodeReasonCounts(Map<String, int> counts) =>
      jsonEncode(counts);

  static List<AdoptedSample> parseSamples(String? raw) {
    if (raw == null || raw.trim().isEmpty) return <AdoptedSample>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <AdoptedSample>[];
      return decoded
          .map(AdoptedSample.tryParse)
          .whereType<AdoptedSample>()
          .take(maxSamples)
          .toList(growable: false);
    } catch (_) {
      return <AdoptedSample>[];
    }
  }

  static String encodeSamples(List<AdoptedSample> samples) =>
      jsonEncode(samples.take(maxSamples).map((s) => s.toJson()).toList());

  /// 新样本置顶、去重并限制条数与长度；无有效内容时原样返回。
  static List<AdoptedSample> addSample(
    List<AdoptedSample> existing,
    AdoptedSample sample,
  ) {
    final text = _clip(sample.text.trim(), maxSampleChars);
    if (text.isEmpty) return existing;
    final next = <AdoptedSample>[
      AdoptedSample(text: text, task: sample.task, createdAt: sample.createdAt),
      ...existing.where((s) => s.text != text),
    ];
    return next.take(maxSamples).toList(growable: false);
  }

  /// 生成注入 system 的「作者协作偏好」文本；无高频原因与样本时返回空串。
  static String promptBlock({
    required Map<String, int> reasonCounts,
    required List<AdoptedSample> samples,
  }) {
    final rules = <String>[];
    for (final reason in AiFeedbackReason.all) {
      if ((reasonCounts[reason] ?? 0) < AiFeedbackReason.minPromptCount) {
        continue;
      }
      final rule = AiFeedbackReason.rule(reason);
      if (rule != null) rules.add(rule);
    }
    final usable = samples
        .where((s) => s.text.trim().isNotEmpty)
        .take(promptSampleCount)
        .toList(growable: false);
    if (rules.isEmpty && usable.isEmpty) return '';

    final buffer = StringBuffer('【作者协作偏好】');
    if (rules.isNotEmpty) {
      buffer.writeln('作者近期放弃过以下 AI 产出，请规避同类问题：');
      for (final rule in rules) {
        buffer.writeln('- $rule');
      }
    }
    if (usable.isNotEmpty) {
      buffer.writeln('以下是作者最近采纳的写法片段，请参考其语气、节奏与细节密度（不要照抄内容）：');
      for (var i = 0; i < usable.length; i++) {
        buffer.writeln('${i + 1}. ${_oneLine(usable[i].text)}');
      }
    }
    return buffer.toString().trim();
  }

  static String _oneLine(String text) =>
      _clip(text.replaceAll(RegExp(r'\s+'), ' ').trim(), promptSampleChars);

  static String _clip(String text, int maxChars) {
    final runes = text.runes;
    if (runes.length <= maxChars) return text;
    return '${String.fromCharCodes(runes.take(maxChars))}…';
  }
}
