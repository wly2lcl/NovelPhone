import '../word_count.dart';

/// 分章结果的最小单元。
class ChapterDraft {
  const ChapterDraft({required this.title, required this.content});

  final String title;
  final String content;

  int get wordCount => countWords(content);

  ChapterDraft copyWith({String? title, String? content}) =>
      ChapterDraft(title: title ?? this.title, content: content ?? this.content);
}

/// 章节标题上限，与 CHAPTER.title 字段约束一致。
const int kMaxChapterTitleLength = 50;

/// 空标题章节的展示文案（PRD 5.2），同时作为导出/导入的往返约定。
const String kUntitledChapterLabel = '未命名章节';

const String _cnDigits = '0-9０-９一二三四五六七八九十百千万零〇两';

/// 章节标题行识别（M2-05）：
/// 1. markdown 标题（本产品导出格式，保证「导出 → 再导入」结构还原）
/// 2. 中文网文常见「第 X 章 / 节 / 回 / 篇」
/// 3. 英文 Chapter N
final RegExp kChapterHeadingPattern = RegExp(
  '^\\s*(?:#{1,3}\\s+(?<md>.+?)'
  '|第\\s*[$_cnDigits]+\\s*[章节回篇]\\s*(?<cn>.*?)'
  '|chapter\\s+\\d+\\s*(?<en>.*?))\\s*\$',
  caseSensitive: false,
);

/// 取出标题文本：markdown 取「# 」之后的部分；「第 X 章」等保留整行，
/// 避免丢掉中文小说的章序信息，同时保证「导出 → 再导入」结构一致。
String? _headingTitle(String line) {
  final match = kChapterHeadingPattern.firstMatch(line);
  if (match == null) return null;
  final title = (match.namedGroup('md') ?? line).trim();
  // 导出时空标题写作「未命名章节」，再导入还原为空标题，保证往返一致。
  if (title == kUntitledChapterLabel) return '';
  return title.length > kMaxChapterTitleLength
      ? title.substring(0, kMaxChapterTitleLength)
      : title;
}

/// 按章节标题正则把全文切分为章节草稿。
/// 全文没有任何标题行时，整体作为一章返回（标题留空，由作者补录）。
List<ChapterDraft> splitIntoChapters(String text, {String fallbackTitle = ''}) {
  final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final lines = normalized.split('\n');

  final headings = <int>[];
  for (var i = 0; i < lines.length; i++) {
    if (kChapterHeadingPattern.hasMatch(lines[i])) headings.add(i);
  }

  if (headings.isEmpty) {
    final content = normalized.trim();
    if (content.isEmpty) return const <ChapterDraft>[];
    return <ChapterDraft>[
      ChapterDraft(
        title: fallbackTitle.length > kMaxChapterTitleLength
            ? fallbackTitle.substring(0, kMaxChapterTitleLength)
            : fallbackTitle,
        content: content,
      ),
    ];
  }

  final drafts = <ChapterDraft>[];
  // 第一个标题之前的内容（卷首语、作者的话等）单独成章，标题留空。
  final leading = lines.sublist(0, headings.first).join('\n').trim();
  if (leading.isNotEmpty) {
    drafts.add(ChapterDraft(title: '', content: leading));
  }

  for (var i = 0; i < headings.length; i++) {
    final start = headings[i];
    final end = i + 1 < headings.length ? headings[i + 1] : lines.length;
    drafts.add(ChapterDraft(
      title: _headingTitle(lines[start]) ?? '',
      content: lines.sublist(start + 1, end).join('\n').trim(),
    ));
  }
  return drafts;
}

/// 手动调整分割点（M2-05）：把第 [index] 章并入上一章，返回新列表。
List<ChapterDraft> mergeWithPrevious(List<ChapterDraft> drafts, int index) {
  if (index <= 0 || index >= drafts.length) return drafts;
  final result = List<ChapterDraft>.of(drafts);
  final previous = result[index - 1];
  final merged = result[index];
  final title = merged.title.isEmpty
      ? previous.title
      : '${previous.title}${previous.title.isEmpty ? '' : ' '}${merged.title}';
  result[index - 1] = previous.copyWith(
    title: title.length > kMaxChapterTitleLength
        ? title.substring(0, kMaxChapterTitleLength)
        : title,
    content: <String>[
      if (previous.content.isNotEmpty) previous.content,
      if (merged.content.isNotEmpty) merged.content,
    ].join('\n\n'),
  );
  result.removeAt(index);
  return result;
}