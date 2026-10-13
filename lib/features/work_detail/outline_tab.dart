import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../data/data_providers.dart';
import '../../data/db.dart';
import 'work_detail_providers.dart';

/// 章纲 Tab（PRD 5.4）：按卷组织，为每章写一句话梗概；作品详情与编辑器双入口。
class OutlineTab extends ConsumerWidget {
  const OutlineTab({super.key, required this.workId});

  final int workId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volumes = ref.watch(volumesProvider(workId)).value ?? const <Volume>[];
    final chapters =
        ref.watch(chaptersProvider(workId)).value ?? const <Chapter>[];
    final outline =
        ref.watch(outlineProvider(workId)).value ?? const <OutlineEntry>[];

    final byChapter = <int, OutlineEntry>{
      for (final entry in outline)
        if (entry.chapterId != null) entry.chapterId!: entry,
    };
    final orphans =
        outline.where((e) => e.chapterId == null).toList(growable: false);

    if (chapters.isEmpty && orphans.isEmpty) {
      return const _EmptyOutlineHint();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: <Widget>[
        for (final volume in volumes) ...<Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              volume.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final chapter in chapters.where((c) => c.volumeId == volume.id))
            _OutlineTile(
              workId: workId,
              volumeId: volume.id,
              chapter: chapter,
              entry: byChapter[chapter.id],
            ),
          const Divider(),
        ],
        if (orphans.isNotEmpty) ...<Widget>[
          Padding(
            padding: EdgeInsets.only(top: 16, bottom: 4),
            child: Text('未关联章节的梗概',
                style: TextStyle(color: context.paper.inkSoft)),
          ),
          for (final entry in orphans)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.link_off, color: context.paper.inkSoft),
              title: Text(
                entry.summary.isEmpty ? '（空梗概）' : entry.summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                tooltip: '删除',
                icon: const Icon(Icons.delete_outline, color: Color(0xFFB3261E)),
                onPressed: () => ref
                    .read(outlineRepositoryProvider)
                    .deleteEntry(entry.id),
              ),
              onTap: () => showSummaryEditor(
                context,
                ref,
                initial: entry.summary,
                onSave: (text) => ref
                    .read(outlineRepositoryProvider)
                    .updateSummary(entry.id, text),
              ),
            ),
        ],
      ],
    );
  }
}

class _EmptyOutlineHint extends StatelessWidget {
  const _EmptyOutlineHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.list_alt_outlined,
                size: 64, color: context.paper.inkSoft),
            const SizedBox(height: 12),
            Text('还没有章纲', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              '先在「章节」Tab 创建章节，即可为每章写一句话梗概。',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.paper.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlineTile extends ConsumerWidget {
  const _OutlineTile({
    required this.workId,
    required this.volumeId,
    required this.chapter,
    required this.entry,
  });

  final int workId;
  final int volumeId;
  final Chapter chapter;
  final OutlineEntry? entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = entry?.summary ?? '';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        chapter.title.isEmpty ? '未命名章节' : chapter.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        summary.isEmpty ? '未填写梗概' : summary,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: summary.isEmpty ? context.paper.inkSoft : context.paper.ink,
        ),
      ),
      trailing: Icon(Icons.edit_note, color: context.paper.accent),
      onTap: () => showSummaryEditor(
        context,
        ref,
        initial: summary,
        onSave: (text) => ref.read(outlineRepositoryProvider).saveChapterSummary(
              workId: workId,
              volumeId: volumeId,
              chapterId: chapter.id,
              summary: text,
            ),
      ),
    );
  }
}

/// 梗概编辑弹窗（作品详情与编辑器侧栏共用）。
Future<void> showSummaryEditor(
  BuildContext context,
  WidgetRef ref, {
  required String initial,
  required Future<void> Function(String summary) onSave,
  String title = '编辑本章梗概',
}) async {
  // 弹窗退场动画期间 showDialog 的 builder 会再次执行，若在 showDialog 返回后
  // 立刻 dispose 外部 TextEditingController，会命中「A TextEditingController was
  // used after being disposed」并连带整页崩溃。这里改用由文本框自身管理生命周期的
  // initialValue，不持有外部 controller。
  var text = initial;
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextFormField(
        initialValue: initial,
        autofocus: true,
        maxLines: 4,
        maxLength: 200,
        onChanged: (value) => text = value,
        decoration: const InputDecoration(
          hintText: '一句话说明本章要发生什么（0-200 字）',
        ),
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
  if (result == null || result.length > 200) return;
  await onSave(result);
}