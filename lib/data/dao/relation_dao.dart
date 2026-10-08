import 'package:drift/drift.dart';

import '../db.dart';

/// CHARACTER_RELATION 表查询（B-09 人物关系图）。
class RelationDao {
  RelationDao(this._db);

  final AppDatabase _db;

  SimpleSelectStatement<$CharacterRelationsTable, CharacterRelation>
      _selectByWork(int workId) {
    return _db.select(_db.characterRelations)
      ..where((t) => t.workId.equals(workId))
      ..orderBy([(t) => OrderingTerm(expression: t.id)]);
  }

  Stream<List<CharacterRelation>> watchByWork(int workId) =>
      _selectByWork(workId).watch();

  Future<List<CharacterRelation>> findByWork(int workId) =>
      _selectByWork(workId).get();

  Future<int> insert(CharacterRelationsCompanion row) {
    return _db.into(_db.characterRelations).insert(row);
  }

  Future<void> updateRelation(int id, CharacterRelationsCompanion patch) {
    return (_db.update(_db.characterRelations)..where((t) => t.id.equals(id)))
        .write(patch);
  }

  Future<void> deleteById(int id) {
    return (_db.delete(_db.characterRelations)..where((t) => t.id.equals(id)))
        .go();
  }
}