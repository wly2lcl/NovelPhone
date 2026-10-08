import 'flavor_lexicon.dart';
import 'word_count.dart';

/// 问题类型枚举（PRD 5.7 / 6.1：套话 / 句式重复 / 翻译腔 / 过度总结 / 节奏拖沓）。
class FlavorType {
  const FlavorType._();

  static const String cliche = '套话';
  static const String repetition = '句式重复';
  static const String translationese = '翻译腔';
  static const String oversummary = '过度总结';
  static const String pacing = '节奏拖沓';

  static const List<String> all = <String>[
    cliche,
    repetition,
    translationese,
    oversummary,
    pacing,
  ];
}

/// 严重度（M4-08）：统一为高/中/低三级，用 3/2/1 表示便于排序与去重取高。
class FlavorSeverity {
  const FlavorSeverity._();

  static const int high = 3;
  static const int medium = 2;
  static const int low = 1;

  static String label(int severity) {
    if (severity >= high) return '高';
    if (severity == medium) return '中';
    return '低';
  }
}

/// 问题来源：规则引擎 / LLM 深检（两层合并时保留来源）。
class FlavorSource {
  const FlavorSource._();

  static const String rule = 'rule';
  static const String llm = 'llm';
}

/// 一条 AI 味问题。位置为原文的字符偏移（start/end）；
/// start == end 表示全文级提示（如密度超阈值），不可定位到具体段落。
class FlavorIssue {
  const FlavorIssue({
    required this.type,
    required this.severity,
    required this.start,
    required this.end,
    required this.message,
    this.excerpt = '',
    this.suggestion,
    this.replacement,
    this.source = FlavorSource.rule,
  });

  final String type;
  final int severity;
  final int start;
  final int end;
  final String message;
  final String excerpt;

  /// 给作者看的修改建议。
  final String? suggestion;

  /// 可直接替换原文的文本；null 表示不支持一键替换（只能定位 / 忽略）。
  final String? replacement;
  final String source;

  bool get isDocumentLevel => start == end;

  FlavorIssue copyWith({int? severity, String? suggestion, String? replacement}) {
    return FlavorIssue(
      type: type,
      severity: severity ?? this.severity,
      start: start,
      end: end,
      message: message,
      excerpt: excerpt,
      suggestion: suggestion ?? this.suggestion,
      replacement: replacement ?? this.replacement,
      source: source,
    );
  }
}

/// 统计指标（M4-03）：套话密度、句式重复率、破折号/省略号频率。
class FlavorMetrics {
  const FlavorMetrics({
    required this.wordCount,
    required this.paragraphCount,
    required this.clicheHits,
    required this.clicheDensity,
    required this.repeatedStructureParagraphs,
    required this.patternRepeatRate,
    required this.ellipsisCount,
    required this.dashCount,
    required this.punctuationDensity,
  });

  static const FlavorMetrics empty = FlavorMetrics(
    wordCount: 0,
    paragraphCount: 0,
    clicheHits: 0,
    clicheDensity: 0,
    repeatedStructureParagraphs: 0,
    patternRepeatRate: 0,
    ellipsisCount: 0,
    dashCount: 0,
    punctuationDensity: 0,
  );

  final int wordCount;
  final int paragraphCount;

  /// 全部权重套话命中次数（含低权重）。
  final int clicheHits;

  /// 套话密度：每千字命中次数。
  final double clicheDensity;

  /// 参与"同结构连续段落"的段落数。
  final int repeatedStructureParagraphs;

  /// 句式重复率：同结构段落数 / 总段落数。
  final double patternRepeatRate;

  final int ellipsisCount;
  final int dashCount;

  /// 破折号 + 省略号密度：每千字出现次数。
  final double punctuationDensity;
}

/// 规则引擎结果。
class FlavorResult {
  const FlavorResult({required this.issues, required this.metrics});

  static const FlavorResult empty = FlavorResult(
    issues: <FlavorIssue>[],
    metrics: FlavorMetrics.empty,
  );

  final List<FlavorIssue> issues;
  final FlavorMetrics metrics;

  bool get isEmpty => issues.isEmpty;
}

/// 套话密度告警阈值（每千字命中次数）。
const double clicheDensityThreshold = 12;

/// 破折号 + 省略号密度告警阈值（每千字出现次数）。
const double punctuationDensityThreshold = 8;

/// 密度类判断的最小样本量：少于该字数的文本不做密度告警，避免短章误报。
const int densityMinWords = 300;

/// 同一套话重复出现达到该次数时给出"句式重复"提示。
const int repeatedWordThreshold = 4;

/// 规则引擎（M4-02 / M4-04）：纯函数，输入章节文本，输出问题清单与指标。
///
/// [minWeight] 以下的词条只计入密度指标、不逐条报问题（控制低权重词误报）；
/// [maxIssues] 限制返回条数，避免长文刷屏。
FlavorResult runFlavorRules(
  String text, {
  int minWeight = FlavorSeverity.medium,
  int maxIssues = 300,
}) {
  if (text.trim().isEmpty) return FlavorResult.empty;

  final paragraphs = _splitParagraphs(text);
  final words = countWords(text);
  final matches = _matchLexicon(text);
  final issues = <FlavorIssue>[];

  // 1. 套话逐条命中（权重 >= minWeight 才报问题）。
  final perWordCount = <String, int>{};
  final perWordFirst = <String, FlavorIssue>{};
  for (final match in matches) {
    perWordCount[match.entry.word] = (perWordCount[match.entry.word] ?? 0) + 1;
    if (match.entry.weight < minWeight) continue;
    final issue = FlavorIssue(
      type: FlavorType.cliche,
      severity: match.entry.weight,
      start: match.start,
      end: match.end,
      excerpt: match.entry.word,
      message: '套话「${match.entry.word}」',
      suggestion: _suggestionFor(match.entry),
      replacement: match.entry.replacement,
    );
    perWordFirst.putIfAbsent(match.entry.word, () => issue);
    issues.add(issue);
  }

  // 2. 同一套话重复出现 → 句式重复（保留首次位置便于定位）。
  for (final entry in perWordCount.entries) {
    if (entry.value < repeatedWordThreshold) continue;
    final first = perWordFirst[entry.key];
    issues.add(FlavorIssue(
      type: FlavorType.repetition,
      severity: FlavorSeverity.medium,
      start: first?.start ?? 0,
      end: first?.end ?? 0,
      excerpt: entry.key,
      message: '「${entry.key}」在本章出现 ${entry.value} 次，重复明显',
    ));
  }

  // 3. 句式模式（对话标签 / 翻译腔）。
  issues.addAll(_matchPatterns(text));

  // 4. 段落级模式（段尾感悟句 / 连续同结构段落）。
  final structure = _analyzeParagraphs(paragraphs);
  issues.addAll(structure.issues);

  // 5. 指标阈值（全文级提示）。
  final clicheDensity = words == 0 ? 0.0 : matches.length * 1000 / words;
  if (words >= densityMinWords && clicheDensity > clicheDensityThreshold) {
    issues.add(FlavorIssue(
      type: FlavorType.cliche,
      severity: FlavorSeverity.high,
      start: 0,
      end: 0,
      message: '套话密度偏高：每千字 ${clicheDensity.toStringAsFixed(1)} 处',
      suggestion: '整体减少套话，改为具体动作、神态与细节描写',
    ));
  }
  final ellipsisCount = '…'.allMatches(text).length + '......'.allMatches(text).length;
  final dashCount = '—'.allMatches(text).length;
  final punctuationDensity = words == 0 ? 0.0 : (ellipsisCount + dashCount) * 1000 / words;
  if (words >= densityMinWords && punctuationDensity > punctuationDensityThreshold) {
    issues.add(FlavorIssue(
      type: FlavorType.pacing,
      severity: FlavorSeverity.medium,
      start: 0,
      end: 0,
      message: '破折号/省略号偏多：每千字 ${punctuationDensity.toStringAsFixed(1)} 处，节奏显拖沓',
      suggestion: '精简省略号与破折号，改用完整的动作或对话推进',
    ));
  }

  final patternRepeatRate =
      paragraphs.isEmpty ? 0.0 : structure.repeatedParagraphs / paragraphs.length;
  final metrics = FlavorMetrics(
    wordCount: words,
    paragraphCount: paragraphs.length,
    clicheHits: matches.length,
    clicheDensity: clicheDensity,
    repeatedStructureParagraphs: structure.repeatedParagraphs,
    patternRepeatRate: patternRepeatRate,
    ellipsisCount: ellipsisCount,
    dashCount: dashCount,
    punctuationDensity: punctuationDensity,
  );

  sortFlavorIssues(issues);
  return FlavorResult(
    issues: issues.length > maxIssues
        ? List<FlavorIssue>.unmodifiable(issues.sublist(0, maxIssues))
        : List<FlavorIssue>.unmodifiable(issues),
    metrics: metrics,
  );
}

/// 按严重度降序、同级按原文位置升序（ARCHITECTURE 5.5）。
void sortFlavorIssues(List<FlavorIssue> issues) {
  issues.sort((a, b) {
    if (a.severity != b.severity) return b.severity.compareTo(a.severity);
    return a.start.compareTo(b.start);
  });
}

/// 段落级判定口径（M4-05 回归集）：是否存在可定位的"中"及以上问题。
/// 全文级密度提示不计入，避免短样本被密度指标带偏。
bool isFlavorFlagged(FlavorResult result) => result.issues
    .any((i) => !i.isDocumentLevel && i.severity >= FlavorSeverity.medium);

/// 两层结果合并去重（M4-08）：按「原文位置 + 类型」去重，同键保留严重度更高者，
/// 严重度相同时优先保留 LLM 深检（带建议）的那条；合并后统一排序。
List<FlavorIssue> mergeFlavorIssues(Iterable<FlavorIssue> issues) {
  final merged = <String, FlavorIssue>{};
  for (final issue in issues) {
    final key = issue.isDocumentLevel
        ? '${issue.type}|${issue.message}'
        : '${issue.type}|${issue.start}|${issue.end}';
    final existing = merged[key];
    if (existing == null) {
      merged[key] = issue;
      continue;
    }
    final preferNew = issue.severity > existing.severity ||
        (issue.severity == existing.severity &&
            issue.source == FlavorSource.llm &&
            existing.source != FlavorSource.llm);
    if (preferNew) merged[key] = issue;
  }
  final result = merged.values.toList();
  sortFlavorIssues(result);
  return List<FlavorIssue>.unmodifiable(result);
}

// ---------- 内部实现 ----------

String _suggestionFor(FlavorLexiconEntry entry) {
  final replacement = entry.replacement;
  if (replacement == null) return '结合上下文改写为具体动作、神态或细节';
  if (replacement.isEmpty) return '可直接删除该词，句子更干净';
  return '建议改为「$replacement」';
}

typedef _LexiconMatch = ({FlavorLexiconEntry entry, int start, int end});

/// 扫描全部词条命中，重叠时保留更长（更具体）的匹配，避免重复计数。
List<_LexiconMatch> _matchLexicon(String text) {
  final raw = <_LexiconMatch>[];
  for (final entry in flavorLexicon) {
    var index = text.indexOf(entry.word);
    while (index != -1) {
      raw.add((entry: entry, start: index, end: index + entry.word.length));
      index = text.indexOf(entry.word, index + entry.word.length);
    }
  }
  raw.sort((a, b) {
    if (a.start != b.start) return a.start.compareTo(b.start);
    final byLength = (b.end - b.start).compareTo(a.end - a.start);
    return byLength != 0 ? byLength : b.entry.weight.compareTo(a.entry.weight);
  });
  final accepted = <_LexiconMatch>[];
  var cursor = 0;
  for (final match in raw) {
    if (match.start < cursor) continue;
    accepted.add(match);
    cursor = match.end;
  }
  return accepted;
}

class _PatternRule {
  const _PatternRule({
    required this.type,
    required this.severity,
    required this.regex,
    required this.message,
    this.suggestion,
  });

  final String type;
  final int severity;
  final RegExp regex;
  final String message;
  final String? suggestion;
}

final List<_PatternRule> _patternRules = <_PatternRule>[
  // 模式化对话标签（M4-02）：副词 + 说/道 的固定搭配。
  _PatternRule(
    type: FlavorType.repetition,
    severity: FlavorSeverity.medium,
    regex: RegExp(r'(?:淡淡|轻轻|缓缓|冷冷|低声|沉声|柔声|轻声|沉声|笑着|苦笑|冷笑|微笑|无奈)(?:地)?(?:说道|开口|说道|说|道|回答|应道|答道)'),
    message: '模式化对话标签：副词 + 说/道 的固定搭配',
    suggestion: '用动作、神态或停顿替代"副词 + 说"',
  ),
  _PatternRule(
    type: FlavorType.translationese,
    severity: FlavorSeverity.medium,
    regex: RegExp(r'如此.{0,12}以至于'),
    message: '翻译腔：如此…以至于…',
  ),
  _PatternRule(
    type: FlavorType.translationese,
    severity: FlavorSeverity.medium,
    regex: RegExp(r'在.{0,10}的情况下'),
    message: '翻译腔：在…的情况下',
  ),
  _PatternRule(
    type: FlavorType.translationese,
    severity: FlavorSeverity.medium,
    regex: RegExp(r'对于.{0,10}来说'),
    message: '翻译腔：对于…来说',
  ),
  _PatternRule(
    type: FlavorType.translationese,
    severity: FlavorSeverity.medium,
    regex: RegExp(r'被认为(?:是|为)'),
    message: '翻译腔：被动式"被认为是"',
  ),
  _PatternRule(
    type: FlavorType.translationese,
    severity: FlavorSeverity.medium,
    regex: RegExp(r'当.{0,12}的时候'),
    message: '翻译腔：当…的时候',
  ),
  _PatternRule(
    type: FlavorType.translationese,
    severity: FlavorSeverity.low,
    regex: RegExp(r'使得'),
    message: '翻译腔：使得',
  ),
  _PatternRule(
    type: FlavorType.translationese,
    severity: FlavorSeverity.low,
    regex: RegExp(r'进行了?(?:一次|一场|一番|一个)'),
    message: '翻译腔：进行了一次…（动词名词化）',
  ),
];

List<FlavorIssue> _matchPatterns(String text) {
  final issues = <FlavorIssue>[];
  for (final rule in _patternRules) {
    for (final match in rule.regex.allMatches(text)) {
      issues.add(FlavorIssue(
        type: rule.type,
        severity: rule.severity,
        start: match.start,
        end: match.end,
        excerpt: match.group(0) ?? '',
        message: rule.message,
        suggestion: rule.suggestion,
      ));
    }
  }
  return issues;
}

typedef _Paragraph = ({int start, String text});

List<_Paragraph> _splitParagraphs(String text) {
  final paragraphs = <_Paragraph>[];
  var offset = 0;
  for (final line in text.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isNotEmpty) {
      final leading = line.length - line.trimLeft().length;
      paragraphs.add((start: offset + leading, text: trimmed));
    }
    offset += line.length + 1;
  }
  return paragraphs;
}

/// 段尾感悟句用到的抽象名词。
const List<String> _reflectionWords = <String>[
  '人生', '命运', '时间', '世界', '世间', '岁月', '意义', '真心', '孤独', '成长',
  '温暖', '真相', '道理', '未来', '灵魂', '人性', '生活', '青春', '回忆',
];

typedef _ParagraphAnalysis = ({List<FlavorIssue> issues, int repeatedParagraphs});

_ParagraphAnalysis _analyzeParagraphs(List<_Paragraph> paragraphs) {
  final issues = <FlavorIssue>[];
  var repeated = 0;

  // 段尾感悟句（M4-02）：段落 >= 2 句，末句短且含抽象名词。
  for (final paragraph in paragraphs) {
    final sentences = _splitSentences(paragraph.text);
    if (sentences.length < 2) continue;
    final last = sentences.last;
    final core = last.text.replaceAll(RegExp(r'[。！？!?…\s]'), '');
    if (core.length > 30) continue;
    if (!_reflectionWords.any(core.contains)) continue;
    issues.add(FlavorIssue(
      type: FlavorType.oversummary,
      severity: FlavorSeverity.medium,
      start: paragraph.start + last.start,
      end: paragraph.start + last.start + last.text.length,
      excerpt: last.text,
      message: '段尾感悟句：为段落强行升华',
      suggestion: '删去或改为具体的动作、对话收束',
    ));
  }

  // 连续同结构段落：首二字相同连续 >= 3 段。
  var i = 0;
  while (i < paragraphs.length) {
    final head = _head(paragraphs[i].text);
    var j = i + 1;
    while (j < paragraphs.length && head.isNotEmpty && _head(paragraphs[j].text) == head) {
      j++;
    }
    final run = j - i;
    if (head.isNotEmpty && run >= 3) {
      repeated += run;
      issues.add(FlavorIssue(
        type: FlavorType.repetition,
        severity: FlavorSeverity.medium,
        start: paragraphs[i].start,
        end: paragraphs[j - 1].start + paragraphs[j - 1].text.length,
        excerpt: '$run 段以「$head」开头',
        message: '连续 $run 段结构相同（均以「$head」开头），句式模式化',
        suggestion: '变换段落起笔方式，避免同构排列',
      ));
    }
    i = j > i ? j : i + 1;
  }

  // 连续长度相近段落：>= 3 段且每段长度差 <= 10%（节奏拖沓）。
  var k = 0;
  while (k < paragraphs.length) {
    var m = k + 1;
    while (m < paragraphs.length && _similarLength(paragraphs[m - 1].text, paragraphs[m].text)) {
      m++;
    }
    final run = m - k;
    if (run >= 3) {
      repeated += run;
      issues.add(FlavorIssue(
        type: FlavorType.pacing,
        severity: FlavorSeverity.low,
        start: paragraphs[k].start,
        end: paragraphs[m - 1].start + paragraphs[m - 1].text.length,
        excerpt: '$run 段长度相近',
        message: '连续 $run 段长度几乎一致，节奏平板',
        suggestion: '长短句交替，打破均匀节奏',
      ));
    }
    k = m > k ? m : k + 1;
  }

  return (issues: issues, repeatedParagraphs: repeated);
}

String _head(String text) {
  final core = text.replaceAll(RegExp(r'^[\s“"「『]+'), '');
  if (core.length < 2) return '';
  return core.substring(0, 2);
}

bool _similarLength(String a, String b) {
  final base = a.length > b.length ? a.length : b.length;
  if (base == 0) return false;
  return (a.length - b.length).abs() <= base * 0.1;
}

typedef _Sentence = ({int start, String text});

List<_Sentence> _splitSentences(String text) {
  final sentences = <_Sentence>[];
  final regex = RegExp(r'[^。！？!?…]+[。！？!?…]*');
  for (final match in regex.allMatches(text)) {
    final value = match.group(0);
    if (value == null || value.trim().isEmpty) continue;
    sentences.add((start: match.start, text: value));
  }
  return sentences;
}