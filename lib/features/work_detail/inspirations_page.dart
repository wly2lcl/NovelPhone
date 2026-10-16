import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/formatting.dart';
import '../../data/data_providers.dart';
import '../../data/db.dart';
import 'work_detail_providers.dart';

/// 灵感箱（PRD 功能 7）：灵感片段列表，新增/编辑/删除。
/// M3 接入 AI 灵感的「存入灵感箱」。
class InspirationsPage extends ConsumerWidget {
  const InspirationsPage({super.key, required this.workId});

  final int workId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inspirations =
        ref.watch(inspirationsProvider(workId)).value ?? const <Inspiration>[];

    return Scaffold(
      appBar: AppBar(title: const Text('灵感箱')),
      body: inspirations.isEmpty
          ? const _EmptyHint()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: inspirations.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _InspirationCard(
                workId: workId,
                inspiration: inspirations[index],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openInspirationEditor(context, ref, workId: workId),
        icon: const Icon(Icons.add),
        label: const Text('记录灵感'),
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
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.lightbulb_outline,
              size: 64,
              color: context.paper.inkSoft,
            ),
            const SizedBox(height: 12),
            Text('灵感箱是空的', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              '随手记下桥段、设定或一句对白，AI 灵感产出的点子也会存到这里。',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.paper.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

class _InspirationCard extends ConsumerWidget {
  const _InspirationCard({required this.workId, required this.inspiration});

  final int workId;
  final Inspiration inspiration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openInspirationEditor(
          context,
          ref,
          workId: workId,
          inspiration: inspiration,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(inspiration.content),
                    const SizedBox(height: 6),
                    Text(
                      formatRelativeTime(inspiration.createdAt),
                      style: TextStyle(
                        color: context.paper.inkSoft,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '删除',
                icon: Icon(Icons.delete_outline, color: context.paper.inkSoft),
                onPressed: () => confirmDeleteInspiration(
                  context,
                  ref,
                  inspiration.id,
                  inspiration.content,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 新增/编辑灵感条目。
Future<void> openInspirationEditor(
  BuildContext context,
  WidgetRef ref, {
  required int workId,
  Inspiration? inspiration,
}) async {
  // 不使用外部 TextEditingController：弹窗退场动画期间 builder 会再次执行，
  // 过早 dispose 会导致「controller used after being disposed」。
  var input = inspiration?.content ?? '';
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(inspiration == null ? '记录灵感' : '编辑灵感'),
      content: TextFormField(
        initialValue: inspiration?.content ?? '',
        autofocus: true,
        maxLines: 6,
        onChanged: (value) => input = value,
        decoration: const InputDecoration(hintText: '写点什么…'),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(input.trim()),
          child: const Text('保存'),
        ),
      ],
    ),
  );
  final text = result?.trim() ?? '';
  if (result == null || text.isEmpty) return;
  final repository = ref.read(inspirationRepositoryProvider);
  if (inspiration == null) {
    await repository.createInspiration(workId, text);
  } else {
    await repository.updateInspiration(inspiration.id, text);
  }
}

/// 删除灵感条目（二次确认）。
Future<void> confirmDeleteInspiration(
  BuildContext context,
  WidgetRef ref,
  int id,
  String content,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('删除这条灵感？'),
      content: Text(content, maxLines: 4, overflow: TextOverflow.ellipsis),
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
  if (confirmed != true) return;
  await ref.read(inspirationRepositoryProvider).deleteInspiration(id);
}
