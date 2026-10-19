import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/ai/writing_preferences.dart';
import '../../l10n/l10n.dart';

/// 放弃 AI 结果时的原因采集（ENH-27）。
///
/// 返回 null = 取消（继续留在面板）；空串 = 不记录原因直接放弃；
/// 其他值 = 选中的 [AiFeedbackReason]。分段未采纳复用同一选择器（ENH-29），
/// 通过 [title] / [hint] / [confirmLabel] 覆盖文案。
Future<String?> showAiDiscardReasonDialog(
  BuildContext context, {
  String? title,
  String? hint,
  String? confirmLabel,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _AiDiscardReasonDialog(
      title: title,
      hint: hint,
      confirmLabel: confirmLabel,
    ),
  );
}

class _AiDiscardReasonDialog extends StatefulWidget {
  const _AiDiscardReasonDialog({this.title, this.hint, this.confirmLabel});

  final String? title;
  final String? hint;
  final String? confirmLabel;

  @override
  State<_AiDiscardReasonDialog> createState() => _AiDiscardReasonDialogState();
}

class _AiDiscardReasonDialogState extends State<_AiDiscardReasonDialog> {
  String _reason = AiFeedbackReason.tooAi;

  String _label(AppLocalizations l10n, String reason) {
    switch (reason) {
      case AiFeedbackReason.offCharacter:
        return l10n.aiFeedbackOffCharacter;
      case AiFeedbackReason.slowPace:
        return l10n.aiFeedbackSlowPace;
      case AiFeedbackReason.offSetting:
        return l10n.aiFeedbackOffSetting;
      case AiFeedbackReason.other:
        return l10n.aiFeedbackOther;
      case AiFeedbackReason.tooAi:
      default:
        return l10n.aiFeedbackTooAi;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.title ?? l10n.aiFeedbackTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.hint ?? l10n.aiFeedbackHint,
              style: TextStyle(fontSize: 12, color: context.paper.inkSoft),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: <Widget>[
                for (final reason in AiFeedbackReason.all)
                  ChoiceChip(
                    label: Text(_label(l10n, reason)),
                    selected: _reason == reason,
                    onSelected: (_) => setState(() => _reason = reason),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(''),
          child: Text(l10n.aiFeedbackSkip),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_reason),
          child: Text(widget.confirmLabel ?? l10n.aiFeedbackConfirm),
        ),
      ],
    );
  }
}
