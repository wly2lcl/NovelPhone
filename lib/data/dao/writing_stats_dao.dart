import 'package:drift/drift.dart';

import '../db.dart';

/// DAILY_WRITING_STAT 表查询（B-07：每日写作字数）。
class WritingStatsDao {
  WritingStatsDao(this._db);

  final AppDatabase _db;

  Future<DailyWritingStat?> findDay(String day) {
    return (_db.select(
      _db.dailyWritingStats,
    )..where((t) => t.day.equals(day))).getSingleOrNull();
  }

  Stream<List<DailyWritingStat>> watchAll() {
    return (_db.select(
      _db.dailyWritingStats,
    )..orderBy([(t) => OrderingTerm.desc(t.day)])).watch();
  }

  Future<List<DailyWritingStat>> listAll() {
    return (_db.select(
      _db.dailyWritingStats,
    )..orderBy([(t) => OrderingTerm.desc(t.day)])).get();
  }

  /// 累加某天的正字数（当天记录不存在则新建）。应在写事务内调用。
  Future<void> addWords(String day, int delta) async {
    if (delta <= 0) return;
    final existing = await findDay(day);
    await _db
        .into(_db.dailyWritingStats)
        .insertOnConflictUpdate(
          DailyWritingStatsCompanion.insert(
            day: day,
            words: Value((existing?.words ?? 0) + delta),
          ),
        );
  }
}
