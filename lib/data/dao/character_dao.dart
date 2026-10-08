import 'package:drift/drift.dart';

import '../db.dart';

/// CHARACTER 表查询。
class CharacterDao {
  CharacterDao(this._db);

  final AppDatabase _db;

  SimpleSelectStatement<$CharactersTable, Character> _selectByWork(int workId) {
    return _db.select(_db.characters)
      ..where((t) => t.workId.equals(workId))
      ..orderBy([(t) => OrderingTerm(expression: t.id)]);
  }

  Stream<List<Character>> watchByWork(int workId) => _selectByWork(workId).watch();

  Future<List<Character>> findByWork(int workId) => _selectByWork(workId).get();

  Future<Character?> findById(int id) {
    return (_db.select(_db.characters)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<int> insert(CharactersCompanion row) {
    return _db.into(_db.characters).insert(row);
  }

  Future<void> updateCharacter(int id, CharactersCompanion patch) {
    return (_db.update(_db.characters)..where((t) => t.id.equals(id))).write(patch);
  }

  Future<void> deleteById(int id) {
    return (_db.delete(_db.characters)..where((t) => t.id.equals(id))).go();
  }
}