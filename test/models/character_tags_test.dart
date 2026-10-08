import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/models/character_tags.dart';

void main() {
  group('decodeTags', () {
    test('解析 JSON 数组字符串', () {
      expect(decodeTags('["冷静","腹黑"]'), <String>['冷静', '腹黑']);
    });

    test('空字符串与非数组内容返回空列表', () {
      expect(decodeTags(''), isEmpty);
      expect(decodeTags('   '), isEmpty);
      expect(decodeTags('{"a":1}'), isEmpty);
    });

    test('兼容空格分隔的纯文本', () {
      expect(decodeTags('冷静 腹黑'), <String>['冷静', '腹黑']);
    });
  });

  group('encodeTags', () {
    test('去空并编码为 JSON', () {
      expect(encodeTags(<String>[' 冷静 ', '', '腹黑']), '["冷静","腹黑"]');
    });

    test('全空返回空字符串', () {
      expect(encodeTags(<String>['', '  ']), '');
    });
  });

  group('parseTagInput', () {
    test('支持空格、逗号、顿号分隔', () {
      expect(parseTagInput('冷静，腹黑、多疑 隐忍'),
          <String>['冷静', '腹黑', '多疑', '隐忍']);
    });

    test('超过上限时截断', () {
      final input = List<String>.generate(12, (i) => '标签$i').join(' ');
      expect(parseTagInput(input, max: 10).length, 10);
    });
  });
}