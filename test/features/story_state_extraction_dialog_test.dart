import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:novelphone/app/theme.dart';
import 'package:novelphone/data/data_providers.dart';
import 'package:novelphone/data/db.dart';
import 'package:novelphone/data/repositories/chapter_repository.dart';
import 'package:novelphone/data/repositories/character_repository.dart';
import 'package:novelphone/data/repositories/outline_repository.dart';
import 'package:novelphone/data/repositories/setting_repository.dart';
import 'package:novelphone/data/repositories/settings_repository.dart';
import 'package:novelphone/data/repositories/story_state_repository.dart';
import 'package:novelphone/data/repositories/token_stats_repository.dart';
import 'package:novelphone/data/repositories/work_repository.dart';
import 'package:novelphone/data/secure_key_store.dart';
import 'package:novelphone/features/ai/ai_providers.dart';
import 'package:novelphone/features/ai/ai_service.dart';
import 'package:novelphone/features/editor/story_state_extraction_dialog.dart';
import 'package:novelphone/l10n/generated/app_localizations.dart';
import 'package:novelphone/models/story_state_kind.dart';

/// ENH-35：状态提取对话框的勾选与应用。
void main() {
  late AppDatabase db;
  late StoryStateRepository states;
  late int workId;
  late int chapterId;
  late AiService service;
  late int shenId;
  late int suId;
  late int guId;
  late String statesJson;
  late String relationChangesJson;

  setUp(() async {
    db = AppDatabase.memory();
    final works = WorkRepository(db);
    final chapters = ChapterRepository(db);
    final settings = SettingRepository(db);
    states = StoryStateRepository(db);
    workId = await works.createWork(title: '长夜行');
    chapterId = await chapters.createChapter(workId: workId, title: '第一章');
    await chapters.saveChapter(
      chapterId: chapterId,
      title: '第一章',
      content: '沈砚左臂中箭，仍握紧了铜印。',
    );
    await states.createEntry(
      workId: workId,
      kind: StoryStateKind.foreshadow,
      title: '铜印来历',
      detail: '旧线索',
    );
    await states.createEntry(
      workId: workId,
      kind: StoryStateKind.timeline,
      title: '雨夜入城',
      detail: '子时从西门进城',
    );
    // ENH-56：预置角色与一条已有关联，验证关系变化的新增 / 更新应用。
    final characters = CharacterRepository(db);
    shenId = await characters.createCharacter(
      workId: workId,
      name: '沈砚',
      aliases: '["沈公子"]',
    );
    suId = await characters.createCharacter(workId: workId, name: '苏晚');
    guId = await characters.createCharacter(workId: workId, name: '顾寒');
    await characters.createRelation(
      workId: workId,
      fromCharacterId: shenId,
      toCharacterId: suId,
      label: '同门',
    );

    final config = SettingsRepository(db, InMemoryKeyStore());
    final groupId = await config.createModelGroup(
      name: '测试模型',
      provider: 'openai_compat',
      baseUrl: 'https://api.example.com/v1',
      models: <String>['m1'],
      apiKey: 'sk-test',
    );
    await config.setTaskModel(AiTask.storyState, groupId);
    statesJson =
        '{"kind":"character","title":"沈砚","detail":"左臂中箭，仍握紧铜印"},'
        '{"kind":"foreshadow","title":"铜印来历","status":"closed"},'
        '{"kind":"timeline","title":"雨夜入城","detail":"子时从西门进城"}';
    relationChangesJson =
        '{"from":"沈公子","to":"顾寒","label":"宿敌","action":"add"},'
        '{"from":"沈砚","to":"苏晚","label":"师姐","action":"update"},'
        '{"from":"无名氏","to":"沈砚","label":"同门","action":"add"}';
    final client = MockClient((request) async {
      final payload = jsonEncode(<String, dynamic>{
        'choices': <dynamic>[
          <String, dynamic>{
            'delta': <String, dynamic>{
              'content':
                  '{"states":[$statesJson],'
                  '"relationChanges":[$relationChangesJson]}',
            },
            'finish_reason': 'stop',
          },
        ],
        'usage': <String, dynamic>{
          'prompt_tokens': 80,
          'completion_tokens': 40,
        },
      });
      return http.Response.bytes(
        utf8.encode('data: $payload\n\ndata: [DONE]\n\n'),
        200,
        headers: <String, String>{'content-type': 'text/event-stream'},
      );
    });
    service = AiService(
      settings: config,
      works: works,
      chapters: chapters,
      characters: CharacterRepository(db),
      outline: OutlineRepository(db),
      stats: TokenStatsRepository(db),
      settingRepository: settings,
      storyStateRepository: states,
      httpClient: client,
    );
  });

  tearDown(() => db.close());

  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          secureKeyStoreProvider.overrideWithValue(InMemoryKeyStore()),
          aiServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          theme: buildPaperTheme(),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => showStoryStateExtractionDialog(
                    context,
                    workId: workId,
                    chapterId: chapterId,
                  ),
                  child: const Text('打开'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pump();
  }

  Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 80; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
      if (finder.evaluate().isNotEmpty) return;
    }
  }

  testWidgets('默认勾选新增与更新，应用后落库并关闭伏笔', (tester) async {
    await pumpHost(tester);
    await pumpUntil(tester, find.textContaining('[角色状态] 沈砚'));

    expect(find.textContaining('[角色状态] 沈砚'), findsOneWidget);
    expect(find.textContaining('[伏笔] 铜印来历'), findsOneWidget);
    expect(find.textContaining('[时间线] 雨夜入城'), findsOneWidget);
    // ENH-56：关系变化区块——新增 / 更新默认勾选，未知名不可选。
    expect(find.text('人物关系变化'), findsOneWidget);
    expect(find.textContaining('[人物关系变化] 沈公子 → 顾寒'), findsOneWidget);
    expect(find.textContaining('沈砚 → 苏晚：师姐'), findsOneWidget);
    expect(find.text('新增'), findsNWidgets(2));
    expect(find.text('更新'), findsNWidgets(2));
    expect(find.text('与现有卡片一致'), findsOneWidget);
    expect(find.text('未找到对应角色'), findsOneWidget);
    expect(find.text('应用选中项（4）'), findsOneWidget);

    await tester.tap(find.text('应用选中项（4）'));
    await pumpUntil(tester, find.textContaining('已新增 1 张、更新 1 张状态卡'));
    expect(find.textContaining('关系图：新增 1 条、更新 1 条、解除 0 条'), findsOneWidget);

    final entries = await states.listEntries(workId);
    expect(entries, hasLength(3));
    final character = entries.firstWhere(
      (e) => e.kind == StoryStateKind.character.value,
    );
    expect(character.title, '沈砚');
    expect(character.detail, '左臂中箭，仍握紧铜印');
    expect(character.chapterId, chapterId);
    final closed = entries.firstWhere((e) => e.title == '铜印来历');
    expect(closed.status, 'closed');
    expect(closed.detail, '旧线索');
    expect(entries.firstWhere((e) => e.title == '雨夜入城').detail, '子时从西门进城');

    // ENH-56：别名「沈公子」解析到沈砚；更新保留原方向仅改称谓。
    final relations = await CharacterRepository(db).listRelations(workId);
    expect(relations, hasLength(2));
    final rival = relations.firstWhere((r) => r.label == '宿敌');
    expect(rival.fromCharacterId, shenId);
    expect(rival.toCharacterId, isNot(suId));
    final senior = relations.firstWhere((r) => r.label == '师姐');
    expect(senior.fromCharacterId, shenId);
    expect(senior.toCharacterId, suId);
  });

  testWidgets('关系方向独立，别名重复项只落库一次（ENH-56）', (tester) async {
    statesJson = '';
    relationChangesJson =
        '{"from":"沈公子","to":"顾寒","label":"宿敌","action":"add"},'
        '{"from":"沈砚","to":"顾寒","label":"盟友","action":"add"},'
        '{"from":"苏晚","to":"沈砚","label":"师妹","action":"add"},'
        '{"from":"沈砚","to":"苏晚","label":"师姐","action":"add"}';
    await pumpHost(tester);
    await pumpUntil(tester, find.textContaining('[人物关系变化] 沈公子 → 顾寒'));

    // 后两条方向相反：苏晚 → 沈砚 是新增，沈砚 → 苏晚 是更新。
    expect(find.text('新增'), findsNWidgets(3));
    expect(find.text('更新'), findsOneWidget);
    expect(find.text('应用选中项（4）'), findsOneWidget);

    await tester.tap(find.text('应用选中项（4）'));
    await pumpUntil(tester, find.textContaining('关系图：新增 2 条、更新 1 条、解除 0 条'));

    final relations = await CharacterRepository(db).listRelations(workId);
    expect(relations, hasLength(3));
    final forward = relations.where(
      (r) => r.fromCharacterId == shenId && r.toCharacterId == guId,
    );
    expect(forward, hasLength(1));
    expect(forward.single.label, '宿敌');
    expect(
      relations
          .singleWhere(
            (r) => r.fromCharacterId == suId && r.toCharacterId == shenId,
          )
          .label,
      '师妹',
    );
    expect(
      relations
          .singleWhere(
            (r) => r.fromCharacterId == shenId && r.toCharacterId == suId,
          )
          .label,
      '师姐',
    );
  });
}
