import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/formatting.dart';
import '../../data/data_providers.dart';
import '../../data/db.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/token_stats_repository.dart';
import '../../l10n/l10n.dart';
import '../ai/ai_providers.dart';
import 'monthly_budget_dialog.dart';

/// Token 与采纳统计（M3-20，PRD 功能 10）：按模型+任务聚合展示，可重置。
class TokenStatsPage extends ConsumerWidget {
  const TokenStatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final stats = ref.watch(tokenStatsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTokenStats),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: Text(l10n.tokenStatsResetTitle),
                  content: Text(l10n.tokenStatsResetBody),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: Text(l10n.commonCancel),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: Text(l10n.commonClear),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await ref.read(tokenStatsRepositoryProvider).reset();
              }
            },
            child: Text(l10n.commonReset),
          ),
        ],
      ),
      body: stats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.tokenStatsLoadFailed('$e'))),
        data: (data) {
          final checkStats = ref.watch(checkStatsProvider).value;
          if (data.isEmpty && (checkStats == null || checkStats.total == 0)) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.insights_outlined,
                      size: 40,
                      color: context.paper.inkSoft,
                    ),
                    const SizedBox(height: 12),
                    Text(l10n.tokenStatsEmpty),
                  ],
                ),
              ),
            );
          }
          final groups =
              ref.watch(modelGroupsProvider).value ?? const <ModelGroup>[];
          final cost = _estimateCost(data, groups);
          final monthly = ref.watch(monthlyTokenStatsProvider).value;
          final budget = ref.watch(monthlyBudgetProvider).value ?? 0;
          final monthlyCost = _estimateCost(
            monthly ?? const TokenStats(rows: <TokenStatRow>[]),
            groups,
          );
          return ListView(
            children: <Widget>[
              _SummaryCard(stats: data, checkStats: checkStats, cost: cost),
              _BudgetCard(
                cost: monthlyCost,
                budget: budget,
                onEdit: () => showMonthlyBudgetDialog(context, ref),
              ),
              if (data.rows.isNotEmpty && !cost.hasPrice)
                _CostNote(text: l10n.tokenStatsCostHint)
              else if (cost.missing > 0)
                _CostNote(text: l10n.tokenStatsCostPartial(cost.missing)),
              const Divider(),
              for (final row in data.rows) _StatRowCard(row: row),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.stats, this.checkStats, this.cost});

  final TokenStats stats;
  final ({int total, int handled})? checkStats;
  final ({double amount, bool hasPrice, int missing})? cost;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final check = checkStats;
    final estimate = cost;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: <Widget>[
          _Metric(label: l10n.tokenStatsCalls, value: '${stats.calls}'),
          _Metric(
            label: l10n.tokenStatsTotalTokens,
            value: formatTokenCount(stats.totalTokens, l10n),
          ),
          if (estimate != null && estimate.hasPrice)
            _Metric(
              label: l10n.tokenStatsEstimatedCost,
              value: l10n.tokenStatsCostValue(
                estimate.amount.toStringAsFixed(2),
              ),
            ),
          _Metric(
            label: l10n.tokenStatsAdoptionRate,
            value: _percent(stats.adoptionRate),
          ),
          if (stats.adopted > 0)
            _Metric(
              label: l10n.tokenStatsVerbatimRate,
              value: _percent(stats.verbatimRate),
            ),
          _Metric(
            label: l10n.tokenStatsIgnoreRate,
            value: _percent(stats.ignoreRate),
          ),
          if (check != null && check.total > 0)
            _Metric(
              label: l10n.tokenStatsCheckHandledRate,
              value:
                  '${(check.handled / check.total * 100).toStringAsFixed(1)}%',
            ),
        ],
      ),
    );
  }

  static String _percent(double value) =>
      '${(value * 100).toStringAsFixed(1)}%';
}

/// 当月花费与预算进度（ENH-24）：达到 80% 提示，超出预算后标红。
class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.cost,
    required this.budget,
    required this.onEdit,
  });

  final ({double amount, bool hasPrice, int missing}) cost;
  final double budget;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final used = cost.amount;
    final ratio = budget <= 0 ? 0.0 : used / budget;
    final exceeded = budget > 0 && used >= budget;
    final warning = budget > 0 && !exceeded && ratio >= 0.8;
    final color = exceeded
        ? Theme.of(context).colorScheme.error
        : warning
        ? const Color(0xFFB26A00)
        : context.paper.accent;
    final usage = budget > 0
        ? l10n.tokenStatsBudgetUsage(
            used.toStringAsFixed(2),
            budget.toStringAsFixed(2),
          )
        : cost.hasPrice
        ? l10n.tokenStatsBudgetUsedOnly(used.toStringAsFixed(2))
        : l10n.tokenStatsBudgetUnset;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: context.paper.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 18,
                  color: context.paper.accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.tokenStatsMonthly,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                TextButton(
                  onPressed: onEdit,
                  child: Text(
                    budget > 0
                        ? l10n.tokenStatsBudgetEdit
                        : l10n.tokenStatsBudgetSet,
                  ),
                ),
              ],
            ),
            if (budget > 0) ...<Widget>[
              LinearProgressIndicator(
                value: ratio.clamp(0.0, 1.0),
                color: color,
                backgroundColor: context.paper.inkSoft.withValues(alpha: 0.15),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      usage,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.paper.inkSoft,
                      ),
                    ),
                  ),
                  Text(
                    l10n.tokenStatsBudgetPercent(
                      (ratio * 100).toStringAsFixed(0),
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ] else
              Text(
                usage,
                style: TextStyle(fontSize: 12, color: context.paper.inkSoft),
              ),
            if (budget > 0 && !cost.hasPrice)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  l10n.tokenStatsBudgetNoPrice,
                  style: TextStyle(fontSize: 12, color: context.paper.inkSoft),
                ),
              ),
            if (exceeded)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  l10n.tokenStatsBudgetExceeded,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              )
            else if (warning)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  l10n.tokenStatsBudgetWarning,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB26A00),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CostNote extends StatelessWidget {
  const _CostNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: context.paper.inkSoft),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(fontSize: 12, color: context.paper.inkSoft),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: context.paper.ink,
          ),
        ),
      ],
    );
  }
}

class _StatRowCard extends StatelessWidget {
  const _StatRowCard({required this.row});

  final TokenStatRow row;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      title: Text('${_aiTaskLabel(l10n, row.task)} · ${row.model}'),
      subtitle: Text(
        '${l10n.tokenStatsRowCalls(row.calls)} · '
        '${l10n.tokenStatsRowTokens(formatTokenCount(row.promptTokens, l10n), formatTokenCount(row.completionTokens, l10n))}\n'
        '${l10n.tokenStatsRowChars(row.outputChars, row.adoptedChars)} · '
        '${l10n.tokenStatsRowCounts(row.adopted, row.ignored)}',
        style: TextStyle(fontSize: 12, color: context.paper.inkSoft),
      ),
      isThreeLine: true,
    );
  }
}

/// 按模型组填写的每百万 token 单价估算费用（ENH-23）。
/// 同名模型以最后一个填写了单价的模型组为准；未填单价的模型计入 missing。
({double amount, bool hasPrice, int missing}) _estimateCost(
  TokenStats stats,
  List<ModelGroup> groups,
) {
  final prices = <String, ({double input, double output})>{};
  for (final group in groups) {
    final input = group.inputPricePerMillion;
    final output = group.outputPricePerMillion;
    if (input <= 0 && output <= 0) continue;
    for (final model in SettingsRepository.parseModels(group.models)) {
      prices[model] = (input: input, output: output);
    }
  }
  var amount = 0.0;
  var missing = 0;
  for (final row in stats.rows) {
    final price = prices[row.model];
    if (price == null) {
      missing++;
      continue;
    }
    amount +=
        row.promptTokens / 1000000 * price.input +
        row.completionTokens / 1000000 * price.output;
  }
  return (amount: amount, hasPrice: prices.isNotEmpty, missing: missing);
}

/// AI 任务展示名（AiTask 常量 → 本地化文案）。
String _aiTaskLabel(AppLocalizations l10n, String task) => switch (task) {
  AiTask.continueWriting => l10n.aiTaskContinue,
  AiTask.inspire => l10n.aiTaskInspire,
  AiTask.rewrite => l10n.aiTaskRewrite,
  AiTask.check => l10n.aiTaskCheck,
  AiTask.summary => l10n.aiTaskSummary,
  AiTask.outlineExpand => l10n.aiTaskOutlineExpand,
  AiTask.volumeSummary => l10n.aiTaskVolumeSummary,
  AiTask.continuity => l10n.aiTaskContinuity,
  AiTask.style => l10n.aiTaskStyle,
  AiTask.extract => l10n.aiTaskExtract,
  AiTask.plan => l10n.aiTaskPlan,
  AiTask.chat => l10n.aiTaskChat,
  _ => task,
};
