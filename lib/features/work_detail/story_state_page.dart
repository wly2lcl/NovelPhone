import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../data/data_providers.dart';
import '../../data/db.dart';
import '../../l10n/l10n.dart';
import '../../models/story_state_kind.dart';
import 'work_detail_providers.dart';

/// 故事状态卡（ENH-31）：角色状态 / 伏笔 open-closed / 时间线。
class StoryStatePage extends ConsumerStatefulWidget {
  const StoryStatePage({super.key, required this.workId});

  final int workId;

  @override
  ConsumerState<StoryStatePage> createState() => _StoryStatePageState();
}

class _StoryStatePageState extends ConsumerState<StoryStatePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: StoryStateKind.values.length,
    vsync: this,
  )..addListener(_onTabChanged);

  void _onTabChanged() {
    if (!_tabs.indexIsChanging) setState(() {});
  }

  @override
  void dispose() {
    _tabs
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entries =
        ref.watch(storyStatesProvider(widget.workId)).value ??
        const <StoryState>[];
    final chapters =
        ref.watch(chaptersProvider(widget.workId)).value ?? const <Chapter>[];
    final kind = StoryStateKind.values[_tabs.index];
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.storyStateTitle),
        bottom: TabBar(
          controller: _tabs,
          tabs: <Widget>[
            Tab(text: l10n.storyStateTabCharacter),
            Tab(text: l10n.storyStateTabForeshadow),
            Tab(text: l10n.storyStateTabTimeline),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: <Widget>[
          for (final value in StoryStateKind.values)
            _StoryStateList(
              workId: widget.workId,
              kind: value,
              entries: entries
                  .where((entry) => entry.kind == value.value)
                  .toList(),
              chapters: chapters,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, kind, null, entries),
        icon: const Icon(Icons.add),
        label: Text(l10n.storyStateAdd),
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    StoryStateKind kind,
    StoryState? entry,
    List<StoryState> entries,
  ) async {
    final l10n = context.l10n;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _StoryStateEditorDialog(
        workId: widget.workId,
        kind: kind,
        entry: entry,
        chapters:
            ref.read(chaptersProvider(widget.workId)).value ??
            const <Chapter>[],
        nextSortOrder: entries
            .where((e) => e.kind == kind.value)
            .fold<int>(
              0,
              (max, e) => e.sortOrder >= max ? e.sortOrder + 1 : max,
            ),
      ),
    );
    if (saved != true || !mounted) return;
    ScaffoldMessenger.of(
      this.context,
    ).showSnackBar(SnackBar(content: Text(l10n.storyStateSaved)));
  }
}

class _StoryStateList extends ConsumerWidget {
  const _StoryStateList({
    required this.workId,
    required this.kind,
    required this.entries,
    required this.chapters,
  });

  final int workId;
  final StoryStateKind kind;
  final List<StoryState> entries;
  final List<Chapter> chapters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (entries.isEmpty) {
      return _EmptyHint(kind: kind);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _StoryStateCard(
        workId: workId,
        entry: entries[index],
        chapterLabel: _chapterLabel(entries[index].chapterId),
        onEdit: () => _edit(context, entries[index]),
      ),
    );
  }

  String? _chapterLabel(int? chapterId) {
    if (chapterId == null) return null;
    final index = chapters.indexWhere((chapter) => chapter.id == chapterId);
    if (index < 0) return null;
    final title = chapters[index].title.trim();
    return '第 ${index + 1} 章${title.isEmpty ? '' : ' $title'}';
  }

  Future<void> _edit(BuildContext context, StoryState entry) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _StoryStateEditorDialog(
        workId: workId,
        kind: kind,
        entry: entry,
        chapters: chapters,
        nextSortOrder: entry.sortOrder,
      ),
    );
    if (saved != true || !context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.storyStateSaved)));
  }
}

class _StoryStateCard extends ConsumerWidget {
  const _StoryStateCard({
    required this.workId,
    required this.entry,
    required this.chapterLabel,
    required this.onEdit,
  });

  final int workId;
  final StoryState entry;
  final String? chapterLabel;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final kind = StoryStateKind.fromValue(entry.kind);
    final closed = entry.status == 'closed';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(_icon(kind), size: 18, color: context.paper.inkSoft),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      decoration: closed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: l10n.storyStateMoreActions,
                  onSelected: (value) async {
                    if (value == 'edit') {
                      onEdit();
                      return;
                    }
                    final confirmed = await _confirmDelete(context);
                    if (!confirmed || !context.mounted) return;
                    await ref
                        .read(storyStateRepositoryProvider)
                        .deleteEntry(entry.id);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.storyStateDeleted)),
                    );
                  },
                  itemBuilder: (menuContext) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Text(l10n.storyStateEdit),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text(l10n.storyStateDelete),
                    ),
                  ],
                ),
              ],
            ),
            if (entry.detail.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                entry.detail.trim(),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.paper.inkSoft),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                if (kind == StoryStateKind.foreshadow)
                  _StatusChip(
                    closed: closed,
                    onTap: () => ref
                        .read(storyStateRepositoryProvider)
                        .setStatus(entry.id, closed ? 'open' : 'closed'),
                  ),
                if (kind == StoryStateKind.foreshadow && chapterLabel != null)
                  const SizedBox(width: 8),
                if (chapterLabel != null)
                  Icon(
                    Icons.menu_book_outlined,
                    size: 14,
                    color: context.paper.inkSoft,
                  ),
                if (chapterLabel != null) const SizedBox(width: 4),
                if (chapterLabel != null)
                  Flexible(
                    child: Text(
                      chapterLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.paper.inkSoft,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final l10n = context.l10n;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.storyStateDeleteTitle),
            content: Text(l10n.storyStateDeleteBody),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.storyStateDelete),
              ),
            ],
          ),
        ) ??
        false;
  }

  IconData _icon(StoryStateKind kind) => switch (kind) {
    StoryStateKind.character => Icons.person_outline,
    StoryStateKind.foreshadow => Icons.anchor_outlined,
    StoryStateKind.timeline => Icons.timeline_outlined,
  };
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.closed, required this.onTap});

  final bool closed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: closed
              ? context.paper.inkSoft.withValues(alpha: 0.12)
              : Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          closed ? l10n.storyStateClosed : l10n.storyStateOpen,
          style: TextStyle(
            fontSize: 12,
            color: closed
                ? context.paper.inkSoft
                : Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.kind});

  final StoryStateKind kind;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = switch (kind) {
      StoryStateKind.character => l10n.storyStateEmptyCharacter,
      StoryStateKind.foreshadow => l10n.storyStateEmptyForeshadow,
      StoryStateKind.timeline => l10n.storyStateEmptyTimeline,
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.dashboard_customize_outlined,
              size: 64,
              color: context.paper.inkSoft,
            ),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              l10n.storyStateEmptyHint,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.paper.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryStateEditorDialog extends ConsumerStatefulWidget {
  const _StoryStateEditorDialog({
    required this.workId,
    required this.kind,
    required this.entry,
    required this.chapters,
    required this.nextSortOrder,
  });

  final int workId;
  final StoryStateKind kind;
  final StoryState? entry;
  final List<Chapter> chapters;
  final int nextSortOrder;

  @override
  ConsumerState<_StoryStateEditorDialog> createState() =>
      _StoryStateEditorDialogState();
}

class _StoryStateEditorDialogState
    extends ConsumerState<_StoryStateEditorDialog> {
  late final TextEditingController _title = TextEditingController(
    text: widget.entry?.title ?? '',
  );
  late final TextEditingController _detail = TextEditingController(
    text: widget.entry?.detail ?? '',
  );
  late int? _chapterId = widget.entry?.chapterId;
  late bool _closed = (widget.entry?.status ?? 'open') == 'closed';
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _detail.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = l10n.storyStateTitleRequired);
      return;
    }
    final repository = ref.read(storyStateRepositoryProvider);
    final entry = widget.entry;
    if (entry == null) {
      await repository.createEntry(
        workId: widget.workId,
        kind: widget.kind,
        title: title,
        detail: _detail.text.trim(),
        status: _closed ? 'closed' : 'open',
        chapterId: _chapterId,
        sortOrder: widget.nextSortOrder,
      );
    } else {
      await repository.updateEntry(
        id: entry.id,
        kind: widget.kind,
        title: title,
        detail: _detail.text.trim(),
        status: _closed ? 'closed' : 'open',
        chapterId: _chapterId,
        sortOrder: entry.sortOrder,
      );
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(
        widget.entry == null ? l10n.storyStateAdd : l10n.storyStateEdit,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              controller: _title,
              autofocus: true,
              maxLength: 50,
              decoration: InputDecoration(
                labelText: l10n.storyStateFieldTitle,
                hintText: switch (widget.kind) {
                  StoryStateKind.character => l10n.storyStateTitleHintCharacter,
                  StoryStateKind.foreshadow =>
                    l10n.storyStateTitleHintForeshadow,
                  StoryStateKind.timeline => l10n.storyStateTitleHintTimeline,
                },
                errorText: _error,
              ),
            ),
            TextField(
              controller: _detail,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: l10n.storyStateFieldDetail,
                hintText: l10n.storyStateDetailHint,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _chapterId,
              decoration: InputDecoration(
                labelText: l10n.storyStateFieldChapter,
              ),
              items: <DropdownMenuItem<int?>>[
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text(l10n.storyStateNoChapter),
                ),
                for (var i = 0; i < widget.chapters.length; i++)
                  DropdownMenuItem<int?>(
                    value: widget.chapters[i].id,
                    child: Text(
                      '第 ${i + 1} 章 '
                      '${widget.chapters[i].title.trim().isEmpty ? '' : widget.chapters[i].title.trim()}',
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _chapterId = value),
            ),
            if (widget.kind == StoryStateKind.foreshadow) ...<Widget>[
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.storyStateClosed),
                value: _closed,
                onChanged: (value) => setState(() => _closed = value),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.commonSave)),
      ],
    );
  }
}
