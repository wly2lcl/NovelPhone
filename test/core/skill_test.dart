import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:novelphone/core/ai/agent_core.dart';
import 'package:novelphone/core/ai/ai_client.dart';
import 'package:novelphone/core/ai/context_builder.dart';
import 'package:novelphone/core/ai/skills/skill.dart';
import 'package:novelphone/data/db.dart';
import 'package:novelphone/data/repositories/chapter_repository.dart';
import 'package:novelphone/data/repositories/character_repository.dart';
import 'package:novelphone/data/repositories/outline_repository.dart';
import 'package:novelphone/data/repositories/settings_repository.dart';
import 'package:novelphone/data/repositories/token_stats_repository.dart';
import 'package:novelphone/data/repositories/work_repository.dart';
import 'package:novelphone/data/secure_key_store.dart';
import 'package:novelphone/features/ai/ai_service.dart';

Tool _tool(String name) => Tool(
      name: name,
      description: name,
      inputSchema: const <String, dynamic>{'type': 'object'},
      execute: (_) async => '',
    );

void main() {
  group('Skill 模型', () {
    test('JSON 往返保住全部字段', () {
      const skill = Skill(
        id: 3,
        name: '冷硬短句',
        instruction: '只用短句，限制在 {{字数}} 字内。',
        enabled: false,
        allowedTools: <String>['get_chapter'],
        parameters: <String, String>{'字数': '800'},
      );
      final restored = Skill.fromJson(
        jsonDecode(jsonEncode(skill.toJson())) as Map<String, dynamic>,
      );
      expect(restored.id, 3);
      expect(restored.name, '冷硬短句');
      expect(restored.enabled, isFalse);
      expect(restored.allowedTools, <String>['get_chapter']);
      expect(restored.parameters['字数'], '800');
    });

    test('脏数据缺字段时给出安全默认值', () {
      final skill = Skill.fromJson(<String, dynamic>{'id': 1});
      expect(skill.name, '');
      expect(skill.enabled, isTrue);
      expect(skill.allowedTools, isEmpty);
      expect(skill.parameters, isEmpty);
    });

    test('renderInstruction 替换参数模板', () {
      const skill = Skill(
        id: 1,
        name: 'x',
        instruction: '每段不超过 {{字数}} 字，视角：{{视角}}。',
        parameters: <String, String>{'字数': '120'},
      );
      expect(skill.renderInstruction(), '每段不超过 120 字，视角：{{视角}}。');
    });
  });

  group('编排注入', () {
    test('composeSkillSystem 追加技能指令；无技能时原样返回', () {
      expect(composeSkillSystem('基础指令', const <Skill>[]), '基础指令');
      final composed = composeSkillSystem('基础指令', const <Skill>[
        Skill(id: 1, name: '冷硬短句', instruction: '只用短句。'),
      ]);
      expect(composed, contains('基础指令'));
      expect(composed, contains('【用户技能：冷硬短句】'));
      expect(composed, contains('只用短句。'));
    });

    test('指令为空的技能不产生段落', () {
      final composed = composeSkillSystem('基础', const <Skill>[
        Skill(id: 1, name: '空技能', instruction: '   '),
      ]);
      expect(composed, '基础');
    });

    test('filterToolsBySkills：无白名单不限制，有白名单取并集过滤', () {
      final tools = <Tool>[_tool('get_chapter'), _tool('get_characters')];
      expect(filterToolsBySkills(tools, const <Skill>[]), tools);
      expect(
        filterToolsBySkills(tools, const <Skill>[
          Skill(id: 1, name: 'a', instruction: 'x'),
        ]),
        tools,
      );
      final filtered = filterToolsBySkills(tools, const <Skill>[
        Skill(id: 1, name: 'a', instruction: 'x', allowedTools: <String>['get_chapter']),
        Skill(id: 2, name: 'b', instruction: 'y', allowedTools: <String>['mcp_foo']),
      ]);
      expect(filtered.map((t) => t.name), <String>['get_chapter']);
    });

    test('BuiltContext.withSystem 同步估算 token 并插入技能段落', () {
      const built = BuiltContext(
        system: '旧system',
        messages: <ChatMessage>[],
        sections: <ContextSection>[ContextSection(label: 'a', content: 'b')],
        truncated: false,
        estimatedTokens: 100,
        budgetTokens: 1000,
      );
      final injected = built.withSystem(
        '旧system加长一段',
        section: const ContextSection(label: '用户技能', content: '冷硬短句'),
      );
      expect(injected.system, '旧system加长一段');
      expect(injected.estimatedTokens, 100 + '旧system加长一段'.length - '旧system'.length);
      expect(injected.sections.first.label, '用户技能');
      expect(injected.sections, hasLength(2));
    });
  });

  group('SettingsRepository 技能持久化', () {
    late AppDatabase db;
    late SettingsRepository settings;

    setUp(() {
      db = AppDatabase.memory();
      settings = SettingsRepository(db, InMemoryKeyStore());
    });

    tearDown(() async => db.close());

    test('新增 / 读取 / 启用停用 / 更新 / 删除', () async {
      final id = await settings.createSkill(
        name: '冷硬短句',
        instruction: '只用短句。',
        allowedTools: <String>['get_chapter'],
        parameters: <String, String>{'字数': '800'},
      );
      expect(id, 1);

      var list = await settings.listSkills();
      expect(list, hasLength(1));
      expect(list.single.parameters['字数'], '800');
      expect(await settings.listEnabledSkills(), hasLength(1));

      await settings.setSkillEnabled(id, false);
      expect(await settings.listEnabledSkills(), isEmpty);

      await settings.updateSkill(
        list.single.copyWith(enabled: true, name: '冷硬短句 v2'),
      );
      list = await settings.listSkills();
      expect(list.single.name, '冷硬短句 v2');
      expect(list.single.parameters['字数'], '800');

      await settings.deleteSkill(id);
      expect(await settings.listSkills(), isEmpty);
    });

    test('指令为空的技能不参与编排注入', () async {
      await settings.createSkill(name: '空', instruction: '   ');
      expect(await settings.listEnabledSkills(), isEmpty);
    });

    test('脏数据不抛异常', () async {
      await settings.setSetting(SettingsRepository.skillsKey, 'not-json');
      expect(await settings.listSkills(), isEmpty);
    });
  });

  group('AiService 续写注入', () {
    late AppDatabase db;
    late SettingsRepository settings;
    late AiService service;
    late int workId;
    late int chapterId;
    late List<String> requestBodies;

    setUp(() async {
      db = AppDatabase.memory();
      settings = SettingsRepository(db, InMemoryKeyStore());
      final works = WorkRepository(db);
      final chapters = ChapterRepository(db);
      workId = await works.createWork(title: '长夜行');
      chapterId = await chapters.createChapter(workId: workId, title: '第一章');
      await chapters.saveChapter(
        chapterId: chapterId,
        title: '第一章',
        content: '她不禁笑了。',
      );
      final groupId = await settings.createModelGroup(
        name: '续写模型',
        provider: 'openai_compat',
        baseUrl: 'https://api.example.com/v1',
        models: <String>['m1'],
        apiKey: 'sk-test',
      );
      await settings.setTaskModel(AiTask.continueWriting, groupId);

      requestBodies = <String>[];
      service = AiService(
        settings: settings,
        works: works,
        chapters: chapters,
        characters: CharacterRepository(db),
        outline: OutlineRepository(db),
        stats: TokenStatsRepository(db),
        httpClient: MockClient((request) async {
          requestBodies.add(utf8.decode(request.bodyBytes));
          final payload = jsonEncode(<String, dynamic>{
            'choices': <dynamic>[
              <String, dynamic>{
                'delta': <String, dynamic>{'content': '续写结果'},
                'finish_reason': 'stop',
              },
            ],
            'usage': <String, dynamic>{'prompt_tokens': 10, 'completion_tokens': 4},
          });
          return http.Response.bytes(
            utf8.encode('data: $payload\n\ndata: [DONE]\n\n'),
            200,
            headers: <String, String>{'content-type': 'text/event-stream'},
          );
        }),
      );
    });

    tearDown(() async => db.close());

    test('启用的技能指令进入 system，并出现在上下文详情', () async {
      await settings.createSkill(
        name: '冷硬短句',
        instruction: '只用短句，避免解释性旁白。',
      );

      final events = await service
          .continueWriting(workId: workId, chapterId: chapterId)
          .toList();

      final built = events.whereType<AiContextBuilt>().single.context;
      expect(built.system, contains('只用短句，避免解释性旁白。'));
      expect(
        built.sections.any((s) => s.label == '用户技能' && s.content.contains('冷硬短句')),
        isTrue,
      );
      expect(requestBodies.single, contains('只用短句，避免解释性旁白。'));
      expect(events.last, isA<AiFinished>());
    });

    test('停用的技能不注入', () async {
      final id = await settings.createSkill(
        name: '停用技能',
        instruction: '这段不该出现。',
      );
      await settings.setSkillEnabled(id, false);

      final events = await service
          .continueWriting(workId: workId, chapterId: chapterId)
          .toList();

      final built = events.whereType<AiContextBuilt>().single.context;
      expect(built.system, isNot(contains('这段不该出现。')));
      expect(built.sections.any((s) => s.label == '用户技能'), isFalse);
      expect(requestBodies.single, isNot(contains('这段不该出现。')));
    });
  });
}