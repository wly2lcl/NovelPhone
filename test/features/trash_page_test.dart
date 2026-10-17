import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/app/theme.dart';
import 'package:novelphone/data/data_providers.dart';
import 'package:novelphone/data/db.dart';
import 'package:novelphone/data/repositories/chapter_repository.dart';
import 'package:novelphone/data/repositories/work_repository.dart';
import 'package:novelphone/features/settings/trash_page.dart';
import 'package:novelphone/l10n/generated/app_localizations.dart';

void main() {
  late AppDatabase db;
  late WorkRepository works;
  late ChapterRepository chapters;

  setUp(() {
    db = AppDatabase.memory();
    works = WorkRepository(db);
    chapters = ChapterRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Widget wrap() {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: buildPaperTheme(),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const TrashPage(),
      ),
    );
  }

  testWidgets('空回收站展示两个 Tab 的空状态', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('回收站里没有作品'), findsOneWidget);

    await tester.tap(find.text('章节'));
    await tester.pumpAndSettle();
    expect(find.text('回收站里没有章节'), findsOneWidget);
  });

  testWidgets('恢复作品后从回收站消失并回到作品列表', (tester) async {
    final workId = await works.createWork(title: '长夜行');
    await works.moveWorkToTrash(workId);

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    expect(find.text('长夜行'), findsOneWidget);

    await tester.tap(find.byTooltip('恢复'));
    await tester.pumpAndSettle();

    expect(find.text('回收站里没有作品'), findsOneWidget);
    expect(await works.getWork(workId), isNotNull);
  });

  testWidgets('永久删除需二次确认并清除数据', (tester) async {
    final workId = await works.createWork(title: '长夜行');
    final chapterId = await chapters.createChapter(
      workId: workId,
      title: '第一章',
    );
    await chapters.saveChapter(
      chapterId: chapterId,
      title: '第一章',
      content: '雨夜。',
    );
    await works.moveWorkToTrash(workId);

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('永久删除'));
    await tester.pumpAndSettle();
    expect(find.text('永久删除「长夜行」？'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '永久删除'));
    await tester.pumpAndSettle();

    expect(find.text('回收站里没有作品'), findsOneWidget);
    expect(
      await (db.select(
        db.works,
      )..where((t) => t.id.equals(workId))).getSingleOrNull(),
      isNull,
    );
    expect(
      await (db.select(
        db.chapters,
      )..where((t) => t.id.equals(chapterId))).getSingleOrNull(),
      isNull,
    );
  });
}
