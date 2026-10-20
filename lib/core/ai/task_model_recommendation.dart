import '../../data/repositories/settings_repository.dart' show AiTask;
import '../../data/repositories/token_stats_repository.dart';

/// ENH-37：用近 30 天的采纳数据推荐「任务 → 模型」映射。
///
/// 只有结果可能被采纳的任务才有可比口径；一致性检查、问答等任务不参与推荐。
const List<String> taskModelRecommendationTasks = <String>[
  AiTask.continueWriting,
  AiTask.inspire,
  AiTask.rewrite,
  AiTask.summary,
  AiTask.outlineExpand,
  AiTask.volumeSummary,
];

/// 推荐门槛：至少 3 次调用、采纳率达到 20%，且比当前映射高 10 个百分点。
const int taskModelMinCalls = 3;
const double taskModelMinAdoptionRate = 0.2;
const double taskModelImprovementMargin = 0.1;

/// 一条任务模型推荐：采纳率取「插入正文字数 / AI 生成总字数」。
class TaskModelRecommendation {
  const TaskModelRecommendation({
    required this.task,
    required this.model,
    required this.calls,
    required this.adoptionRate,
    required this.verbatimRate,
    required this.currentModel,
  });

  final String task;

  /// 近 30 天在该任务上表现最好的模型名。
  final String model;

  final int calls;
  final double adoptionRate;

  /// 采纳结果中编辑不超过 10% 的占比（ENH-30 口径）。
  final double verbatimRate;

  /// 当前映射实际使用的模型；null 表示任务未单独指定（走回退）。
  final String? currentModel;

  int get adoptionPercent => (adoptionRate * 100).round();

  int get verbatimPercent => (verbatimRate * 100).round();
}

List<TaskModelRecommendation> recommendTaskModels({
  required List<TokenStatRow> rows,
  required Map<String, String?> currentModels,
  Iterable<String> tasks = taskModelRecommendationTasks,
  int minCalls = taskModelMinCalls,
  double minAdoptionRate = taskModelMinAdoptionRate,
  double margin = taskModelImprovementMargin,
}) {
  final byTask = <String, List<TokenStatRow>>{};
  for (final row in rows) {
    if (row.calls < minCalls || row.outputChars <= 0) continue;
    (byTask[row.task] ??= <TokenStatRow>[]).add(row);
  }

  final result = <TaskModelRecommendation>[];
  for (final task in tasks) {
    final candidates = byTask[task];
    if (candidates == null || candidates.isEmpty) continue;
    candidates.sort((a, b) {
      final byRate = _adoptionRate(b).compareTo(_adoptionRate(a));
      if (byRate != 0) return byRate;
      final byVerbatim = _verbatimRate(b).compareTo(_verbatimRate(a));
      if (byVerbatim != 0) return byVerbatim;
      final byCalls = b.calls.compareTo(a.calls);
      return byCalls != 0 ? byCalls : a.model.compareTo(b.model);
    });

    final best = candidates.first;
    final bestRate = _adoptionRate(best);
    if (bestRate < minAdoptionRate) continue;

    final current = currentModels[task];
    if (current == best.model) continue;
    if (current != null) {
      TokenStatRow? currentRow;
      for (final row in candidates) {
        if (row.model == current) {
          currentRow = row;
          break;
        }
      }
      final currentRate = currentRow == null ? 0.0 : _adoptionRate(currentRow);
      if (bestRate < currentRate + margin) continue;
    }

    result.add(
      TaskModelRecommendation(
        task: task,
        model: best.model,
        calls: best.calls,
        adoptionRate: bestRate,
        verbatimRate: _verbatimRate(best),
        currentModel: current,
      ),
    );
  }
  return result;
}

double _adoptionRate(TokenStatRow row) =>
    row.outputChars <= 0 ? 0 : row.adoptedChars / row.outputChars;

double _verbatimRate(TokenStatRow row) =>
    row.adopted <= 0 ? 0 : row.verbatimAdopted / row.adopted;
