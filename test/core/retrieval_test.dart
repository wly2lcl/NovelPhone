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
  intent: '',
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

  test('同章片段数量与 topK 受限', () {
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
  });

  test('每章上限只限制最终命中，不会提前截掉靠后的相关块', () {
    final lateHit = _chapter(7, '长章', '${'甲' * 640}\n\n铜印藏在梁上。');

    final hits = retrievePassages(
      chapters: <Chapter>[lateHit],
      query: '铜印',
      maxPerChapter: 2,
    );

    expect(hits, isNotEmpty);
    expect(hits.first.text, contains('铜印'));
  });

  test('扫描预算按章均分，长篇靠后章节仍可命中（ENH-33）', () {
    final filler = _chapter(
      6,
      '集市',
      List<String>.generate(400, (i) => '清晨的集市人来人往，卖鱼人高声吆喝。').join('\n\n'),
    );
    final later = _chapter(
      7,
      '铜印',
      List<String>.generate(400, (i) => '铜印的秘密仍未解开。').join('\n\n'),
    );
    final hits = retrievePassages(
      chapters: <Chapter>[filler, later],
      query: '铜印的秘密',
      maxScanChars: 640,
    );
    expect(hits, isNotEmpty);
    expect(hits.first.chapterId, 7);
  });

  test('IDF 压低高频词，稀有名词片段优先（ENH-40）', () {
    final common = List<Chapter>.generate(
      20,
      (i) => _chapter(100 + i, '集市$i', '集市'),
    );
    final rare = _chapter(200, '铜印', '铜印');
    final hits = retrievePassages(
      chapters: <Chapter>[...common, rare],
      query: '铜印集市',
      topK: 1,
    );
    expect(hits.single.chapterId, 200);
  });

  test('查询提到别名时，同组本名片段也能召回（ENH-40）', () {
    final chapter = _chapter(10, '夜行', '沈砚推门而入，雨水湿了衣袖。');
    expect(
      retrievePassages(chapters: <Chapter>[chapter], query: '小砚'),
      isEmpty,
    );
    final hits = retrievePassages(
      chapters: <Chapter>[chapter],
      query: '小砚',
      aliasGroups: <List<String>>[
        <String>['沈砚', '小砚'],
      ],
    );
    expect(hits, isNotEmpty);
    expect(hits.first.chapterId, 10);
  });

  test('靠近当前章的片段小幅提权（ENH-40）', () {
    final chapters = <Chapter>[
      _chapter(11, '一', '铜印藏在梁上。'),
      _chapter(12, '二', '铜印藏在梁上。'),
      _chapter(13, '三', '铜印藏在梁上。'),
    ];
    final hits = retrievePassages(
      chapters: chapters,
      query: '铜印',
      topK: 2,
      excludeChapterId: 13,
      nearbyChapterId: 13,
    );
    expect(hits.map((hit) => hit.chapterId).toList(), <int>[12, 11]);
  });

  test('窗口检索保留绝对章节序号（ENH-40）', () {
    final hits = retrievePassages(
      chapters: <Chapter>[_chapter(11, '一', '铜印藏在梁上。')],
      query: '铜印',
      chapterIndexOffset: 60,
    );
    expect(hits.single.chapterIndex, 61);
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
    expect(text, isNot(contains('id=')));
  });

  test('作品问答来源可附带章节 id（ENH-43）', () {
    final text = formatRetrievedPassages(<RetrievedPassage>[
      const RetrievedPassage(
        chapterId: 2,
        chapterTitle: '灯下等人',
        chapterIndex: 2,
        text: '苏晚问起铜印。',
        score: 0.8,
      ),
    ], includeId: true);
    expect(text, contains('第 2 章 灯下等人（id=2）：苏晚问起铜印。'));
  });
}
