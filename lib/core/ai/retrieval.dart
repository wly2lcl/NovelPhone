import 'dart:math';

import '../../data/db.dart';

/// 本地检索命中的一段前文（ENH-32）。
class RetrievedPassage {
  const RetrievedPassage({
    required this.chapterId,
    required this.chapterTitle,
    required this.chapterIndex,
    required this.text,
    required this.score,
  });

  final int chapterId;
  final String chapterTitle;

  /// 1 起的章节序号（按作品内顺序）。
  final int chapterIndex;
  final String text;
  final double score;
}

/// RAG-lite 本地检索（ENH-32）：把章节正文切成段落块，用字符 bigram 余弦
/// 相似度（外加整串命中加分）为查询挑出 Top-K 片段。
///
/// 不引入向量库：中文没有天然分词，bigram 召回对人物名、物件名和短句足够，
/// 且纯 Dart 可在生成前一次性完成，不增加模型调用成本。
///
/// [maxScanChars] 是**全书总量**的软上限（ENH-33）：预算按章均分并在章内均匀
/// 抽样，保证长篇后期章节也能被检索到；旧实现从第一章顺序累加、到达上限即
/// 停止，导致 40 万字以上的作品问答永远看不到后半部分。
///
/// ENH-40 在召回打分上做了三件事：
/// - bigram 覆盖按 IDF 加权，常见字词（“集市”“他说”）不再压过稀有名词；
/// - [aliasGroups] 中任一别名出现在查询里时，命中同组其他别名（含本名）加分；
/// - [nearbyChapterId] 前后几章的片段小幅提权，续写 / 改写优先用近处上下文。
List<RetrievedPassage> retrievePassages({
  required List<Chapter> chapters,
  required String query,
  int topK = 5,
  int chunkChars = 320,
  int maxPerChapter = 2,
  int? excludeChapterId,
  int maxScanChars = 400000,
  int? nearbyChapterId,
  List<List<String>> aliasGroups = const <List<String>>[],
  int chapterIndexOffset = 0,
}) {
  final normalizedQuery = _normalize(query);
  if (normalizedQuery.length < 2 || topK <= 0) {
    return const <RetrievedPassage>[];
  }
  final queryGrams = _bigrams(normalizedQuery);
  if (queryGrams.isEmpty) return const <RetrievedPassage>[];

  final active = chapters
      .where(
        (chapter) =>
            chapter.id != excludeChapterId && chapter.content.trim().isNotEmpty,
      )
      .toList(growable: false);
  if (active.isEmpty) return const <RetrievedPassage>[];

  // 预算按章均分（至少保留一个块），章内再均匀抽样，避免长作只覆盖开头。
  final perChapterBudget = max(
    chunkChars,
    maxScanChars ~/ max(1, active.length),
  );
  final chunksPerChapter = max(1, perChapterBudget ~/ chunkChars);

  final nearbyIndex = nearbyChapterId == null
      ? -1
      : chapters.indexWhere((c) => c.id == nearbyChapterId);
  final expandedTerms = _expandedAliasTerms(normalizedQuery, aliasGroups);

  final candidates = <_ChunkCandidate>[];
  for (var index = 0; index < chapters.length; index++) {
    final chapter = chapters[index];
    if (chapter.id == excludeChapterId) continue;
    final content = chapter.content.trim();
    if (content.isEmpty) continue;
    final title = chapter.title.trim().isEmpty ? '未命名章节' : chapter.title.trim();
    final normalizedTitle = _normalize(title);
    final titleMatch =
        normalizedTitle.contains(normalizedQuery) ||
        expandedTerms.any(normalizedTitle.contains);

    final chunks = _chunks(content, chunkChars).toList(growable: false);
    for (final chunk in _sampleEven(chunks, chunksPerChapter)) {
      final normalizedChunk = _normalize(chunk);
      if (normalizedChunk.isEmpty) continue;
      candidates.add(
        _ChunkCandidate(
          chapter: chapter,
          chapterIndex: index,
          title: title,
          text: chunk,
          normalized: normalizedChunk,
          grams: _bigrams(normalizedChunk),
          titleMatch: titleMatch,
        ),
      );
    }
  }
  if (candidates.isEmpty) return const <RetrievedPassage>[];

  // IDF 需要先知道每个 bigram 出现在多少块候选里，再回头逐块打分。
  final documentFrequency = <String, int>{};
  for (final candidate in candidates) {
    for (final gram in candidate.grams.keys) {
      documentFrequency[gram] = (documentFrequency[gram] ?? 0) + 1;
    }
  }
  final idfCache = <String, double>{};
  double idf(String gram) => idfCache.putIfAbsent(gram, () {
    final df = documentFrequency[gram] ?? 0;
    return log(1 + candidates.length / (1 + df));
  });

  var queryWeight = 0.0;
  for (final entry in queryGrams.entries) {
    queryWeight += entry.value * idf(entry.key);
  }
  if (queryWeight <= 0) return const <RetrievedPassage>[];

  final hits = <RetrievedPassage>[];
  for (final candidate in candidates) {
    var overlapWeight = 0.0;
    for (final entry in queryGrams.entries) {
      final count = candidate.grams[entry.key];
      if (count == null) continue;
      final matched = entry.value < count ? entry.value : count;
      overlapWeight += matched * idf(entry.key);
    }
    var score = overlapWeight / queryWeight;
    if (candidate.normalized.contains(normalizedQuery)) score += 0.5;
    if (expandedTerms.isNotEmpty) {
      final aliasHits = expandedTerms
          .where(candidate.normalized.contains)
          .length;
      if (aliasHits > 0) score += min(0.3, 0.15 * aliasHits);
    }
    if (candidate.titleMatch) score += 0.05;
    if (nearbyIndex >= 0) {
      score *= _proximityFactor(candidate.chapterIndex, nearbyIndex);
    }
    if (score <= 0) continue;
    hits.add(
      RetrievedPassage(
        chapterId: candidate.chapter.id,
        chapterTitle: candidate.title,
        chapterIndex: candidate.chapterIndex + 1 + chapterIndexOffset,
        text: candidate.text,
        score: score,
      ),
    );
  }

  hits.sort((a, b) => b.score.compareTo(a.score));
  // 先给全部候选打分，再按每章上限挑选，避免每章上限把靠后的相关块提前截掉。
  final perChapterCount = <int, int>{};
  final selected = <RetrievedPassage>[];
  for (final hit in hits) {
    final count = perChapterCount[hit.chapterId] ?? 0;
    if (count >= maxPerChapter) continue;
    perChapterCount[hit.chapterId] = count + 1;
    selected.add(hit);
    if (selected.length >= topK) break;
  }
  return selected;
}

class _ChunkCandidate {
  _ChunkCandidate({
    required this.chapter,
    required this.chapterIndex,
    required this.title,
    required this.text,
    required this.normalized,
    required this.grams,
    required this.titleMatch,
  });

  final Chapter chapter;
  final int chapterIndex;
  final String title;
  final String text;
  final String normalized;
  final Map<String, int> grams;
  final bool titleMatch;
}

/// 查询提到某角色的任一别名时，把同组别名都视为扩展检索词（ENH-40）。
List<String> _expandedAliasTerms(
  String normalizedQuery,
  List<List<String>> aliasGroups,
) {
  final terms = <String>[];
  for (final group in aliasGroups) {
    final normalized = group
        .map(_normalize)
        .where((term) => term.length >= 2)
        .toList(growable: false);
    if (normalized.isEmpty) continue;
    if (!normalized.any(normalizedQuery.contains)) continue;
    for (final term in normalized) {
      if (!terms.contains(term)) terms.add(term);
    }
  }
  return terms;
}

/// 离目标章越近权重越高：相邻章 ×1.25，隔一章 ×1.1，两到四章内 ×1.04。
double _proximityFactor(int chapterIndex, int nearbyIndex) {
  final distance = (chapterIndex - nearbyIndex).abs();
  if (distance == 1) return 1.25;
  if (distance == 2) return 1.1;
  if (distance <= 4) return 1.04;
  return 1;
}

/// 把命中片段格式化为上下文段落（ENH-32）。
///
/// [includeId] 为 true 时在章节标题后附上章节 id（ENH-43），让作品问答
/// 能直接引用检索片段来源。
String formatRetrievedPassages(
  List<RetrievedPassage> passages, {
  String header = '相关前文片段',
  bool includeId = false,
}) {
  if (passages.isEmpty) return '';
  final buffer = StringBuffer();
  if (header.isNotEmpty) buffer.write('【$header】');
  for (final passage in passages) {
    if (buffer.isNotEmpty) buffer.writeln();
    final id = includeId ? '（id=${passage.chapterId}）' : '';
    buffer.write(
      '- 第 ${passage.chapterIndex} 章 ${passage.chapterTitle}$id：'
      '${passage.text}',
    );
  }
  return buffer.toString();
}

/// 在 [items] 中均匀选取至多 [limit] 个元素（含首尾）；`limit == 1` 时取中间。
List<T> _sampleEven<T>(List<T> items, int limit) {
  if (items.isEmpty || limit <= 0) return <T>[];
  if (items.length <= limit) return items;
  if (limit == 1) return <T>[items[items.length ~/ 2]];
  final picked = <T>[];
  for (var i = 0; i < limit; i++) {
    final index = (i * (items.length - 1) / (limit - 1)).round();
    if (picked.isEmpty || picked.last != items[index]) {
      picked.add(items[index]);
    }
  }
  return picked;
}

/// 按空行切段并合并小段，单块不超过 [chunkChars]；超长段按句号 / 换行再切。
Iterable<String> _chunks(String content, int chunkChars) sync* {
  final paragraphs = content
      .split(RegExp(r'\n\s*\n'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty);
  final buffer = StringBuffer();
  for (final paragraph in paragraphs) {
    if (paragraph.length > chunkChars) {
      if (buffer.isNotEmpty) {
        yield buffer.toString();
        buffer.clear();
      }
      for (var start = 0; start < paragraph.length; start += chunkChars) {
        final end = start + chunkChars < paragraph.length
            ? start + chunkChars
            : paragraph.length;
        yield paragraph.substring(start, end);
      }
      continue;
    }
    if (buffer.isEmpty) {
      buffer.write(paragraph);
    } else if (buffer.length + paragraph.length + 2 <= chunkChars) {
      buffer
        ..writeln()
        ..writeln()
        ..write(paragraph);
    } else {
      yield buffer.toString();
      buffer
        ..clear()
        ..write(paragraph);
    }
  }
  if (buffer.isNotEmpty) yield buffer.toString();
}

String _normalize(String text) => text.toLowerCase().replaceAll(
  RegExp(r'[\s\u3000-\u303F\uFF00-\uFFEF!-/:-@\[-`{-~]+'),
  '',
);

Map<String, int> _bigrams(String text) {
  final map = <String, int>{};
  for (var i = 0; i < text.length - 1; i++) {
    final gram = text.substring(i, i + 2);
    map[gram] = (map[gram] ?? 0) + 1;
  }
  return map;
}
