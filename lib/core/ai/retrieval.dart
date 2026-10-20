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
List<RetrievedPassage> retrievePassages({
  required List<Chapter> chapters,
  required String query,
  int topK = 5,
  int chunkChars = 320,
  int maxPerChapter = 2,
  int? excludeChapterId,
  int maxScanChars = 400000,
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

  final hits = <RetrievedPassage>[];
  for (var index = 0; index < chapters.length; index++) {
    final chapter = chapters[index];
    if (chapter.id == excludeChapterId) continue;
    final content = chapter.content.trim();
    if (content.isEmpty) continue;
    final title = chapter.title.trim().isEmpty ? '未命名章节' : chapter.title.trim();
    final titleMatch = _normalize(title).contains(normalizedQuery);

    var perChapter = 0;
    final chunks = _chunks(content, chunkChars).toList(growable: false);
    for (final chunk in _sampleEven(chunks, chunksPerChapter)) {
      if (perChapter >= maxPerChapter) break;
      final normalizedChunk = _normalize(chunk);
      if (normalizedChunk.isEmpty) continue;
      final chunkGrams = _bigrams(normalizedChunk);
      var overlap = 0;
      for (final entry in queryGrams.entries) {
        final count = chunkGrams[entry.key];
        if (count == null) continue;
        overlap += entry.value < count ? entry.value : count;
      }
      final total = _gramCount(queryGrams) + _gramCount(chunkGrams);
      var score = total == 0 ? 0.0 : 2 * overlap / total;
      if (normalizedChunk.contains(normalizedQuery)) score += 0.5;
      if (titleMatch) score += 0.05;
      if (score <= 0) continue;
      hits.add(
        RetrievedPassage(
          chapterId: chapter.id,
          chapterTitle: title,
          chapterIndex: index + 1,
          text: chunk,
          score: score,
        ),
      );
      perChapter++;
    }
  }

  hits.sort((a, b) => b.score.compareTo(a.score));
  return hits.take(topK).toList(growable: false);
}

/// 把命中片段格式化为上下文段落（ENH-32）。
String formatRetrievedPassages(
  List<RetrievedPassage> passages, {
  String header = '相关前文片段',
}) {
  if (passages.isEmpty) return '';
  final buffer = StringBuffer();
  if (header.isNotEmpty) buffer.write('【$header】');
  for (final passage in passages) {
    if (buffer.isNotEmpty) buffer.writeln();
    buffer.write(
      '- 第 ${passage.chapterIndex} 章 ${passage.chapterTitle}：'
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

int _gramCount(Map<String, int> grams) =>
    grams.values.fold(0, (sum, count) => sum + count);
