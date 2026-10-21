import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:novelphone/app/theme.dart';
import 'package:novelphone/core/ai/sanitize_ai_text.dart';
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
import 'package:novelphone/l10n/generated/app_localizations.dart';

/// 计数用的章节仓储替身（ENH-13）：统计整部作品正文读取次数。
class _CountingChapters extends ChapterRepository {
  _CountingChapters(super._db);

  int fullWorkReads = 0;

  @override
  Stream<List<Chapter>> watchChapters(int workId) {
    fullWorkReads++;
    return super.watchChapters(workId);
  }
}

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
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      if (until.evaluate().isNotEmpty) return;
    }
  }

  Widget wrap({AiService? service, ChapterRepository? repo}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secureKeyStoreProvider.overrideWithValue(InMemoryKeyStore()),
        if (repo != null) chapterRepositoryProvider.overrideWithValue(repo),
        if (service != null) aiServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp(
        theme: buildPaperTheme(),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: EditorPage(workId: workId, chapterId: chapterId),
      ),
    );
  }

  /// 推进一段真实异步后渲染（网络流 / drift 查询都需 runAsync 驱动）。
  Future<void> pumpReal(
    WidgetTester tester, {
    bool Function()? until,
    int rounds = 60,
  }) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
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
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
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
          'usage': <String, dynamic>{
            'prompt_tokens': 20,
            'completion_tokens': 8,
          },
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
    final editable = tester.widget<EditableText>(
      find.byType(EditableText).first,
    );
    editable.controller.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 6,
    );
    await tester.pump();

    await tester.tap(find.text('AI 改写'));
    await settle(tester, find.text('替换原文'));

    // 4 种意图齐备；ENH-30 起改写模式也可把结果存入灵感箱。
    for (final label in <String>['润色', '扩写', '缩写', '改语气']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('存入灵感箱'), findsOneWidget);
    expect(find.text('换个方向'), findsNothing);

    final replaceButton = find.widgetWithText(FilledButton, '替换原文');
    await pumpReal(
      tester,
      until: () {
        return replaceButton.evaluate().isNotEmpty &&
            tester.widget<FilledButton>(replaceButton).onPressed != null;
      },
    );

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
      tester
          .widget<EditableText>(find.byType(EditableText).first)
          .controller
          .text,
      '她轻轻笑了。',
    );
    expect(find.text('她不禁笑了。'), findsNothing);
    expect(tester.takeException(), isNull);

    await closePage(tester);
  });

  testWidgets('换选区重新打开改写面板会丢弃旧结果', (tester) async {
    await seed('她不禁笑了。他转身离开。', confirmAiNotice: true);
    final settings = SettingsRepository(db, InMemoryKeyStore());
    final groupId = await settings.createModelGroup(
      name: '续写模型',
      provider: 'openai_compat',
      baseUrl: 'https://api.example.com/v1',
      models: <String>['m1'],
      apiKey: 'sk-test',
    );
    await settings.setTaskModel(AiTask.continueWriting, groupId);

    var requests = 0;
    final service = AiService(
      settings: settings,
      works: works,
      chapters: chapters,
      characters: CharacterRepository(db),
      outline: OutlineRepository(db),
      stats: TokenStatsRepository(db),
      httpClient: MockClient((request) async {
        requests++;
        final text = requests == 1 ? '她轻轻笑了。' : '他转身离去。';
        final payload = jsonEncode(<String, dynamic>{
          'choices': <dynamic>[
            <String, dynamic>{
              'delta': <String, dynamic>{'content': text},
              'finish_reason': 'stop',
            },
          ],
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
    try {
      final editable = tester.widget<EditableText>(
        find.byType(EditableText).first,
      );
      editable.controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 6,
      );
      await tester.pump();

      await tester.tap(find.text('AI 改写'));
      await settle(tester, find.text('她轻轻笑了。'));
      expect(requests, 1);

      // 面板未关闭时换到第二句再次打开：旧面板状态必须被丢弃。
      editable.controller.selection = const TextSelection(
        baseOffset: 6,
        extentOffset: 12,
      );
      await tester.pump();
      // 面板标题也叫「AI 改写」，工具栏按钮位于其后。
      await tester.tap(find.text('AI 改写').last);
      await pumpReal(
        tester,
        until: () => find.text('他转身离去。').evaluate().isNotEmpty,
      );

      expect(requests, 2);
      expect(find.text('她轻轻笑了。'), findsNothing);
      expect(editable.controller.text, '她不禁笑了。他转身离开。');
    } finally {
      await closePage(tester);
    }
  });

  testWidgets('改写：原文漂移时拒绝替换且不记采纳', (tester) async {
    await seed('她不禁笑了。', confirmAiNotice: true);
    final settings = SettingsRepository(db, InMemoryKeyStore());
    final groupId = await settings.createModelGroup(
      name: '续写模型',
      provider: 'openai_compat',
      baseUrl: 'https://api.example.com/v1',
      models: <String>['m1'],
      apiKey: 'sk-test',
    );
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

    final editable = tester.widget<EditableText>(
      find.byType(EditableText).first,
    );
    editable.controller.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 6,
    );
    await tester.pump();

    await tester.tap(find.text('AI 改写'));
    await settle(tester, find.text('替换原文'));

    final replaceButton = find.widgetWithText(FilledButton, '替换原文');
    await pumpReal(
      tester,
      until: () {
        return replaceButton.evaluate().isNotEmpty &&
            tester.widget<FilledButton>(replaceButton).onPressed != null;
      },
    );

    // 面板生成期间作者改动了选区文本：区间内容与 AI 所见不一致。
    editable.controller.text = '她不禁哭了。';
    await tester.pump();

    await tester.ensureVisible(replaceButton);
    await tester.pump();
    await tester.tap(replaceButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('原文已变化，请重新选中后再改写'), findsOneWidget);
    // 面板保持打开，正文未被 AI 结果覆盖。
    expect(find.text('替换原文'), findsOneWidget);
    expect(editable.controller.text, '她不禁哭了。');

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    final rows = await tester.runAsync(() => db.select(db.aiUsages).get());
    expect(rows, hasLength(1));
    expect(rows!.single.outcome, 'pending');

    await closePage(tester);
  });

  testWidgets('修订失败后旧结果仍可采纳并回写原用量', (tester) async {
    await seed('她不禁笑了。', confirmAiNotice: true);
    final settings = SettingsRepository(db, InMemoryKeyStore());
    final groupId = await settings.createModelGroup(
      name: '续写模型',
      provider: 'openai_compat',
      baseUrl: 'https://api.example.com/v1',
      models: <String>['m1'],
      apiKey: 'sk-test',
    );
    await settings.setTaskModel(AiTask.continueWriting, groupId);

    var requests = 0;
    final service = AiService(
      settings: settings,
      works: works,
      chapters: chapters,
      characters: CharacterRepository(db),
      outline: OutlineRepository(db),
      stats: TokenStatsRepository(db),
      httpClient: MockClient((request) async {
        requests++;
        if (requests > 1) {
          return http.Response('{"error":"boom"}', 400);
        }
        final payload = jsonEncode(<String, dynamic>{
          'choices': <dynamic>[
            <String, dynamic>{
              'delta': <String, dynamic>{'content': '她轻轻笑了。'},
              'finish_reason': 'stop',
            },
          ],
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
    try {
      final editable = tester.widget<EditableText>(
        find.byType(EditableText).first,
      );
      editable.controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 6,
      );
      await tester.pump();

      await tester.tap(find.text('AI 改写'));
      await settle(tester, find.text('替换原文'));

      final replaceButton = find.widgetWithText(FilledButton, '替换原文');
      await pumpReal(
        tester,
        until: () {
          return replaceButton.evaluate().isNotEmpty &&
              tester.widget<FilledButton>(replaceButton).onPressed != null;
        },
      );
      // 等首轮用量落库，记下旧结果的 usageId。
      await pumpReal(tester, rounds: 40);
      final before = await tester.runAsync(() => db.select(db.aiUsages).get());
      expect(before, hasLength(1));
      final usageId = before!.single.id;

      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.hintText == '告诉 AI 怎么改，例如：对白更克制，删掉最后一句',
        ),
        '改得更克制',
      );
      await tester.ensureVisible(find.text('继续修改'));
      await tester.pump();
      await tester.tap(find.text('继续修改'));
      await pumpReal(
        tester,
        until: () => find.textContaining('请求失败（400）').evaluate().isNotEmpty,
      );
      expect(requests, 2);
      expect(find.textContaining('请求失败（400）'), findsOneWidget);

      // 修订在首个新文本前失败：旧结果保留，仍可替换回正文。
      await tester.ensureVisible(replaceButton);
      await tester.pump();
      await tester.tap(replaceButton);
      await pumpReal(tester, until: () => find.text('替换原文').evaluate().isEmpty);
      expect(editable.controller.text, '她轻轻笑了。');

      await pumpReal(tester, rounds: 40);
      final rows = await tester.runAsync(() => db.select(db.aiUsages).get());
      expect(rows, hasLength(1));
      expect(rows!.single.id, usageId);
      expect(rows.single.outcome, 'adopted');
      expect(rows.single.adoptedChars, greaterThan(0));
    } finally {
      await closePage(tester);
    }
  });

  // ---------- ENH-06：AI 章节工具菜单 / 查看编辑本章摘要 ----------

  testWidgets('一致性检查：结构化冲突可定位原文并进入改写（ENH-38）', (tester) async {
    const quote = '苏晚今年十六岁';
    await seed('$quote，站在门口。', confirmAiNotice: true);
    final settings = SettingsRepository(db, InMemoryKeyStore());
    final groupId = await settings.createModelGroup(
      name: '检查模型',
      provider: 'openai_compat',
      baseUrl: 'https://api.example.com/v1',
      models: <String>['m1'],
      apiKey: 'sk-test',
    );
    await settings.setTaskModel(AiTask.continuity, groupId);

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
              'delta': <String, dynamic>{
                'content':
                    '{"summary":"发现 1 处冲突","issues":[{'
                    '"quote":"$quote","detail":"角色卡中苏晚二十四岁",'
                    '"source":"角色卡·苏晚","suggestion":"改为二十四岁",'
                    '"severity":"high"}]}',
              },
              'finish_reason': 'stop',
            },
          ],
          'usage': <String, dynamic>{
            'prompt_tokens': 30,
            'completion_tokens': 12,
          },
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

    Future<void> openReport() async {
      await tester.tap(find.byTooltip('AI 章节工具'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.text('设定一致性检查'));
      await pumpReal(
        tester,
        until: () => find.text('定位原文').evaluate().isNotEmpty,
      );
    }

    await openReport();
    expect(find.text('共 1 处冲突'), findsOneWidget);
    expect(find.text('「$quote」'), findsOneWidget);
    expect(find.textContaining('角色卡·苏晚'), findsWidgets);

    await tester.tap(find.text('定位原文'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    final field = tester.widget<TextField>(find.byType(TextField).first);
    final controller = field.controller!;
    final selection = controller.selection;
    expect(
      controller.text.substring(selection.start, selection.end),
      quote,
      reason: '定位后应选中冲突原文',
    );

    await openReport();
    await tester.tap(find.text('生成修订'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('AI 改写'), findsWidgets);
    expect(find.textContaining('请修正选中片段'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await closePage(tester);
  });

  testWidgets('AI 章节工具菜单五项可见，可查看/编辑本章摘要', (tester) async {
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
      '设定一致性检查',
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
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(tester.takeException(), isNull);
    final chapter = await chapters.getChapter(chapterId);
    expect(chapter!.summary, '手动摘要：她笑了。');

    await closePage(tester);
  });

  testWidgets('一致性检查：流式展示结束后可查看报告（ENH-22 / ENH-23）', (tester) async {
    await seed('她不禁笑了。', confirmAiNotice: true);
    final settings = SettingsRepository(db, InMemoryKeyStore());
    final groupId = await settings.createModelGroup(
      name: '检查模型',
      provider: 'openai_compat',
      baseUrl: 'https://api.example.com/v1',
      models: <String>['m1'],
      apiKey: 'sk-test',
    );
    await settings.setTaskModel(AiTask.continuity, groupId);

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
              'delta': <String, dynamic>{'content': '「她不禁笑了」与角色卡「冷面剑客」冲突。'},
              'finish_reason': 'stop',
            },
          ],
          'usage': <String, dynamic>{
            'prompt_tokens': 30,
            'completion_tokens': 12,
          },
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

    await tester.tap(find.byTooltip('AI 章节工具'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('设定一致性检查'));
    // 流式弹窗先实时展示增量，结束后自动切换为带「关闭」的报告弹窗。
    await pumpReal(tester, until: () => find.text('关闭').evaluate().isNotEmpty);

    expect(find.textContaining('冷面剑客'), findsOneWidget);
    expect(find.text('关闭'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await closePage(tester);
  });

  // ---------- ENH-13：本卷前情回顾前置校验 ----------

  testWidgets('本卷前情回顾前置校验只查元数据，不整部读正文（ENH-13）', (tester) async {
    await seed('她不禁笑了。');
    // 当前章为本卷第二章（空），第一章有正文 → 应通过前置校验。
    chapterId = await chapters.createChapter(workId: workId, title: '第二章');

    final counting = _CountingChapters(db);
    await tester.pumpWidget(wrap(repo: counting));
    await settle(tester, find.byType(TextField));

    await tester.tap(find.byTooltip('AI 章节工具'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('生成本卷前情回顾'));
    await pumpReal(
      tester,
      until: () => find.text('尚未配置模型').evaluate().isNotEmpty,
    );

    // 前置校验只查章节元数据，不整部读作品正文。
    expect(counting.fullWorkReads, 0);
    // 第一章有内容 → 通过前置校验，走到「尚未配置模型」引导（未配置模型组）。
    expect(find.text('尚未配置模型'), findsOneWidget);
    expect(find.text('本卷还没有更早的章节内容，暂无法生成本卷前情回顾'), findsNothing);
    expect(tester.takeException(), isNull);

    await closePage(tester);
  });

  // ---------- ENH-07：摘要过期提示（O4）/ AI 输出清洗（O8）----------

  testWidgets('正文改动后查看摘要提示可能过期（ENH-07 O4）', (tester) async {
    await seed('她不禁笑了。');
    await chapters.saveChapterSummary(chapterId, '摘要：她笑了。');
    // 让正文更新时间晚于摘要更新时间（drift 时间戳秒级精度，直接写未来时间避免等待）。
    await (db.update(db.chapters)..where((t) => t.id.equals(chapterId))).write(
      ChaptersCompanion(
        updatedAt: Value(DateTime.now().add(const Duration(days: 1))),
      ),
    );

    await tester.pumpWidget(wrap());
    await settle(tester, find.byType(TextField));

    await tester.tap(find.byTooltip('AI 章节工具'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('查看/编辑本章摘要'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('正文已改动，摘要可能过期，建议重新生成'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await closePage(tester);
  });

  test('清洗 AI 输出的 Markdown 标记与多余空行（ENH-07 O8）', () async {
    await seed('她不禁笑了。');

    expect(
      sanitizeAiText('# 本章摘要\n- 第一件事\n- 第二件事\n\n\n1. 第三件事\n'),
      '本章摘要\n第一件事\n第二件事\n\n第三件事',
    );
  });

  test('清洗 AI 输出不误删正文小数（ENH-07 回归）', () async {
    await seed('她不禁笑了。');

    expect(
      sanitizeAiText('1.5 倍的收益\n3.14 是圆周率\n1. 真正的编号\n1、中文编号\n1） 全角编号'),
      '1.5 倍的收益\n3.14 是圆周率\n真正的编号\n中文编号\n全角编号',
    );
  });

  // ---------- ENH-09：写入正文前统一清洗 ----------

  testWidgets('替换原文前清洗 AI 产出的 Markdown 标记（ENH-09）', (tester) async {
    await seed('她不禁笑了。', confirmAiNotice: true);
    final settings = SettingsRepository(db, InMemoryKeyStore());
    final groupId = await settings.createModelGroup(
      name: '续写模型',
      provider: 'openai_compat',
      baseUrl: 'https://api.example.com/v1',
      models: <String>['m1'],
      apiKey: 'sk-test',
    );
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
              'delta': <String, dynamic>{'content': '## 她笑了\n\n1. 收尾。'},
              'finish_reason': 'stop',
            },
          ],
          'usage': <String, dynamic>{
            'prompt_tokens': 20,
            'completion_tokens': 8,
          },
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

    final editable = tester.widget<EditableText>(
      find.byType(EditableText).first,
    );
    editable.controller.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 6,
    );
    await tester.pump();

    await tester.tap(find.text('AI 改写'));
    await settle(tester, find.text('替换原文'));

    final replaceButton = find.widgetWithText(FilledButton, '替换原文');
    await pumpReal(
      tester,
      until: () {
        return replaceButton.evaluate().isNotEmpty &&
            tester.widget<FilledButton>(replaceButton).onPressed != null;
      },
    );

    await tester.ensureVisible(replaceButton);
    await tester.pump();
    await tester.tap(replaceButton);
    await pumpReal(
      tester,
      until: () {
        return tester
                .widget<EditableText>(find.byType(EditableText).first)
                .controller
                .text !=
            '她不禁笑了。';
      },
    );

    final body = tester
        .widget<EditableText>(find.byType(EditableText).first)
        .controller
        .text;
    // 写回正文的是清洗后的文本：标题标记与行首编号都被剥离。
    expect(body, isNot(contains('##')));
    expect(body, isNot(contains('1. ')));
    expect(body, contains('收尾。'));
    expect(tester.takeException(), isNull);

    await closePage(tester);
  });

  // ---------- ENH-09：多候选续写共用一份上下文 ----------

  test('多候选续写三路共用同一份预组装上下文（ENH-09）', () async {
    await seed('她不禁笑了。', confirmAiNotice: true);
    final settings = SettingsRepository(db, InMemoryKeyStore());
    final groupId = await settings.createModelGroup(
      name: '续写模型',
      provider: 'openai_compat',
      baseUrl: 'https://api.example.com/v1',
      models: <String>['m1'],
      apiKey: 'sk-test',
    );
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
              'delta': <String, dynamic>{'content': '续写内容。'},
              'finish_reason': 'stop',
            },
          ],
          'usage': <String, dynamic>{
            'prompt_tokens': 20,
            'completion_tokens': 8,
          },
        });
        return http.Response.bytes(
          utf8.encode('data: $payload\n\ndata: [DONE]\n\n'),
          200,
          headers: <String, String>{'content-type': 'text/event-stream'},
        );
      }),
    );

    final prebuilt = await service.prebuildContinue(
      workId: workId,
      chapterId: chapterId,
    );
    expect(prebuilt, isNotNull);

    // 三路候选只在温度上不同：传入 prebuilt 后不再各自组装，
    // 事件里携带的就是同一个上下文对象（省掉两次全量取数与组装）。
    for (var variant = 0; variant < 3; variant++) {
      final events = await service
          .continueWriting(
            workId: workId,
            chapterId: chapterId,
            variant: variant,
            prebuilt: prebuilt,
          )
          .toList();
      final built = events.whereType<AiContextBuilt>().single;
      expect(identical(built.context, prebuilt), isTrue);
    }
  });
}
