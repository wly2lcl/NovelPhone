import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/core/ai/collaboration_rules.dart';

/// ENH-44：协作守则、套话黑名单与本地套话发现。
void main() {
  test('守则与黑名单去重、裁剪并限制条数', () {
    final rules = CollaborationRules.sanitize(
      rules: <String>['  保持短句  ', '保持短句', '', '不写心理独白'],
      banned: <String>['不由自主', ' 不由自主 ', '仿佛'],
    );
    expect(rules.rules, <String>['保持短句', '不写心理独白']);
    expect(rules.banned, <String>['不由自主', '仿佛']);

    final many = CollaborationRules.sanitize(
      rules: List<String>.generate(15, (i) => '守则 $i'),
      banned: List<String>.generate(25, (i) => '词 $i'),
    );
    expect(many.rules, hasLength(CollaborationRules.maxRules));
    expect(many.banned, hasLength(CollaborationRules.maxBanned));

    final long = CollaborationRules.sanitize(
      rules: <String>[List<String>.filled(200, '字').join()],
      banned: <String>[List<String>.filled(80, '词').join()],
    );
    expect(long.rules.single.runes.length, CollaborationRules.maxRuleChars + 1);
    expect(
      long.banned.single.runes.length,
      CollaborationRules.maxBannedChars + 1,
    );
  });

  test('脏 JSON 容忍并只保留字符串条目', () {
    expect(
      CollaborationRules.parseList('not json', maxItems: 10, maxChars: 10),
      isEmpty,
    );
    expect(
      CollaborationRules.parseList(
        '["甲", 3, null, "甲", "乙"]',
        maxItems: 10,
        maxChars: 10,
      ),
      <String>['甲', '乙'],
    );
    expect(CollaborationRules.encodeList(<String>['a', 'b']), '["a","b"]');
  });

  test('注入文本包含守则与黑名单，无内容时为空串', () {
    final block = CollaborationRules.promptBlock(
      rules: <String>['保持短句'],
      banned: <String>['不由自主'],
    );
    expect(block, contains('【协作守则】'));
    expect(block, contains('- 保持短句'));
    expect(block, contains('「不由自主」'));
    expect(
      CollaborationRules.promptBlock(
        rules: const <String>[],
        banned: const <String>[],
      ),
      isEmpty,
    );
  });

  test('从被放弃的 AI 产出中发现套话并按次数排序', () {
    final suggestions = AiCliche.suggest(
      rejectedTexts: <String>['他不由自主地怔住，心中一颤，空气仿佛凝固。', '她不由自主地后退，空气仿佛凝固了。'],
      banned: const <String>['心中一颤'],
    );
    expect(suggestions, contains('不由自主'));
    expect(suggestions, contains('空气仿佛凝固'));
    expect(suggestions, isNot(contains('心中一颤')));
    expect(suggestions.length, lessThanOrEqualTo(6));
  });

  test('新增条目置顶去重', () {
    final next = CollaborationRules.add(
      <String>['旧守则'],
      '新守则',
      maxItems: 10,
      maxChars: 120,
    );
    expect(next, <String>['新守则', '旧守则']);
    final deduped = CollaborationRules.add(
      <String>['旧守则'],
      '旧守则',
      maxItems: 10,
      maxChars: 120,
    );
    expect(deduped, <String>['旧守则']);
  });
}
