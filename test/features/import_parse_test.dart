import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/core/exporter/text_exporter.dart';
import 'package:novelphone/core/importer/chapter_splitter.dart';
import 'package:novelphone/features/work_detail/import_page.dart';

/// 导入解析（ENH-12）：解析移入独立 isolate 后，结果必须仍与同步解析完全一致，
/// 且 `ChapterDraft` 能安全跨 isolate 传递。
/// 用例直接调用生产入口 `parseImportFileAsync`，避免测试与真实接线各写一份。
void main() {
  test('txt 解析经 isolate 执行，与同步分章一致（ENH-12）', () async {
    final text =
        List.generate(40, (i) => '第${i + 1}章 标题$i\n${'雨' * 200}').join('\n');
    final bytes = Uint8List.fromList(utf8.encode(text));

    final parsed = await parseImportFileAsync('novel.txt', bytes);
    final expected = splitIntoChapters(text, fallbackTitle: 'novel');

    expect(parsed.encoding, 'UTF-8');
    expect(parsed.drafts.length, 40);
    expect(parsed.drafts.length, expected.length);
    for (var i = 0; i < expected.length; i++) {
      expect(parsed.drafts[i].title, expected[i].title);
      expect(parsed.drafts[i].content, expected[i].content);
      expect(parsed.drafts[i].wordCount, expected[i].wordCount);
    }
  });

  test('docx 解析经 isolate 执行（ENH-12）', () async {
    final bytes = buildWorkDocx(const <ExportChapter>[
      ExportChapter(title: '第一章', content: '少年推开木门，风灌了进来。'),
      ExportChapter(title: '第二章', content: '沈砚在雨里走了很久。'),
    ]);

    final parsed = await parseImportFileAsync('长夜行.docx', bytes);

    expect(parsed.encoding, 'docx');
    expect(parsed.drafts.length, 2);
    expect(parsed.drafts[0].title, '第一章');
    expect(parsed.drafts[0].content, contains('少年推开木门'));
    expect(parsed.drafts[1].content, contains('沈砚在雨里走了很久'));
  });
}
