import 'package:drift/drift.dart';

import '../db.dart';

/// AI_USAGE 的「模型 + 任务」聚合行（ENH-15）。
typedef UsageAggregate = ({
  String model,
  String task,
  int calls,
  int promptTokens,
  int completionTokens,
  int outputChars,
  int adoptedChars,
  int adopted,
  int ignored,
});

/// 与 `AiOutcome` 的取值一致；DAO 层不反向依赖仓储，故此处用字面量。
const String _outcomeAdopted = 'adopted';
const String _outcomeIgnored = 'ignored';

/// AI_USAGE 表查询。
class AiUsageDao {
  AiUsageDao(this._db);

  final AppDatabase _db;

  /// 按「模型 + 任务」在 SQL 内聚合（ENH-15）：统计只需要分组小计，没必要把整表
  /// AI_USAGE 读回 Dart 逐行累加（原实现还附带一次对聚合毫无用处的
  /// `ORDER BY createdAt DESC`，等于白跑一次全表排序）。
  Selectable<UsageAggregate> aggregateQuery() {
    final t = _db.aiUsages;
    final calls = t.id.count();
    final promptTokens = t.promptTokens.sum();
    final completionTokens = t.completionTokens.sum();
    final outputChars = t.outputChars.sum();
    final adoptedChars = t.adoptedChars.sum();
    final adopted = t.id.count(filter: t.outcome.equals(_outcomeAdopted));
    final ignored = t.id.count(filter: t.outcome.equals(_outcomeIgnored));
    final query = _db.selectOnly(t)
      ..addColumns(<Expression<Object>>[
        t.model,
        t.task,
        calls,
        promptTokens,
        completionTokens,
        outputChars,
        adoptedChars,
        adopted,
        ignored,
      ])
      ..groupBy(<Expression<Object>>[t.model, t.task]);
    // map 返回新的 Selectable，不能写进级联里。
    return query.map((row) => (
          model: row.read(t.model) ?? '',
          task: row.read(t.task) ?? '',
          calls: row.read(calls) ?? 0,
          promptTokens: row.read(promptTokens) ?? 0,
          completionTokens: row.read(completionTokens) ?? 0,
          outputChars: row.read(outputChars) ?? 0,
          adoptedChars: row.read(adoptedChars) ?? 0,
          adopted: row.read(adopted) ?? 0,
          ignored: row.read(ignored) ?? 0,
        ));
  }

  Stream<List<UsageAggregate>> watchAggregated() => aggregateQuery().watch();

  Future<List<UsageAggregate>> findAggregated() => aggregateQuery().get();

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