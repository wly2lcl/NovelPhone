import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/ai/structured_response.dart';
import '../../l10n/l10n.dart';

/// 报告对话框的后续动作（ENH-38 / ENH-41）。
enum ContinuityReportAction { locate, revise, ignore, recheck }

class ContinuityReportSelection {
  const ContinuityReportSelection(this.action, [this.issue, this.reason = '']);

  final ContinuityReportAction action;
  final ContinuityIssue? issue;

  /// 忽略时作者填写的保留原因（可选）。
  final String reason;
}

/// 结构化一致性检查报告（ENH-38）：每条冲突可定位原文或生成修订，并可重新检查；
/// 作者确认有意保留的差异可忽略，后续检查不再报告（ENH-41）。
Future<ContinuityReportSelection?> showContinuityReportDialog(
  BuildContext context, {
  required ContinuityCheckResult check,
  required String rawText,
  required bool truncated,
  bool stopped = false,
  int ignoredCount = 0,
}) {
  return showDialog<ContinuityReportSelection>(
    context: context,
    builder: (dialogContext) => _ContinuityReportDialog(
      check: check,
      rawText: rawText,
      truncated: truncated,
      stopped: stopped,
      ignoredCount: ignoredCount,
    ),
  );
}

/// 忽略冲突时收集保留原因（ENH-41）；取消返回 null，直接忽略返回空串。
Future<String?> promptContinuityIgnoreReason(
  BuildContext context,
  ContinuityIssue issue,
) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => _IgnoreIssueDialog(issue: issue),
  );
}

class _ContinuityReportDialog extends StatelessWidget {
  const _ContinuityReportDialog({
    required this.check,
    required this.rawText,
    required this.truncated,
    required this.stopped,
    required this.ignoredCount,
  });

  final ContinuityCheckResult check;
  final String rawText;
  final bool truncated;
  final bool stopped;
  final int ignoredCount;

  void _select(
    BuildContext context,
    ContinuityReportAction action, [
    ContinuityIssue? issue,
    String reason = '',
  ]) {
    Navigator.of(context).pop(ContinuityReportSelection(action, issue, reason));
  }

  Future<void> _ignore(BuildContext context, ContinuityIssue issue) async {
    final reason = await promptContinuityIgnoreReason(context, issue);
    if (reason == null || !context.mounted) return;
    _select(context, ContinuityReportAction.ignore, issue, reason);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.editorContinuityTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.58,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (stopped) ...<Widget>[
                  _Hint(text: l10n.editorContinuityStopped),
                  const SizedBox(height: 10),
                ],
                if (truncated) ...<Widget>[
                  _Hint(text: l10n.editorContinuityTruncated),
                  const SizedBox(height: 10),
                ],
                if (ignoredCount > 0) ...<Widget>[
                  _Hint(text: l10n.continuityIgnoredCount(ignoredCount)),
                  const SizedBox(height: 10),
                ],
                if (check.parseFailed) ...<Widget>[
                  _Hint(text: l10n.continuityIssueParseFallback),
                  const SizedBox(height: 10),
                  SelectableText(rawText),
                ] else ...<Widget>[
                  if (check.summary.isNotEmpty)
                    SelectableText(
                      check.summary,
                      style: TextStyle(
                        color: context.paper.ink,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                  if (check.issues.isEmpty) ...<Widget>[
                    if (check.summary.isEmpty)
                      Text(
                        l10n.continuityNoIssues,
                        style: TextStyle(color: context.paper.inkSoft),
                      ),
                  ] else ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      l10n.continuityIssueCount(check.issues.length),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.paper.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < check.issues.length; i++)
                      _IssueCard(
                        index: i + 1,
                        issue: check.issues[i],
                        onLocate: () => _select(
                          context,
                          ContinuityReportAction.locate,
                          check.issues[i],
                        ),
                        onRevise: () => _select(
                          context,
                          ContinuityReportAction.revise,
                          check.issues[i],
                        ),
                        onIgnore: () => _ignore(context, check.issues[i]),
                      ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => _select(context, ContinuityReportAction.recheck),
          child: Text(l10n.continuityIssueRecheck),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }
}

class _IssueCard extends StatelessWidget {
  const _IssueCard({
    required this.index,
    required this.issue,
    required this.onLocate,
    required this.onRevise,
    required this.onIgnore,
  });

  final int index;
  final ContinuityIssue issue;
  final VoidCallback onLocate;
  final VoidCallback onRevise;
  final VoidCallback onIgnore;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final severityLabel = switch (issue.severity) {
      'high' => l10n.continuitySeverityHigh,
      'low' => l10n.continuitySeverityLow,
      _ => l10n.continuitySeverityMedium,
    };
    final severityColor = switch (issue.severity) {
      'high' => const Color(0xFFB3261E),
      'low' => context.paper.inkSoft,
      _ => const Color(0xFFA15C00),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
        color: context.paper.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.paper.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  severityLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: severityColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '#$index',
                style: TextStyle(fontSize: 11, color: context.paper.inkSoft),
              ),
            ],
          ),
          if (issue.quote.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            SelectableText(
              '「${issue.quote}」',
              style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4),
            ),
          ],
          if (issue.detail.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              l10n.continuityIssueDetail(issue.detail),
              style: TextStyle(
                fontSize: 12,
                color: context.paper.inkSoft,
                height: 1.4,
              ),
            ),
          ],
          if (issue.source.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              l10n.continuityIssueSource(issue.source),
              style: TextStyle(fontSize: 12, color: context.paper.inkSoft),
            ),
          ],
          if (issue.suggestion.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              l10n.continuityIssueSuggestion(issue.suggestion),
              style: TextStyle(
                fontSize: 12,
                color: context.paper.ink,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 2),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 2,
            children: <Widget>[
              if (issue.quote.isNotEmpty)
                TextButton.icon(
                  onPressed: onLocate,
                  icon: const Icon(Icons.my_location_outlined, size: 16),
                  label: Text(l10n.continuityIssueLocate),
                ),
              TextButton.icon(
                onPressed: onRevise,
                icon: const Icon(Icons.auto_fix_high_outlined, size: 16),
                label: Text(l10n.continuityIssueRevise),
              ),
              TextButton.icon(
                onPressed: onIgnore,
                icon: const Icon(Icons.visibility_off_outlined, size: 16),
                label: Text(l10n.continuityIssueIgnore),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IgnoreIssueDialog extends StatefulWidget {
  const _IgnoreIssueDialog({required this.issue});

  final ContinuityIssue issue;

  @override
  State<_IgnoreIssueDialog> createState() => _IgnoreIssueDialogState();
}

class _IgnoreIssueDialogState extends State<_IgnoreIssueDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _fill(String value) {
    setState(() {
      _controller.text = value;
      _controller.selection = TextSelection.collapsed(offset: value.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.continuityIgnoreTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.continuityIgnoreBody,
              style: TextStyle(
                fontSize: 12,
                color: context.paper.inkSoft,
                height: 1.5,
              ),
            ),
            if (widget.issue.quote.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                '「${widget.issue.quote}」',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLength: 80,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: l10n.continuityIgnoreReasonLabel,
                hintText: l10n.continuityIgnoreReasonHint,
                border: const OutlineInputBorder(),
              ),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 2,
              children: <Widget>[
                for (final label in <String>[
                  l10n.continuityIgnoreReasonIntentional,
                  l10n.continuityIgnoreReasonLater,
                  l10n.continuityIgnoreReasonFalsePositive,
                ])
                  ActionChip(label: Text(label), onPressed: () => _fill(label)),
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
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(l10n.continuityIgnoreConfirm),
        ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: 12, color: context.paper.inkSoft, height: 1.4),
    );
  }
}
