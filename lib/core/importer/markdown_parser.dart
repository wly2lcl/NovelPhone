import 'chapter_splitter.dart';
import 'html_entities.dart';

/// Markdown 导入：先按现有分章规则切分（`#` 标题可直接作为分章点），
/// 再把每章正文里的 Markdown 标记还原为纯文本。
List<ChapterDraft> parseMarkdown(String text, {String fallbackTitle = ''}) {
  final drafts = splitIntoChapters(
    _stripFrontMatter(text),
    fallbackTitle: fallbackTitle,
  );
  return drafts
      .map(
        (draft) => ChapterDraft(
          title: stripMarkdown(draft.title),
          content: stripMarkdown(draft.content),
        ),
      )
      .where((draft) => draft.title.isNotEmpty || draft.content.isNotEmpty)
      .toList(growable: false);
}

/// 去掉 Markdown 语法，保留可读正文。
String stripMarkdown(String input) {
  var text = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

  // 围栏代码块只去掉围栏行，保留其中文本（小说里可能是信件 / 引文）。
  text = text.replaceAll(RegExp(r'^\s*```.*$', multiLine: true), '');
  text = text.replaceAll(RegExp(r'^\s*~~~.*$', multiLine: true), '');

  // 分隔线。
  text = text.replaceAll(
    RegExp(
      r'^\s{0,3}(?:-\s*){3,}$|^\s{0,3}(?:\*\s*){3,}$|^\s{0,3}(?:_\s*){3,}$',
      multiLine: true,
    ),
    '',
  );

  // 图片保留 alt 文本，链接保留链接文字。
  text = text.replaceAllMapped(
    RegExp(r'!\[([^\]]*)\]\([^)]*\)'),
    (match) => match.group(1) ?? '',
  );
  text = text.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]\([^)]*\)'),
    (match) => match.group(1) ?? '',
  );

  // 标题、引用、列表前缀。
  text = text.replaceAll(RegExp(r'^\s{0,3}#{1,6}\s+', multiLine: true), '');
  text = text.replaceAll(RegExp(r'^\s{0,3}>\s?', multiLine: true), '');
  text = text.replaceAll(
    RegExp(r'^\s{0,3}(?:[-*+]|\d+[.)])\s+', multiLine: true),
    '',
  );

  // 强调 / 删除线 / 行内代码。
  text = text.replaceAllMapped(
    RegExp(r'(\*\*|__)(.+?)\1'),
    (match) => match.group(2) ?? '',
  );
  text = text.replaceAllMapped(
    RegExp(r'~~(.+?)~~'),
    (match) => match.group(1) ?? '',
  );
  text = text.replaceAllMapped(
    RegExp(r'`([^`\n]+)`'),
    (match) => match.group(1) ?? '',
  );
  text = text.replaceAllMapped(
    RegExp(r'(\*|_)([^*_\n]+)\1'),
    (match) => match.group(2) ?? '',
  );

  // 内嵌 HTML 标签与实体。
  text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  text = text.replaceAll(RegExp(r'<[^>]+>'), '');
  text = decodeHtmlEntities(text);

  return _normalizeLines(text);
}

String _stripFrontMatter(String text) {
  final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (!normalized.startsWith('---\n')) return normalized;
  final end = normalized.indexOf('\n---', 4);
  if (end < 0) return normalized;
  final lineEnd = normalized.indexOf('\n', end + 4);
  return lineEnd < 0 ? '' : normalized.substring(lineEnd + 1);
}

String _normalizeLines(String text) {
  final result = <String>[];
  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) {
      if (result.isNotEmpty && result.last.isNotEmpty) result.add('');
      continue;
    }
    result.add(line);
  }
  return result.join('\n').trim();
}
