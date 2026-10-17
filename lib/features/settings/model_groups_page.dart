import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/ai/ai_client_factory.dart';
import '../../data/data_providers.dart';
import '../../data/db.dart';
import '../../data/repositories/settings_repository.dart';
import '../../l10n/l10n.dart';
import '../ai/ai_providers.dart';

/// 模型组管理（M3-18）：按服务商维护协议类型、baseUrl、模型列表与生成参数。
class ModelGroupsPage extends ConsumerWidget {
  const ModelGroupsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final groups = ref.watch(modelGroupsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsModelGroups)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/settings/model-groups/new'),
        icon: const Icon(Icons.add),
        label: Text(l10n.modelGroupsNew),
      ),
      body: groups.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.modelGroupsLoadFailed('$e'))),
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
            Text(context.l10n.modelGroupsEmptyTitle),
            const SizedBox(height: 4),
            Text(
              context.l10n.modelGroupsEmptyHint,
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
    final l10n = context.l10n;
    final group = widget.group;
    final models = SettingsRepository.parseModels(group.models);
    final providerLabel = group.provider == AiProvider.anthropic
        ? 'Anthropic Messages'
        : l10n.modelGroupsOpenAiCompat;
    return ListTile(
      leading: Icon(
        _hasKey ? Icons.key : Icons.key_off_outlined,
        color: _hasKey ? context.paper.accent : context.paper.inkSoft,
      ),
      title: Text(group.name),
      subtitle: Text(
        '$providerLabel · ${group.baseUrl}\n'
        '${models.isEmpty ? l10n.modelGroupsNoModel : models.join(l10n.modelGroupsModelSeparator)}'
        '${_hasKey ? '' : ' · ${l10n.modelGroupsNoKey}'}',
        maxLines: 3,
        style: TextStyle(fontSize: 12, color: context.paper.inkSoft),
      ),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Semantics(
            label: l10n.commonToggleSwitch(group.name),
            child: Switch(
              value: group.enabled,
              activeTrackColor: context.paper.accent,
              onChanged: (value) => ref
                  .read(settingsRepositoryProvider)
                  .setModelGroupEnabled(group.id, value),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: l10n.commonMoreActions,
            onSelected: (value) async {
              switch (value) {
                case 'edit':
                  context.push('/settings/model-groups/${group.id}');
                case 'delete':
                  await _confirmDelete(context);
              }
            },
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'edit',
                child: Text(l10n.commonEdit),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Text(l10n.commonDelete),
              ),
            ],
          ),
        ],
      ),
      onTap: () => context.push('/settings/model-groups/${group.id}'),
    );
  }

  /// 删除二次确认（M3-19）：同时清除安全存储中的 key。
  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.modelGroupsDeleteTitle),
        content: Text(l10n.modelGroupsDeleteConfirm(widget.group.name)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.commonDelete),
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
      ).showSnackBar(SnackBar(content: Text(l10n.modelGroupsDeleted)));
    }
  }
}
