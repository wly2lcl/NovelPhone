import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/data_providers.dart';
import '../../l10n/l10n.dart';
import '../editor/flavor_check_panel.dart';
import 'chapters_tab.dart';
import 'characters_tab.dart';
import 'export_actions.dart';
import 'outline_tab.dart';
import 'work_detail_providers.dart';
import 'worldbuilding_tab.dart';

/// 作品详情页（PRD 5.2）：Tab 框架（章节 / 角色卡 / 章纲）与作品级操作入口。
class WorkDetailPage extends ConsumerWidget {
  const WorkDetailPage({super.key, required this.workId});

  final int workId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workAsync = ref.watch(workProvider(workId));

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            workAsync.value?.title ?? context.l10n.workDetailTitleFallback,
          ),
          actions: <Widget>[
            IconButton(
              tooltip: context.l10n.commonMore,
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showWorkActions(context, ref, workId),
            ),
          ],
          bottom: TabBar(
            tabs: <Widget>[
              Tab(text: context.l10n.workDetailTabChapters),
              Tab(text: context.l10n.workDetailTabCharacters),
              Tab(text: context.l10n.workDetailTabWorldbuilding),
              Tab(text: context.l10n.workDetailTabOutline),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            ChaptersTab(workId: workId),
            CharactersTab(workId: workId),
            WorldbuildingTab(workId: workId),
            OutlineTab(workId: workId),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: OutlinedButton.icon(
              onPressed: () => _runFlavorCheck(context, workId),
              icon: const Icon(Icons.spellcheck),
              label: Text(context.l10n.workDetailRunFlavorCheck),
            ),
          ),
        ),
      ),
    );
  }

  /// 运行 AI 感检查（PRD 5.7）：作品详情入口默认范围为整部作品。
  Future<void> _runFlavorCheck(BuildContext context, int workId) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => FlavorCheckPanel(
        workId: workId,
        initialChapterId: null,
        heightFactor: 0.85,
        onClose: () => Navigator.of(sheetContext).pop(),
      ),
    );
  }

  Future<void> _showWorkActions(
    BuildContext context,
    WidgetRef ref,
    int workId,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final l10n = sheetContext.l10n;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.upload_file_outlined),
                title: Text(l10n.workDetailImportTxtDocx),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final count = await context.push<int>('/work/$workId/import');
                  if (count != null && count > 0 && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.workDetailImportedCount(count)),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.lightbulb_outline),
                title: Text(l10n.workDetailInspirationsTitle),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/work/$workId/inspirations');
                },
              ),
              ListTile(
                leading: const Icon(Icons.hub_outlined),
                title: Text(l10n.relationGraphTitle),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/work/$workId/relations');
                },
              ),
              ListTile(
                leading: const Icon(Icons.file_download_outlined),
                title: Text(l10n.exportActionsExportWorkTitle),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await exportWork(context, ref, workId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.tune),
                title: Text(l10n.workDetailAiSettings),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/settings');
                },
              ),
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline),
                title: Text(l10n.workDetailRenameWork),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _renameWork(context, ref, workId);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _renameWork(
    BuildContext context,
    WidgetRef ref,
    int workId,
  ) async {
    final work = await ref.read(workRepositoryProvider).getWork(workId);
    if (work == null || !context.mounted) return;
    // 不使用外部 TextEditingController：弹窗退场动画期间 builder 会再次执行，
    // 过早 dispose 会导致「controller used after being disposed」。
    var text = work.title;
    final newTitle = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.workDetailRenameWork),
        content: TextFormField(
          initialValue: work.title,
          autofocus: true,
          maxLength: 50,
          onChanged: (value) => text = value,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dialogContext.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(text.trim()),
            child: Text(dialogContext.l10n.commonSave),
          ),
        ],
      ),
    );
    if (newTitle == null || newTitle.isEmpty || newTitle.length > 50) return;
    await ref.read(workRepositoryProvider).renameWork(workId, newTitle);
  }
}
