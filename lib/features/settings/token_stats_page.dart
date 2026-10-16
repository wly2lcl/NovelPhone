import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/formatting.dart';
import '../../data/data_providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/token_stats_repository.dart';
import '../ai/ai_providers.dart';

/// Token 与采纳统计（M3-20，PRD 功能 10）：按模型+任务聚合展示，可重置。
class TokenStatsPage extends ConsumerWidget {
  const TokenStatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(tokenStatsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Token 与采纳统计'),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('重置统计'),
                  content: const Text('清空全部生成与采纳记录，不可恢复。'),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: const Text('清空'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await ref.read(tokenStatsRepositoryProvider).reset();
              }
            },
            child: const Text('重置'),
          ),
        ],
      ),
      body: stats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (data) {
          final checkStats = ref.watch(checkStatsProvider).value;
          if (data.isEmpty && (checkStats == null || checkStats.total == 0)) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.insights_outlined,
                      size: 40,
                      color: context.paper.inkSoft,
                    ),
                    SizedBox(height: 12),
                    Text('还没有生成记录'),
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
    final check = checkStats;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: <Widget>[
          _Metric(label: '生成次数', value: '${stats.calls}'),
          _Metric(
            label: 'Token 合计',
            value: formatTokenCount(stats.totalTokens),
          ),
          _Metric(label: '采纳率', value: _percent(stats.adoptionRate)),
          _Metric(label: '忽略率', value: _percent(stats.ignoreRate)),
          if (check != null && check.total > 0)
            _Metric(
              label: '检查问题处置率',
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
    return ListTile(
      title: Text('${AiTask.label(row.task)} · ${row.model}'),
      subtitle: Text(
        '${row.calls} 次 · 输入 ${formatTokenCount(row.promptTokens)} · '
        '输出 ${formatTokenCount(row.completionTokens)}\n'
        '生成 ${row.outputChars} 字 · 采纳 ${row.adoptedChars} 字 · '
        '采纳 ${row.adopted} 次 · 忽略 ${row.ignored} 次',
        style: TextStyle(fontSize: 12, color: context.paper.inkSoft),
      ),
      isThreeLine: true,
    );
  }
}
