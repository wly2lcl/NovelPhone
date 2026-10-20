import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:novelphone/data/db.dart';
import 'package:novelphone/data/repositories/chapter_repository.dart';
import 'package:novelphone/data/repositories/character_repository.dart';
import 'package:novelphone/data/repositories/outline_repository.dart';
import 'package:novelphone/data/repositories/setting_repository.dart';
import 'package:novelphone/data/repositories/settings_repository.dart';
import 'package:novelphone/data/repositories/story_state_repository.dart';
import 'package:novelphone/data/repositories/token_stats_repository.dart';
import 'package:novelphone/data/repositories/work_repository.dart';
import 'package:novelphone/core/ai/context_builder.dart';
import 'package:novelphone/data/secure_key_store.dart';
import 'package:novelphone/features/ai/ai_service.dart';
import 'package:novelphone/models/setting_type.dart';
import 'package:novelphone/models/story_state_kind.dart';
import 'package:novelphone/models/work_style_guide.dart';

void main() {
  late AppDatabase db;
  late WorkRepository works;
  late ChapterRepository chapters;
  late CharacterRepository characters;
  late SettingRepository settings;
  late SettingsRepository config;
  late TokenStatsRepository stats;
  late int workId;
  late int chapterId;

  AiService serviceWith(http.Client client) => AiService(
    settings: config,
    works: works,
    chapters: chapters,
    characters: characters,
    outline: OutlineRepository(db),
    stats: stats,
    settingRepository: settings,
    storyStateRepository: StoryStateRepository(db),
    httpClient: client,
  );

  http.Response sseResponse(String content) {
    final payload = jsonEncode(<String, dynamic>{
      'choices': <dynamic>[
        <String, dynamic>{
          'delta': <String, dynamic>{'content': content},
          'finish_reason': 'stop',
        },
      ],
      'usage': <String, dynamic>{'prompt_tokens': 120, 'completion_tokens': 30},
    });
    return http.Response.bytes(
      utf8.encode('data: $payload\n\ndata: [DONE]\n\n'),
      200,
      headers: <String, String>{'content-type': 'text/event-stream'},
    );
  }

  Future<void> configure(
    String task, {
    double inputPrice = 0,
    double outputPrice = 0,
  }) async {
    final id = await config.createModelGroup(
      name: '测试模型',
      provider: 'openai_compat',
      baseUrl: 'https://api.example.com/v1',
      models: <String>['m1'],
      apiKey: 'sk-test',
      inputPricePerMillion: inputPrice,
      outputPricePerMillion: outputPrice,
    );
    await config.setTaskModel(task, id);
  }

  setUp(() async {
    db = AppDatabase.memory();
    works = WorkRepository(db);
    chapters = ChapterRepository(db);
    characters = CharacterRepository(db);
    settings = SettingRepository(db);
    config = SettingsRepository(db, InMemoryKeyStore());
    stats = TokenStatsRepository(db);
    workId = await works.createWork(title: '长夜行');
    chapterId = await chapters.createChapter(workId: workId, title: '第一章');
    await chapters.saveChapter(
      chapterId: chapterId,
      title: '第一章',
      content: '少年推开木门，风灌了进来。他叫沈砚。',
    );
    await chapters.createChapter(workId: workId, title: '第二章');
  });

  tearDown(() async {
    await db.close();
  });

  test('文风提取：解析档案、回填现有字段并记录 style 用量', () async {
    await works.updateStyleGuide(
      workId,
      const WorkStyleGuide(perspective: '第一人称'),
    );
    await configure(AiTask.style);
    final client = MockClient(
      (request) async => sseResponse(
        '{"perspective":"第三人称限知","tone":"冷峻克制","taboos":["少用感叹号"],"sample":"雨落在刀鞘上。"}',
      ),
    );

    final result = await serviceWith(client).extractStyleGuide(workId: workId);

    expect(result.guide.perspective, '第三人称限知');
    expect(result.guide.tone, '冷峻克制');
    expect(result.guide.taboos, '少用感叹号');
    expect(result.guide.sample, '雨落在刀鞘上。');
    expect(result.result.promptTokens, 120);
    final summary = await stats.stats();
    expect(summary.rows.first.task, AiTask.style);
  });

  test('设定补全：抽取角色、设定与关系并记录 extract 用量', () async {
    await configure(AiTask.extract);
    final client = MockClient(
      (request) async => sseResponse(
        '{"characters":[{"name":"沈砚","identity":"游侠","性格":["沉默","克制"]},'
        '{"name":"苏晚","身份":"医女"}],'
        '"settings":[{"name":"长夜城","type":"地点","content":"北境边城"}],'
        '"relations":[{"from":"沈砚","to":"苏晚","label":"旧识"}]}',
      ),
    );

    final result = await serviceWith(client).extractEntities(workId: workId);

    expect(result.extraction.parseFailed, isFalse);
    expect(result.extraction.characters.first.name, '沈砚');
    expect(result.extraction.characters.first.personality, '沉默、克制');
    expect(result.extraction.settings.single.type, SettingType.location);
    expect(result.extraction.relations.single.from, '沈砚');
    expect(result.extraction.relations.single.to, '苏晚');
    expect(result.extraction.relations.single.label, '旧识');
    final summary = await stats.stats();
    expect(summary.rows.single.task, AiTask.extract);
  });

  test('状态提取：携带现有卡片、解析变化并记录 storyState 用量（ENH-35）', () async {
    final states = StoryStateRepository(db);
    await states.createEntry(
      workId: workId,
      kind: StoryStateKind.foreshadow,
      title: '铜印来历',
    );
    await states.createEntry(
      workId: workId,
      kind: StoryStateKind.foreshadow,
      title: '密信去向',
      status: 'closed',
    );
    await configure(AiTask.storyState);
    String? systemPrompt;
    String? userPrompt;
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      systemPrompt = body['messages'][0]['content'] as String;
      userPrompt = body['messages'][1]['content'] as String;
      return sseResponse(
        '{"states":['
        '{"kind":"character","title":"沈砚","detail":"左臂中箭，暂不能提刀","status":"open"},'
        '{"kind":"foreshadow","title":"铜印来历","status":"closed"},'
        '{"kind":"timeline","title":"雨夜入城"}]}',
      );
    });

    final result = await serviceWith(
      client,
    ).extractStoryStates(workId: workId, chapterId: chapterId);

    expect(result.extraction.parseFailed, isFalse);
    expect(result.extraction.suggestions, hasLength(3));
    expect(result.extraction.suggestions[0].kind, StoryStateKind.character);
    expect(result.extraction.suggestions[0].detail, '左臂中箭，暂不能提刀');
    expect(result.extraction.suggestions[1].kind, StoryStateKind.foreshadow);
    expect(result.extraction.suggestions[1].closes, isTrue);
    expect(result.extraction.suggestions[2].kind, StoryStateKind.timeline);
    expect(systemPrompt, contains('"states"'));
    expect(userPrompt, contains('【已有状态卡】'));
    expect(userPrompt, contains('铜印来历（未回收）'));
    expect(userPrompt, contains('密信去向（已回收）'));
    expect(userPrompt, contains('【本章正文】'));
    expect(userPrompt, contains('他叫沈砚'));
    final summary = await stats.stats();
    expect(summary.rows.single.task, AiTask.storyState);
  });

  test('剧情推演：携带作者方向并解析走向与分章', () async {
    await configure(AiTask.plan);
    late String userPrompt;
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final messages = body['messages'] as List<dynamic>;
      final user =
          messages.lastWhere((m) => (m as Map)['role'] == 'user') as Map;
      userPrompt = user['content'] as String;
      return sseResponse(
        '{"directions":[{"title":"雪夜决裂","summary":"沈砚发现苏晚隐瞒身份",'
        '"beats":["对质","亮出信物"],"hook":"信物与灭门案有关"}],'
        '"chapters":[{"title":"第十二章 雪夜","summary":"对质与决裂"}]}',
      );
    });

    final result = await serviceWith(
      client,
    ).planPlot(workId: workId, direction: '让苏晚主动摊牌');

    expect(userPrompt, contains('作者希望的方向：让苏晚主动摊牌'));
    expect(result.plan.directions.single.title, '雪夜决裂');
    expect(result.plan.directions.single.hook, contains('灭门案'));
    expect(result.plan.chapters.single.title, '第十二章 雪夜');
    expect(result.plan.parseFailed, isFalse);
  });

  test('模型只输出推理而无可见正文时抛出明确错误并保留两次用量', () async {
    await configure(AiTask.plan);
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return sseResponse('');
    });

    await expectLater(
      serviceWith(client).planPlot(workId: workId),
      throwsA(
        isA<AiServiceException>().having(
          (e) => e.message,
          'message',
          contains('已自动提高输出上限重试'),
        ),
      ),
    );
    expect(calls, 2);
    final summary = await stats.stats();
    expect(summary.rows.single.task, AiTask.plan);
    expect(summary.rows.single.calls, 2);
    expect(summary.rows.single.completionTokens, 60);
  });

  test('空正文自动提高输出上限重试一次并返回内容', () async {
    await configure(AiTask.plan);
    final maxTokens = <int>[];
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      maxTokens.add(body['max_tokens'] as int);
      if (maxTokens.length == 1) return sseResponse('');
      return sseResponse(
        '{"directions":[{"title":"雪夜来客","summary":"门外有人求见",'
        '"beats":["开门","认出旧识"],"hook":"来客带着染血的剑穗"}],'
        '"chapters":[{"title":"第十三章 雪夜来客","summary":"旧识登场"}]}',
      );
    });

    final result = await serviceWith(client).planPlot(workId: workId);

    expect(maxTokens, <int>[1024, 2048]);
    expect(result.plan.directions.single.title, '雪夜来客');
    final summary = await stats.stats();
    expect(summary.rows.single.calls, 2);
    expect(summary.rows.single.completionTokens, 60);
  });

  test('作品问答：注入历史、返回流式回答并记录 chat 用量', () async {
    await configure(AiTask.chat);
    late Map<String, dynamic> requestBody;
    final client = MockClient((request) async {
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return sseResponse('苏晚是医女，与沈砚是旧识。');
    });

    final events = await serviceWith(client)
        .chat(
          workId: workId,
          history: const <ChatContextTurn>[
            ChatContextTurn(role: 'user', content: '第一章讲了什么？'),
            ChatContextTurn(role: 'assistant', content: '沈砚离乡。'),
          ],
          message: '苏晚是谁？',
        )
        .toList();

    expect(events.whereType<AiContextBuilt>(), isNotEmpty);
    final finished = events.whereType<AiFinished>().single;
    expect(finished.text, '苏晚是医女，与沈砚是旧识。');
    final messages = requestBody['messages'] as List<dynamic>;
    final chatMessages = messages.sublist(1); // 首条为系统提示
    expect(chatMessages, hasLength(3));
    expect((chatMessages[0] as Map)['content'], '第一章讲了什么？');
    expect((chatMessages[1] as Map)['role'], 'assistant');
    expect((chatMessages[2] as Map)['content'], '苏晚是谁？');
    final tools = requestBody['tools'] as List<dynamic>;
    expect(
      tools.map((t) => ((t as Map)['function'] as Map)['name']),
      containsAll(<String>['get_chapter', 'search_chapters', 'get_settings']),
    );
    final summary = await stats.stats();
    expect(summary.rows.single.task, AiTask.chat);
  });

  test('月度统计只累计当月用量，预算可设置与清除', () async {
    final now = DateTime(2026, 10, 18);
    await db
        .into(db.aiUsages)
        .insert(
          AiUsagesCompanion.insert(
            task: AiTask.summary,
            model: 'm1',
            createdAt: DateTime(2026, 9, 20),
            promptTokens: const Value(10),
            completionTokens: const Value(10),
          ),
        );
    await db
        .into(db.aiUsages)
        .insert(
          AiUsagesCompanion.insert(
            task: AiTask.plan,
            model: 'm1',
            createdAt: DateTime(2026, 10, 2),
            promptTokens: const Value(20),
            completionTokens: const Value(10),
          ),
        );

    final monthly = await stats.monthlyStats(now);
    expect(monthly.calls, 1);
    expect(monthly.rows.single.task, AiTask.plan);
    expect(monthly.totalTokens, 30);
    expect((await stats.stats()).calls, 2);

    expect(await config.monthlyBudget(), 0);
    await config.setMonthlyBudget(5.5);
    expect(await config.monthlyBudget(), 5.5);
    await config.setMonthlyBudget(0);
    expect(await config.monthlyBudget(), 0);
  });

  test('流式一致性检查：返回上下文与完整报告', () async {
    await configure(AiTask.continuity);
    final client = MockClient((request) async => sseResponse('冲突：角色年龄前后不一致。'));

    final events = await serviceWith(
      client,
    ).streamContinuity(workId: workId, chapterId: chapterId).toList();

    expect(events.whereType<AiContextBuilt>(), isNotEmpty);
    final finished = events.whereType<AiFinished>().single;
    expect(finished.text, contains('角色年龄'));
    final summary = await stats.stats();
    expect(summary.rows.single.task, AiTask.continuity);
  });
}
