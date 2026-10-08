import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
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
}