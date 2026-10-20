import 'package:drift/drift.dart';

import '../dao/ai_usage_dao.dart';
import '../db.dart';

/// 一次生成的处置结果（AI_USAGE.outcome）。
class AiOutcome {
  const AiOutcome._();

  static const String pending = 'pending';
  static const String adopted = 'adopted';
  static const String ignored = 'ignored';
  static const String regenerated = 'regenerated';
  static const String aborted = 'aborted';

  static String label(String outcome) {
    switch (outcome) {
      case adopted:
        return '已采纳';
      case ignored:
        return '已忽略';
      case regenerated:
        return '重新生成';
      case aborted:
        return '已中止';
      default:
        return '待处置';
    }
  }
}

/// 按「模型 + 任务」聚合的一行统计。
class TokenStatRow {
  const TokenStatRow({
    required this.model,
    required this.task,
    required this.calls,
    required this.promptTokens,
    required this.completionTokens,
    required this.outputChars,
    required this.adoptedChars,
    required this.adopted,
    required this.verbatimAdopted,
    required this.ignored,
  });

  final String model;
  final String task;
  final int calls;
  final int promptTokens;
  final int completionTokens;
  final int outputChars;
  final int adoptedChars;
  final int adopted;
  final int verbatimAdopted;
  final int ignored;
}

/// Token 与采纳统计（M3-20，PRD 功能 10）。
class TokenStats {
  const TokenStats({required this.rows});

  final List<TokenStatRow> rows;

  int get calls => rows.fold(0, (sum, r) => sum + r.calls);

  int get promptTokens => rows.fold(0, (sum, r) => sum + r.promptTokens);

  int get completionTokens =>
      rows.fold(0, (sum, r) => sum + r.completionTokens);

  int get totalTokens => promptTokens + completionTokens;

  int get outputChars => rows.fold(0, (sum, r) => sum + r.outputChars);

  int get adoptedChars => rows.fold(0, (sum, r) => sum + r.adoptedChars);

  int get adopted => rows.fold(0, (sum, r) => sum + r.adopted);

  int get verbatimAdopted => rows.fold(0, (sum, r) => sum + r.verbatimAdopted);

  int get ignored => rows.fold(0, (sum, r) => sum + r.ignored);

  /// 采纳率：被插入正文字数 / AI 生成总字数（PRD 2.2 字符口径）。
  double get adoptionRate => outputChars == 0 ? 0 : adoptedChars / outputChars;

  /// 原样采纳率（ENH-30）：采纳中编辑不超过 10% 的占比。
  double get verbatimRate => adopted == 0 ? 0 : verbatimAdopted / adopted;

  /// 忽略率：忽略次数 / 生成总次数。
  double get ignoreRate => calls == 0 ? 0 : ignored / calls;

  bool get isEmpty => rows.isEmpty;
}

/// AI_USAGE 读写与聚合（ARCHITECTURE 4.2：AI_USAGE 是 token 统计的唯一数据源）。
class TokenStatsRepository {
  TokenStatsRepository(AppDatabase db) : _dao = AiUsageDao(db);

  final AiUsageDao _dao;

  Future<int> record({
    required String task,
    required String model,
    int? workId,
    int? chapterId,
    int promptTokens = 0,
    int completionTokens = 0,
    int outputChars = 0,
    String outcome = AiOutcome.pending,
  }) {
    return _dao.insert(
      AiUsagesCompanion.insert(
        task: task,
        model: model,
        createdAt: DateTime.now(),
        workId: Value(workId),
        chapterId: Value(chapterId),
        promptTokens: Value(promptTokens),
        completionTokens: Value(completionTokens),
        outputChars: Value(outputChars),
        outcome: Value(outcome),
      ),
    );
  }

  Future<void> updateOutcome(int id, String outcome) =>
      _dao.updateOutcome(id, outcome);

  /// 采纳时同时记录实际插入的字数与编辑比例（ENH-30）。
  Future<void> markAdopted(int id, int adoptedChars, {int? editPercent}) =>
      _dao.updateAdoptedChars(
        id,
        adoptedChars,
        AiOutcome.adopted,
        editPercent: editPercent,
      );

  Stream<TokenStats> watchStats() => _dao.watchAggregated().map(_toStats);

  Future<TokenStats> stats() async => _toStats(await _dao.findAggregated());

  /// 自然月统计（ENH-24 月度预算）：从当月 1 日 00:00 起累计。
  Stream<TokenStats> watchMonthlyStats([DateTime? now]) {
    final since = _monthStart(now ?? DateTime.now());
    return _dao.watchAggregated(since: since).map(_toStats);
  }

  Future<TokenStats> monthlyStats([DateTime? now]) async {
    final since = _monthStart(now ?? DateTime.now());
    return _toStats(await _dao.findAggregated(since: since));
  }

  /// 近 30 天统计（ENH-37）：推荐只看近期表现，避免早期试验数据干扰。
  Future<TokenStats> recentStats({
    Duration window = const Duration(days: 30),
    DateTime? now,
  }) async {
    final since = (now ?? DateTime.now()).subtract(window);
    return _toStats(await _dao.findAggregated(since: since));
  }

  static DateTime _monthStart(DateTime now) => DateTime(now.year, now.month, 1);

  Future<void> reset() => _dao.deleteAll();

  /// 分组小计已在 SQL 内算好（ENH-15），这里只做排序与类型映射。
  TokenStats _toStats(List<UsageAggregate> aggregated) {
    final rows =
        <TokenStatRow>[
          for (final a in aggregated)
            TokenStatRow(
              model: a.model,
              task: a.task,
              calls: a.calls,
              promptTokens: a.promptTokens,
              completionTokens: a.completionTokens,
              outputChars: a.outputChars,
              adoptedChars: a.adoptedChars,
              adopted: a.adopted,
              verbatimAdopted: a.verbatimAdopted,
              ignored: a.ignored,
            ),
        ]..sort((a, b) {
          final byTask = a.task.compareTo(b.task);
          return byTask != 0 ? byTask : a.model.compareTo(b.model);
        });
    return TokenStats(rows: rows);
  }
}
