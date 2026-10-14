import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// EPUB MIME 类型（分享面板识别与 zip 首条目内容）。
const String epubMimeType = 'application/epub+zip';

/// 导出用的章节数据（避免 core 依赖数据层实体）。
class ExportChapter {
  const ExportChapter({
    required this.title,
    required this.content,
    this.volumeName = '',
  });

  final String title;
  final String content;
  final String volumeName;

  String get displayTitle => title.isEmpty ? '未命名章节' : title;
}

/// 单章纯文本（M2-08）：标题行 + 正文。
String buildChapterText(ExportChapter chapter) {
  final buffer = StringBuffer('${chapter.displayTitle}\n\n');
  buffer.write(chapter.content);
  return buffer.toString();
}

/// 单章 markdown（M2-08）：`# 标题` 一级标题，可被导入分章正则还原。
String buildChapterMarkdown(ExportChapter chapter) {
  return '# ${chapter.displayTitle}\n\n${chapter.content}\n';
}

/// 整作纯文本（M2-09）：章节按顺序输出，标题单独成行，便于人工阅读。
/// 作品标题不写入正文（文件名已承载），避免再导入时多出一段前言。
String buildWorkText(List<ExportChapter> chapters) {
  final buffer = StringBuffer();
  for (final chapter in chapters) {
    buffer.write('${chapter.displayTitle}\n\n');
    if (chapter.content.isNotEmpty) {
      buffer.write('${chapter.content}\n\n');
    }
  }
  return buffer.toString();
}

/// 整作 markdown（M2-09）：每章一个一级标题，保证「导出 → 再导入」结构还原。
/// 卷信息不写入 markdown，卷结构由整库备份 JSON 完整保留（见 ARCHITECTURE 4.1）。
String buildWorkMarkdown(List<ExportChapter> chapters) {
  final buffer = StringBuffer();
  for (final chapter in chapters) {
    buffer.write(buildChapterMarkdown(chapter));
    buffer.write('\n');
  }
  return buffer.toString();
}

/// 整作 docx（M2-09）：标题段落使用 Heading1 样式，可被 docx 导入按样式分章。
Uint8List buildWorkDocx(List<ExportChapter> chapters) {
  final body = StringBuffer();
  for (final chapter in chapters) {
    body.write(_docxHeadingParagraph(chapter.displayTitle));
    for (final paragraph in chapter.content.split('\n')) {
      if (paragraph.trim().isEmpty) continue;
      body.write(_docxTextParagraph(paragraph.trim()));
    }
  }

  final documentXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
      '<w:body>$body</w:body></w:document>';
  final contentTypes = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '</Types>';
  final rels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
      '</Relationships>';

  final archive = Archive()
    ..add(ArchiveFile.string('[Content_Types].xml', contentTypes))
    ..add(ArchiveFile.string('_rels/.rels', rels))
    ..add(ArchiveFile.string('word/document.xml', documentXml));
  return ZipEncoder().encodeBytes(archive);
}

/// 整作 EPUB（ENH-04）：EPUB 3 最小结构。
/// mimetype 必须是 zip 首条目且不压缩（archive 保插入顺序 + noCompress 写 STORE）。
Uint8List buildWorkEpub(
  List<ExportChapter> chapters, {
  required String title,
  DateTime? modified,
}) {
  final mimetypeBytes = textToBytes(epubMimeType);
  final archive = Archive()
    ..add(ArchiveFile.noCompress('mimetype', mimetypeBytes.length, mimetypeBytes))
    ..add(ArchiveFile.string('META-INF/container.xml', _epubContainerXml()));

  final pages = <String>[];
  for (var i = 0; i < chapters.length; i++) {
    final name = 'chapter_${i + 1}.xhtml';
    pages.add(name);
    archive.add(ArchiveFile.string('OEBPS/$name', _epubChapter(chapters[i])));
  }
  archive
    ..add(ArchiveFile.string(
        'OEBPS/content.opf', _epubOpf(chapters, pages, title: title, modified: modified)))
    ..add(ArchiveFile.string('OEBPS/nav.xhtml', _epubNav(chapters, pages)))
    ..add(ArchiveFile.string('OEBPS/style.css', _epubCss()));
  return ZipEncoder().encodeBytes(archive);
}

String _epubContainerXml() =>
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">'
    '<rootfiles>'
    '<rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>'
    '</rootfiles></container>';

String _epubOpf(
  List<ExportChapter> chapters,
  List<String> pages, {
  required String title,
  DateTime? modified,
}) {
  // 确定性标识符，便于测试断言，也避免每次导出 ID 漂移。
  final identifier = 'urn:novelphone:${title.isEmpty ? 'untitled' : title}';
  final modifiedAt = _isoUtc(modified ?? DateTime.now());
  final manifest = StringBuffer()
    ..write('<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>')
    ..write('<item id="style" href="style.css" media-type="text/css"/>');
  final spine = StringBuffer();
  for (var i = 0; i < pages.length; i++) {
    manifest.write(
        '<item id="chapter_${i + 1}" href="${pages[i]}" media-type="application/xhtml+xml"/>');
    spine.write('<itemref idref="chapter_${i + 1}"/>');
  }
  return '<?xml version="1.0" encoding="UTF-8"?>'
      '<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid">'
      '<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">'
      '<dc:identifier id="bookid">${_escapeXml(identifier)}</dc:identifier>'
      '<dc:title>${_escapeXml(title.isEmpty ? '未命名作品' : title)}</dc:title>'
      '<dc:language>zh-CN</dc:language>'
      '<meta property="dcterms:modified">$modifiedAt</meta>'
      '</metadata>'
      '<manifest>$manifest</manifest>'
      '<spine>$spine</spine>'
      '</package>';
}

String _epubNav(List<ExportChapter> chapters, List<String> pages) {
  final items = StringBuffer();
  for (var i = 0; i < chapters.length; i++) {
    items.write(
        '<li><a href="${pages[i]}">${_escapeXml(chapters[i].displayTitle)}</a></li>');
  }
  return '<?xml version="1.0" encoding="UTF-8"?>'
      '<!DOCTYPE html>'
      '<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">'
      '<head><title>目录</title></head>'
      '<body><nav epub:type="toc" id="toc"><h1>目录</h1><ol>$items</ol></nav></body>'
      '</html>';
}

String _epubChapter(ExportChapter chapter) {
  final body = StringBuffer();
  for (final paragraph in chapter.content.split('\n')) {
    if (paragraph.trim().isEmpty) continue;
    body.write('<p>${_escapeXml(paragraph.trim())}</p>');
  }
  return '<?xml version="1.0" encoding="UTF-8"?>'
      '<!DOCTYPE html>'
      '<html xmlns="http://www.w3.org/1999/xhtml">'
      '<head><title>${_escapeXml(chapter.displayTitle)}</title>'
      '<link rel="stylesheet" type="text/css" href="style.css"/></head>'
      '<body><h1>${_escapeXml(chapter.displayTitle)}</h1>$body</body>'
      '</html>';
}

String _epubCss() =>
    'body { font-family: serif; line-height: 1.6; } h1 { font-size: 1.3em; }';

String _isoUtc(DateTime time) {
  final utc = time.toUtc();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${utc.year}-${two(utc.month)}-${two(utc.day)}T'
      '${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}Z';
}

String _docxHeadingParagraph(String text) {
  return '<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr>'
      '<w:r><w:t xml:space="preserve">${_escapeXml(text)}</w:t></w:r></w:p>';
}

String _docxTextParagraph(String text) {
  return '<w:p><w:r><w:t xml:space="preserve">${_escapeXml(text)}</w:t></w:r></w:p>';
}

String _escapeXml(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// 文本导出为字节。
Uint8List textToBytes(String text) => Uint8List.fromList(utf8.encode(text));