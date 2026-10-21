import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/core/ai/chapter_intent.dart';

/// ENH-51：本章写作目标的结构化存储、容错解析与提示词渲染。
void main() {
  test('空目标编码为空串，不向上下文注入空标题', () {
    const intent = ChapterIntent();
    expect(intent.isEmpty, isTrue);
    expect(intent.encode(), '');
    expect(intent.toPromptText(), '');
    expect(ChapterIntent.parse('').isEmpty, isTrue);
    expect(ChapterIntent.parse('   ').isEmpty, isTrue);
  });

  test('编码与解析往返保留目标、节拍顺序与避免项', () {
    const intent = ChapterIntent(
      goal: '让沈砚决定离开雾港',
      beats: <String>['沈砚发现船票', '苏晚拦住他', '他仍然登船'],
      avoid: <String>['不要写回忆', '不要出现新角色'],
    );

    final restored = ChapterIntent.parse(intent.encode());

    expect(restored.goal, '让沈砚决定离开雾港');
    expect(restored.beats, <String>['沈砚发现船票', '苏晚拦住他', '他仍然登船']);
    expect(restored.avoid, <String>['不要写回忆', '不要出现新角色']);
  });

  test('非 JSON 旧数据按纯文本核心目标兼容', () {
    final parsed = ChapterIntent.parse('本章要收掉船票这条线');

    expect(parsed.goal, '本章要收掉船票这条线');
    expect(parsed.beats, isEmpty);
    expect(parsed.avoid, isEmpty);
  });

  test('解析时去重、丢弃空项并按上限截断', () {
    final parsed = ChapterIntent.parse(
      '{"goal":"${'目' * 200}",'
      '"beats":["一","一","  ","${'节' * 120}",'
      '"二","三","四","五","六","七","八","九"],'
      '"avoid":["甲","甲","乙","丙","丁","戊","己"]}',
    );

    expect(parsed.goal.runes.length, ChapterIntent.maxGoalChars);
    expect(parsed.beats, hasLength(ChapterIntent.maxBeats));
    expect(parsed.beats.first, '一');
    expect(parsed.beats[1].runes.length, ChapterIntent.maxBeatChars);
    expect(parsed.avoid, hasLength(ChapterIntent.maxAvoid));
    expect(parsed.avoid.first, '甲');
    expect(parsed.avoid.where((item) => item == '甲'), hasLength(1));
  });

  test('提示词按核心目标 / 节拍 / 避免项的顺序渲染', () {
    const intent = ChapterIntent(
      goal: '收掉船票线',
      beats: <String>['发现船票', '登船'],
      avoid: <String>['回忆杀'],
    );

    final text = intent.toPromptText();

    expect(text, startsWith('【本章写作目标】'));
    expect(text, contains('核心目标：收掉船票线'));
    expect(text.indexOf('关键节拍（按顺序）：'), lessThan(text.indexOf('1. 发现船票')));
    expect(text, contains('2. 登船'));
    expect(text.indexOf('避免（本章不要出现）：'), lessThan(text.indexOf('- 回忆杀')));
  });

  test('splitIntentLines 忽略空行、去重并按上限截断', () {
    final lines = splitIntentLines(
      '第一拍\n\n  第一拍  \n${'长' * 100}\n第二拍\n第三拍',
      maxCount: 3,
    );

    expect(lines, hasLength(3));
    expect(lines[0], '第一拍');
    expect(lines[1].runes.length, ChapterIntent.maxBeatChars);
    expect(lines[2], '第二拍');
  });
}
