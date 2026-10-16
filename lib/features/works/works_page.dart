import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/formatting.dart';
import '../../core/word_count.dart';
import '../../data/data_providers.dart';
import '../../data/db.dart';
import '../../models/work_cover_colors.dart';
import 'works_providers.dart';

/// 作品列表页（PRD 5.1）：卡片列表、置顶、删除二次确认、空状态引导。
class WorksPage extends ConsumerWidget {
  const WorksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worksAsync = ref.watch(worksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('NovelPhone'),
        actions: <Widget>[
          IconButton(
            tooltip: '全局搜索',
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.tune),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: '新建作品',
        onPressed: () => context.push('/new-work'),
        child: const Icon(Icons.add),
      ),
      body: worksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('读取作品失败：$error')),
        data: (works) {
          if (works.isEmpty) return const _EmptyWorks();
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: works.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _WorkCard(work: works[index]),
          );
        },
      ),
    );
  }
}

class _EmptyWorks extends StatelessWidget {
  const _EmptyWorks();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.menu_book_outlined,
            size: 72,
            color: context.paper.inkSoft,
          ),
          const SizedBox(height: 16),
          Text('还没有作品', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            '把脑中的故事写下来，从第一部作品开始。',
            style: TextStyle(color: context.paper.inkSoft),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.push('/new-work'),
            icon: const Icon(Icons.add),
            label: const Text('创建第一部作品'),
          ),
        ],
      ),
    );
  }
}

class _WorkCard extends ConsumerWidget {
  const _WorkCard({required this.work});

  final Work work;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: context.paper.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/work/${work.id}'),
        onLongPress: () => _showActions(context, ref, work),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _CoverBlock(work: work),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        if (work.pinned) ...<Widget>[
                          Icon(
                            Icons.push_pin,
                            size: 15,
                            color: context.paper.accent,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            work.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${formatWordCount(work.wordCount)} · ${work.chapterCount} 章',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.paper.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '最后编辑 ${formatRelativeTime(work.lastEditedAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.paper.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showActions(
    BuildContext context,
    WidgetRef ref,
    Work work,
  ) async {
    final repository = ref.read(workRepositoryProvider);
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: Icon(
                work.pinned ? Icons.push_pin_outlined : Icons.push_pin,
              ),
              title: Text(work.pinned ? '取消置顶' : '置顶'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await repository.setPinned(work.id, !work.pinned);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Color(0xFFB3261E),
              ),
              title: const Text(
                '删除作品',
                style: TextStyle(color: Color(0xFFB3261E)),
              ),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await _confirmDelete(context, ref, work);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Work work,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('删除《${work.title}》？'),
        content: const Text('该作品的全部章节、角色卡与章纲会一并删除，此操作不可恢复。'),
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
    if (confirmed != true || !context.mounted) return;
    await ref.read(workRepositoryProvider).deleteWork(work.id);
  }
}

class _CoverBlock extends StatelessWidget {
  const _CoverBlock({required this.work});

  final Work work;

  @override
  Widget build(BuildContext context) {
    final color = WorkCoverColors.of(work.coverColor);
    return Container(
      width: 54,
      height: 70,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        work.title.characters.first,
        style: const TextStyle(
          fontSize: 26,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
