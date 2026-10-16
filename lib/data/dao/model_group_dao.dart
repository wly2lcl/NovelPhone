import 'package:drift/drift.dart';

import '../db.dart';

/// MODEL_GROUP 表查询。
class ModelGroupDao {
  ModelGroupDao(this._db);

  final AppDatabase _db;

  Stream<List<ModelGroup>> watchAll() {
    return (_db.select(
      _db.modelGroups,
    )..orderBy([(t) => OrderingTerm(expression: t.id)])).watch();
  }

  Future<List<ModelGroup>> findAll() {
    return (_db.select(
      _db.modelGroups,
    )..orderBy([(t) => OrderingTerm(expression: t.id)])).get();
  }

  Future<ModelGroup?> findById(int id) {
    return (_db.select(
      _db.modelGroups,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Stream<ModelGroup?> watchById(int id) {
    return (_db.select(
      _db.modelGroups,
    )..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  Future<int> insert(ModelGroupsCompanion row) {
    return _db.into(_db.modelGroups).insert(row);
  }

  Future<void> updateGroup(int id, ModelGroupsCompanion patch) {
    return (_db.update(
      _db.modelGroups,
    )..where((t) => t.id.equals(id))).write(patch);
  }

  Future<void> deleteById(int id) {
    return (_db.delete(_db.modelGroups)..where((t) => t.id.equals(id))).go();
  }
}
