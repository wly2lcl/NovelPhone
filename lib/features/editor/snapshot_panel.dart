import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/formatting.dart';
import '../../data/data_providers.dart';
import '../../data/db.dart';
import '../work_detail/work_detail_providers.dart';
import 'editor_controller.dart';

/// 章节版本历史面板（B-05）：创建快照、预览、恢复、删除。
class SnapshotPanel extends ConsumerWidget {
  const SnapshotPanel({
    super.key,
    required this.controller,
    required this.chapterId,
    required this.onClose,
  });

  final EditorController controller;
  final int chapterId;
  final VoidCallback onClose;

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    await ref
        .read(chapterRepositoryProvider)
        .createSnapshot(
          chapterId: chapterId,
          title: controller.title,
          content: controller.textController.text,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已创建快照')));
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    ChapterSnapshot snapshot,
  ) async {
    final repository = ref.read(chapterRepositoryProvider);
    // ENH-10：列表流只带元数据，预览 / 恢复所需的正文在此按 id 单取。
    final full = await repository.getSnapshot(snapshot.id);
    if (full == null || !context.mounted) return;
    final action = await showDialog<_SnapshotAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(full.title.isEmpty ? '未命名章节' : full.title),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '${formatRelativeTime(full.createdAt)} · ${full.wordCount} 字',
                  style: TextStyle(fontSize: 12, color: context.paper.inkSoft),
                ),
                const SizedBox(height: 8),
                Text(
                  _preview(full.content),
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_SnapshotAction.delete),
            child: const Text('删除', style: TextStyle(color: Color(0xFFB3261E))),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_SnapshotAction.restore),
            child: const Text('恢复此版本'),
          ),
        ],
      ),
    );
    if (action == null) return;
    if (action == _SnapshotAction.delete) {
      await repository.deleteSnapshot(full.id);
      return;
    }
    // 恢复前先把当前内容存一份，避免误操作丢稿。
    await repository.createSnapshot(
      chapterId: chapterId,
      title: controller.title,
      content: controller.textController.text,
    );
    await controller.restoreVersion(title: full.title, content: full.content);
    if (!context.mounted) return;
    onClose();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已恢复到该版本')));
  }

  /// 预览截断，避免超长章节（10 万字）在弹窗内渲染卡顿。
  static String _preview(String content) {
    if (content.isEmpty) return '（空章节）';
    return content.length > 2000 ? '${content.substring(0, 2000)}…' : content;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshots =
        ref.watch(snapshotsProvider(chapterId)).value ??
        const <ChapterSnapshot>[];
    return Container(
      color: context.paper.surface,
      padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  '版本历史',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton.icon(
                onPressed: () => _create(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('创建快照'),
              ),
              IconButton(
                tooltip: '关闭',
                icon: const Icon(Icons.close),
                onPressed: onClose,
              ),
            ],
          ),
          if (snapshots.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                '还没有快照。写作途中点「创建快照」留存一个版本。',
                style: TextStyle(fontSize: 13, color: context.paper.inkSoft),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: snapshots.length,
                itemBuilder: (context, index) {
                  final snapshot = snapshots[index];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.history,
                      size: 20,
                      color: context.paper.inkSoft,
                    ),
                    title: Text(
                      snapshot.title.isEmpty ? '未命名章节' : snapshot.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${formatRelativeTime(snapshot.createdAt)} · ${snapshot.wordCount} 字',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.paper.inkSoft,
                      ),
                    ),
                    onTap: () => _open(context, ref, snapshot),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

enum _SnapshotAction { restore, delete }
