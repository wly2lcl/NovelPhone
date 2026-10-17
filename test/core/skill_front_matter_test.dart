import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/core/ai/skills/skill.dart';
import 'package:novelphone/core/ai/skills/skill_front_matter.dart';

void main() {
  group('parseSkillFrontMatter 正常解析', () {
    test('完整 front matter：块列表 + 块映射 + enabled=false', () {
      const raw = '''
---
name: 悬疑推进
description: 每章结尾留下悬念
allowed-tools:
  - get_chapter
  - update_chapter
parameters:
  tone: 冷峻
  era: 民国
enabled: false
---
请在续写时保持{{tone}}的笔调。
''';
      final draft = parseSkillFrontMatter(raw);
      expect(draft.name, '悬疑推进');
      expect(draft.description, '每章结尾留下悬念');
      expect(draft.allowedTools, <String>['get_chapter', 'update_chapter']);
      expect(draft.parameters, <String, String>{'tone': '冷峻', 'era': '民国'});
      expect(draft.enabled, isFalse);
      expect(draft.instruction, '请在续写时保持{{tone}}的笔调。');
    });

    test('行内列表与行内参数对', () {
      const raw = '''
---
name: 短句控
allowed-tools: [get_chapter, search]
parameters: tone=凛冽, pace=快
---
只用短句。
''';
      final draft = parseSkillFrontMatter(raw);
      expect(draft.allowedTools, <String>['get_chapter', 'search']);
      expect(draft.parameters, <String, String>{'tone': '凛冽', 'pace': '快'});
      expect(draft.enabled, isTrue);
      expect(draft.description, '');
    });

    test('逗号分隔列表与去引号', () {
      const raw = '''
---
name: "引号名"
allowed_tools: a, b, c
---
正文。
''';
      final draft = parseSkillFrontMatter(raw);
      expect(draft.name, '引号名');
      expect(draft.allowedTools, <String>['a', 'b', 'c']);
    });

    test('BOM 与 CRLF 容忍、未知键忽略', () {
      const raw =
          '\uFEFF---\r\nname: 兼容\r\nmodel: gpt\r\nenabled: true\r\n---\r\n内容\r\n';
      final draft = parseSkillFrontMatter(raw);
      expect(draft.name, '兼容');
      expect(draft.enabled, isTrue);
      expect(draft.instruction, '内容');
    });

    test('enabled 各种写法', () {
      for (final value in <String>['1', 'true', 'yes', 'on']) {
        final draft = parseSkillFrontMatter(
          '---\nname: x\nenabled: $value\n---\n正文',
        );
        expect(draft.enabled, isTrue, reason: 'enabled: $value');
      }
      for (final value in <String>['0', 'false', 'no', 'off']) {
        final draft = parseSkillFrontMatter(
          '---\nname: x\nenabled: $value\n---\n正文',
        );
        expect(draft.enabled, isFalse, reason: 'enabled: $value');
      }
    });
  });

  group('parseSkillFrontMatter 报错', () {
    test('没有 front matter 开头', () {
      expect(
        () => parseSkillFrontMatter('直接是正文'),
        throwsA(isA<FormatException>()),
      );
    });

    test('缺少结束标记', () {
      expect(
        () => parseSkillFrontMatter('---\nname: x\n正文'),
        throwsA(isA<FormatException>()),
      );
    });

    test('name 为空', () {
      expect(
        () => parseSkillFrontMatter('---\ndescription: x\n---\n正文'),
        throwsA(isA<FormatException>()),
      );
    });

    test('正文为空', () {
      expect(
        () => parseSkillFrontMatter('---\nname: x\n---\n   \n'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('skillToMarkdown 往返', () {
    test('导出后再解析得到等价字段', () {
      const skill = Skill(
        id: 7,
        name: '卷首语',
        instruction: '为每一章生成一段{{style}}的卷首语。',
        description: '章前小序',
        enabled: false,
        allowedTools: <String>['get_chapter'],
        parameters: <String, String>{'style': '古风'},
      );
      final markdown = skillToMarkdown(skill);
      final draft = parseSkillFrontMatter(markdown);
      expect(draft.name, skill.name);
      expect(draft.description, skill.description);
      expect(draft.instruction, skill.instruction);
      expect(draft.enabled, skill.enabled);
      expect(draft.allowedTools, skill.allowedTools);
      expect(draft.parameters, skill.parameters);
    });
  });
}
