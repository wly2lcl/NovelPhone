import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/exporter/backup_archive.dart';
import '../../core/exporter/share_export.dart';
import '../../core/formatting.dart';
import '../../data/data_providers.dart';
import '../../l10n/error_text.dart';
import '../../l10n/l10n.dart';

/// 备份文件名前缀（M2-10）。
const String kBackupFilePrefix = 'novelphone_backup';

/// 导出整库备份（M2-10）：全部表数据 JSON + 各作品 markdown 全文，经系统分享保存。
Future<void> exportBackup(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  try {
    final repository = ref.read(backupRepositoryProvider);
    final bytes = await exportBackupZipBytes(repository);
    final stamp = DateTime.now()
        .toIso8601String()
        .substring(0, 19)
        .replaceAll(RegExp(r'[:\-T]'), '');
    if (!context.mounted) return;
    await shareExport(
      fileName: '${kBackupFilePrefix}_$stamp.zip',
      bytes: bytes,
      title: l10n.backupShareTitle,
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(backupErrorText(l10n, e))));
  }
}

/// 从备份文件恢复（M2-11）：选 zip → 校验/预览 → 选择合并/覆盖 → 执行并报告结果。
Future<void> restoreBackup(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final ParsedBackup parsed;
  try {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const <String>['zip'],
    );
    if (file == null) return;
    // ENH-15：解压 + jsonDecode 放到 isolate，避免恢复大备份时卡住 UI。
    // ENH-22：同时校验 manifest 中的 SHA-256，并在恢复前展示预览。
    parsed = await inspectBackupZipAsync(await file.readAsBytes());
  } on FormatException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(backupErrorText(l10n, e))));
    return;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(backupErrorText(l10n, e))));
    return;
  }

  if (!context.mounted) return;
  if (!await showBackupPreviewDialog(context, parsed.preview)) return;
  if (!context.mounted) return;
  final overwrite = await pickRestoreMode(context);
  if (overwrite == null) return;

  try {
    final report = await ref
        .read(backupRepositoryProvider)
        .restore(parsed.data, overwrite: overwrite);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          l10n.backupRestoreDone(
            report.works,
            report.chapters,
            report.characters,
          ),
        ),
      ),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(backupErrorText(l10n, e))));
  }
}

/// 恢复前预览（ENH-22）：展示导出时间、数据版本、作品/章节/角色数量与
/// SHA-256 校验结果，确认后才进入恢复方式选择。
Future<bool> showBackupPreviewDialog(
  BuildContext context,
  BackupPreview preview,
) async {
  final l10n = context.l10n;
  final exportedAt = preview.exportedAt;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final paper = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Text(l10n.backupPreviewTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (exportedAt != null)
              Text(
                l10n.backupPreviewExportedAt(
                  formatRelativeTime(exportedAt, l10n),
                ),
              ),
            if (preview.schemaVersion != null)
              Text(l10n.backupPreviewSchema(preview.schemaVersion!)),
            const SizedBox(height: 4),
            Text(
              l10n.backupPreviewCounts(
                preview.works,
                preview.chapters,
                preview.characters,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Icon(
                  preview.checksumVerified
                      ? Icons.verified_outlined
                      : Icons.info_outline,
                  size: 18,
                  color: preview.checksumVerified
                      ? paper.primary
                      : paper.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    preview.checksumVerified
                        ? l10n.backupPreviewChecksumOk
                        : l10n.backupPreviewChecksumLegacy,
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.backupPreviewContinue),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}

/// 恢复方式二选一（PRD 功能 12）：合并为新增作品 / 覆盖并清空本地。
/// 本地文件恢复与云端恢复共用。
Future<bool?> pickRestoreMode(BuildContext context) {
  final l10n = context.l10n;
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.backupRestoreModeTitle),
      content: Text(l10n.backupRestoreModeBody),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.backupRestoreModeMerge),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.backupRestoreModeOverwrite),
        ),
      ],
    ),
  );
}
