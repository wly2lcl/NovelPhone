import 'package:flutter/material.dart';

import '../../core/ai/chapter_intent.dart';
import '../../l10n/l10n.dart';

/// 编辑本章写作目标（ENH-51）。
///
/// 返回 null 表示取消；返回空目标表示清空。数据落库由调用方负责，
/// 便于复用同一弹窗而不把仓库依赖带进 UI。
Future<ChapterIntent?> showChapterIntentDialog(
  BuildContext context, {
  required ChapterIntent initial,
  String outlineSummary = '',
  List<String> openForeshadows = const <String>[],
}) {
  return showDialog<ChapterIntent>(
    context: context,
    builder: (_) => _ChapterIntentDialog(
      initial: initial,
      outlineSummary: outlineSummary.trim(),
      openForeshadows: openForeshadows,
    ),
  );
}

class _ChapterIntentDialog extends StatefulWidget {
  const _ChapterIntentDialog({
    required this.initial,
    required this.outlineSummary,
    required this.openForeshadows,
  });

  final ChapterIntent initial;
  final String outlineSummary;
  final List<String> openForeshadows;

  @override
  State<_ChapterIntentDialog> createState() => _ChapterIntentDialogState();
}

class _ChapterIntentDialogState extends State<_ChapterIntentDialog> {
  late final TextEditingController _goal = TextEditingController(
    text: widget.initial.goal,
  );
  late final TextEditingController _beats = TextEditingController(
    text: widget.initial.beats.join('\n'),
  );
  late final TextEditingController _avoid = TextEditingController(
    text: widget.initial.avoid.join('\n'),
  );
  String? _beatsError;
  String? _avoidError;

  @override
  void dispose() {
    _goal.dispose();
    _beats.dispose();
    _avoid.dispose();
    super.dispose();
  }

  void _fillOutline() {
    final summary = widget.outlineSummary;
    if (summary.isEmpty) {
      _notice(context.l10n.chapterIntentOutlineEmpty);
      return;
    }
    _goal.text = _clip(summary, ChapterIntent.maxGoalChars);
    _goal.selection = TextSelection.collapsed(offset: _goal.text.length);
  }

  void _fillForeshadows() {
    if (widget.openForeshadows.isEmpty) {
      _notice(context.l10n.chapterIntentNoForeshadows);
      return;
    }
    final lines = _lines(_beats.text);
    var added = 0;
    for (final title in widget.openForeshadows) {
      if (lines.length >= ChapterIntent.maxBeats) break;
      final item = '回收伏笔：$title';
      if (lines.contains(item)) continue;
      lines.add(item);
      added++;
    }
    if (added == 0) return;
    _beats.text = lines.join('\n');
    _beats.selection = TextSelection.collapsed(offset: _beats.text.length);
    if (lines.length >= ChapterIntent.maxBeats) {
      _notice(context.l10n.chapterIntentLimitBeats);
    }
  }

  void _clear() {
    _goal.clear();
    _beats.clear();
    _avoid.clear();
    setState(() {
      _beatsError = null;
      _avoidError = null;
    });
  }

  void _save() {
    final beatCount = _lines(_beats.text).length;
    final avoidCount = _lines(_avoid.text).length;
    setState(() {
      _beatsError = beatCount > ChapterIntent.maxBeats
          ? context.l10n.chapterIntentLimitBeats
          : null;
      _avoidError = avoidCount > ChapterIntent.maxAvoid
          ? context.l10n.chapterIntentLimitAvoid
          : null;
    });
    if (_beatsError != null || _avoidError != null) return;
    Navigator.of(context).pop(
      ChapterIntent(
        goal: _clip(_goal.text.trim(), ChapterIntent.maxGoalChars),
        beats: splitIntentLines(
          _beats.text,
          maxCount: ChapterIntent.maxBeats,
          maxChars: ChapterIntent.maxBeatChars,
        ),
        avoid: splitIntentLines(
          _avoid.text,
          maxCount: ChapterIntent.maxAvoid,
          maxChars: ChapterIntent.maxAvoidChars,
        ),
      ),
    );
  }

  void _notice(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  static List<String> _lines(String text) => text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  static String _clip(String text, int max) {
    if (text.runes.length <= max) return text;
    return String.fromCharCodes(text.runes.take(max));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.chapterIntentTitle),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.chapterIntentHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _goal,
                maxLength: ChapterIntent.maxGoalChars,
                maxLines: 2,
                minLines: 1,
                decoration: InputDecoration(
                  labelText: l10n.chapterIntentGoalLabel,
                  hintText: l10n.chapterIntentGoalHint,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _beats,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: l10n.chapterIntentBeatsLabel,
                  hintText: l10n.chapterIntentBeatsHint,
                  errorText: _beatsError,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _avoid,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l10n.chapterIntentAvoidLabel,
                  hintText: l10n.chapterIntentAvoidHint,
                  errorText: _avoidError,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  TextButton(
                    onPressed: _fillOutline,
                    child: Text(l10n.chapterIntentFillOutline),
                  ),
                  TextButton(
                    onPressed: _fillForeshadows,
                    child: Text(l10n.chapterIntentFillForeshadows),
                  ),
                  TextButton(
                    onPressed: _clear,
                    child: Text(l10n.chapterIntentClear),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.commonSave)),
      ],
    );
  }
}
