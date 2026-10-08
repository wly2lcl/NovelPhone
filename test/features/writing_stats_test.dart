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
import 'package:novelphone/features/stats/writing_stats_page.dart';

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
          chapterId: chapterId, title: '第一章', content: first);

      final stats = await chapters.listDailyWritingStats();
      expect(stats, hasLength(1));
      expect(stats.single.day, writingDayKey(DateTime.now()));
      expect(stats.single.words, countWords(first));
    });

    test('删减正文不回退统计（只加不减）', () async {
      const long = '一二三四五六七八九十';
      await chapters.saveChapter(
          chapterId: chapterId, title: '第一章', content: long);
      final afterFirst = (await chapters.listDailyWritingStats()).single.words;
      expect(afterFirst, countWords(long));

      await chapters.saveChapter(
          chapterId: chapterId, title: '第一章', content: '一二');

      final stats = await chapters.listDailyWritingStats();
      expect(stats.single.words, afterFirst);
    });

    test('多次增写在同一天累加', () async {
      await chapters.saveChapter(
          chapterId: chapterId, title: '第一章', content: '一二三');
      await chapters.saveChapter(
          chapterId: chapterId, title: '第一章', content: '一二三四五');

      final stats = await chapters.listDailyWritingStats();
      expect(stats.single.words, countWords('一二三四五'));
    });

    test('备份导出与覆盖恢复保留每日写作统计', () async {
      final backup = BackupRepository(db);
      await chapters.saveChapter(
          chapterId: chapterId, title: '第一章', content: '一二三');
      final data = await backup.exportData();
      expect((data['tables'] as Map)['dailyWritingStats'], hasLength(1));

      // 导出后本机继续写作，覆盖恢复应回到备份时的字数。
      await chapters.saveChapter(
          chapterId: chapterId, title: '第一章', content: '一二三四五');
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
    final chapterId =
        await chapters.createChapter(workId: workId, title: '第一章');
    await chapters.saveChapter(
        chapterId: chapterId, title: '第一章', content: '一二三四五');
    await settings.setDailyWordTarget(100);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secureKeyStoreProvider.overrideWithValue(InMemoryKeyStore()),
      ],
      child: MaterialApp(
        theme: buildPaperTheme(),
        home: const WritingStatsPage(),
      ),
    ));

    for (var i = 0; i < 60; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
      if (find.text('5 / 100 字', findRichText: true).evaluate().isNotEmpty) {
        break;
      }
    }
    await tester.pump();

    expect(find.text('今日写作'), findsOneWidget);
    expect(find.text('5 / 100 字', findRichText: true), findsOneWidget);
    expect(find.text('1 天'), findsOneWidget);
    expect(find.text('25 分钟'), findsOneWidget);
    expect(find.text('今日已完成 0 个番茄钟'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    await db.close();
  });
}