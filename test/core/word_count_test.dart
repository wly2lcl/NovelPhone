import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/core/word_count.dart';
import 'package:novelphone/l10n/l10n.dart';

void main() {
  group('countWords 中文字数统计', () {
    test('汉字逐字计数', () {
      expect(countWords('今天天气很好'), 6);
    });

    test('空白与标点不计入', () {
      expect(countWords('你好，世界！\n\n  你好'), 6);
    });

    test('连续拉丁字母与数字按词计', () {
      expect(countWords('hello world 2026'), 3);
      expect(countWords('abc123def'), 1);
    });

    test('中英混排', () {
      expect(countWords('他用 iPhone 拍了 3 张照片'), 9);
    });

    test('空文本为 0', () {
      expect(countWords(''), 0);
      expect(countWords(' \n\t '), 0);
    });
  });

  group('formatWordCount 字数展示', () {
    final zh = lookupAppLocalizations(const Locale('zh'));
    final en = lookupAppLocalizations(const Locale('en'));

    test('中文一万以内显示原值', () {
      expect(formatWordCount(0, zh), '0 字');
      expect(formatWordCount(9999, zh), '9999 字');
    });

    test('中文超过一万按万保留一位小数', () {
      expect(formatWordCount(10000, zh), '1.0 万字');
      expect(formatWordCount(123456, zh), '12.3 万字');
    });

    test('英文按 K / M 折算', () {
      expect(formatWordCount(999, en), '999 words');
      expect(formatWordCount(5800, en), '5.8K words');
      expect(formatWordCount(123456, en), '123K words');
      expect(formatWordCount(2500000, en), '2.5M words');
    });
  });
}
