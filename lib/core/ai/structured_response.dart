import '../../models/setting_type.dart';
import '../../models/work_style_guide.dart';
import 'json_extract.dart';

/// 解析文风档案提取结果（ENH-23）。字段缺失时沿用 [fallback]。
WorkStyleGuide? parseStyleGuideResponse(
  String raw, {
  WorkStyleGuide fallback = WorkStyleGuide.empty,
}) {
  final decoded = extractJson(raw);
  if (decoded is! Map) return null;
  String pickString(List<String> keys, String current) {
    final value = readJsonString(decoded, keys);
    return value.isEmpty ? current : value;
  }

  String pickText(List<String> keys, String current, String separator) {
    final value = readJsonText(decoded, keys, separator: separator);
    return value.isEmpty ? current : value;
  }

  final guide = fallback.copyWith(
    perspective: pickString(const [
      'perspective',
      '叙事人称',
      '人称视角',
      '视角',
      '人称',
    ], fallback.perspective),
    tone: pickString(const ['tone', '语言风格', '文风', '风格', '基调'], fallback.tone),
    taboos: pickText(
      const ['taboos', '禁忌', '偏好', '注意事项', '避免'],
      fallback.taboos,
      '；',
    ),
    sample: pickString(const ['sample', '示例段落', '示例', '样例'], fallback.sample),
  );
  return guide.isEmpty ? null : guide;
}

/// 抽取出的角色卡（ENH-23 设定补全）。
class ExtractedCharacter {
  const ExtractedCharacter({
    required this.name,
    this.identity = '',
    this.personality = '',
    this.appearance = '',
    this.relations = '',
    this.arc = '',
  });

  final String name;
  final String identity;
  final String personality;
  final String appearance;
  final String relations;
  final String arc;

  String get summary => <String>[
    if (identity.isNotEmpty) identity,
    if (personality.isNotEmpty) personality,
    if (appearance.isNotEmpty) appearance,
  ].join(' · ');
}

/// 抽取出的设定条目（ENH-23 设定补全）。
class ExtractedSetting {
  const ExtractedSetting({
    required this.type,
    required this.name,
    this.content = '',
  });

  final SettingType type;
  final String name;
  final String content;
}

/// 抽取出的角色关系（ENH-24 设定补全）：from → to 的有向关系。
class ExtractedRelation {
  const ExtractedRelation({
    required this.from,
    required this.to,
    this.label = '',
  });

  final String from;
  final String to;
  final String label;

  String get key =>
      '${from.trim().toLowerCase()}|${to.trim().toLowerCase()}|${label.trim().toLowerCase()}';

  String get summary =>
      <String>['$from → $to', if (label.isNotEmpty) label].join(' · ');
}

/// 设定补全解析结果。
class EntityExtraction {
  const EntityExtraction({
    this.characters = const <ExtractedCharacter>[],
    this.settings = const <ExtractedSetting>[],
    this.relations = const <ExtractedRelation>[],
    this.parseFailed = false,
  });

  final List<ExtractedCharacter> characters;
  final List<ExtractedSetting> settings;
  final List<ExtractedRelation> relations;
  final bool parseFailed;

  bool get isEmpty =>
      characters.isEmpty && settings.isEmpty && relations.isEmpty;
  int get total => characters.length + settings.length + relations.length;
}

/// 解析设定补全 JSON（ENH-23）。容忍中英文键名与数组/字符串两种值。
EntityExtraction parseEntityExtractionResponse(String raw) {
  final roots = _rootMaps(extractJson(raw));
  if (roots.isEmpty) {
    return const EntityExtraction(parseFailed: true);
  }
  final characters = <ExtractedCharacter>[];
  final characterSeen = <String>{};
  final settings = <ExtractedSetting>[];
  final settingSeen = <String>{};
  final relations = <ExtractedRelation>[];
  final relationSeen = <String>{};
  for (final root in roots) {
    for (final item in _listOf(root, const ['characters', '角色', '角色卡'])) {
      if (item is! Map) continue;
      final name = readJsonString(item, const ['name', '名字', '姓名', '名称']);
      if (name.isEmpty || !characterSeen.add(name.toLowerCase())) continue;
      characters.add(
        ExtractedCharacter(
          name: name,
          identity: readJsonString(item, const ['identity', '身份', '职业']),
          personality: readJsonText(item, const [
            'personality',
            '性格',
            '性格标签',
          ], separator: '、'),
          appearance: readJsonText(item, const [
            'appearance',
            '外貌',
            '外形',
          ], separator: '；'),
          relations: readJsonText(item, const [
            'relations',
            '关系',
            '人际关系',
          ], separator: '；'),
          arc: readJsonText(item, const ['arc', '弧光', '成长线']),
        ),
      );
    }

    for (final item in _listOf(root, const ['settings', '设定', '设定集'])) {
      if (item is! Map) continue;
      final name = readJsonString(item, const ['name', '名字', '名称']);
      if (name.isEmpty) continue;
      final type = _settingType(
        readJsonString(item, const ['type', '类型', '分类']),
      );
      if (!settingSeen.add('${type.value}|${name.toLowerCase()}')) continue;
      settings.add(
        ExtractedSetting(
          type: type,
          name: name,
          content: readJsonText(item, const ['content', '内容', '描述', '说明']),
        ),
      );
    }

    for (final item in _listOf(root, const [
      'relations',
      '关系',
      '人物关系',
      '角色关系',
    ])) {
      if (item is! Map) continue;
      final from = readJsonString(item, const [
        'from',
        'source',
        'fromName',
        '角色A',
        '甲',
        '起点',
      ]);
      final to = readJsonString(item, const [
        'to',
        'target',
        'toName',
        '角色B',
        '乙',
        '终点',
      ]);
      final label = readJsonText(item, const ['label', 'relation', '关系', '描述']);
      if (from.isEmpty || to.isEmpty || from == to) continue;
      final relation = ExtractedRelation(from: from, to: to, label: label);
      if (!relationSeen.add(relation.key)) continue;
      relations.add(relation);
    }
  }
  return EntityExtraction(
    characters: characters,
    settings: settings,
    relations: relations,
  );
}

/// 一条剧情走向（ENH-23 剧情推演）。
class PlotDirection {
  const PlotDirection({
    required this.title,
    required this.summary,
    this.beats = '',
    this.hook = '',
  });

  final String title;
  final String summary;

  /// 2~4 个推进步骤，按行分隔。
  final String beats;

  /// 看点 / 风险提示。
  final String hook;
}

/// 一条分章建议。
class PlotChapter {
  const PlotChapter({required this.title, required this.summary});

  final String title;
  final String summary;
}

/// 剧情推演解析结果；JSON 解析失败时保留原文作为单条走向，避免白屏。
class PlotPlan {
  const PlotPlan({
    this.directions = const <PlotDirection>[],
    this.chapters = const <PlotChapter>[],
    this.rawText = '',
  });

  final List<PlotDirection> directions;
  final List<PlotChapter> chapters;

  /// 解析失败时的原始输出。
  final String rawText;

  bool get isEmpty => directions.isEmpty && chapters.isEmpty && rawText.isEmpty;

  bool get parseFailed => rawText.isNotEmpty;
}

/// 解析剧情推演结果（ENH-23）。
PlotPlan parsePlotPlanResponse(String raw) {
  final roots = _rootMaps(extractJson(raw));
  if (roots.isEmpty) {
    final text = raw.trim();
    return PlotPlan(
      rawText: text,
      directions: text.isEmpty
          ? const <PlotDirection>[]
          : <PlotDirection>[PlotDirection(title: 'AI 剧情推演', summary: text)],
    );
  }

  final directions = <PlotDirection>[];
  final chapters = <PlotChapter>[];
  for (final root in roots) {
    for (final item in _listOf(root, const [
      'directions',
      '走向',
      '剧情走向',
      'direction',
    ])) {
      if (item is! Map) continue;
      final summary = readJsonText(item, const ['summary', '概括', '一句话', '说明']);
      final title = readJsonString(item, const ['title', '标题', '名称']);
      final beats = readJsonText(item, const [
        'beats',
        '展开',
        '要点',
        '步骤',
        '情节',
      ], separator: '\n');
      final hook = readJsonText(item, const ['hook', '钩子', '看点', '风险']);
      if (summary.isEmpty && title.isEmpty && beats.isEmpty) continue;
      directions.add(
        PlotDirection(
          title: title.isEmpty ? '剧情走向 ${directions.length + 1}' : title,
          summary: summary.isEmpty ? beats : summary,
          beats: summary.isEmpty ? '' : beats,
          hook: hook,
        ),
      );
    }

    for (final item in _listOf(root, const [
      'chapters',
      '分章',
      '章节规划',
      'chapterPlans',
    ])) {
      if (item is! Map) continue;
      final title = readJsonString(item, const ['title', '标题', '章节']);
      final summary = readJsonText(item, const ['summary', '梗概', '摘要', '内容']);
      if (title.isEmpty && summary.isEmpty) continue;
      chapters.add(
        PlotChapter(
          title: title.isEmpty ? '第 ${chapters.length + 1} 章' : title,
          summary: summary,
        ),
      );
    }
  }

  final plan = PlotPlan(directions: directions, chapters: chapters);
  if (!plan.isEmpty) return plan;
  // JSON 合法但字段名不匹配时保留原文，让界面明确提示解析失败而不是静默空白。
  return PlotPlan(rawText: raw.trim());
}

/// 模型可能返回单个对象或对象数组，统一成待遍历的根对象列表。
List<Map<dynamic, dynamic>> _rootMaps(dynamic decoded) {
  if (decoded is Map) return <Map<dynamic, dynamic>>[decoded];
  if (decoded is List) {
    return decoded.whereType<Map<dynamic, dynamic>>().toList();
  }
  return const <Map<dynamic, dynamic>>[];
}

List<dynamic> _listOf(Map<dynamic, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is List) return value;
  }
  return const <dynamic>[];
}

SettingType _settingType(String raw) {
  final value = raw.trim();
  if (value.contains('地点') ||
      value.contains('场景') ||
      value.contains('城') ||
      value.toLowerCase().contains('location')) {
    return SettingType.location;
  }
  if (value.contains('道具') ||
      value.contains('物品') ||
      value.toLowerCase().contains('item')) {
    return SettingType.item;
  }
  return SettingType.worldview;
}
