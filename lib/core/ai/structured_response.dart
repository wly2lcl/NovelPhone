import '../../models/setting_type.dart';
import '../../models/story_state_kind.dart';
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

/// 一条 AI 提取出的故事状态变化（ENH-35）。
class StoryStateSuggestion {
  const StoryStateSuggestion({
    required this.kind,
    required this.title,
    this.detail = '',
    this.status = 'open',
  });

  final StoryStateKind kind;
  final String title;
  final String detail;
  final String status;

  bool get closes => status == 'closed';

  /// 与现有卡片对照时使用的键（同类同名视为同一张卡）。
  String get key => '${kind.value}|${title.trim().toLowerCase()}';
}

/// 故事状态提取解析结果。
class StoryStateExtraction {
  const StoryStateExtraction({
    this.suggestions = const <StoryStateSuggestion>[],
    this.relationChanges = const <RelationChangeSuggestion>[],
    this.parseFailed = false,
  });

  final List<StoryStateSuggestion> suggestions;

  /// 本章识别出的人物关系变化（ENH-56），作者勾选后写入关系图。
  final List<RelationChangeSuggestion> relationChanges;

  /// 模型输出不是可解析的 JSON。
  final bool parseFailed;

  bool get isEmpty => suggestions.isEmpty && relationChanges.isEmpty;
}

/// 一条 AI 识别的人物关系变化（ENH-56）。
class RelationChangeSuggestion {
  const RelationChangeSuggestion({
    required this.from,
    required this.to,
    this.label = '',
    this.action = 'add',
  });

  /// 两端角色名（应与角色卡名称或别名一致）。
  final String from;
  final String to;

  /// 关系称谓，如「师姐」「宿敌」。
  final String label;

  /// 归一化后的动作：add（新增）/ update（修改称谓）/ remove（解除）。
  final String action;

  /// 与既有关系对照的键：无向配对 + 称谓（关系图为有向边，但变化识别按两端人物判断）。
  String get key {
    final a = from.trim().toLowerCase();
    final b = to.trim().toLowerCase();
    return a.compareTo(b) <= 0 ? '$a|$b' : '$b|$a';
  }
}

/// 归一化关系变化动作词。
String _relationChangeAction(String raw) {
  final value = raw.toLowerCase();
  if (value.contains('remove') ||
      value.contains('delete') ||
      value.contains('解除') ||
      value.contains('删除') ||
      value.contains('决裂')) {
    return 'remove';
  }
  if (value.contains('update') ||
      value.contains('change') ||
      value.contains('修改') ||
      value.contains('更新') ||
      value.contains('转变')) {
    return 'update';
  }
  return 'add';
}

/// 解析本章状态变化 JSON（ENH-35）。
/// 兼容 `{"states":[...]}`、按类型分组以及直接返回数组三种写法。
StoryStateExtraction parseStoryStateExtractionResponse(String raw) {
  final decoded = extractJson(raw);
  if (decoded is! Map && decoded is! List) {
    return const StoryStateExtraction(parseFailed: true);
  }

  final items = <(Map<dynamic, dynamic>, StoryStateKind?)>[];
  void collect(dynamic node, StoryStateKind? hint) {
    if (node is Map) items.add((node, hint));
  }

  // ENH-56：关系变化单独收集（relationChanges / relations / 关系变化 / 关系）。
  final relationChanges = <String, RelationChangeSuggestion>{};
  void collectRelationChanges(Map<dynamic, dynamic> map) {
    for (final key in const <String>[
      'relationChanges',
      'relations',
      '关系变化',
      '关系',
    ]) {
      final value = map[key];
      if (value is! List) continue;
      for (final item in value) {
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
        if (from.isEmpty || to.isEmpty || from == to) continue;
        final change = RelationChangeSuggestion(
          from: from,
          to: to,
          label: readJsonText(item, const [
            'label',
            'relation',
            '称谓',
            '关系',
            '描述',
          ]),
          action: _relationChangeAction(
            readJsonString(item, const [
              'action',
              'relationAction',
              '变化类型',
              '操作',
              '变化',
            ]),
          ),
        );
        relationChanges[change.key] = change;
      }
      if (relationChanges.isNotEmpty) break;
    }
  }

  if (decoded is List) {
    for (final item in decoded) {
      collect(item, null);
    }
  } else {
    final map = decoded as Map;
    collectRelationChanges(map);
    var wrapped = false;
    for (final key in const <String>[
      'states',
      '状态',
      '状态变化',
      'storyStates',
      'updates',
      'changes',
    ]) {
      final value = map[key];
      if (value is List) {
        for (final item in value) {
          collect(item, null);
        }
        wrapped = true;
        break;
      }
    }
    if (!wrapped) {
      const groups = <(List<String>, StoryStateKind)>[
        (<String>['characters', '角色', '角色状态'], StoryStateKind.character),
        (<String>['foreshadows', '伏笔'], StoryStateKind.foreshadow),
        (<String>['timeline', '时间线', '事件'], StoryStateKind.timeline),
      ];
      for (final group in groups) {
        for (final item in _listOf(map, group.$1)) {
          collect(item, group.$2);
        }
      }
      if (items.isEmpty &&
          (map.containsKey('title') || map.containsKey('标题'))) {
        collect(map, null);
      }
    }
  }

  final suggestions = <String, StoryStateSuggestion>{};
  for (final (item, hint) in items) {
    final title = readJsonString(item, const [
      'title',
      'name',
      '标题',
      '名称',
      '角色',
      '卡片',
    ]);
    if (title.isEmpty) continue;
    final kind =
        hint ??
        _storyStateKind(
          readJsonString(item, const ['kind', 'type', '类型', '类别']),
        );
    final detail = readJsonText(item, const [
      'detail',
      'content',
      'description',
      '详情',
      '内容',
      '描述',
      '变化',
      '状态',
    ]);
    final status = _storyStateStatus(
      readJsonString(item, const ['status', 'state', '伏笔状态', '卡片状态']),
    );
    final suggestion = StoryStateSuggestion(
      kind: kind,
      title: title,
      detail: detail,
      status: status,
    );
    // 同类同名以最后一条为准：模型常先写“角色状态”再补充细节。
    suggestions[suggestion.key] = suggestion;
    if (suggestions.length >= 30) break;
  }
  return StoryStateExtraction(
    suggestions: suggestions.values.toList(growable: false),
    relationChanges: relationChanges.values.take(10).toList(growable: false),
  );
}

StoryStateKind _storyStateKind(String raw) {
  final value = raw.toLowerCase();
  if (value.contains('伏笔') ||
      value.contains('foreshadow') ||
      value.contains('clue')) {
    return StoryStateKind.foreshadow;
  }
  if (value.contains('时间') ||
      value.contains('timeline') ||
      value.contains('event')) {
    return StoryStateKind.timeline;
  }
  return StoryStateKind.character;
}

String _storyStateStatus(String raw) {
  final value = raw.toLowerCase();
  if (value.contains('closed') ||
      value.contains('resolved') ||
      value.contains('回收') ||
      value.contains('解决') ||
      value.contains('闭合')) {
    return 'closed';
  }
  return 'open';
}

/// 一条设定一致性冲突（ENH-38）。
class ContinuityIssue {
  const ContinuityIssue({
    required this.quote,
    this.detail = '',
    this.source = '',
    this.suggestion = '',
    this.severity = 'medium',
  });

  /// 本章正文中的冲突原文，用于在编辑器里定位。
  final String quote;

  /// 与哪条设定冲突。
  final String detail;

  /// 来源卡片：角色卡 / 设定集 / 故事状态 / 章纲。
  final String source;

  /// 建议改法。
  final String suggestion;

  /// high / medium / low。
  final String severity;

  String get key =>
      '${quote.trim().toLowerCase()}|${source.trim().toLowerCase()}';
}

/// 一致性检查结构化结果（ENH-38）。
class ContinuityCheckResult {
  const ContinuityCheckResult({
    this.summary = '',
    this.issues = const <ContinuityIssue>[],
    this.rawText = '',
    this.parseFailed = false,
  });

  final String summary;
  final List<ContinuityIssue> issues;

  /// 模型输出不是可解析 JSON 时的原文，供界面回退展示。
  final String rawText;

  /// 无法从输出中识别出 summary / issues。
  final bool parseFailed;

  bool get clean => !parseFailed && issues.isEmpty;
}

/// 解析一致性检查 JSON（ENH-38）。
/// 兼容 `{"summary":...,"issues":[...]}`、裸数组、单条问题对象与中英文键名；
/// 无法识别时保留原文并标记 [ContinuityCheckResult.parseFailed]。
ContinuityCheckResult parseContinuityResponse(String raw) {
  final text = raw.trim();
  final decoded = extractJson(text);
  if (decoded is! Map && decoded is! List) {
    return ContinuityCheckResult(rawText: text, parseFailed: true);
  }
  if (decoded is List && decoded.isEmpty) {
    return const ContinuityCheckResult();
  }
  var recognized = false;
  var summary = '';
  final issues = <ContinuityIssue>[];
  final seen = <String>{};

  for (final root in _rootMaps(decoded)) {
    final rootSummary = readJsonString(root, const [
      'summary',
      '结论',
      '总结',
      '说明',
      'overview',
      'result',
    ]);
    if (rootSummary.isNotEmpty) {
      if (summary.isEmpty) summary = rootSummary;
      recognized = true;
    }

    List<dynamic> items = const <dynamic>[];
    for (final key in const <String>[
      'issues',
      'conflicts',
      'problems',
      '问题',
      '冲突',
      '冲突列表',
      '一致性冲突',
      'continuityIssues',
    ]) {
      final value = root[key];
      if (value is List) {
        items = value;
        recognized = true;
        break;
      }
    }
    if (items.isEmpty && _looksLikeIssue(root)) {
      items = <dynamic>[root];
    }

    for (final item in items) {
      if (item is! Map) continue;
      final issue = _continuityIssue(item);
      if (issue == null || !seen.add(issue.key)) continue;
      issues.add(issue);
      if (issues.length >= 20) break;
    }
    if (issues.length >= 20) break;
  }

  if (!recognized && issues.isEmpty) {
    return ContinuityCheckResult(rawText: text, parseFailed: true);
  }
  return ContinuityCheckResult(summary: summary, issues: issues);
}

bool _looksLikeIssue(Map<dynamic, dynamic> map) {
  const keys = <String>[
    'quote',
    'original',
    '原文',
    '冲突原文',
    '引用',
    'suggestion',
    '建议',
  ];
  return keys.any(map.containsKey);
}

ContinuityIssue? _continuityIssue(Map<dynamic, dynamic> item) {
  final quote = readJsonString(item, const [
    'quote',
    'original',
    'text',
    '原文',
    '冲突原文',
    '引用',
    '选段',
    '句子',
  ]);
  final detail = readJsonText(item, const [
    'detail',
    'conflict',
    'setting',
    'reason',
    'description',
    '说明',
    '冲突',
    '冲突的设定',
    '设定',
    '原因',
  ]);
  final source = readJsonString(item, const [
    'source',
    'card',
    'origin',
    '来源',
    '卡片',
    '来源卡片',
    '设定来源',
  ]);
  final suggestion = readJsonText(item, const [
    'suggestion',
    'fix',
    'advice',
    '建议',
    '建议改法',
    '改法',
    '修改建议',
  ]);
  if (quote.isEmpty && detail.isEmpty && suggestion.isEmpty) return null;
  return ContinuityIssue(
    quote: quote,
    detail: detail,
    source: source,
    suggestion: suggestion,
    severity: _continuitySeverity(
      readJsonString(item, const ['severity', 'level', '严重程度', '级别']),
    ),
  );
}

String _continuitySeverity(String raw) {
  final value = raw.toLowerCase();
  if (value.contains('high') ||
      value.contains('crit') ||
      value.contains('error') ||
      value.contains('严重') ||
      value.contains('高')) {
    return 'high';
  }
  if (value.contains('low') ||
      value.contains('minor') ||
      value.contains('info') ||
      value.contains('轻微') ||
      value.contains('低') ||
      value.contains('提示')) {
    return 'low';
  }
  return 'medium';
}

/// 在正文中定位冲突原文（ENH-38）。
/// 先精确匹配；找不到时忽略空白差异，并容忍模型给原文加的引号。
({int start, int end})? findContinuityQuote(String content, String quote) {
  final cleaned = _trimQuoteMarks(quote.trim());
  if (cleaned.isEmpty || content.isEmpty) return null;
  final direct = content.indexOf(cleaned);
  if (direct >= 0) {
    return (start: direct, end: direct + cleaned.length);
  }

  final compactQuote = cleaned.replaceAll(RegExp(r'\s+'), '');
  if (compactQuote.isEmpty) return null;
  final positions = <int>[];
  final compact = StringBuffer();
  for (var i = 0; i < content.length; i++) {
    final char = content[i];
    if (RegExp(r'\s').hasMatch(char)) continue;
    compact.write(char);
    positions.add(i);
  }
  final index = compact.toString().indexOf(compactQuote);
  if (index < 0) return null;
  return (
    start: positions[index],
    end: positions[index + compactQuote.length - 1] + 1,
  );
}

String _trimQuoteMarks(String value) {
  const marks = <String>['「', '」', '『', '』', '“', '”', '"', "'", '‘', '’'];
  var result = value;
  var changed = true;
  while (changed && result.isNotEmpty) {
    changed = false;
    for (final mark in marks) {
      if (result.startsWith(mark)) {
        result = result.substring(mark.length);
        changed = true;
      }
      if (result.endsWith(mark)) {
        result = result.substring(0, result.length - mark.length);
        changed = true;
      }
    }
  }
  return result.trim();
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
