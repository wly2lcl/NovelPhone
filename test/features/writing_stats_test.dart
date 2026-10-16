import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/app/theme.dart';
import 'package:novelphone/core/word_count.dart';
import 'package:novelphone/core/writing_stats.dart';
import 'package:novelphone/data/data_providers.dart';
import 'package:novelphone/data/db.dart';
import 'package:novelphone/data/repositories/backup_repository.dart';
import 'package:novelphone/data/repositories/chapter_repository.dart';
import 'package:novelphone/data/repositories/settings_repository.dart';
import 'package:novelphone/data/repositories/work_repository.dart';
import 'package:novelphone/data/secure_key_store.dart';
import 'package:novelphone/features/stats/writing_heatmap.dart';
import 'package:novelphone/features/stats/writing_stats_page.dart';
import 'package:novelphone/l10n/generated/app_localizations.dart';

/// B-07：每日字数目标、连击统计、番茄钟。
void main() {
  group('纯函数', () {
    test('writingDayKey 补零为 yyyy-MM-dd', () {
      expect(writingDayKey(DateTime(2026, 3, 7)), '2026-03-07');
      expect(writingDayKey(DateTime(2026, 12, 31)), '2026-12-31');
    });

    test('writingStreak 统计连续天数，今天没写则从昨天起算', () {
      final now = DateTime(2026, 3, 7);
      final byDay = <String, int>{
        '2026-03-07': 120,
        '2026-03-06': 80,
        '2026-03-05': 50,
        '2026-03-02': 10,
      };
      expect(writingStreak(byDay, now: now), 3);

      // 今天没写，但昨天写了 → 连击仍从昨天算起。
      final noToday = <String, int>{'2026-03-06': 80, '2026-03-05': 50};
      expect(writingStreak(noToday, now: now), 2);

      // 昨天也没写 → 断连。
      expect(writingStreak(<String, int>{'2026-03-05': 50}, now: now), 0);
    });

    test('recentDayWords 补零并按时间从早到晚（ENH-18）', () {
      final now = DateTime(2026, 3, 7);
      final series = recentDayWords(
        <String, int>{'2026-03-07': 50, '2026-03-04': 10},
        5,
        now: now,
      );

      expect(series.map((e) => e.day), [
        '2026-03-03',
        '2026-03-04',
        '2026-03-05',
        '2026-03-06',
        '2026-03-07',
      ]);
      expect(series.map((e) => e.words), [0, 10, 0, 0, 50]);
    });

    test('recentDayWords 跨月与跨年边界', () {
      expect(
        recentDayWords(
          <String, int>{},
          3,
          now: DateTime(2026, 3, 1),
        ).map((e) => e.day),
        ['2026-02-27', '2026-02-28', '2026-03-01'],
      );
      expect(
        recentDayWords(
          <String, int>{},
          2,
          now: DateTime(2026, 1, 1),
        ).map((e) => e.day),
        ['2025-12-31', '2026-01-01'],
      );
    });

    test('heatmapWeeks 生成 53 周网格，超出今天的格子为 null（ENH-19）', () {
      final now = DateTime(2026, 3, 7); // 周六。
      final grid = heatmapWeeks(<String, int>{
        '2026-03-07': 300,
        '2026-03-06': 100,
      }, now: now);

      expect(grid, hasLength(53));
      expect(grid.every((column) => column.length == 7), isTrue);
      expect(grid.first.first!.day, '2025-03-03');
      expect(grid.first.first!.words, 0);

      final last = grid.last;
      expect(last[0]!.day, '2026-03-02');
      expect(last[5]!.day, '2026-03-07');
      expect(last[5]!.words, 300);
      expect(last[6], isNull);
    });

    test('heatmapWeeks 周日为当周最后一天（ENH-19）', () {
      final grid = heatmapWeeks(<String, int>{}, now: DateTime(2026, 3, 8));

      final last = grid.last;
      expect(last[0]!.day, '2026-03-02');
      expect(last[6]!.day, '2026-03-08');
      expect(last[6], isNotNull);
    });
  });

  group('每日写作统计', () {
    late AppDatabase db;
    late WorkRepository works;
    late ChapterRepository chapters;
    late int workId;
    late int chapterId;

    setUp(() async {
      db = AppDatabase.memory();
      works = WorkRepository(db);
      chapters = ChapterRepository(db);
      workId = await works.createWork(title: '长夜行');
      chapterId = await chapters.createChapter(workId: workId, title: '第一章');
    });

    tearDown(() async {
      await db.close();
    });

    test('保存正文时当天字数按净增累积', () async {
      const first = '一二三四五';
      await chapters.saveChapter(
        chapterId: chapterId,
        title: '第一章',
        content: first,
      );

      final stats = await chapters.listDailyWritingStats();
      expect(stats, hasLength(1));
      expect(stats.single.day, writingDayKey(DateTime.now()));
      expect(stats.single.words, countWords(first));
    });

    test('删减正文不回退统计（只加不减）', () async {
      const long = '一二三四五六七八九十';
      await chapters.saveChapter(
        chapterId: chapterId,
        title: '第一章',
        content: long,
      );
      final afterFirst = (await chapters.listDailyWritingStats()).single.words;
      expect(afterFirst, countWords(long));

      await chapters.saveChapter(
        chapterId: chapterId,
        title: '第一章',
        content: '一二',
      );

      final stats = await chapters.listDailyWritingStats();
      expect(stats.single.words, afterFirst);
    });

    test('多次增写在同一天累加', () async {
      await chapters.saveChapter(
        chapterId: chapterId,
        title: '第一章',
        content: '一二三',
      );
      await chapters.saveChapter(
        chapterId: chapterId,
        title: '第一章',
        content: '一二三四五',
      );

      final stats = await chapters.listDailyWritingStats();
      expect(stats.single.words, countWords('一二三四五'));
    });

    test('备份导出与覆盖恢复保留每日写作统计', () async {
      final backup = BackupRepository(db);
      await chapters.saveChapter(
        chapterId: chapterId,
        title: '第一章',
        content: '一二三',
      );
      final data = await backup.exportData();
      expect((data['tables'] as Map)['dailyWritingStats'], hasLength(1));

      // 导出后本机继续写作，覆盖恢复应回到备份时的字数。
      await chapters.saveChapter(
        chapterId: chapterId,
        title: '第一章',
        content: '一二三四五',
      );
      await backup.restore(data, overwrite: true);

      final restored = await chapters.listDailyWritingStats();
      expect(restored, hasLength(1));
      expect(restored.single.words, countWords('一二三'));
    });
  });

  group('写作设置与番茄钟', () {
    late AppDatabase db;
    late SettingsRepository settings;

    setUp(() {
      db = AppDatabase.memory();
      settings = SettingsRepository(db, InMemoryKeyStore());
    });

    tearDown(() async {
      await db.close();
    });

    test('每日目标默认 0，设置后可读回，负数归零', () async {
      expect(await settings.dailyWordTarget(), 0);

      await settings.setDailyWordTarget(2000);
      expect(await settings.dailyWordTarget(), 2000);

      await settings.setDailyWordTarget(-5);
      expect(await settings.dailyWordTarget(), 0);
    });

    test('番茄钟时长默认 25，越界夹紧到 1~120', () async {
      expect(await settings.pomodoroMinutes(), 25);

      await settings.setPomodoroMinutes(0);
      expect(await settings.pomodoroMinutes(), 1);

      await settings.setPomodoroMinutes(999);
      expect(await settings.pomodoroMinutes(), 120);

      await settings.setPomodoroMinutes(45);
      expect(await settings.pomodoroMinutes(), 45);
    });

    test('番茄钟完成数按日累计', () async {
      final now = DateTime(2026, 3, 7);
      expect(await settings.pomodoroDoneToday(now: now), 0);

      expect(await settings.incrementPomodoroDone(now: now), 1);
      expect(await settings.incrementPomodoroDone(now: now), 2);
      expect(await settings.pomodoroDoneToday(now: now), 2);

      // 换一天从 0 重新计。
      final nextDay = DateTime(2026, 3, 8);
      expect(await settings.pomodoroDoneToday(now: nextDay), 0);
    });
  });

  testWidgets('写作统计页展示今日字数、连击与番茄钟', (tester) async {
    final db = AppDatabase.memory();
    final works = WorkRepository(db);
    final chapters = ChapterRepository(db);
    final settings = SettingsRepository(db, InMemoryKeyStore());
    final workId = await works.createWork(title: '长夜行');
    final chapterId = await chapters.createChapter(
      workId: workId,
      title: '第一章',
    );
    await chapters.saveChapter(
      chapterId: chapterId,
      title: '第一章',
      content: '一二三四五',
    );
    await settings.setDailyWordTarget(100);

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
          home: const WritingStatsPage(),
        ),
      ),
    );

    for (var i = 0; i < 60; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      if (find.text('5 / 100 字', findRichText: true).evaluate().isNotEmpty) {
        break;
      }
    }
    await tester.pump();

    expect(find.text('今日写作'), findsOneWidget);
    expect(find.text('5 / 100 字', findRichText: true), findsOneWidget);

    // ENH-18 趋势图与 ENH-19 热力图加入后连击与番茄钟在首屏之下，滚动后再断言。
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pump();

    expect(find.text('写作热力图'), findsOneWidget);
    expect(find.text('1 天'), findsOneWidget);
    expect(find.text('25 分钟'), findsOneWidget);
    expect(find.text('今日已完成 0 个番茄钟'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    await db.close();
  });

  testWidgets('写作趋势图：7 天柱形、汇总与 30 天切换（ENH-18）', (tester) async {
    final db = AppDatabase.memory();
    for (var i = 0; i < 7; i++) {
      final day = writingDayKey(DateTime.now().subtract(Duration(days: i)));
      await db
          .into(db.dailyWritingStats)
          .insert(
            DailyWritingStatsCompanion.insert(
              day: day,
              words: Value((i + 1) * 100),
            ),
          );
    }

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
          home: const WritingStatsPage(),
        ),
      ),
    );

    for (var i = 0; i < 60; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      if (find.text('近 7 天共 2800 字').evaluate().isNotEmpty) {
        break;
      }
    }
    await tester.pump();

    expect(find.text('写作趋势'), findsOneWidget);
    expect(find.text('近 7 天共 2800 字'), findsOneWidget);
    expect(_trendBarCount(), 7);

    // 切到 30 天：柱形补零扩展到 30 根，汇总随之更新。
    await tester.tap(find.text('30 天'));
    await tester.pumpAndSettle();
    expect(find.text('近 30 天共 2800 字'), findsOneWidget);
    expect(_trendBarCount(), 30);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    await db.close();
  });

  testWidgets('写作趋势图：无记录时展示空态', (tester) async {
    final db = AppDatabase.memory();
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
          home: const WritingStatsPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('写作趋势'), findsOneWidget);
    expect(find.text('最近还没有写作记录'), findsOneWidget);
    expect(find.text('近 7 天共 0 字'), findsOneWidget);
    expect(_trendBarCount(), 0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    await db.close();
  });

  testWidgets('写作热力图：53 周网格、活跃天数与图例（ENH-19）', (tester) async {
    final today = DateTime.now();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPaperTheme(),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: WritingHeatmap(
            wordsByDay: <String, int>{
              writingDayKey(today): 300,
              writingDayKey(today.subtract(const Duration(days: 1))): 100,
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('写作热力图'), findsOneWidget);
    expect(find.text('近一年共 2 天有写作'), findsOneWidget);
    expect(_heatCellCount(), 53 * 7);
    expect(find.text('少'), findsOneWidget);
    expect(find.text('多'), findsOneWidget);
  });
}

/// 统计已渲染的趋势柱数量（key 形如 trend-bar-N）。
int _trendBarCount() {
  return find
      .byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('trend-bar-'),
      )
      .evaluate()
      .length;
}

/// 统计已渲染的热力图格子数量（key 形如 heat-cell-W-R）。
int _heatCellCount() {
  return find
      .byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('heat-cell-'),
      )
      .evaluate()
      .length;
}
