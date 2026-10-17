import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../data/data_providers.dart';
import '../../data/db.dart';
import '../../data/repositories/settings_repository.dart';
import '../../l10n/l10n.dart';
import '../ai/ai_providers.dart';

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
