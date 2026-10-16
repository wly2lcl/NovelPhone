import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/core/text_search.dart';

/// ENH-19：编辑面板与全书替换共用的查找/替换纯函数。
void main() {
  group('findTextMatches', () {
    test('默认忽略大小写，命中区间落在原文', () {
      final matches = findTextMatches('Alice met alice.', 'alice');

      expect(matches.map((m) => (m.start, m.end)), [(0, 5), (10, 15)]);
    });

    test('区分大小写开关', () {
      expect(
        findTextMatches('Alice alice', 'Alice', caseSensitive: true),
        hasLength(1),
      );
      expect(
        findTextMatches(
          'Alice alice',
          'alice',
          caseSensitive: true,
        ).single.start,
        6,
      );
    });

    test('只计非重叠命中', () {
      expect(findTextMatches('aaaa', 'aa'), hasLength(2));
    });

    test('空关键词不命中', () {
      expect(findTextMatches('abc', ''), isEmpty);
    });

    test('偏移按 UTF-16 计数（emoji 占两个单元）', () {
      final matches = findTextMatches('😀街道', '街道');

      expect(matches, hasLength(1));
      expect(matches.single.start, 2);
      expect(matches.single.end, 4);
    });
  });

  group('replaceTextMatches', () {
    test('全部替换并返回处数', () {
      final result = replaceTextMatches('街道尽头是海，另一条街道通向山谷。', '街道', '小巷');

      expect(result.text, '小巷尽头是海，另一条小巷通向山谷。');
      expect(result.count, 2);
    });

    test('无命中时原样返回', () {
      final result = replaceTextMatches('abc', 'x', 'y');

      expect(result.text, 'abc');
      expect(result.count, 0);
    });

    test('忽略大小写替换：全部命中均替换为给定文本', () {
      final result = replaceTextMatches('Alice met alice.', 'alice', 'Bob');

      expect(result.text, 'Bob met Bob.');
      expect(result.count, 2);
    });
  });
}
