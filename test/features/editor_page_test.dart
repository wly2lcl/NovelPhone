import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/app/theme.dart';
import 'package:novelphone/data/data_providers.dart';
import 'package:novelphone/data/db.dart';
import 'package:novelphone/data/repositories/chapter_repository.dart';
import 'package:novelphone/data/repositories/work_repository.dart';
import 'package:novelphone/data/secure_key_store.dart';
import 'package:novelphone/features/editor/editor_page.dart';

/// 编辑器页面级回归（M1-22 真机验收暴露的缺陷）：
/// 章节加载完成后正文区必须自动进入可编辑态，不能停留在加载指示器上。
void main() {
  late AppDatabase db;
  late WorkRepository works;
  late ChapterRepository chapters;
  late int workId;
  late int chapterId;

  Future<void> seed(String content) async {
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

  Widget wrap() {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secureKeyStoreProvider.overrideWithValue(InMemoryKeyStore()),
      ],
      child: MaterialApp(
        theme: buildPaperTheme(),
        home: EditorPage(workId: workId, chapterId: chapterId),
      ),
    );
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
}