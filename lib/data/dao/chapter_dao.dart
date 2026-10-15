import 'package:drift/drift.dart';

import '../db.dart';

/// CHAPTER 表查询。
class ChapterDao {
  ChapterDao(this._db);

  final AppDatabase _db;

  /// 作品全部章节，按卷排序号 + 章节排序号排列。
  Stream<List<Chapter>> watchByWork(int workId) {
    final query = _db.select(_db.chapters).join([
      innerJoin(_db.volumes, _db.volumes.id.equalsExp(_db.chapters.volumeId)),
    ])
      ..where(_db.volumes.workId.equals(workId))
      ..orderBy([
        OrderingTerm.asc(_db.volumes.sortOrder),
        OrderingTerm.asc(_db.chapters.sortOrder),
      ]);
    return query
        .watch()
        .map((rows) => rows.map((r) => r.readTable(_db.chapters)).toList());
  }

  /// 作品全部章节的元数据流（ENH-10，不含正文）：目录 / 大纲 / 检查范围只需
  /// 标题与字数，避免每次自动保存写 chapters 表都重发并重读全书正文。
  Stream<List<Chapter>> watchMetaByWork(int workId) {
    final query = _db.selectOnly(_db.chapters).join([
      innerJoin(_db.volumes, _db.volumes.id.equalsExp(_db.chapters.volumeId)),
    ])
      ..addColumns(<Expression<Object>>[
        _db.chapters.id,
        _db.chapters.volumeId,
        _db.chapters.title,
        _db.chapters.wordCount,
        _db.chapters.status,
        _db.chapters.sortOrder,
        _db.chapters.cursorOffset,
        _db.chapters.scrollOffset,
        _db.chapters.updatedAt,
        _db.chapters.summary,
        _db.chapters.summaryUpdatedAt,
      ])
      ..where(_db.volumes.workId.equals(workId))
      ..orderBy([
        OrderingTerm.asc(_db.volumes.sortOrder),
        OrderingTerm.asc(_db.chapters.sortOrder),
      ]);
    return query.watch().map((rows) => rows
        .map((row) => Chapter(
              id: row.read(_db.chapters.id)!,
              volumeId: row.read(_db.chapters.volumeId)!,
              title: row.read(_db.chapters.title)!,
              content: '',
              wordCount: row.read(_db.chapters.wordCount)!,
              status: row.read(_db.chapters.status)!,
              sortOrder: row.read(_db.chapters.sortOrder)!,
              cursorOffset: row.read(_db.chapters.cursorOffset)!,
              scrollOffset: row.read(_db.chapters.scrollOffset)!,
              updatedAt: row.read(_db.chapters.updatedAt)!,
              summary: row.read(_db.chapters.summary)!,
              summaryUpdatedAt: row.read(_db.chapters.summaryUpdatedAt),
            ))
        .toList());
  }

  /// 卷内章节的轻量元数据（ENH-10，不含正文）：删除卷 / 章节排序只需 id 与 sortOrder。
  Future<List<({int id, int sortOrder})>> findMetaByVolume(int volumeId) async {
    final query = _db.selectOnly(_db.chapters)
      ..addColumns(<Expression<Object>>[
        _db.chapters.id,
        _db.chapters.sortOrder,
      ])
      ..where(_db.chapters.volumeId.equals(volumeId))
      ..orderBy(<OrderingTerm>[OrderingTerm.asc(_db.chapters.sortOrder)]);
    final rows = await query.get();
    return rows
        .map((row) => (
              id: row.read(_db.chapters.id)!,
              sortOrder: row.read(_db.chapters.sortOrder)!,
            ))
        .toList();
  }

  Future<Chapter?> findById(int id) {
    return (_db.select(_db.chapters)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Stream<Chapter?> watchById(int id) {
    return (_db.select(_db.chapters)..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  /// 卷内下一个排序号。
  Future<int> nextSortOrder(int volumeId) async {
    final maxOrder = _db.chapters.sortOrder.max();
    final query = _db.selectOnly(_db.chapters)
      ..addColumns([maxOrder])
      ..where(_db.chapters.volumeId.equals(volumeId));
    final row = await query.getSingle();
    return (row.read(maxOrder) ?? 0) + 1;
  }

  /// 作品维度的字数与章节数汇总（不读取正文）。
  Future<({int words, int chapters})> aggregateByWork(int workId) async {
    final wordSum = _db.chapters.wordCount.sum();
    final chapterCount = _db.chapters.id.count();
    final query = _db.selectOnly(_db.chapters).join([
      innerJoin(_db.volumes, _db.volumes.id.equalsExp(_db.chapters.volumeId)),
    ])
      ..addColumns([wordSum, chapterCount])
      ..where(_db.volumes.workId.equals(workId));
    final row = await query.getSingle();
    return (words: row.read(wordSum) ?? 0, chapters: row.read(chapterCount) ?? 0);
  }

  Future<int> insert(ChaptersCompanion row) {
    return _db.into(_db.chapters).insert(row);
  }

  Future<void> updateChapter(int id, ChaptersCompanion patch) {
    return (_db.update(_db.chapters)..where((t) => t.id.equals(id))).write(patch);
  }

  Future<void> deleteById(int id) {
    return (_db.delete(_db.chapters)..where((t) => t.id.equals(id))).go();
  }

  Future<void> deleteByVolume(int volumeId) {
    return (_db.delete(_db.chapters)..where((t) => t.volumeId.equals(volumeId))).go();
  }
}