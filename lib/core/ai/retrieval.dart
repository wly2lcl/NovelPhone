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

  final hits = <RetrievedPassage>[];
  var scanned = 0;
  for (var index = 0; index < chapters.length; index++) {
    final chapter = chapters[index];
    if (chapter.id == excludeChapterId) continue;
    final content = chapter.content.trim();
    if (content.isEmpty) continue;
    if (scanned >= maxScanChars) {
      break;
    }
    scanned += content.length;
    final title = chapter.title.trim().isEmpty ? '未命名章节' : chapter.title.trim();
    final titleMatch = _normalize(title).contains(normalizedQuery);

    var perChapter = 0;
    for (final chunk in _chunks(content, chunkChars)) {
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
