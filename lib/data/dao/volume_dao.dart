import 'package:drift/drift.dart';

import '../db.dart';

/// VOLUME 表查询。
class VolumeDao {
  VolumeDao(this._db);

  final AppDatabase _db;

  SimpleSelectStatement<$VolumesTable, Volume> _selectByWork(int workId) {
    return _db.select(_db.volumes)
      ..where((t) => t.workId.equals(workId))
      ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]);
  }

  Stream<List<Volume>> watchByWork(int workId) => _selectByWork(workId).watch();

  Future<List<Volume>> findByWork(int workId) => _selectByWork(workId).get();

  Future<Volume?> findById(int id) {
    return (_db.select(_db.volumes)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<Volume?> findFirst(int workId) {
    return (_selectByWork(workId)..limit(1)).getSingleOrNull();
  }

  Future<List<Volume>> findAll() => _db.select(_db.volumes).get();

  Future<int> insert(VolumesCompanion row) {
    return _db.into(_db.volumes).insert(row);
  }

  Future<void> updateVolume(int id, VolumesCompanion patch) {
    return (_db.update(_db.volumes)..where((t) => t.id.equals(id))).write(patch);
  }

  Future<void> deleteById(int id) {
    return (_db.delete(_db.volumes)..where((t) => t.id.equals(id))).go();
  }
}