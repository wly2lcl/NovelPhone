import 'package:drift/drift.dart';

import '../db.dart';

/// CHAPTER_SNAPSHOT 表查询（B-05 章节版本历史）。
class SnapshotDao {
  SnapshotDao(this._db);

  final AppDatabase _db;

  /// 单章快照，按创建时间倒序（最新在前）。
  Stream<List<ChapterSnapshot>> watchByChapter(int chapterId) {
    return _ordered(chapterId).watch();
  }

  Future<List<ChapterSnapshot>> findByChapter(int chapterId) {
    return _ordered(chapterId).get();
  }

  Future<ChapterSnapshot?> findById(int id) {
    return (_db.select(_db.chapterSnapshots)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<int> insert(ChapterSnapshotsCompanion row) {
    return _db.into(_db.chapterSnapshots).insert(row);
  }

  Future<void> deleteById(int id) {
    return (_db.delete(_db.chapterSnapshots)..where((t) => t.id.equals(id))).go();
  }

  /// 只保留最新 [keep] 条，删除更旧的，返回清理条数。
  Future<int> pruneBeyond(int chapterId, int keep) async {
    // ENH-09：只读 id 列，不再把每条快照的正文载入内存。
    final ids = await (_db.selectOnly(_db.chapterSnapshots)
          ..addColumns(<Expression<int>>[_db.chapterSnapshots.id])
          ..where(_db.chapterSnapshots.chapterId.equals(chapterId))
          ..orderBy(<OrderingTerm>[
            OrderingTerm.desc(_db.chapterSnapshots.createdAt),
            OrderingTerm.desc(_db.chapterSnapshots.id),
          ]))
        .map((row) => row.read<int>(_db.chapterSnapshots.id)!)
        .get();
    if (ids.length <= keep) return 0;
    final staleIds = ids.skip(keep).toList(growable: false);
    await (_db.delete(_db.chapterSnapshots)..where((t) => t.id.isIn(staleIds)))
        .go();
    return staleIds.length;
  }

  SimpleSelectStatement<$ChapterSnapshotsTable, ChapterSnapshot> _ordered(
    int chapterId,
  ) {
    return _db.select(_db.chapterSnapshots)
      ..where((t) => t.chapterId.equals(chapterId))
      ..orderBy([
        (t) => OrderingTerm.desc(t.createdAt),
        (t) => OrderingTerm.desc(t.id),
      ]);
  }
}