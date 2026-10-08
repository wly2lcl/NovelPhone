import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/app/theme.dart';
import 'package:novelphone/core/ai/ai_client.dart';
import 'package:novelphone/core/ai/flavor_check.dart';
import 'package:novelphone/core/ai_flavor_rules.dart';
import 'package:novelphone/data/data_providers.dart';
import 'package:novelphone/data/db.dart';
import 'package:novelphone/data/repositories/chapter_repository.dart';
import 'package:novelphone/data/repositories/character_repository.dart';
import 'package:novelphone/data/repositories/outline_repository.dart';
import 'package:novelphone/data/repositories/settings_repository.dart';
import 'package:novelphone/data/repositories/token_stats_repository.dart';
import 'package:novelphone/data/repositories/work_repository.dart';
import 'package:novelphone/data/secure_key_store.dart';
import 'package:novelphone/features/ai/ai_providers.dart';
import 'package:novelphone/features/ai/ai_service.dart';
import 'package:novelphone/features/editor/editor_controller.dart';
import 'package:novelphone/features/editor/flavor_check_panel.dart';

/// 深检必失败的假用例服务（M4-13）：仅用于验证面板对失败事件的处置。
class _FailingDeepService extends AiService {
  _FailingDeepService({
    required super.settings,
    required super.works,
    required super.chapters,
    required super.characters,
    required super.outline,
    required super.stats,
    required this.scopedChapterId,
  });

  final int scopedChapterId;

  @override
  Stream<CheckEvent> checkFlavor({
    required int workId,
    int? chapterId,
    bool deep = false,
  }) async* {
    final all = await chapters.watchChapters(workId).first;
    final scope = buildCheckScope(
      all.where((c) => c.id == scopedChapterId).toList(growable: false),
    );
    yield CheckRuleResult(result: runFlavorRules(scope.text), scope: scope);
    if (!deep) return;
    yield const CheckDeepFailed(kind: AiErrorKind.auth, message: 'invalid key');
  }
}

void main() {
  late AppDatabase db;
  late WorkRepository works;
  late ChapterRepository chapters;
  late int workId;
  late int chapterId;

  /// [confirmAiNotice] 默认预确认首次联网告知，避免深检用例被告知弹窗拦截；
  /// 需要在用例中验证告知流程时传 false。
  Future<void> seed(String content, {bool confirmAiNotice = true}) async {
    db = AppDatabase.memory();
    works = WorkRepository(db);
    chapters = ChapterRepository(db);
    workId = await works.createWork(title: '长夜行');
    chapterId = await chapters.createChapter(workId: workId, title: '第一章');
    await chapters.saveChapter(
      chapterId: chapterId,
      title: '第一章',
      content: content,
    );
    if (confirmAiNotice) {
      await SettingsRepository(db, InMemoryKeyStore()).confirmAiNotice();
    }
  }

  tearDown(() async {
    await db.close();
  });

  /// 推进真实事件循环并渲染：检查面板依赖 drift 异步流，
  /// `pumpAndSettle` 只驱动帧、不驱动真实异步，需配合 [WidgetTester.runAsync]。
  Future<void> settle(WidgetTester tester, Finder until) async {
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
      if (until.evaluate().isNotEmpty) return;
    }
  }

  /// 卸载面板并清空挂起定时器：drift 流查询在取消时会创建零延迟 Timer，
  /// 需在测试内推进时钟，否则 flutter_test 会报「Timer 仍未结束」。
  Future<void> closePanel(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 6));
  }

  /// 面板内容在固定高度内滚动，条目上的按钮可能不在视口内，先滚动可见再点。
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump();
  }

  Widget wrap({
    int? scopeChapterId,
    EditorController? controller,
    VoidCallback? onClose,
    AiService? service,
  }) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secureKeyStoreProvider.overrideWithValue(InMemoryKeyStore()),
        if (service != null) aiServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp(
        theme: buildPaperTheme(),
        home: Scaffold(
          body: Column(
            children: <Widget>[
              const Spacer(),
              FlavorCheckPanel(
                workId: workId,
                initialChapterId: scopeChapterId,
                controller: controller,
                onClose: onClose ?? () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('规则结果即时展示（不联网）', (tester) async {
    await seed('她不禁笑了。');
    await tester.pumpWidget(wrap(scopeChapterId: chapterId));
    await settle(tester, find.text('1 处'));

    expect(find.text('AI 感检查'), findsOneWidget);
    expect(find.text('1 处'), findsOneWidget);
    expect(find.text('原文：不禁'), findsOneWidget);
    expect(find.textContaining('套话'), findsWidgets);

    await closePanel(tester);
  });

  testWidgets('0 字范围提示无可检查内容并禁用深检', (tester) async {
    await seed('');
    await tester.pumpWidget(wrap(scopeChapterId: chapterId));
    await settle(tester, find.text('该范围没有正文，无可检查内容'));

    expect(find.text('该范围没有正文，无可检查内容'), findsOneWidget);
    final deep = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'LLM 深检'),
    );
    expect(deep.onPressed, isNull);

    await closePanel(tester);
  });

  testWidgets('未配置检查模型时深检给出引导', (tester) async {
    await seed('她不禁笑了。');
    await tester.pumpWidget(wrap(scopeChapterId: chapterId));
    await settle(tester, find.text('原文：不禁'));

    await tester.tap(find.widgetWithText(FilledButton, 'LLM 深检'));
    await settle(tester, find.textContaining('尚未配置 AI 感检查所用的模型'));

    expect(find.textContaining('尚未配置 AI 感检查所用的模型'), findsOneWidget);
    // 规则层结果保留。
    expect(find.text('原文：不禁'), findsOneWidget);

    await closePanel(tester);
  });

  testWidgets('按类型筛选问题列表', (tester) async {
    await seed('她不禁笑了。对于他来说，这一切都无所谓。');
    await tester.pumpWidget(wrap(scopeChapterId: chapterId));
    await settle(tester, find.text('套话 1'));

    expect(find.text('套话 1'), findsOneWidget);
    expect(find.text('翻译腔 1'), findsOneWidget);

    await tapVisible(tester, find.text('套话 1'));

    expect(find.text('原文：不禁'), findsOneWidget);
    expect(find.textContaining('对于'), findsNothing);

    await closePanel(tester);
  });

  testWidgets('忽略问题后从列表移除', (tester) async {
    await seed('她不禁笑了。');
    await tester.pumpWidget(wrap(scopeChapterId: chapterId));
    await settle(tester, find.text('原文：不禁'));

    await tapVisible(tester, find.text('忽略'));

    expect(find.text('0 处'), findsOneWidget);
    expect(find.text('未发现明显的 AI 味问题'), findsOneWidget);

    await closePanel(tester);
  });

  testWidgets('编辑器内一键删除套话且可撤销（M4-11）', (tester) async {
    await seed('她不禁笑了。');
    final controller = EditorController(
      repository: chapters,
      workId: workId,
      chapterId: chapterId,
    );
    await controller.load();
    addTearDown(controller.dispose);

    await tester.pumpWidget(wrap(
      scopeChapterId: chapterId,
      controller: controller,
    ));
    await settle(tester, find.text('原文：不禁'));

    await tapVisible(tester, find.widgetWithText(TextButton, '删除'));

    expect(controller.textController.text, '她笑了。');
    expect(find.text('未发现明显的 AI 味问题'), findsOneWidget);

    controller.undo();
    expect(controller.textController.text, '她不禁笑了。');

    await closePanel(tester);
  });

  testWidgets('批量忽略同类问题（M4-12）', (tester) async {
    await seed('她不禁笑了。他也不禁皱眉。');
    await tester.pumpWidget(wrap(scopeChapterId: chapterId));
    await settle(tester, find.text('2 处'));

    await tapVisible(tester, find.byIcon(Icons.more_horiz).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('忽略全部「套话」'));
    await tester.pumpAndSettle();

    expect(find.text('0 处'), findsOneWidget);
    expect(find.text('未发现明显的 AI 味问题'), findsOneWidget);

    await closePanel(tester);
  });

  testWidgets('深检失败保留规则结果并提示（M4-13）', (tester) async {
    await seed('她不禁笑了。');
    final service = _FailingDeepService(
      settings: SettingsRepository(db, InMemoryKeyStore()),
      works: works,
      chapters: chapters,
      characters: CharacterRepository(db),
      outline: OutlineRepository(db),
      stats: TokenStatsRepository(db),
      scopedChapterId: chapterId,
    );
    await tester.pumpWidget(wrap(scopeChapterId: chapterId, service: service));
    await settle(tester, find.text('原文：不禁'));

    await tester.tap(find.widgetWithText(FilledButton, 'LLM 深检'));
    await settle(tester, find.textContaining('深检失败（已保留规则结果）'));

    expect(find.textContaining('深检失败（已保留规则结果）'), findsOneWidget);
    // 规则层结果未被清空。
    expect(find.text('原文：不禁'), findsOneWidget);

    await closePanel(tester);
  });

  testWidgets('深检首次触发先弹联网告知，确认后继续（M4-16）', (tester) async {
    await seed('她不禁笑了。', confirmAiNotice: false);
    final service = _FailingDeepService(
      settings: SettingsRepository(db, InMemoryKeyStore()),
      works: works,
      chapters: chapters,
      characters: CharacterRepository(db),
      outline: OutlineRepository(db),
      stats: TokenStatsRepository(db),
      scopedChapterId: chapterId,
    );
    await tester.pumpWidget(wrap(scopeChapterId: chapterId, service: service));
    await settle(tester, find.text('原文：不禁'));

    await tester.tap(find.widgetWithText(FilledButton, 'LLM 深检'));
    await settle(tester, find.text('使用 AI 前请知悉'));
    expect(find.text('使用 AI 前请知悉'), findsOneWidget);

    // 确认后继续发起深检（假服务返回失败事件，说明确实联网了）。
    await tester.tap(find.widgetWithText(FilledButton, '我已了解'));
    await settle(tester, find.textContaining('深检失败（已保留规则结果）'));
    expect(find.textContaining('深检失败（已保留规则结果）'), findsOneWidget);

    await closePanel(tester);
  });

  testWidgets('取消联网告知则不发起深检（M4-16）', (tester) async {
    await seed('她不禁笑了。', confirmAiNotice: false);
    final service = _FailingDeepService(
      settings: SettingsRepository(db, InMemoryKeyStore()),
      works: works,
      chapters: chapters,
      characters: CharacterRepository(db),
      outline: OutlineRepository(db),
      stats: TokenStatsRepository(db),
      scopedChapterId: chapterId,
    );
    await tester.pumpWidget(wrap(scopeChapterId: chapterId, service: service));
    await settle(tester, find.text('原文：不禁'));

    await tester.tap(find.widgetWithText(FilledButton, 'LLM 深检'));
    await settle(tester, find.text('使用 AI 前请知悉'));

    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();

    expect(find.text('使用 AI 前请知悉'), findsNothing);
    expect(find.textContaining('深检失败'), findsNothing);
    // 深检按钮仍可再次点击（未被置于运行中状态）。
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'LLM 深检'))
          .onPressed,
      isNotNull,
    );

    await closePanel(tester);
  });

  testWidgets('定位按钮选中编辑器对应区间（M4-10）', (tester) async {
    await seed('她不禁笑了。');
    final controller = EditorController(
      repository: chapters,
      workId: workId,
      chapterId: chapterId,
    );
    await controller.load();
    addTearDown(controller.dispose);

    await tester.pumpWidget(wrap(
      scopeChapterId: chapterId,
      controller: controller,
    ));
    await settle(tester, find.text('原文：不禁'));

    await tapVisible(tester, find.widgetWithText(TextButton, '定位'));

    expect(controller.textController.selection.baseOffset, 1);
    expect(controller.textController.selection.extentOffset, 3);

    await closePanel(tester);
  });
}