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
import 'package:novelphone/data/repositories/settings_repository.dart';
import 'package:novelphone/data/repositories/token_stats_repository.dart';
import 'package:novelphone/data/repositories/work_repository.dart';
import 'package:novelphone/data/secure_key_store.dart';
import 'package:novelphone/features/ai/ai_providers.dart';
import 'package:novelphone/features/ai/ai_service.dart';
import 'package:novelphone/features/editor/editor_page.dart';

/// 编辑器页面级回归（M1-22 真机验收暴露的缺陷）：
/// 章节加载完成后正文区必须自动进入可编辑态，不能停留在加载指示器上。
void main() {
  late AppDatabase db;
  late WorkRepository works;
  late ChapterRepository chapters;
  late int workId;
  late int chapterId;

  /// [confirmAiNotice] 默认预确认首次联网告知，避免 AI 用例被告知弹窗拦截。
  Future<void> seed(String content, {bool confirmAiNotice = false}) async {
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

  /// 推进真实事件循环：drift 查询是真实异步，`pumpAndSettle` 不驱动它。
  Future<void> settle(WidgetTester tester, Finder until) async {
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
      if (until.evaluate().isNotEmpty) return;
    }
  }

  Widget wrap({AiService? service}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secureKeyStoreProvider.overrideWithValue(InMemoryKeyStore()),
        if (service != null) aiServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp(
        theme: buildPaperTheme(),
        home: EditorPage(workId: workId, chapterId: chapterId),
      ),
    );
  }

  /// 推进一段真实异步后渲染（网络流 / drift 查询都需 runAsync 驱动）。
  Future<void> pumpReal(WidgetTester tester,
      {bool Function()? until, int rounds = 60}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
      if (until != null && until()) return;
    }
  }

  /// 卸载并清空挂起定时器（自动保存 / drift 流取消的零延迟 Timer）。
  Future<void> closePage(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 6));
  }

  testWidgets('章节加载完成后正文区自动可编辑（无需任何交互）', (tester) async {
    await seed('她不禁笑了。');
    await tester.pumpWidget(wrap());

    await settle(tester, find.byType(TextField));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('她不禁笑了。'), findsOneWidget);
    expect(find.text('本章 5 字'), findsOneWidget);

    await closePage(tester);
  });

  testWidgets('编辑器内编辑本章梗概并保存不应崩溃', (tester) async {
    await seed('她不禁笑了。');
    await tester.pumpWidget(wrap());
    await settle(tester, find.byType(TextField));

    await tester.tap(find.byTooltip('本章梗概'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('编辑本章梗概'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '本章梗概测试');
    await tester.tap(find.text('保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(tester.takeException(), isNull);
    await closePage(tester);
  });

  testWidgets('编辑器内重命名章节保存不应崩溃', (tester) async {
    await seed('她不禁笑了。');
    await tester.pumpWidget(wrap());
    await settle(tester, find.byType(TextField));

    await tester.tap(find.text('第一章').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('章节标题'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '第二章');
    await tester.tap(find.text('保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(tester.takeException(), isNull);
    await closePage(tester);
  });

  // ---------- ENH-04：专注模式 / AI 改写 ----------

  testWidgets('专注模式隐藏并恢复工具栏与状态栏', (tester) async {
    await seed('她不禁笑了。');
    await tester.pumpWidget(wrap());
    await settle(tester, find.byType(TextField));

    expect(find.text('AI 续写'), findsOneWidget);
    expect(find.text('本章 5 字'), findsOneWidget);

    await tester.tap(find.byTooltip('专注模式'));
    await tester.pump();

    // 工具栏（AI 续写等）与状态栏（本章字数）都在专注模式下隐藏。
    expect(find.text('AI 续写'), findsNothing);
    expect(find.text('本章 5 字'), findsNothing);
    expect(find.byTooltip('退出专注模式'), findsOneWidget);

    await tester.tap(find.byTooltip('退出专注模式'));
    await tester.pump();

    expect(find.text('AI 续写'), findsOneWidget);
    expect(find.text('本章 5 字'), findsOneWidget);

    await closePage(tester);
  });

  testWidgets('窄屏下工具栏 8 个按钮不溢出', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await seed('她不禁笑了。');
    await tester.pumpWidget(wrap());
    await settle(tester, find.byType(TextField));

    for (final label in <String>[
      'AI 续写',
      'AI 灵感',
      'AI 改写',
      '查找',
      'AI 感',
      '段落移动',
      '撤销',
      '重做',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(tester.takeException(), isNull);

    await closePage(tester);
  });

  testWidgets('未选中正文时点 AI 改写给提示且不开面板', (tester) async {
    await seed('她不禁笑了。');
    await tester.pumpWidget(wrap());
    await settle(tester, find.byType(TextField));

    // load() 后光标为折叠态（start == end），不构成可改写选区。
    await tester.tap(find.text('AI 改写'));
    await tester.pump();

    expect(find.text('请先在正文中选中要改写的段落'), findsOneWidget);
    expect(find.text('润色'), findsNothing);
    expect(find.text('替换原文'), findsNothing);

    await closePage(tester);
  });

  testWidgets('AI 改写：4 种意图 + 替换原文生效（ENH-04）', (tester) async {
    await seed('她不禁笑了。', confirmAiNotice: true);
    final settings = SettingsRepository(db, InMemoryKeyStore());
    final groupId = await settings.createModelGroup(
      name: '续写模型',
      provider: 'openai_compat',
      baseUrl: 'https://api.example.com/v1',
      models: <String>['m1'],
      apiKey: 'sk-test',
    );
    // 改写未单独配置 → 回退续写模型组（零配置可用）。
    await settings.setTaskModel(AiTask.continueWriting, groupId);

    final service = AiService(
      settings: settings,
      works: works,
      chapters: chapters,
      characters: CharacterRepository(db),
      outline: OutlineRepository(db),
      stats: TokenStatsRepository(db),
      httpClient: MockClient((request) async {
        final payload = jsonEncode(<String, dynamic>{
          'choices': <dynamic>[
            <String, dynamic>{
              'delta': <String, dynamic>{'content': '她轻轻笑了。'},
              'finish_reason': 'stop',
            },
          ],
          'usage': <String, dynamic>{'prompt_tokens': 20, 'completion_tokens': 8},
        });
        return http.Response.bytes(
          utf8.encode('data: $payload\n\ndata: [DONE]\n\n'),
          200,
          headers: <String, String>{'content-type': 'text/event-stream'},
        );
      }),
    );

    await tester.pumpWidget(wrap(service: service));
    await settle(tester, find.byType(TextField));

    // 选中整段「她不禁笑了。」（6 字）。
    final editable =
        tester.widget<EditableText>(find.byType(EditableText).first);
    editable.controller.selection =
        const TextSelection(baseOffset: 0, extentOffset: 6);
    await tester.pump();

    await tester.tap(find.text('AI 改写'));
    await settle(tester, find.text('替换原文'));

    // 4 种意图齐备；改写模式不显示「存入灵感箱」。
    for (final label in <String>['润色', '扩写', '缩写', '改语气']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('存入灵感箱'), findsNothing);
    expect(find.text('换个方向'), findsNothing);

    final replaceButton = find.widgetWithText(FilledButton, '替换原文');
    await pumpReal(tester, until: () {
      return replaceButton.evaluate().isNotEmpty &&
          tester.widget<FilledButton>(replaceButton).onPressed != null;
    });

    // 面板内容在限高内滚动，按钮可能不在视口内：先滚动可见再点。
    await tester.ensureVisible(replaceButton);
    await tester.pump();
    await tester.tap(replaceButton);
    await pumpReal(
      tester,
      until: () =>
          find.text('她不禁笑了。').evaluate().isEmpty &&
          find.text('她轻轻笑了。').evaluate().isNotEmpty,
    );

    expect(
      tester.widget<EditableText>(find.byType(EditableText).first).controller.text,
      '她轻轻笑了。',
    );
    expect(find.text('她不禁笑了。'), findsNothing);
    expect(tester.takeException(), isNull);

    await closePage(tester);
  });

  // ---------- ENH-06：AI 章节工具菜单 / 查看编辑本章摘要 ----------

  testWidgets('AI 章节工具菜单四项可见，可查看/编辑本章摘要', (tester) async {
    await seed('她不禁笑了。');
    await tester.pumpWidget(wrap());
    await settle(tester, find.byType(TextField));

    await tester.tap(find.byTooltip('AI 章节工具'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    for (final label in <String>[
      '生成本章摘要',
      '生成本卷前情回顾',
      'AI 扩写本章纲',
      '查看/编辑本章摘要',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }

    await tester.tap(find.text('查看/编辑本章摘要'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('本章 AI 摘要'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).last, '手动摘要：她笑了。');
    await tester.tap(find.text('保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(tester.takeException(), isNull);
    final chapter = await chapters.getChapter(chapterId);
    expect(chapter!.summary, '手动摘要：她笑了。');

    await closePage(tester);
  });
}
