import 'package:drift/drift.dart';

import '../db.dart';

/// CHAPTER_SNAPSHOT 表查询（B-05 章节版本历史）。
class SnapshotDao {
  SnapshotDao(this._db);

  final AppDatabase _db;

  /// 单章快照（含正文），按创建时间倒序（最新在前）。
  Future<List<ChapterSnapshot>> findByChapter(int chapterId) {
    return _ordered(chapterId).get();
  }

  /// 单章快照元数据流（ENH-10，不含正文）：列表只需标题 / 字数 / 时间，
  /// 预览与恢复改为按 id 单取，避免把全部快照的正文都载入内存。
  Stream<List<ChapterSnapshot>> watchMetaByChapter(int chapterId) {
    final query = _db.selectOnly(_db.chapterSnapshots)
      ..addColumns(<Expression<Object>>[
        _db.chapterSnapshots.id,
        _db.chapterSnapshots.title,
        _db.chapterSnapshots.note,
        _db.chapterSnapshots.wordCount,
        _db.chapterSnapshots.createdAt,
      ])
      ..where(_db.chapterSnapshots.chapterId.equals(chapterId))
      ..orderBy(<OrderingTerm>[
        OrderingTerm.desc(_db.chapterSnapshots.createdAt),
        OrderingTerm.desc(_db.chapterSnapshots.id),
      ]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => ChapterSnapshot(
              id: row.read(_db.chapterSnapshots.id)!,
              chapterId: chapterId,
              title: row.read(_db.chapterSnapshots.title)!,
              content: '',
              note: row.read(_db.chapterSnapshots.note)!,
              wordCount: row.read(_db.chapterSnapshots.wordCount)!,
              createdAt: row.read(_db.chapterSnapshots.createdAt)!,
            ),
          )
          .toList(),
    );
  }

  Future<ChapterSnapshot?> findById(int id) {
    return (_db.select(
      _db.chapterSnapshots,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> insert(ChapterSnapshotsCompanion row) {
    return _db.into(_db.chapterSnapshots).insert(row);
  }

  Future<void> deleteById(int id) {
    return (_db.delete(
      _db.chapterSnapshots,
    )..where((t) => t.id.equals(id))).go();
  }

  /// 只保留最新 [keep] 条，删除更旧的，返回清理条数。
  Future<int> pruneBeyond(int chapterId, int keep) async {
    // ENH-09：只读 id 列，不再把每条快照的正文载入内存。
    final ids =
        await (_db.selectOnly(_db.chapterSnapshots)
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
    await (_db.delete(
      _db.chapterSnapshots,
    )..where((t) => t.id.isIn(staleIds))).go();
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
