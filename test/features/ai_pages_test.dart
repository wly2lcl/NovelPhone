import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/app/theme.dart';
import 'package:novelphone/data/dao/app_setting_dao.dart';
import 'package:novelphone/data/data_providers.dart';
import 'package:novelphone/data/db.dart';
import 'package:novelphone/data/repositories/chat_repository.dart';
import 'package:novelphone/data/repositories/chapter_repository.dart';
import 'package:novelphone/data/repositories/work_repository.dart';
import 'package:novelphone/data/secure_key_store.dart';
import 'package:novelphone/features/work_detail/continuity_scan_page.dart';
import 'package:novelphone/features/work_detail/entity_extraction_page.dart';
import 'package:novelphone/features/work_detail/plot_plan_page.dart';
import 'package:novelphone/features/work_detail/style_guide_page.dart';
import 'package:novelphone/features/work_detail/work_chat_page.dart';
import 'package:novelphone/l10n/generated/app_localizations.dart';
import 'package:novelphone/models/work_chat_turn.dart';

/// ENH-23 新页面：加载、空态与未配置提示。
void main() {
  late AppDatabase db;
  late int workId;

  setUp(() async {
    db = AppDatabase.memory();
    workId = await WorkRepository(db).createWork(title: '长夜行');
  });

  tearDown(() => db.close());

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          secureKeyStoreProvider.overrideWithValue(InMemoryKeyStore()),
        ],
        child: MaterialApp(
          theme: buildPaperTheme(),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: page,
        ),
      ),
    );
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

  Future<void> disposePage(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('作品问答：历史渲染、清空后回到空态', (tester) async {
    final chat = ChatRepository(AppSettingDao(db));
    await chat.save(workId, const <WorkChatTurn>[
      WorkChatTurn(role: 'user', content: '第一章讲了什么？'),
      WorkChatTurn(role: 'assistant', content: '沈砚离乡。'),
    ]);

    await pumpPage(tester, WorkChatPage(workId: workId));
    await pumpUntil(tester, find.text('沈砚离乡。'));

    expect(find.text('第一章讲了什么？'), findsOneWidget);
    expect(find.text('沈砚离乡。'), findsOneWidget);
    expect(find.text('和 AI 聊聊这部作品'), findsNothing);

    await tester.tap(find.byTooltip('清空对话'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '清空'));
    await pumpUntil(tester, find.text('和 AI 聊聊这部作品'));

    expect(find.text('第一章讲了什么？'), findsNothing);
    expect(await chat.load(workId), isEmpty);

    await disposePage(tester);
  });

  testWidgets('剧情推演：未配置时提示配置且不发起请求', (tester) async {
    await pumpPage(tester, PlotPlanPage(workId: workId));
    expect(find.text('剧情推演'), findsOneWidget);
    expect(find.text('开始推演'), findsOneWidget);

    await tester.tap(find.text('开始推演'));
    await pumpUntil(tester, find.text('尚未配置可用的模型与 API Key'));

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('推演失败：'), findsNothing);

    await disposePage(tester);
  });

  testWidgets('全书体检：无正文时提示先写正文', (tester) async {
    await ChapterRepository(db).createChapter(workId: workId, title: '空章');

    await pumpPage(tester, ContinuityScanPage(workId: workId));
    await pumpUntil(tester, find.text('没有可检查的章节，请先写正文。'));

    expect(find.text('全书一致性体检'), findsOneWidget);
    expect(find.text('开始全书体检'), findsNothing);

    await disposePage(tester);
  });

  testWidgets('全书体检：有正文时可开始，未配置时提示', (tester) async {
    final chapters = ChapterRepository(db);
    final chapterId = await chapters.createChapter(
      workId: workId,
      title: '第一章',
    );
    await chapters.saveChapter(
      chapterId: chapterId,
      title: '第一章',
      content: '雪夜里，沈砚推门而入。',
    );

    await pumpPage(tester, ContinuityScanPage(workId: workId));
    await pumpUntil(tester, find.text('开始全书体检'));

    await tester.tap(find.text('开始全书体检'));
    await pumpUntil(tester, find.text('尚未配置可用的模型与 API Key'));

    expect(find.byType(SnackBar), findsOneWidget);

    await disposePage(tester);
  });

  testWidgets('AI 设定补全：未配置时提示配置', (tester) async {
    await pumpPage(tester, EntityExtractionPage(workId: workId));
    expect(find.text('AI 设定补全'), findsOneWidget);

    await tester.tap(find.text('AI 抽取设定'));
    await pumpUntil(tester, find.text('尚未配置可用的模型与 API Key'));

    expect(find.byType(SnackBar), findsOneWidget);

    await disposePage(tester);
  });

  testWidgets('文风档案：展示字段并可直接保存', (tester) async {
    await pumpPage(tester, StyleGuidePage(workId: workId));
    await pumpUntil(tester, find.text('叙事人称与视角'));

    expect(find.text('文风档案'), findsOneWidget);
    expect(find.text('语言风格与基调'), findsOneWidget);
    expect(find.text('AI 从最近章节提取'), findsOneWidget);

    await tester.tap(find.text('保存'));
    await pumpUntil(tester, find.text('文风档案已保存'));
    expect(find.byType(SnackBar), findsOneWidget);

    await disposePage(tester);
  });
}
