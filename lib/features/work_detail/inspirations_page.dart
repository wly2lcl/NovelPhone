import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/formatting.dart';
import '../../data/data_providers.dart';
import '../../data/db.dart';
import '../../l10n/l10n.dart';
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
      appBar: AppBar(title: Text(context.l10n.workDetailInspirationsTitle)),
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
        label: Text(context.l10n.workDetailRecordInspiration),
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
            Text(
              context.l10n.workDetailInspirationsEmpty,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.workDetailInspirationsEmptyHint,
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
                      formatRelativeTime(inspiration.createdAt, context.l10n),
                      style: TextStyle(
                        color: context.paper.inkSoft,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: context.l10n.commonDelete,
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
      title: Text(
        inspiration == null
            ? dialogContext.l10n.workDetailRecordInspiration
            : dialogContext.l10n.workDetailEditInspiration,
      ),
      content: TextFormField(
        initialValue: inspiration?.content ?? '',
        autofocus: true,
        maxLines: 6,
        onChanged: (value) => input = value,
        decoration: InputDecoration(
          hintText: dialogContext.l10n.workDetailInspirationHint,
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(dialogContext.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(input.trim()),
          child: Text(dialogContext.l10n.commonSave),
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
      title: Text(dialogContext.l10n.workDetailDeleteInspirationConfirm),
      content: Text(content, maxLines: 4, overflow: TextOverflow.ellipsis),
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
  await ref.read(inspirationRepositoryProvider).deleteInspiration(id);
}
