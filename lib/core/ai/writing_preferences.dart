/// AI 协作偏好（ENH-27）：忽略原因、采纳片段与 prompt 注入文本。
///
/// 纯逻辑模块，便于单测；存储由 `SettingsRepository` 负责，只保存在本机。
library;

import 'dart:convert';

import 'continuity_suppression.dart';

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
  const AdoptedSample({
    required this.text,
    required this.task,
    this.source = '',
    this.createdAt,
  });

  /// 作者最终采用的文本。
  final String text;

  /// 模型原稿（ENH-42）：仅在作者做过轻度～中度修改时保存，用于学习取舍。
  final String source;
  final String task;
  final DateTime? createdAt;

  bool get hasSource =>
      source.trim().isNotEmpty && source.trim() != text.trim();

  Map<String, dynamic> toJson() => <String, dynamic>{
    'text': text,
    'task': task,
    if (source.isNotEmpty) 'source': source,
    if (createdAt != null) 'at': createdAt!.toIso8601String(),
  };

  static AdoptedSample? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final text = (raw['text'] as String?)?.trim() ?? '';
    if (text.isEmpty) return null;
    return AdoptedSample(
      text: text,
      source: (raw['source'] as String?)?.trim() ?? '',
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

  /// 分段采纳时未勾选段落的反馈计数（ENH-29，与整篇放弃分开统计）。
  static String paragraphFeedbackKey(int workId) =>
      'ai_paragraph_feedback_$workId';

  /// 作品永久删除时一并清理的偏好键（含 ENH-41 一致性忽略项）。
  static List<String> keysFor(int workId) => <String>[
    feedbackKey(workId),
    adoptedSamplesKey(workId),
    enabledKey(workId),
    paragraphFeedbackKey(workId),
    ContinuitySuppressions.storageKey(workId),
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
    final source = _clip(sample.source.trim(), maxSampleChars);
    final next = <AdoptedSample>[
      AdoptedSample(
        text: text,
        source: source == text ? '' : source,
        task: sample.task,
        createdAt: sample.createdAt,
      ),
      ...existing.where((s) => s.text != text),
    ];
    return next.take(maxSamples).toList(growable: false);
  }

  /// 生成注入 system 的「作者协作偏好」文本；无高频原因与样本时返回空串。
  ///
  /// [preferredTask] 用于优先选取与本次任务相同的采纳片段（ENH-29）。
  static String promptBlock({
    required Map<String, int> reasonCounts,
    required List<AdoptedSample> samples,
    String preferredTask = '',
  }) {
    final rules = <String>[];
    for (final reason in AiFeedbackReason.all) {
      if ((reasonCounts[reason] ?? 0) < AiFeedbackReason.minPromptCount) {
        continue;
      }
      final rule = AiFeedbackReason.rule(reason);
      if (rule != null) rules.add(rule);
    }
    final eligible = samples
        .where((s) => s.text.trim().isNotEmpty)
        .toList(growable: false);
    final usable = <AdoptedSample>[
      ...eligible.where((s) => s.task == preferredTask),
      ...eligible.where((s) => s.task != preferredTask),
    ].take(promptSampleCount).toList(growable: false);
    if (rules.isEmpty && usable.isEmpty) return '';

    final buffer = StringBuffer('【作者协作偏好】');
    if (rules.isNotEmpty) {
      buffer.writeln('作者近期放弃过以下 AI 产出，请规避同类问题：');
      for (final rule in rules) {
        buffer.writeln('- $rule');
      }
    }
    if (usable.isNotEmpty) {
      buffer.writeln(
        '以下是作者最近采纳的写法片段，请参考其语气、节奏与细节密度（不要照抄内容）；'
        '带「模型原稿 → 作者定稿」的样本，重点学习作者的取舍与改写方式：',
      );
      for (var i = 0; i < usable.length; i++) {
        final sample = usable[i];
        if (sample.hasSource) {
          buffer.writeln('${i + 1}. 模型原稿：${_oneLine(sample.source)}');
          buffer.writeln('   作者定稿：${_oneLine(sample.text)}');
        } else {
          buffer.writeln('${i + 1}. ${_oneLine(sample.text)}');
        }
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
