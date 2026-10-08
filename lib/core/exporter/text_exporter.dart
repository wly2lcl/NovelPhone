import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

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