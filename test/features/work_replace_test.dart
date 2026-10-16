import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/app/theme.dart';
import 'package:novelphone/data/data_providers.dart';
import 'package:novelphone/data/db.dart';
import 'package:novelphone/data/repositories/chapter_repository.dart';
import 'package:novelphone/data/repositories/work_repository.dart';
import 'package:novelphone/data/secure_key_store.dart';
import 'package:novelphone/features/work_detail/replace_page.dart';
import 'package:novelphone/l10n/generated/app_localizations.dart';

/// ENH-19：全书查找替换页。
void main() {
  Future<void> pumpPage(WidgetTester tester, AppDatabase db, int workId) async {
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
          home: WorkReplacePage(workId: workId),
        ),
      ),
    );
    await tester.pump();
  }

  /// 等待异步检索/替换完成（drift 用真实异步 I/O）。
  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 60; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      if (finder.evaluate().isNotEmpty) return;
    }
  }

  testWidgets('预览全书命中，确认后替换并留存快照（ENH-19）', (tester) async {
    final db = AppDatabase.memory();
    final works = WorkRepository(db);
    final chapters = ChapterRepository(db);
    final workId = await works.createWork(title: '长夜行');
    final firstId = await chapters.createChapter(workId: workId, title: '第一章');
    final secondId = await chapters.createChapter(workId: workId, title: '第二章');
    await chapters.saveChapter(
      chapterId: firstId,
      title: '第一章',
      content: '清晨的街道很安静。',
    );
    await chapters.saveChapter(
      chapterId: secondId,
      title: '第二章',
      content: '街道尽头是海，另一条街道通向山谷。',
    );

    await pumpPage(tester, db, workId);

    // 输入关键词 → 防抖后展示分组预览。
    await tester.enterText(find.byType(TextField).first, '街道');
    await tester.pump(const Duration(milliseconds: 350));
    await waitFor(tester, find.text('共 3 处命中，涉及 2 章'));
    await tester.pump();

    expect(find.text('共 3 处命中，涉及 2 章'), findsOneWidget);
    expect(find.text('第一章'), findsOneWidget);
    expect(find.text('1 处'), findsOneWidget);
    expect(find.text('第二章'), findsOneWidget);
    expect(find.text('2 处'), findsOneWidget);

    // 填写替换文本 → 确认弹窗 → 执行替换。
    await tester.enterText(find.byType(TextField).at(1), '小巷');
    await tester.tap(find.text('全部替换'));
    await tester.pumpAndSettle();

    expect(find.text('全部替换？'), findsOneWidget);
    expect(
      find.text('将在 2 章中共替换 3 处文本。替换前会自动为受影响章节创建快照，可在版本历史中恢复。'),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('全部替换'),
      ),
    );
    await waitFor(tester, find.text('已替换：2 章共 3 处'));
    await waitFor(tester, find.text('没有找到包含「街道」的章节'));
    await tester.pump();

    expect(find.text('已替换：2 章共 3 处'), findsOneWidget);
    expect(find.text('没有找到包含「街道」的章节'), findsOneWidget);

    // 库中正文已替换，原稿快照已留存。
    final first = await chapters.getChapter(firstId);
    expect(first!.content, '清晨的小巷很安静。');
    final snapshots = await chapters.listSnapshots(firstId);
    expect(snapshots, hasLength(1));
    expect(snapshots.single.content, '清晨的街道很安静。');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    await db.close();
  });

  testWidgets('关键词为空时展示提示且不能替换', (tester) async {
    final db = AppDatabase.memory();
    final works = WorkRepository(db);
    final workId = await works.createWork(title: '长夜行');

    await pumpPage(tester, db, workId);

    expect(find.text('输入查找内容，预览全书章节的匹配结果'), findsOneWidget);

    await tester.tap(find.text('全部替换'), warnIfMissed: false);
    await tester.pump();
    expect(find.byType(AlertDialog), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    await db.close();
  });
}
