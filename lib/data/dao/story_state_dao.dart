import 'package:drift/drift.dart';

import '../db.dart';

/// STORY_STATE 表查询（ENH-31）：按类型、排序号与更新时间组织故事状态卡。
class StoryStateDao {
  StoryStateDao(this._db);

  final AppDatabase _db;

  SimpleSelectStatement<$StoryStatesTable, StoryState> _selectByWork(
    int workId,
  ) {
    return _db.select(_db.storyStates)
      ..where((t) => t.workId.equals(workId))
      ..orderBy([
        (t) => OrderingTerm(expression: t.kind),
        (t) => OrderingTerm(expression: t.sortOrder),
        (t) => OrderingTerm(expression: t.id),
      ]);
  }

  Stream<List<StoryState>> watchByWork(int workId) =>
      _selectByWork(workId).watch();

  Future<List<StoryState>> findByWork(int workId) =>
      _selectByWork(workId).get();

  Future<int> insert(StoryStatesCompanion row) {
    return _db.into(_db.storyStates).insert(row);
  }

  Future<void> updateEntry(int id, StoryStatesCompanion patch) {
    return (_db.update(
      _db.storyStates,
    )..where((t) => t.id.equals(id))).write(patch);
  }

  Future<void> deleteById(int id) {
    return (_db.delete(_db.storyStates)..where((t) => t.id.equals(id))).go();
  }
}
