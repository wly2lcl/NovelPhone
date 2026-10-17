import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/formatting.dart';
import '../../core/word_count.dart';
import '../../data/data_providers.dart';
import '../../data/db.dart';
import '../../data/repositories/trash_repository.dart';
import '../../l10n/l10n.dart';

/// 回收站（ENH-22）：恢复或永久删除软删除的作品与章节。
/// 内容保留 30 天，打开本页与启动应用时都会清理过期条目。
class TrashPage extends ConsumerStatefulWidget {
  const TrashPage({super.key});

  @override
  ConsumerState<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends ConsumerState<TrashPage> {
  List<Work>? _works;
  List<TrashedChapter>? _chapters;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repository = ref.read(trashRepositoryProvider);
    await repository.purgeExpired();
    final works = await repository.listWorks();
    final chapters = await repository.listChapters();
    if (!mounted) return;
    setState(() {
      _works = works;
      _chapters = chapters;
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _restoreWork(Work work) async {
    await ref.read(trashRepositoryProvider).restoreWork(work.id);
    await _load();
    if (!mounted) return;
    _showSnack(context.l10n.trashRestored(work.title));
  }

  Future<void> _restoreChapter(TrashedChapter item) async {
    await ref.read(trashRepositoryProvider).restoreChapter(item.chapter.id);
    await _load();
    if (!mounted) return;
    final title = item.chapter.title.isEmpty
        ? context.l10n.commonUntitledChapter
        : item.chapter.title;
    _showSnack(context.l10n.trashRestored(title));
  }

  Future<void> _purgeWork(Work work) async {
    final confirmed = await _confirmPurge(
      context.l10n.trashPurgeTitle(work.title),
      context.l10n.trashPurgeWorkBody,
    );
    if (confirmed != true) return;
    await ref.read(trashRepositoryProvider).purgeWork(work.id);
    await _load();
    if (!mounted) return;
    _showSnack(context.l10n.trashPurged);
  }

  Future<void> _purgeChapter(TrashedChapter item) async {
    final title = item.chapter.title.isEmpty
        ? context.l10n.commonUntitledChapter
        : item.chapter.title;
    final confirmed = await _confirmPurge(
      context.l10n.trashPurgeTitle(title),
      context.l10n.trashPurgeChapterBody,
    );
    if (confirmed != true) return;
    await ref.read(trashRepositoryProvider).purgeChapter(item.chapter.id);
    await _load();
    if (!mounted) return;
    _showSnack(context.l10n.trashPurged);
  }

  Future<bool?> _confirmPurge(String title, String body) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.trashDeleteForever),
          ),
        ],
      ),
    );
  }

  Future<void> _emptyTrash() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.trashEmptyConfirmTitle),
        content: Text(context.l10n.trashEmptyConfirmBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.trashEmptyAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(trashRepositoryProvider).empty();
    await _load();
    if (!mounted) return;
    _showSnack(context.l10n.trashEmptyDone);
  }

  @override
  Widget build(BuildContext context) {
    final works = _works;
    final chapters = _chapters;
    final l10n = context.l10n;
    final isEmpty =
        works != null && chapters != null && works.isEmpty && chapters.isEmpty;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.trashTitle),
          actions: <Widget>[
            IconButton(
              tooltip: l10n.trashEmptyAction,
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: isEmpty ? null : _emptyTrash,
            ),
          ],
          bottom: TabBar(
            tabs: <Widget>[
              Tab(text: l10n.trashTabWorks),
              Tab(text: l10n.trashTabChapters),
            ],
          ),
        ),
        body: works == null || chapters == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: <Widget>[
                  _RetentionHint(text: l10n.trashHint),
                  Expanded(
                    child: TabBarView(
                      children: <Widget>[
                        _worksTab(works),
                        _chaptersTab(chapters),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _worksTab(List<Work> works) {
    final l10n = context.l10n;
    if (works.isEmpty) {
      return _EmptyHint(
        icon: Icons.menu_book_outlined,
        text: l10n.trashEmptyWorks,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: works.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final work = works[index];
        return ListTile(
          leading: Icon(Icons.menu_book_outlined, color: context.paper.inkSoft),
          title: Text(work.title),
          subtitle: Text(
            '${formatWordCount(work.wordCount, l10n)} · '
            '${l10n.chapterCount(work.chapterCount)}\n'
            '${l10n.trashDeletedAt(formatRelativeTime(work.deletedAt ?? work.lastEditedAt, l10n))}',
          ),
          isThreeLine: true,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                tooltip: l10n.trashRestore,
                icon: const Icon(Icons.restore),
                onPressed: () => _restoreWork(work),
              ),
              IconButton(
                tooltip: l10n.trashDeleteForever,
                icon: Icon(
                  Icons.delete_forever_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => _purgeWork(work),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chaptersTab(List<TrashedChapter> chapters) {
    final l10n = context.l10n;
    if (chapters.isEmpty) {
      return _EmptyHint(
        icon: Icons.description_outlined,
        text: l10n.trashEmptyChapters,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: chapters.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = chapters[index];
        final chapter = item.chapter;
        final title = chapter.title.isEmpty
            ? l10n.commonUntitledChapter
            : chapter.title;
        return ListTile(
          leading: Icon(
            Icons.description_outlined,
            color: context.paper.inkSoft,
          ),
          title: Text(title),
          subtitle: Text(
            '${l10n.trashChapterMeta(item.workTitle, item.volumeTitle)}\n'
            '${l10n.trashDeletedAt(formatRelativeTime(chapter.deletedAt ?? chapter.updatedAt, l10n))}',
          ),
          isThreeLine: true,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                tooltip: l10n.trashRestore,
                icon: const Icon(Icons.restore),
                onPressed: () => _restoreChapter(item),
              ),
              IconButton(
                tooltip: l10n.trashDeleteForever,
                icon: Icon(
                  Icons.delete_forever_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => _purgeChapter(item),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RetentionHint extends StatelessWidget {
  const _RetentionHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.paper.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.schedule, size: 18, color: context.paper.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 40, color: context.paper.inkSoft),
          const SizedBox(height: 12),
          Text(text, style: TextStyle(color: context.paper.inkSoft)),
        ],
      ),
    );
  }
}
