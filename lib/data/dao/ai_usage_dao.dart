import 'package:drift/drift.dart';

import '../db.dart';

/// AI_USAGE 表查询。
class AiUsageDao {
  AiUsageDao(this._db);

  final AppDatabase _db;

  Stream<List<AiUsage>> watchAll() {
    return (_db.select(_db.aiUsages)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<List<AiUsage>> findAll() {
    return (_db.select(_db.aiUsages)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .get();
  }

  Future<int> insert(AiUsagesCompanion row) {
    return _db.into(_db.aiUsages).insert(row);
  }

  Future<void> updateOutcome(int id, String outcome) {
    return (_db.update(_db.aiUsages)..where((t) => t.id.equals(id)))
        .write(AiUsagesCompanion(outcome: Value(outcome)));
  }

  Future<void> updateAdoptedChars(int id, int adoptedChars, String outcome) {
    return (_db.update(_db.aiUsages)..where((t) => t.id.equals(id))).write(
      AiUsagesCompanion(
        adoptedChars: Value(adoptedChars),
        outcome: Value(outcome),
      ),
    );
  }

  Future<void> deleteAll() => _db.delete(_db.aiUsages).go();
}