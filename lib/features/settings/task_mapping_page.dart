import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../data/data_providers.dart';
import '../../data/db.dart';
import '../../data/repositories/settings_repository.dart';
import '../ai/ai_providers.dart';

/// 任务 → 模型映射（M3-18）：续写 / 灵感 / AI 感检查各自指定模型组。
class TaskMappingPage extends ConsumerWidget {
  const TaskMappingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(modelGroupsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('任务与模型映射')),
      body: groups.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('请先在「模型组与 API Key」中添加模型组'),
              ),
            );
          }
          return ListView(
            children: <Widget>[
              Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  '为每类 AI 任务指定使用的模型组；未指定则对应功能不可用。',
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
    final selectedId = ref.watch(taskModelIdProvider(task)).value;
    final enabledGroups = groups.where((g) => g.enabled).toList();
    final validSelected =
        enabledGroups.any((g) => g.id == selectedId) ? selectedId : null;

    return ListTile(
      title: Text(AiTask.label(task)),
      trailing: DropdownButton<int?>(
        value: validSelected,
        hint: const Text('未指定'),
        underline: const SizedBox.shrink(),
        items: <DropdownMenuItem<int?>>[
          const DropdownMenuItem<int?>(value: null, child: Text('未指定')),
          for (final group in enabledGroups)
            DropdownMenuItem<int?>(
              value: group.id,
              child: Text(group.name),
            ),
        ],
        onChanged: (value) => ref
            .read(settingsRepositoryProvider)
            .setTaskModel(task, value),
      ),
    );
  }
}