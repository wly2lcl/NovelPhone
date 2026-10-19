import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/core/ai/retrieval.dart';
import 'package:novelphone/data/db.dart';

Chapter _chapter(int id, String title, String content) => Chapter(
  id: id,
  volumeId: 1,
  title: title,
  content: content,
  wordCount: content.length,
  status: 'draft',
  sortOrder: id,
  cursorOffset: 0,
  scrollOffset: 0,
  updatedAt: DateTime(2026, 10, 19),
  summary: '',
);

/// RAG-lite 本地检索（ENH-32）。
void main() {
  final chapters = <Chapter>[
    _chapter(1, '密文归来', '沈砚推开木门，雨水打湿了衣襟。他把铜印藏进袖中。'),
    _chapter(2, '灯下等人', '苏晚在灯下缝补旧衣，听见门外脚步。她问：铜印找到了吗？'),
    _chapter(3, '码头夜谈', '老陈在码头说起十年前的旧案，海风很大。'),
    _chapter(4, '无关章节', '清晨的集市人来人往，卖鱼人高声吆喝。'),
  ];

  test('按字符 bigram 相似度返回最相关片段，并排除当前章', () {
    final hits = retrievePassages(
      chapters: chapters,
      query: '铜印在哪里？',
      topK: 2,
      excludeChapterId: 1,
    );

    expect(hits, isNotEmpty);
    expect(hits.first.chapterId, 2);
    expect(hits.first.chapterTitle, '灯下等人');
    expect(hits.first.chapterIndex, 2);
    expect(hits.first.text, contains('铜印'));
    expect(hits.map((hit) => hit.chapterId), isNot(contains(1)));
  });

  test('空查询 / 无命中返回空列表', () {
    expect(retrievePassages(chapters: chapters, query: '  '), isEmpty);
    expect(retrievePassages(chapters: chapters, query: '宇宙飞船降落在火星'), isEmpty);
  });

  test('同章片段数量与 topK 受限，且不扫描超过字符上限的内容', () {
    final long = _chapter(
      5,
      '铜印',
      List<String>.generate(20, (i) => '第$i段：铜印的秘密仍未解开。').join('\n\n'),
    );
    final hits = retrievePassages(
      chapters: <Chapter>[long],
      query: '铜印的秘密',
      topK: 3,
      maxPerChapter: 2,
    );
    expect(hits.length, lessThanOrEqualTo(2));

    // 第一个无命中章节已耗尽扫描预算，后续章节不再读取。
    final filler = _chapter(6, '集市', '清晨的集市人来人往，卖鱼人高声吆喝。');
    final limited = retrievePassages(
      chapters: <Chapter>[filler, long],
      query: '铜印的秘密',
      maxScanChars: 10,
    );
    expect(limited, isEmpty);
  });

  test('格式化输出包含章节序号、标题与片段正文', () {
    final text = formatRetrievedPassages(<RetrievedPassage>[
      const RetrievedPassage(
        chapterId: 2,
        chapterTitle: '灯下等人',
        chapterIndex: 2,
        text: '苏晚问起铜印。',
        score: 0.8,
      ),
    ]);
    expect(text, contains('【相关前文片段】'));
    expect(text, contains('第 2 章 灯下等人：苏晚问起铜印。'));
  });
}
