import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'chapter_splitter.dart';
import 'text_encoding.dart';

/// docx 正文解析（M2-06）：解包 word/document.xml，取段落文本；
/// 标题样式段落作为分章点，若整篇无标题样式则降级为 txt 的正则分章。
List<ChapterDraft> parseDocx(Uint8List bytes, {String fallbackTitle = ''}) {
  final archive = ZipDecoder().decodeBytes(bytes);
  ArchiveFile? entry;
  for (final file in archive.files) {
    if (file.isFile && file.name == 'word/document.xml') {
      entry = file;
      break;
    }
  }
  if (entry == null) {
    throw const FormatException('不是有效的 docx 文件（缺少 word/document.xml）');
  }
  final xmlBytes = entry.readBytes();
  if (xmlBytes == null) {
    throw const FormatException('docx 正文解析失败');
  }
  final document = XmlDocument.parse(decodeTextBytes(xmlBytes).text);

  final drafts = <ChapterDraft>[];
  final plainLines = <String>[];
  var hasHeading = false;

  for (final paragraph in _elementsByLocalName(document, 'p')) {
    final text = _paragraphText(paragraph);
    if (_isHeadingParagraph(paragraph)) {
      hasHeading = true;
      drafts.add(ChapterDraft(
        title: text.length > kMaxChapterTitleLength
            ? text.substring(0, kMaxChapterTitleLength)
            : text,
        content: '',
      ));
      continue;
    }
    if (drafts.isEmpty) {
      plainLines.add(text);
    } else {
      final last = drafts.last;
      drafts[drafts.length - 1] = last.copyWith(
        content: <String>[
          if (last.content.isNotEmpty) last.content,
          if (text.isNotEmpty) text,
        ].join('\n\n'),
      );
    }
  }

  // 无标题样式：降级为正则分章，避免整篇挤成一章。
  if (!hasHeading) {
    return splitIntoChapters(
      _elementsByLocalName(document, 'p').map(_paragraphText).join('\n'),
      fallbackTitle: fallbackTitle,
    );
  }

  // 标题之前的正文单独成章。
  final leading = plainLines.join('\n').trim();
  if (leading.isNotEmpty) {
    drafts.insert(0, ChapterDraft(title: '', content: leading));
  }
  return drafts
      .where((d) => d.title.isNotEmpty || d.content.isNotEmpty)
      .toList(growable: false);
}

/// docx 的 XML 声明通常为 UTF-8；极少数工具导出为 GBK，复用统一的编码探测。
Iterable<XmlElement> _elementsByLocalName(XmlNode node, String local) {
  return node.descendants
      .whereType<XmlElement>()
      .where((e) => e.name.local == local);
}

String _paragraphText(XmlElement paragraph) {
  final buffer = StringBuffer();
  for (final node in paragraph.descendants) {
    if (node is XmlElement && node.name.local == 't') {
      buffer.write(node.innerText);
    }
  }
  return buffer.toString().trim();
}

bool _isHeadingParagraph(XmlElement paragraph) {
  for (final style in _elementsByLocalName(paragraph, 'pStyle')) {
    final value = style.getAttribute('val') ?? style.getAttribute('w:val') ?? '';
    final normalized = value.toLowerCase();
    if (normalized == 'title' ||
        normalized.startsWith('heading') ||
        value.startsWith('标题')) {
      return true;
    }
  }
  return false;
}