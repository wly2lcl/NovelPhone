import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/data_providers.dart';
import '../../l10n/l10n.dart';

/// AI 功能首次联网前的告知（M4-16，COMPLIANCE §3）。
///
/// 返回 true 表示已确认（或此前已确认过），调用方可以继续发起联网请求；
/// 返回 false 表示用户取消，调用方应中止本次 AI 操作。
Future<bool> ensureAiNotice(BuildContext context, WidgetRef ref) async {
  final settings = ref.read(settingsRepositoryProvider);
  if (await settings.hasConfirmedAiNotice()) return true;
  if (!context.mounted) return false;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(dialogContext.l10n.aiNoticeTitle),
      content: Text(dialogContext.l10n.aiNoticeBody),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(dialogContext.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(dialogContext.l10n.aiNoticeConfirm),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  await settings.confirmAiNotice();
  return true;
}
