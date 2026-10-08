import 'package:drift/drift.dart';

import '../db.dart';

/// SETTING_ENTRY 表查询（B-09 设定集）。
class SettingDao {
  SettingDao(this._db);

  final AppDatabase _db;

  SimpleSelectStatement<$SettingEntriesTable, SettingEntry> _selectByWork(
      int workId) {
    return _db.select(_db.settingEntries)
      ..where((t) => t.workId.equals(workId))
      ..orderBy([(t) => OrderingTerm(expression: t.id)]);
  }

  Stream<List<SettingEntry>> watchByWork(int workId) =>
      _selectByWork(workId).watch();

  Future<List<SettingEntry>> findByWork(int workId) =>
      _selectByWork(workId).get();

  Future<int> insert(SettingEntriesCompanion row) {
    return _db.into(_db.settingEntries).insert(row);
  }

  Future<void> updateEntry(int id, SettingEntriesCompanion patch) {
    return (_db.update(_db.settingEntries)..where((t) => t.id.equals(id)))
        .write(patch);
  }

  Future<void> deleteById(int id) {
    return (_db.delete(_db.settingEntries)..where((t) => t.id.equals(id))).go();
  }
}