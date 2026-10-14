import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/core/exporter/share_export.dart';
import 'package:novelphone/core/exporter/text_exporter.dart';
import 'package:novelphone/core/importer/chapter_splitter.dart';

/// M2-08 / M2-09：导出文本与「导出 → 再导入」往返一致性。
void main() {
  const chapter1 = ExportChapter(title: '第一章 雨', content: '雨下了一整夜。');
  const chapter2 = ExportChapter(title: '', content: '第二段正文。');

  test('单章 txt 含标题行与正文', () {
    final text = buildChapterText(chapter1);
    expect(text, '第一章 雨\n\n雨下了一整夜。');
  });

  test('单章 markdown 使用一级标题', () {
    expect(buildChapterMarkdown(chapter1), '# 第一章 雨\n\n雨下了一整夜。\n');
  });

  test('整作 markdown 导出后再分章，标题与正文一致', () {
    final markdown = buildWorkMarkdown(const <ExportChapter>[chapter1, chapter2]);

    final drafts = splitIntoChapters(markdown);

    expect(drafts, hasLength(2));
    expect(drafts[0].title, '第一章 雨');
    expect(drafts[0].content, '雨下了一整夜。');
    // 空标题导出为「未命名章节」，再导入还原为空标题。
    expect(drafts[1].title, '');
    expect(drafts[1].content, '第二段正文。');
  });

  test('整作 txt 每章标题单独成行', () {
    final text = buildWorkText(const <ExportChapter>[chapter1]);
    expect(text, '第一章 雨\n\n雨下了一整夜。\n\n');
  });

  test('整作 docx 是可解包的 zip，且正文含标题与段落', () {
    final bytes = buildWorkDocx(const <ExportChapter>[chapter1]);

    final archive = ZipDecoder().decodeBytes(bytes);
    final document = archive.files.firstWhere(
      (f) => f.isFile && f.name == 'word/document.xml',
    );
    final xml = utf8.decode(document.readBytes()!);

    expect(xml, contains('Heading1'));
    expect(xml, contains('第一章 雨'));
    expect(xml, contains('雨下了一整夜。'));
  });

  // ---------- ENH-04：EPUB ----------

  test('整作 epub：mimetype 是首条目且未压缩（STORE）', () {
    final bytes = buildWorkEpub(
      const <ExportChapter>[chapter1],
      title: '长夜行',
      modified: DateTime.utc(2026, 1, 2, 3, 4, 5),
    );

    // 本地文件头：偏移 0 为签名 0x04034b50，偏移 8 为压缩方式（小端 uint16）。
    expect(bytes.sublist(0, 4), <int>[0x50, 0x4b, 0x03, 0x04]);
    expect(bytes[8], 0); // STORE
    expect(bytes[9], 0);
    // 文件名长度在偏移 26，文件名从偏移 30 起。
    final nameLength = bytes[26] | (bytes[27] << 8);
    expect(nameLength, 8);
    expect(utf8.decode(bytes.sublist(30, 30 + nameLength)), 'mimetype');

    // 契约锁：mimetype 首条目且内容为标准 MIME（archive 升级破坏该行为立刻红灯）。
    final archive = ZipDecoder().decodeBytes(bytes);
    expect(archive.files.first.name, 'mimetype');
    expect(utf8.decode(archive.files.first.readBytes()!), 'application/epub+zip');
  });

  test('整作 epub：包含 container / opf / nav / 章节条目与必需元数据', () {
    final bytes = buildWorkEpub(
      const <ExportChapter>[chapter1, chapter2],
      title: '长夜行',
      modified: DateTime.utc(2026, 1, 2, 3, 4, 5),
    );

    final archive = ZipDecoder().decodeBytes(bytes);
    final names =
        archive.files.where((f) => f.isFile).map((f) => f.name).toList();
    expect(names, containsAll(<String>[
      'mimetype',
      'META-INF/container.xml',
      'OEBPS/content.opf',
      'OEBPS/nav.xhtml',
      'OEBPS/style.css',
      'OEBPS/chapter_1.xhtml',
      'OEBPS/chapter_2.xhtml',
    ]));

    final opf = utf8.decode(archive.files
        .firstWhere((f) => f.name == 'OEBPS/content.opf')
        .readBytes()!);
    expect(opf, contains('properties="nav"'));
    expect(opf, contains('<dc:identifier id="bookid">urn:novelphone:长夜行</dc:identifier>'));
    expect(opf, contains('>2026-01-02T03:04:05Z<'));
    expect(opf, contains('<dc:title>长夜行</dc:title>'));
    expect(opf, contains('<dc:language>zh-CN</dc:language>'));

    final container = utf8.decode(archive.files
        .firstWhere((f) => f.name == 'META-INF/container.xml')
        .readBytes()!);
    expect(container, contains('OEBPS/content.opf'));
  });

  test('整作 epub：章节 xhtml 以 XML 声明开头并正确转义', () {
    const chapter = ExportChapter(title: '第一章 雨', content: '他说：<走> & "好"。');
    final bytes = buildWorkEpub(const <ExportChapter>[chapter], title: '书');
    final archive = ZipDecoder().decodeBytes(bytes);
    final xhtml = utf8.decode(archive.files
        .firstWhere((f) => f.name == 'OEBPS/chapter_1.xhtml')
        .readBytes()!);

    expect(xhtml, startsWith('<?xml'));
    expect(xhtml, contains('<h1>第一章 雨</h1>'));
    expect(xhtml, contains('&lt;走&gt; &amp; &quot;好&quot;'));
  });

  test('epub 扩展名推断 MIME 类型', () {
    expect(mimeTypeForFileName('长夜行.epub'), epubMimeType);
    expect(mimeTypeForFileName('长夜行.EPUB'), epubMimeType);
  });
}