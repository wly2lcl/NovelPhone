import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/ai/structured_response.dart';
import '../../l10n/l10n.dart';

/// 报告对话框的后续动作（ENH-38）。
enum ContinuityReportAction { locate, revise, recheck }

class ContinuityReportSelection {
  const ContinuityReportSelection(this.action, [this.issue]);

  final ContinuityReportAction action;
  final ContinuityIssue? issue;
}

/// 结构化一致性检查报告（ENH-38）：每条冲突可定位原文或生成修订，并可重新检查。
Future<ContinuityReportSelection?> showContinuityReportDialog(
  BuildContext context, {
  required ContinuityCheckResult check,
  required String rawText,
  required bool truncated,
  bool stopped = false,
}) {
  return showDialog<ContinuityReportSelection>(
    context: context,
    builder: (dialogContext) => _ContinuityReportDialog(
      check: check,
      rawText: rawText,
      truncated: truncated,
      stopped: stopped,
    ),
  );
}

class _ContinuityReportDialog extends StatelessWidget {
  const _ContinuityReportDialog({
    required this.check,
    required this.rawText,
    required this.truncated,
    required this.stopped,
  });

  final ContinuityCheckResult check;
  final String rawText;
  final bool truncated;
  final bool stopped;

  void _select(
    BuildContext context,
    ContinuityReportAction action, [
    ContinuityIssue? issue,
  ]) {
    Navigator.of(context).pop(ContinuityReportSelection(action, issue));
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
  });

  final int index;
  final ContinuityIssue issue;
  final VoidCallback onLocate;
  final VoidCallback onRevise;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
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
            ],
          ),
        ],
      ),
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
