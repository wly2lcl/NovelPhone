import 'package:drift/drift.dart';

import '../db.dart';

/// INSPIRATION 表查询。
class InspirationDao {
  InspirationDao(this._db);

  final AppDatabase _db;

  SimpleSelectStatement<$InspirationsTable, Inspiration> _selectByWork(
    int workId,
  ) {
    return _db.select(_db.inspirations)
      ..where((t) => t.workId.equals(workId))
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ]);
  }

  Stream<List<Inspiration>> watchByWork(int workId) =>
      _selectByWork(workId).watch();

  Future<List<Inspiration>> findByWork(int workId) =>
      _selectByWork(workId).get();

  Future<int> insert(InspirationsCompanion row) {
    return _db.into(_db.inspirations).insert(row);
  }

  Future<void> updateContent(int id, String content) {
    return (_db.update(_db.inspirations)..where((t) => t.id.equals(id))).write(
      InspirationsCompanion(content: Value(content)),
    );
  }

  Future<void> deleteById(int id) {
    return (_db.delete(_db.inspirations)..where((t) => t.id.equals(id))).go();
  }
}
