import 'package:drift/drift.dart';

import '../db.dart';

/// WORK 表查询（仅拼装查询，事务与领域规则在 Repository）。
class WorkDao {
  WorkDao(this._db);

  final AppDatabase _db;

  SimpleSelectStatement<$WorksTable, Work> _selectAll() {
    return _db.select(_db.works)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm(expression: t.pinned, mode: OrderingMode.desc),
        (t) =>
            OrderingTerm(expression: t.lastEditedAt, mode: OrderingMode.desc),
      ]);
  }

  Stream<List<Work>> watchAll() => _selectAll().watch();

  Future<List<Work>> findAll() => _selectAll().get();

  Future<Work?> findById(int id) {
    return (_db.select(
      _db.works,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
  }

  Stream<Work?> watchById(int id) {
    return (_db.select(_db.works)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .watchSingleOrNull();
  }

  /// 回收站中的作品（ENH-22），最近删除的排在前面。
  Stream<List<Work>> watchTrashed() {
    return (_db.select(_db.works)
          ..where((t) => t.deletedAt.isNotNull())
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.deletedAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<List<Work>> findTrashed() {
    return (_db.select(_db.works)
          ..where((t) => t.deletedAt.isNotNull())
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.deletedAt, mode: OrderingMode.desc),
          ]))
        .get();
  }

  Future<Work?> findTrashedById(int id) {
    return (_db.select(_db.works)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNotNull()))
        .getSingleOrNull();
  }

  Future<void> markDeleted(int id, DateTime deletedAt) {
    return (_db.update(_db.works)..where((t) => t.id.equals(id))).write(
      WorksCompanion(deletedAt: Value(deletedAt), pinned: const Value(false)),
    );
  }

  Future<void> restore(int id) {
    return (_db.update(_db.works)..where((t) => t.id.equals(id))).write(
      const WorksCompanion(deletedAt: Value(null)),
    );
  }

  Future<int> insert(WorksCompanion row) {
    return _db.into(_db.works).insert(row);
  }

  Future<void> updateWork(int id, WorksCompanion patch) {
    return (_db.update(_db.works)..where((t) => t.id.equals(id))).write(patch);
  }

  Future<void> deleteById(int id) {
    return (_db.delete(_db.works)..where((t) => t.id.equals(id))).go();
  }

  Future<int> count() async {
    final row = await _db
        .customSelect(
          'SELECT COUNT(*) AS c FROM works WHERE deleted_at IS NULL',
        )
        .getSingle();
    return row.read<int>('c');
  }
}
