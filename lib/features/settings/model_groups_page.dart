import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/ai/ai_client_factory.dart';
import '../../data/data_providers.dart';
import '../../data/db.dart';
import '../../data/repositories/settings_repository.dart';
import '../ai/ai_providers.dart';

/// 模型组管理（M3-18）：按服务商维护协议类型、baseUrl、模型列表与生成参数。
class ModelGroupsPage extends ConsumerWidget {
  const ModelGroupsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(modelGroupsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('模型组与 API Key')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/settings/model-groups/new'),
        icon: const Icon(Icons.add),
        label: const Text('新增模型组'),
      ),
      body: groups.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (list) {
          if (list.isEmpty) return const _EmptyHint();
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) =>
                _ModelGroupTile(group: list[index]),
          );
        },
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.key_outlined, size: 40, color: context.paper.inkSoft),
            const SizedBox(height: 12),
            const Text('还没有模型组'),
            const SizedBox(height: 4),
            Text(
              '添加服务商与 API Key 后，续写与灵感功能才能使用',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelGroupTile extends ConsumerStatefulWidget {
  const _ModelGroupTile({required this.group});

  final ModelGroup group;

  @override
  ConsumerState<_ModelGroupTile> createState() => _ModelGroupTileState();
}

class _ModelGroupTileState extends ConsumerState<_ModelGroupTile> {
  bool _hasKey = false;

  @override
  void initState() {
    super.initState();
    _loadKeyState();
  }

  Future<void> _loadKeyState() async {
    final has = await ref
        .read(settingsRepositoryProvider)
        .hasApiKey(widget.group.id);
    if (mounted) setState(() => _hasKey = has);
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final models = SettingsRepository.parseModels(group.models);
    final providerLabel = group.provider == AiProvider.anthropic
        ? 'Anthropic Messages'
        : 'OpenAI 兼容';
    return ListTile(
      leading: Icon(
        _hasKey ? Icons.key : Icons.key_off_outlined,
        color: _hasKey ? context.paper.accent : context.paper.inkSoft,
      ),
      title: Text(group.name),
      subtitle: Text(
        '$providerLabel · ${group.baseUrl}\n'
        '${models.isEmpty ? '未填写模型' : models.join('、')}'
        '${_hasKey ? '' : ' · 未填 Key'}',
        maxLines: 3,
        style: TextStyle(fontSize: 12, color: context.paper.inkSoft),
      ),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Switch(
            value: group.enabled,
            activeTrackColor: context.paper.accent,
            onChanged: (value) => ref
                .read(settingsRepositoryProvider)
                .setModelGroupEnabled(group.id, value),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'edit':
                  context.push('/settings/model-groups/${group.id}');
                case 'delete':
                  await _confirmDelete(context);
              }
            },
            itemBuilder: (context) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(value: 'edit', child: Text('编辑')),
              PopupMenuItem<String>(value: 'delete', child: Text('删除')),
            ],
          ),
        ],
      ),
      onTap: () => context.push('/settings/model-groups/${group.id}'),
    );
  }

  /// 删除二次确认（M3-19）：同时清除安全存储中的 key。
  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除模型组'),
        content: Text('删除「${widget.group.name}」后，其 API Key 也会一并从本机移除。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref
        .read(settingsRepositoryProvider)
        .deleteModelGroup(widget.group.id);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已删除模型组')));
    }
  }
}
