import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/data_providers.dart';
import '../../l10n/l10n.dart';

/// 月度 AI 预算编辑（ENH-24）：留空或 0 表示不限制。
Future<bool> showMonthlyBudgetDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final repository = ref.read(settingsRepositoryProvider);
  final current = await repository.monthlyBudget();
  if (!context.mounted) return false;
  final controller = TextEditingController(
    text: current <= 0 ? '' : current.toStringAsFixed(2),
  );
  String? errorText;
  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: Text(dialogContext.l10n.tokenStatsBudgetDialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(dialogContext.l10n.tokenStatsBudgetDialogBody),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: dialogContext.l10n.tokenStatsBudgetField,
                border: const OutlineInputBorder(),
                errorText: errorText,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () async {
              final text = controller.text.trim();
              final value = text.isEmpty ? 0.0 : double.tryParse(text);
              if (value == null || !value.isFinite || value < 0) {
                setState(
                  () => errorText = dialogContext.l10n.tokenStatsBudgetInvalid,
                );
                return;
              }
              await repository.setMonthlyBudget(value);
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop(true);
              }
            },
            child: Text(dialogContext.l10n.commonSave),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.tokenStatsBudgetSaved)));
  }
  return saved == true;
}
