import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/summary_editor.dart';
import '../../app/theme.dart';
import '../../core/word_count.dart';
import '../../data/data_providers.dart';
import '../../data/db.dart';
import '../../l10n/l10n.dart';
import '../../models/chapter_status.dart';
import 'export_actions.dart';
import 'work_detail_providers.dart';

/// 章节状态展示文案：ChapterStatus.label 仍供 AI 提示词与 DB 使用，
/// UI 展示统一走共享 l10n 键。
String _statusLabel(AppLocalizations l10n, ChapterStatus status) {
  return switch (status) {
    ChapterStatus.draft => l10n.chapterStatusDraft,
    ChapterStatus.revising => l10n.chapterStatusRevising,
    ChapterStatus.finished => l10n.chapterStatusFinished,
  };
}

/// 章节 Tab（PRD 5.2）：按卷分组展示章节，提供卷管理与章节管理入口。
class ChaptersTab extends ConsumerWidget {
  const ChaptersTab({super.key, required this.workId});

  final int workId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volumesAsync = ref.watch(volumesProvider(workId));
    final chaptersAsync = ref.watch(chaptersProvider(workId));

    if (volumesAsync.isLoading || chaptersAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final volumes = volumesAsync.value ?? const <Volume>[];
    final chapters = chaptersAsync.value ?? const <Chapter>[];

    // M2-13 长列表性能：只构造轻量行描述，实际 Widget 由 ListView.builder 按需创建。
    final grouped = <int, List<Chapter>>{};
    for (final chapter in chapters) {
      grouped.putIfAbsent(chapter.volumeId, () => <Chapter>[]).add(chapter);
    }
    final rows = <_Row>[
      for (final volume in volumes) ...<_Row>[
        _RowVolumeHeader(volume, grouped[volume.id]?.length ?? 0),
        for (final chapter in grouped[volume.id] ?? const <Chapter>[])
          _RowChapter(chapter, grouped[volume.id]!),
        _RowAddChapter(volume.id),
        const _RowDivider(),
      ],
      if (chapters.isEmpty) const _RowEmptyHint(),
      const _RowFooter(),
    ];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        return switch (row) {
          _RowVolumeHeader() => _VolumeHeader(
            workId: workId,
            volume: row.volume,
            chapterCount: row.chapterCount,
          ),
          _RowChapter() => _ChapterTile(
            workId: workId,
            chapter: row.chapter,
            chaptersInVolume: row.siblings,
          ),
          _RowAddChapter() => _AddChapterButton(
            workId: workId,
            volumeId: row.volumeId,
          ),
          _RowDivider() => const Divider(),
          _RowEmptyHint() => const _EmptyChaptersHint(),
          _RowFooter() => Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Center(
              child: OutlinedButton.icon(
                onPressed: () => _createVolume(context, ref),
                icon: const Icon(Icons.create_new_folder_outlined),
                label: Text(context.l10n.chaptersNewVolume),
              ),
            ),
          ),
        };
      },
    );
  }

  Future<void> _createVolume(BuildContext context, WidgetRef ref) async {
    // 不使用外部 TextEditingController：弹窗退场动画期间 builder 会再次执行，
    // 过早 dispose 会导致「controller used after being disposed」。
    var text = '';
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.chaptersNewVolume),
        content: TextFormField(
          autofocus: true,
          maxLength: 30,
          onChanged: (value) => text = value,
          decoration: InputDecoration(
            hintText: dialogContext.l10n.chaptersNewVolumeHint,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dialogContext.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(text.trim()),
            child: Text(dialogContext.l10n.chaptersCreate),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || name.length > 30) return;
    await ref.read(chapterRepositoryProvider).createVolume(workId, name);
  }
}

class _EmptyChaptersHint extends StatelessWidget {
  const _EmptyChaptersHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.edit_note_outlined,
            size: 64,
            color: context.paper.inkSoft,
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.chaptersEmptyTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.chaptersEmptyHint,
            style: TextStyle(color: context.paper.inkSoft),
          ),
        ],
      ),
    );
  }
}

/// 列表行描述（M2-13）：行数据而非 Widget，供 ListView.builder 按需创建。
sealed class _Row {
  const _Row();
}

class _RowVolumeHeader extends _Row {
  const _RowVolumeHeader(this.volume, this.chapterCount);

  final Volume volume;
  final int chapterCount;
}

class _RowChapter extends _Row {
  const _RowChapter(this.chapter, this.siblings);

  final Chapter chapter;
  final List<Chapter> siblings;
}

class _RowAddChapter extends _Row {
  const _RowAddChapter(this.volumeId);

  final int volumeId;
}

class _RowDivider extends _Row {
  const _RowDivider();
}

class _RowEmptyHint extends _Row {
  const _RowEmptyHint();
}

class _RowFooter extends _Row {
  const _RowFooter();
}

class _VolumeHeader extends ConsumerWidget {
  const _VolumeHeader({
    required this.workId,
    required this.volume,
    required this.chapterCount,
  });

  final int workId;
  final Volume volume;
  final int chapterCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              context.l10n.chaptersVolumeHeader(volume.name, chapterCount),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: context.l10n.chaptersVolumeActions,
            icon: const Icon(Icons.more_horiz),
            onPressed: () => _showVolumeActions(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _showVolumeActions(BuildContext context, WidgetRef ref) async {
    final repository = ref.read(chapterRepositoryProvider);
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final l10n = sheetContext.l10n;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline),
                title: Text(l10n.chaptersRenameVolume),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _renameVolume(context, ref);
                },
              ),
              // ENH-07 O3：查看 / 编辑本卷前情回顾（AI 生成的 VOLUME.summary）。
              ListTile(
                leading: const Icon(Icons.auto_stories_outlined),
                title: Text(l10n.chaptersVolumeSummaryAction),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _editVolumeSummary(context, ref);
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_upward),
                title: Text(l10n.chaptersMoveUp),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  repository.moveVolume(volume.id, up: true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_downward),
                title: Text(l10n.chaptersMoveDown),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  repository.moveVolume(volume.id, up: false);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFB3261E),
                ),
                title: Text(
                  l10n.chaptersDeleteVolume,
                  style: const TextStyle(color: Color(0xFFB3261E)),
                ),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _confirmDeleteVolume(context, ref);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _renameVolume(BuildContext context, WidgetRef ref) async {
    var text = volume.name;
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.chaptersRenameVolume),
        content: TextFormField(
          initialValue: volume.name,
          autofocus: true,
          maxLength: 30,
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
    if (name == null || name.isEmpty || name.length > 30) return;
    await ref.read(chapterRepositoryProvider).renameVolume(volume.id, name);
  }

  /// 查看 / 编辑本卷前情回顾（ENH-07 O3）：读写 VOLUME.summary。
  Future<void> _editVolumeSummary(BuildContext context, WidgetRef ref) async {
    await showSummaryEditor(
      context,
      initial: volume.summary,
      title: context.l10n.chaptersVolumeSummaryTitle,
      maxLines: 10,
      hintText: context.l10n.chaptersVolumeSummaryHint,
      onSave: (text) => ref
          .read(chapterRepositoryProvider)
          .saveVolumeSummary(volume.id, text),
    );
  }

  Future<void> _confirmDeleteVolume(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          dialogContext.l10n.chaptersDeleteVolumeConfirm(volume.name),
        ),
        content: Text(
          chapterCount == 0
              ? dialogContext.l10n.chaptersDeleteVolumeEmptyBody
              : dialogContext.l10n.chaptersDeleteVolumeBody(chapterCount),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(chapterRepositoryProvider).deleteVolume(volume.id);
  }
}

class _AddChapterButton extends ConsumerWidget {
  const _AddChapterButton({required this.workId, required this.volumeId});

  final int workId;
  final int volumeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => _createChapter(context, ref),
        icon: const Icon(Icons.add, size: 18),
        label: Text(context.l10n.chaptersAddChapterInVolume),
      ),
    );
  }

  Future<void> _createChapter(BuildContext context, WidgetRef ref) async {
    final repository = ref.read(chapterRepositoryProvider);
    final chapterId = await repository.createChapter(
      workId: workId,
      volumeId: volumeId,
    );
    if (!context.mounted) return;
    context.push('/work/$workId/chapter/$chapterId');
  }
}

class _ChapterTile extends ConsumerWidget {
  const _ChapterTile({
    required this.workId,
    required this.chapter,
    required this.chaptersInVolume,
  });

  final int workId;
  final Chapter chapter;
  final List<Chapter> chaptersInVolume;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ChapterStatus.fromValue(chapter.status);
    return Dismissible(
      key: ValueKey<int>(chapter.id),
      direction: DismissDirection.endToStart,
      // 左滑露出操作入口，操作在底部面板中完成，条目本身不消失。
      confirmDismiss: (_) async {
        await _showChapterActions(context, ref);
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: context.paper.accent.withValues(alpha: 0.12),
        child: Text(
          context.l10n.commonMore,
          style: TextStyle(color: context.paper.accent),
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          chapter.title.isEmpty
              ? context.l10n.commonUntitledChapter
              : chapter.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${formatWordCount(chapter.wordCount, context.l10n)} · '
          '${_statusLabel(context.l10n, status)}',
        ),
        trailing: Icon(Icons.chevron_right, color: context.paper.inkSoft),
        onTap: () => context.push('/work/$workId/chapter/${chapter.id}'),
        onLongPress: () => _showChapterActions(context, ref),
      ),
    );
  }

  Future<void> _showChapterActions(BuildContext context, WidgetRef ref) async {
    final repository = ref.read(chapterRepositoryProvider);
    final index = chaptersInVolume.indexWhere((c) => c.id == chapter.id);
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final l10n = sheetContext.l10n;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline),
                title: Text(l10n.chaptersRenameChapter),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _renameChapter(context, ref);
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_upward),
                title: Text(l10n.chaptersMoveUp),
                enabled: index > 0,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  repository.moveChapter(chapter.id, up: true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_downward),
                title: Text(l10n.chaptersMoveDown),
                enabled: index >= 0 && index < chaptersInVolume.length - 1,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  repository.moveChapter(chapter.id, up: false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: Text(l10n.chaptersMoveToVolume),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _moveToVolume(context, ref);
                },
              ),
              const Divider(height: 1),
              for (final status in ChapterStatus.values)
                ListTile(
                  leading: Icon(
                    status == ChapterStatus.fromValue(chapter.status)
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: context.paper.accent,
                  ),
                  title: Text(l10n.chaptersMarkAs(_statusLabel(l10n, status))),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    repository.setChapterStatus(chapter.id, status);
                  },
                ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.ios_share),
                title: Text(l10n.exportActionsChapterTitle),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await exportChapter(context, ref, chapter);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFB3261E),
                ),
                title: Text(
                  l10n.chaptersDeleteChapter,
                  style: const TextStyle(color: Color(0xFFB3261E)),
                ),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _confirmDeleteChapter(context, ref);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _renameChapter(BuildContext context, WidgetRef ref) async {
    var text = chapter.title;
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.chaptersRenameChapter),
        content: TextFormField(
          initialValue: chapter.title,
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
    if (title == null || title.length > 50) return;
    await ref.read(chapterRepositoryProvider).renameChapter(chapter.id, title);
  }

  Future<void> _moveToVolume(BuildContext context, WidgetRef ref) async {
    final volumes = await ref
        .read(chapterRepositoryProvider)
        .listVolumes(workId);
    final candidates = volumes.where((v) => v.id != chapter.volumeId).toList();
    if (candidates.isEmpty || !context.mounted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.chaptersNoOtherVolume)),
        );
      }
      return;
    }
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final candidate in candidates)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(candidate.name),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  ref
                      .read(chapterRepositoryProvider)
                      .moveChapterToVolume(chapter.id, candidate.id);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteChapter(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          dialogContext.l10n.chaptersDeleteChapterConfirm(
            chapter.title.isEmpty
                ? dialogContext.l10n.commonUntitledChapter
                : chapter.title,
          ),
        ),
        content: Text(dialogContext.l10n.chaptersDeleteChapterBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(chapterRepositoryProvider).deleteChapter(chapter.id);
  }
}
