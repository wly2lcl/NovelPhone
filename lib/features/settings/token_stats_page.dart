import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/formatting.dart';
import '../../data/data_providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/token_stats_repository.dart';
import '../../l10n/l10n.dart';
import '../ai/ai_providers.dart';

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
          return ListView(
            children: <Widget>[
              _SummaryCard(stats: data, checkStats: checkStats),
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
  const _SummaryCard({required this.stats, this.checkStats});

  final TokenStats stats;
  final ({int total, int handled})? checkStats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final check = checkStats;
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
          _Metric(
            label: l10n.tokenStatsAdoptionRate,
            value: _percent(stats.adoptionRate),
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
  _ => task,
};
