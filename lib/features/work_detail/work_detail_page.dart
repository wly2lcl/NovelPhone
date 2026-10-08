import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/data_providers.dart';
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
          title: Text(workAsync.value?.title ?? '作品'),
          actions: <Widget>[
            IconButton(
              tooltip: '更多',
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showWorkActions(context, ref, workId),
            ),
          ],
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: '章节'),
              Tab(text: '角色卡'),
              Tab(text: '设定集'),
              Tab(text: '章纲'),
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
              label: const Text('运行 AI 感检查'),
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
      BuildContext context, WidgetRef ref, int workId) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('导入 txt / docx'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final count = await context.push<int>('/work/$workId/import');
                if (count != null && count > 0 && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已导入 $count 章')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.lightbulb_outline),
              title: const Text('灵感箱'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push('/work/$workId/inspirations');
              },
            ),
            ListTile(
              leading: const Icon(Icons.hub_outlined),
              title: const Text('人物关系图'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push('/work/$workId/relations');
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_download_outlined),
              title: const Text('导出作品'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await exportWork(context, ref, workId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('AI 设置'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push('/settings');
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('重命名作品'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _renameWork(context, ref, workId);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _renameWork(
      BuildContext context, WidgetRef ref, int workId) async {
    final work = await ref.read(workRepositoryProvider).getWork(workId);
    if (work == null || !context.mounted) return;
    // 不使用外部 TextEditingController：弹窗退场动画期间 builder 会再次执行，
    // 过早 dispose 会导致「controller used after being disposed」。
    var text = work.title;
    final newTitle = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('重命名作品'),
        content: TextFormField(
          initialValue: work.title,
          autofocus: true,
          maxLength: 50,
          onChanged: (value) => text = value,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (newTitle == null || newTitle.isEmpty || newTitle.length > 50) return;
    await ref.read(workRepositoryProvider).renameWork(workId, newTitle);
  }
}