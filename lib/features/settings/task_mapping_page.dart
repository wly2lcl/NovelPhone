import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/ai/task_model_recommendation.dart';
import '../../data/data_providers.dart';
import '../../data/db.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/token_stats_repository.dart';
import '../../l10n/l10n.dart';
import '../ai/ai_providers.dart';

/// 近 30 天「模型 + 任务」统计（ENH-37）。
final recentTaskStatsProvider = FutureProvider.autoDispose<TokenStats>(
  (ref) => ref.watch(tokenStatsRepositoryProvider).recentStats(),
);

/// 任务模型推荐（ENH-37）：把近 30 天表现最好的模型映射回模型组。
final taskModelRecommendationsProvider =
    FutureProvider.autoDispose<List<TaskModelRecommendation>>((ref) async {
      final groups = await ref.watch(modelGroupsProvider.future);
      final stats = await ref.watch(recentTaskStatsProvider.future);
      final settings = ref.watch(settingsRepositoryProvider);
      final currentModels = <String, String?>{};
      for (final task in taskModelRecommendationTasks) {
        final group = _groupById(groups, await settings.taskModelId(task));
        if (group == null || !group.enabled) {
          currentModels[task] = null;
          continue;
        }
        final models = SettingsRepository.parseModels(group.models);
        currentModels[task] = models.isEmpty ? null : models.first;
      }
      return recommendTaskModels(
        rows: stats.rows,
        currentModels: currentModels,
      );
    });

/// 任务 → 模型映射（M3-18）：续写 / 灵感 / AI 感检查各自指定模型组。
class TaskMappingPage extends ConsumerWidget {
  const TaskMappingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final groups = ref.watch(modelGroupsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTaskMapping)),
      body: groups.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.taskMapLoadFailed('$e'))),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(l10n.taskMapEmptyHint),
              ),
            );
          }
          return ListView(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  l10n.taskMapIntro,
                  style: TextStyle(fontSize: 12, color: context.paper.inkSoft),
                ),
              ),
              _TaskModelRecommendations(groups: list),
              for (final task in AiTask.all)
                _TaskMappingTile(task: task, groups: list),
            ],
          );
        },
      ),
    );
  }
}

class _TaskMappingTile extends ConsumerWidget {
  const _TaskMappingTile({required this.task, required this.groups});

  final String task;
  final List<ModelGroup> groups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final selectedId = ref.watch(taskModelIdProvider(task)).value;
    final enabledGroups = groups.where((g) => g.enabled).toList();
    final validSelected = enabledGroups.any((g) => g.id == selectedId)
        ? selectedId
        : null;

    return ListTile(
      title: Text(_aiTaskLabel(l10n, task)),
      trailing: DropdownButton<int?>(
        value: validSelected,
        hint: Text(l10n.taskMapUnassigned),
        underline: const SizedBox.shrink(),
        items: <DropdownMenuItem<int?>>[
          DropdownMenuItem<int?>(
            value: null,
            child: Text(l10n.taskMapUnassigned),
          ),
          for (final group in enabledGroups)
            DropdownMenuItem<int?>(value: group.id, child: Text(group.name)),
        ],
        onChanged: (value) =>
            ref.read(settingsRepositoryProvider).setTaskModel(task, value),
      ),
    );
  }
}

/// 采纳质量推荐卡片（ENH-37）：只在有足够样本且确有提升时出现。
class _TaskModelRecommendations extends ConsumerWidget {
  const _TaskModelRecommendations({required this.groups});

  final List<ModelGroup> groups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final recommendations = switch (ref.watch(
      taskModelRecommendationsProvider,
    )) {
      AsyncData<List<TaskModelRecommendation>>(:final value) => value,
      _ => const <TaskModelRecommendation>[],
    };
    final items = <({TaskModelRecommendation rec, ModelGroup group})>[
      for (final rec in recommendations)
        if (_groupForModel(groups, rec.model) case final group?)
          (rec: rec, group: group),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.taskModelRecommendTitle,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.taskModelRecommendIntro,
                style: TextStyle(fontSize: 12, color: context.paper.inkSoft),
              ),
              for (final item in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_aiTaskLabel(l10n, item.rec.task)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.taskModelRecommendStat(
                          item.rec.model,
                          item.rec.calls,
                          item.rec.adoptionPercent,
                          item.rec.verbatimPercent,
                        ),
                      ),
                      Text(
                        item.rec.currentModel == null
                            ? l10n.taskModelRecommendNoCurrent
                            : l10n.taskModelRecommendCurrent(
                                item.rec.currentModel!,
                              ),
                      ),
                    ],
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      await ref
                          .read(settingsRepositoryProvider)
                          .setTaskModel(item.rec.task, item.group.id);
                      if (!context.mounted) return;
                      ref.invalidate(taskModelRecommendationsProvider);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            l10n.taskModelRecommendApplied(item.group.name),
                          ),
                        ),
                      );
                    },
                    child: Text(l10n.taskModelRecommendApply(item.group.name)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

ModelGroup? _groupById(List<ModelGroup> groups, int? id) {
  if (id == null) return null;
  for (final group in groups) {
    if (group.id == id) return group;
  }
  return null;
}

ModelGroup? _groupForModel(List<ModelGroup> groups, String model) {
  for (final group in groups) {
    if (!group.enabled) continue;
    if (SettingsRepository.parseModels(group.models).contains(model)) {
      return group;
    }
  }
  return null;
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
  AiTask.storyState => l10n.aiTaskStoryState,
  _ => task,
};
