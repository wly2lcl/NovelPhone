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

  test('ENH-49 守则按任务作用域过滤并可往返解析', () {
    const scopes = <String, List<String>>{
      '保持短句': <String>[CollabRuleTask.continueWriting],
      '多用对白': <String>[
        CollabRuleTask.rewrite,
        CollabRuleTask.inspire,
        'unknown',
      ],
    };
    final clean = CollaborationRules.sanitize(
      rules: <String>['保持短句', '多用对白'],
      scopes: scopes,
    );
    expect(clean.scopes['多用对白'], <String>[
      CollabRuleTask.rewrite,
      CollabRuleTask.inspire,
    ]);
    expect(
      CollaborationRules.promptBlock(
        rules: clean.rules,
        banned: const <String>[],
        scopes: clean.scopes,
        task: CollabRuleTask.continueWriting,
      ),
      contains('保持短句'),
    );
    expect(
      CollaborationRules.promptBlock(
        rules: clean.rules,
        banned: const <String>[],
        scopes: clean.scopes,
        task: CollabRuleTask.continueWriting,
      ),
      isNot(contains('多用对白')),
    );
    expect(
      CollaborationRules.promptBlock(
        rules: clean.rules,
        banned: const <String>[],
        scopes: clean.scopes,
        task: CollabRuleTask.plot,
      ),
      isEmpty,
    );
    final parsed = CollaborationRules.parseScopes(
      CollaborationRules.encodeScopes(clean.scopes),
    );
    expect(parsed, clean.scopes);
  });

  test('ENH-49 识别方向相反的守则', () {
    final conflicts = CollaborationRules.conflicts(<String>[
      '描写尽量精简，删去冗词',
      '多补充环境细节，写得更详细',
      '多用对白推进',
    ]);
    expect(conflicts, hasLength(1));
    expect(conflicts.single.first, contains('精简'));
    expect(
      CollaborationRules.conflicts(
        <String>['描写尽量精简', '少写对白'],
        scopes: <String, List<String>>{
          '描写尽量精简': <String>[CollabRuleTask.continueWriting],
          '少写对白': <String>[CollabRuleTask.plot],
        },
      ),
      isEmpty,
    );
  });

  test('ENH-48 本地守则自检合并黑名单、守则引号词与词库套话', () {
    final result = CollaborationRules.inspectText(
      '他不由自主地后退，空气仿佛凝固，仿佛时间停住。',
      rules: const <String>['禁止使用「时间停住」'],
      banned: const <String>['不由自主'],
    );
    expect(result.total, greaterThanOrEqualTo(3));
    expect(result.issues.any((e) => e.phrase == '不由自主' && e.isBanned), isTrue);
    expect(
      result.issues.any((e) => e.phrase == '空气仿佛凝固' && e.isCliche),
      isTrue,
    );
    expect(result.issues.any((e) => e.phrase == '仿佛'), isTrue);
    expect(CollaborationRules.inspectText('这段文字干净利落。').isEmpty, isTrue);
  });

  test('ENH-50 词库扩展套话候选并给出替换建议', () {
    expect(AiCliche.candidates.length, greaterThan(100));
    expect(AiCliche.replacementOf('嘴角勾起'), '嘴角扬了扬');
    final suggestions = AiCliche.suggest(
      rejectedTexts: <String>['他不禁微微一顿，嘴角勾起一抹笑，意味深长。'],
      banned: const <String>[],
    );
    expect(suggestions, contains('嘴角勾起'));
    expect(suggestions, contains('意味深长'));
    expect(suggestions.length, lessThanOrEqualTo(6));
    // 长词已经提示时，不再重复提示其包含的短词。
    expect(
      suggestions.where((e) => e == '不禁' || e == '微微').length,
      lessThan(2),
    );
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
