import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/l10n.dart';

/// 分段采纳结果：合并后的正文 + 被取消勾选的段数（ENH-29 负反馈用）。
class AiMergeResult {
  const AiMergeResult({required this.text, required this.rejectedCount});

  final String text;
  final int rejectedCount;
}

/// 段落级采纳（ENH-27）：按段落勾选 / 修改 AI 结果，返回合并后的正文。
/// 取消返回 null；全部取消勾选时确认按钮不可用。
Future<AiMergeResult?> showAiMergeDialog(
  BuildContext context, {
  required String text,
  String? baseText,
}) {
  return showDialog<AiMergeResult>(
    context: context,
    builder: (_) => _AiMergeDialog(text: text, baseText: baseText),
  );
}

class _MergeParagraph {
  _MergeParagraph(this.controller, {required this.changed});

  final TextEditingController controller;
  final bool changed;
  bool selected = true;
}

class _AiMergeDialog extends StatefulWidget {
  const _AiMergeDialog({required this.text, this.baseText});

  final String text;
  final String? baseText;

  @override
  State<_AiMergeDialog> createState() => _AiMergeDialogState();
}

class _AiMergeDialogState extends State<_AiMergeDialog> {
  late final List<_MergeParagraph> _paragraphs;

  @override
  void initState() {
    super.initState();
    final baseLines = (widget.baseText ?? '')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toSet();
    final showChanged = baseLines.isNotEmpty;
    _paragraphs = widget.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map(
          (line) => _MergeParagraph(
            TextEditingController(text: line),
            changed: showChanged && !baseLines.contains(line),
          ),
        )
        .toList(growable: false);
  }

  @override
  void dispose() {
    for (final paragraph in _paragraphs) {
      paragraph.controller.dispose();
    }
    super.dispose();
  }

  int get _selectedCount =>
      _paragraphs.where((paragraph) => paragraph.selected).length;

  void _setAll(bool selected) {
    setState(() {
      for (final paragraph in _paragraphs) {
        paragraph.selected = selected;
      }
    });
  }

  String? _merged() {
    final lines = <String>[
      for (final paragraph in _paragraphs)
        if (paragraph.selected) paragraph.controller.text.trim(),
    ].where((line) => line.isNotEmpty).toList(growable: false);
    return lines.isEmpty ? null : lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.aiMergeTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.aiMergeHint,
              style: TextStyle(fontSize: 12, color: context.paper.inkSoft),
            ),
            Row(
              children: <Widget>[
                TextButton(
                  onPressed: () => _setAll(true),
                  child: Text(l10n.aiMergeSelectAll),
                ),
                TextButton(
                  onPressed: () => _setAll(false),
                  child: Text(l10n.aiMergeSelectNone),
                ),
                const Spacer(),
                Text(
                  l10n.aiMergeSelected(_selectedCount, _paragraphs.length),
                  style: TextStyle(fontSize: 12, color: context.paper.inkSoft),
                ),
              ],
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.45,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _paragraphs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _buildParagraph(index, l10n),
              ),
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
          onPressed: _selectedCount == 0
              ? null
              : () {
                  final text = _merged();
                  if (text == null) return;
                  Navigator.of(context).pop(
                    AiMergeResult(
                      text: text,
                      rejectedCount: _paragraphs.length - _selectedCount,
                    ),
                  );
                },
          child: Text(l10n.aiMergeApply(_selectedCount)),
        ),
      ],
    );
  }

  Widget _buildParagraph(int index, AppLocalizations l10n) {
    final paragraph = _paragraphs[index];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Checkbox(
          value: paragraph.selected,
          onChanged: (value) =>
              setState(() => paragraph.selected = value ?? false),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (paragraph.changed)
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.paper.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    l10n.aiMergeChanged,
                    style: TextStyle(fontSize: 11, color: context.paper.accent),
                  ),
                ),
              TextField(
                controller: paragraph.controller,
                minLines: 1,
                maxLines: 5,
                style: const TextStyle(fontSize: 13, height: 1.5),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
