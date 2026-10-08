import 'package:drift/drift.dart';

import '../db.dart';

/// OUTLINE_ENTRY 表查询。
class OutlineDao {
  OutlineDao(this._db);

  final AppDatabase _db;

  Stream<List<OutlineEntry>> watchByWork(int workId) {
    return (_db.select(_db.outlineEntries)
          ..where((t) => t.workId.equals(workId))
          ..orderBy([(t) => OrderingTerm(expression: t.id)]))
        .watch();
  }

  Future<List<OutlineEntry>> findByWork(int workId) {
    return (_db.select(_db.outlineEntries)
          ..where((t) => t.workId.equals(workId)))
        .get();
  }

  Future<OutlineEntry?> findByChapter(int chapterId) {
    return (_db.select(_db.outlineEntries)
          ..where((t) => t.chapterId.equals(chapterId)))
        .getSingleOrNull();
  }

  Future<int> insert(OutlineEntriesCompanion row) {
    return _db.into(_db.outlineEntries).insert(row);
  }

  Future<void> updateEntry(int id, OutlineEntriesCompanion patch) {
    return (_db.update(_db.outlineEntries)..where((t) => t.id.equals(id)))
        .write(patch);
  }

  Future<void> deleteById(int id) {
    return (_db.delete(_db.outlineEntries)..where((t) => t.id.equals(id))).go();
  }

  /// 章节删除时置空引用（不级联删除，见 ARCHITECTURE 4.3）。
  Future<void> clearChapterRef(int chapterId) {
    return (_db.update(_db.outlineEntries)
          ..where((t) => t.chapterId.equals(chapterId)))
        .write(const OutlineEntriesCompanion(chapterId: Value(null)));
  }

  /// 卷删除时置空引用。
  Future<void> clearVolumeRef(int volumeId) {
    return (_db.update(_db.outlineEntries)
          ..where((t) => t.volumeId.equals(volumeId)))
        .write(const OutlineEntriesCompanion(volumeId: Value(null)));
  }
}