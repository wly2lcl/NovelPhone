import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:novelphone/core/ai/context_builder.dart';
import 'package:novelphone/core/ai/structured_response.dart';
import 'package:novelphone/core/ai/writing_preferences.dart';
import 'package:novelphone/data/db.dart';
import 'package:novelphone/data/repositories/chapter_repository.dart';
import 'package:novelphone/data/repositories/character_repository.dart';
import 'package:novelphone/data/repositories/outline_repository.dart';
import 'package:novelphone/data/repositories/setting_repository.dart';
import 'package:novelphone/data/repositories/settings_repository.dart';
import 'package:novelphone/data/repositories/token_stats_repository.dart';
import 'package:novelphone/data/repositories/work_repository.dart';
import 'package:novelphone/data/secure_key_store.dart';
import 'package:novelphone/features/ai/ai_service.dart';

/// ENH-27：分段采纳 / 多轮修改 / 本地偏好闭环的存储、上下文与请求装配。
void main() {
  late AppDatabase db;
  late WorkRepository works;
  late ChapterRepository chapters;
  late CharacterRepository characters;
  late OutlineRepository outline;
  late SettingRepository settings;
  late SettingsRepository config;
  late TokenStatsRepository stats;
  late ContextBuilder builder;
  late int workId;
  late int chapterId;

  setUp(() async {
    db = AppDatabase.memory();
    works = WorkRepository(db);
    chapters = ChapterRepository(db);
    characters = CharacterRepository(db);
    outline = OutlineRepository(db);
    settings = SettingRepository(db);
    config = SettingsRepository(db, InMemoryKeyStore());
    stats = TokenStatsRepository(db);
    builder = ContextBuilder(
      works: works,
      chapters: chapters,
      characters: characters,
      outline: outline,
      settings: settings,
    );
    workId = await works.createWork(title: '长夜行');
    chapterId = await chapters.createChapter(workId: workId, title: '第一章');
    await chapters.saveChapter(
      chapterId: chapterId,
      title: '第一章',
      content: '少年推开木门，风灌了进来。他叫沈砚。',
    );
  });

  tearDown(() async {
    await db.close();
  });

  AiService serviceWith(http.Client client) => AiService(
    settings: config,
    works: works,
    chapters: chapters,
    characters: characters,
    outline: outline,
    stats: stats,
    settingRepository: settings,
    httpClient: client,
  );

  Future<void> configure(String task) async {
    final id = await config.createModelGroup(
      name: '测试模型',
      provider: 'openai_compat',
      baseUrl: 'https://api.example.com/v1',
      models: <String>['m1'],
      apiKey: 'sk-test',
    );
    await config.setTaskModel(task, id);
  }

  http.Response sseResponse(String content) {
    final payload = jsonEncode(<String, dynamic>{
      'choices': <dynamic>[
        <String, dynamic>{
          'delta': <String, dynamic>{'content': content},
          'finish_reason': 'stop',
        },
      ],
      'usage': <String, dynamic>{'prompt_tokens': 100, 'completion_tokens': 20},
    });
    return http.Response.bytes(
      utf8.encode('data: $payload\n\ndata: [DONE]\n\n'),
      200,
      headers: <String, String>{'content-type': 'text/event-stream'},
    );
  }

  test('忽略原因按作品计数，采纳样本去重、限长并容忍脏数据', () async {
    await config.recordAiFeedback(workId, AiFeedbackReason.tooAi);
    await config.recordAiFeedback(workId, AiFeedbackReason.tooAi);
    await config.recordAiFeedback(workId, 'unknown');
    expect(await config.readAiFeedback(workId), <String, int>{
      AiFeedbackReason.tooAi: 2,
    });
    expect(await config.readAiFeedback(workId + 999), isEmpty);

    for (var i = 0; i < WritingPreferences.maxSamples + 2; i++) {
      await config.recordAdoptedSample(
        workId,
        text: '片段$i',
        task: AiTask.continueWriting,
      );
    }
    final samples = await config.readAdoptedSamples(workId);
    expect(samples, hasLength(WritingPreferences.maxSamples));
    expect(samples.first.text, '片段6');

    await config.setSetting(
      SettingsRepository.aiFeedbackKey(workId),
      'not-json',
    );
    await config.setSetting(
      SettingsRepository.aiAdoptedSamplesKey(workId),
      '[{"text":""},{"text":"有效样本","task":"rewrite"}]',
    );
    expect(await config.readAiFeedback(workId), isEmpty);
    expect((await config.readAdoptedSamples(workId)).single.text, '有效样本');
  });

  test('配对采纳样本落库并保留原稿（ENH-42）', () async {
    await config.recordAdoptedSample(
      workId,
      text: '他把刀放回鞘里，没再说话。',
      source: '他将长刀收回鞘中，沉默不语。',
      task: AiTask.rewrite,
    );
    final samples = await config.readAdoptedSamples(workId);
    expect(samples.single.text, '他把刀放回鞘里，没再说话。');
    expect(samples.single.source, '他将长刀收回鞘中，沉默不语。');
    expect(samples.single.hasSource, isTrue);
  });

  test('续写修订上下文：当前草稿 + 修改意见 + 协作偏好，替换原续写任务', () async {
    final built = await builder.buildContinue(
      workId: workId,
      chapterId: chapterId,
      revisionDraft: '甲段。\n乙段。',
      revisionInstruction: '对白更克制',
      preferenceText: '【作者协作偏好】\n- 测试规则',
    );
    final user = built.messages.single.content;
    expect(user, contains('【当前续写草稿】\n甲段。\n乙段。'));
    expect(user, contains('作者本次修改意见（优先满足）：对白更克制'));
    expect(user, isNot(contains('【续写要求】')));
    expect(built.system, contains('【作者协作偏好】'));
    expect(built.sections.map((section) => section.label), contains('作者协作偏好'));
  });

  test('改写修订上下文：原文与当前改写草稿同时保留', () async {
    final built = await builder.buildRewrite(
      workId: workId,
      chapterId: chapterId,
      selectedText: '原文一。\n原文二。',
      intent: 'polish',
      revisionDraft: '草稿一。',
      revisionInstruction: '去掉最后一句',
      preferenceText: '【作者协作偏好】\n- 作者偏好',
    );
    final user = built.messages.single.content;
    expect(user, contains('【待改写原文】\n原文一。\n原文二。'));
    expect(user, contains('【当前改写草稿】\n草稿一。'));
    expect(user, contains('本次修改意见（优先满足）：去掉最后一句'));
    expect(user, isNot(contains('【改写要求】')));
    expect(built.system, contains('作者偏好'));
  });

  test('关闭偏好开关后不再注入，清空只删计数与样本', () async {
    await config.recordAiFeedback(workId, AiFeedbackReason.offCharacter);
    await config.recordAiFeedback(workId, AiFeedbackReason.offCharacter);
    await config.recordAiParagraphFeedback(workId, AiFeedbackReason.slowPace);
    await config.recordAdoptedSample(
      workId,
      text: '他把刀放回鞘里，没说话。',
      task: AiTask.continueWriting,
    );
    expect(await config.readAiPreferencesEnabled(workId), isTrue);

    await config.setAiPreferencesEnabled(workId, false);
    expect(await config.readAiPreferencesEnabled(workId), isFalse);

    await configure(AiTask.continueWriting);
    String? requestBody;
    final client = MockClient((request) async {
      requestBody = request.body;
      return sseResponse('他停了半步。');
    });
    await serviceWith(client)
        .continueWriting(workId: workId, chapterId: chapterId, length: 300)
        .toList();
    final decoded = jsonDecode(requestBody!) as Map<String, dynamic>;
    final messages = decoded['messages'] as List<dynamic>;
    final system =
        (messages.first as Map<String, dynamic>)['content'] as String;
    expect(system, isNot(contains('【作者协作偏好】')));

    await config.clearAiPreferences(workId);
    expect(await config.readAiFeedback(workId), isEmpty);
    expect(await config.readAiParagraphFeedback(workId), isEmpty);
    expect(await config.readAdoptedSamples(workId), isEmpty);
    expect(await config.readAiPreferencesEnabled(workId), isFalse);
  });

  test('永久删除作品时清理偏好键', () async {
    await config.recordAiFeedback(workId, AiFeedbackReason.tooAi);
    await config.recordAiParagraphFeedback(workId, AiFeedbackReason.slowPace);
    await config.recordAdoptedSample(workId, text: '片段', task: AiTask.rewrite);
    await config.setAiPreferencesEnabled(workId, false);
    await config.ignoreContinuityIssue(
      workId,
      const ContinuityIssue(quote: '沈砚没有出声', source: '角色卡·沈砚'),
      reason: '有意保留',
    );
    for (final key in WritingPreferences.keysFor(workId)) {
      expect(await config.getSetting(key), isNotNull);
    }

    await works.deleteWork(workId);

    for (final key in WritingPreferences.keysFor(workId)) {
      expect(await config.getSetting(key), isNull);
    }
  });

  test('一致性忽略项按作品持久化、去重并可恢复（ENH-41）', () async {
    const issue = ContinuityIssue(quote: '沈砚没有出声', source: '角色卡·沈砚');
    final entry = await config.ignoreContinuityIssue(
      workId,
      issue,
      reason: '后续会解释',
    );
    expect(entry, isNotNull);
    await config.ignoreContinuityIssue(
      workId,
      const ContinuityIssue(quote: '「沈砚没有出声」', source: '角色卡-沈砚'),
      reason: '重复来源',
    );

    final entries = await config.readContinuitySuppressions(workId);
    expect(entries, hasLength(1));
    expect(entries.single.reason, '重复来源');

    await config.restoreContinuitySuppression(workId, entry!.fingerprint);
    expect(await config.readContinuitySuppressions(workId), isEmpty);

    await config.ignoreContinuityIssue(workId, issue);
    await config.clearContinuitySuppressions(workId);
    expect(await config.readContinuitySuppressions(workId), isEmpty);
  });

  test('续写请求注入高频偏好与采纳片段，修订意见进入用户消息', () async {
    await configure(AiTask.continueWriting);
    await config.recordAiFeedback(workId, AiFeedbackReason.offCharacter);
    await config.recordAiFeedback(workId, AiFeedbackReason.offCharacter);
    await config.recordAdoptedSample(
      workId,
      text: '他把刀放回鞘里，没说话。',
      task: AiTask.continueWriting,
    );
    String? requestBody;
    final client = MockClient((request) async {
      requestBody = request.body;
      return sseResponse('他停了半步。');
    });

    final events = await serviceWith(client)
        .continueWriting(
          workId: workId,
          chapterId: chapterId,
          length: 300,
          revisionDraft: '旧草稿。',
          revisionInstruction: '对白更少',
        )
        .toList();

    expect(events.whereType<AiFinished>(), hasLength(1));
    final decoded = jsonDecode(requestBody!) as Map<String, dynamic>;
    final messages = decoded['messages'] as List<dynamic>;
    final system =
        (messages.first as Map<String, dynamic>)['content'] as String;
    final user = (messages[1] as Map<String, dynamic>)['content'] as String;
    expect(system, contains('避免角色出戏'));
    expect(system, contains('他把刀放回鞘里'));
    expect(user, contains('【当前续写草稿】\n旧草稿。'));
    expect(user, contains('对白更少'));
    expect(user, isNot(contains('【续写要求】')));
  });

  test('分段未采纳原因与整篇原因合并注入，采纳片优先同类任务', () async {
    await config.recordAiFeedback(workId, AiFeedbackReason.offCharacter);
    await config.recordAiFeedback(workId, AiFeedbackReason.offCharacter);
    await config.recordAiParagraphFeedback(workId, AiFeedbackReason.slowPace);
    await config.recordAiParagraphFeedback(workId, AiFeedbackReason.slowPace);
    await config.recordAiParagraphFeedback(workId, 'unknown');
    expect(await config.readAiParagraphFeedback(workId), <String, int>{
      AiFeedbackReason.slowPace: 2,
    });
    // 分段计数与整篇计数分开保存，不污染整篇口径。
    expect(await config.readAiFeedback(workId), <String, int>{
      AiFeedbackReason.offCharacter: 2,
    });

    // 更新的改写片段默认排前，续写任务应把同类片段提到前面。
    await config.recordAdoptedSample(
      workId,
      text: '旧续写片段甲。',
      task: AiTask.continueWriting,
    );
    await config.recordAdoptedSample(
      workId,
      text: '新改写片段乙。',
      task: AiTask.rewrite,
    );

    await configure(AiTask.continueWriting);
    String? requestBody;
    final client = MockClient((request) async {
      requestBody = request.body;
      return sseResponse('他停了半步。');
    });
    await serviceWith(client)
        .continueWriting(workId: workId, chapterId: chapterId, length: 300)
        .toList();

    final decoded = jsonDecode(requestBody!) as Map<String, dynamic>;
    final messages = decoded['messages'] as List<dynamic>;
    final system =
        (messages.first as Map<String, dynamic>)['content'] as String;
    expect(system, contains('避免角色出戏'));
    expect(system, contains('加快叙事节奏'));
    final continueIndex = system.indexOf('旧续写片段甲');
    final rewriteIndex = system.indexOf('新改写片段乙');
    expect(continueIndex, greaterThanOrEqualTo(0));
    expect(rewriteIndex, greaterThan(continueIndex));
  });
}
