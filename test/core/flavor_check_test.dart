import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/core/ai/flavor_check.dart';
import 'package:novelphone/core/ai_flavor_rules.dart';
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
      updatedAt: DateTime(2026, 9, 30),
    );

void main() {
  group('检查范围（M4-06）', () {
    test('拼接多章并记录各章起始偏移', () {
      final scope = buildCheckScope(<Chapter>[
        _chapter(1, '第一章', '她不禁笑了。'),
        _chapter(2, '第二章', '他缓缓开口。'),
      ]);
      expect(scope.segments, hasLength(2));
      expect(scope.segments[0].start, 0);
      expect(scope.text.startsWith('她不禁笑了。'), isTrue);
      expect(scope.wordCount, greaterThan(0));
      expect(scope.isEmpty, isFalse);
    });

    test('全局偏移可定位回章节', () {
      final scope = buildCheckScope(<Chapter>[
        _chapter(1, '第一章', '她不禁笑了。'),
        _chapter(2, '第二章', '他缓缓开口。'),
      ]);
      final second = scope.segments[1];
      final located = scope.locate(second.start + 1);
      expect(located, isNotNull);
      expect(located!.chapterId, 2);
      expect(located.offsetInChapter, 1);
      expect(scope.locate(0)!.chapterId, 1);
    });

    test('空章节范围标记为空', () {
      final scope = buildCheckScope(<Chapter>[_chapter(1, '空章', '')]);
      expect(scope.isEmpty, isTrue);
    });
  });

  group('分段送检（M4-06）', () {
    test('分段覆盖全文且不超长', () {
      final text =
          List<String>.generate(50, (i) => '第 $i 段：他走进屋子，看了她一眼，没有说话。')
              .join('\n');
      final segments = splitDeepCheckSegments(text, maxChars: 60);
      expect(segments.length, greaterThan(1));

      final buffer = StringBuffer();
      for (final segment in segments) {
        expect(segment.start, buffer.length);
        expect(segment.text.length, lessThanOrEqualTo(60));
        buffer.write(segment.text);
      }
      expect(buffer.toString(), text);
    });

    test('优先在段落边界断开', () {
      final text = '${'甲' * 30}\n${'乙' * 30}\n${'丙' * 30}';
      final segments = splitDeepCheckSegments(text, maxChars: 40);
      expect(segments.first.text.endsWith('\n'), isTrue);
    });
  });

  group('深检结果解析（M4-06 / M4-07）', () {
    const segment = '她不禁笑了，缓缓开口：“也好。”';

    test('解析标准 JSON 并还原偏移', () {
      final outcome = parseDeepCheckResponse(
        '{"issues":[{"type":"套话","severity":"高","quote":"不禁",'
        '"suggestion":"删除该词"}]}',
        segmentText: segment,
        segmentOffset: 100,
      );
      expect(outcome.parseFailed, isFalse);
      final issue = outcome.issues.single;
      expect(issue.type, FlavorType.cliche);
      expect(issue.severity, FlavorSeverity.high);
      expect(issue.start, 101);
      expect(issue.end, 103);
      expect(issue.excerpt, '不禁');
      expect(issue.suggestion, '删除该词');
      expect(issue.source, FlavorSource.llm);
    });

    test('容忍代码块包裹与前后解释文字', () {
      final outcome = parseDeepCheckResponse(
        '检查结果如下：\n```json\n{"issues":[{"type":"句式重复","severity":"中",'
        '"quote":"缓缓开口"}]}\n```\n以上。',
        segmentText: segment,
        segmentOffset: 0,
      );
      expect(outcome.parseFailed, isFalse);
      expect(outcome.issues.single.type, FlavorType.repetition);
      expect(outcome.issues.single.severity, FlavorSeverity.medium);
      expect(outcome.issues.single.start, segment.indexOf('缓缓开口'));
    });

    test('容忍裸数组与中文键名', () {
      final outcome = parseDeepCheckResponse(
        '[{"问题类型":"翻译腔","严重度":"低","原文":"也好","修改建议":"改成口语"}]',
        segmentText: segment,
        segmentOffset: 0,
      );
      expect(outcome.issues.single.type, FlavorType.translationese);
      expect(outcome.issues.single.severity, FlavorSeverity.low);
      expect(outcome.issues.single.suggestion, '改成口语');
    });

    test('原文片段定位不到时按不可定位处理', () {
      final outcome = parseDeepCheckResponse(
        '{"issues":[{"type":"套话","severity":"中","quote":"这句话不在原文里"}]}',
        segmentText: segment,
        segmentOffset: 10,
      );
      final issue = outcome.issues.single;
      expect(issue.start, 10);
      expect(issue.end, 10);
      expect(issue.isDocumentLevel, isTrue);
    });

    test('无问题时返回空列表', () {
      final outcome = parseDeepCheckResponse(
        '{"issues":[]}',
        segmentText: segment,
        segmentOffset: 0,
      );
      expect(outcome.issues, isEmpty);
      expect(outcome.parseFailed, isFalse);
    });

    test('非 JSON 输出降级为纯文本', () {
      final outcome = parseDeepCheckResponse(
        '这段文字里有明显的套话，"不禁"用得太多了。',
        segmentText: segment,
        segmentOffset: 0,
      );
      expect(outcome.parseFailed, isTrue);
      expect(outcome.issues, isEmpty);
      expect(outcome.fallbackText, contains('不禁'));
    });

    test('空白输出不产生降级文本', () {
      final outcome = parseDeepCheckResponse(
        '   ',
        segmentText: segment,
        segmentOffset: 0,
      );
      expect(outcome.parseFailed, isTrue);
      expect(outcome.fallbackText, isNull);
    });
  });
}