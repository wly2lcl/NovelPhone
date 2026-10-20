import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/l10n.dart';

/// 跨候选段落组合（ENH-36）：逐段从多路候选中挑选，返回按段序拼接的正文。
/// 取消返回 null。
Future<String?> showCandidateMergeDialog(
  BuildContext context, {
  required List<String> candidates,
  int selectedIndex = 0,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _CandidateMergeDialog(
      candidates: candidates,
      selectedIndex: selectedIndex,
    ),
  );
}

List<String> _paragraphsOf(String text) => text
    .split('\n')
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty)
    .toList(growable: false);

class _CandidateMergeDialog extends StatefulWidget {
  const _CandidateMergeDialog({
    required this.candidates,
    required this.selectedIndex,
  });

  final List<String> candidates;
  final int selectedIndex;

  @override
  State<_CandidateMergeDialog> createState() => _CandidateMergeDialogState();
}

class _CandidateMergeDialogState extends State<_CandidateMergeDialog> {
  late final List<List<String>> _paragraphs;
  late final List<int> _choices;

  @override
  void initState() {
    super.initState();
    _paragraphs = <List<String>>[
      for (final candidate in widget.candidates) _paragraphsOf(candidate),
    ];
    var slots = 0;
    for (final paragraphs in _paragraphs) {
      if (paragraphs.length > slots) slots = paragraphs.length;
    }
    _choices = <int>[
      for (var slot = 0; slot < slots; slot++)
        if (_options(slot).contains(widget.selectedIndex))
          widget.selectedIndex
        else
          _options(slot).first,
    ];
  }

  List<int> _options(int slot) => <int>[
    for (var i = 0; i < _paragraphs.length; i++)
      if (slot < _paragraphs[i].length) i,
  ];

  int get _selectedCount => _choices.length;

  String _merged() => <String>[
    for (var slot = 0; slot < _choices.length; slot++)
      _paragraphs[_choices[slot]][slot],
  ].join('\n');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.candidateMixTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.candidateMixIntro,
              style: TextStyle(fontSize: 12, color: context.paper.inkSoft),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.5,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _choices.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: _buildSlot,
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
              : () => Navigator.of(context).pop(_merged()),
          child: Text(l10n.candidateMixApply(_selectedCount)),
        ),
      ],
    );
  }

  Widget _buildSlot(BuildContext context, int slot) {
    final l10n = context.l10n;
    final options = _options(slot);
    final text = _paragraphs[_choices[slot]][slot];
    return Container(
      key: ValueKey<String>('mix-slot-$slot'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.paper.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.candidateMixSlot(slot + 1),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          if (options.length > 1) ...<Widget>[
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<int>(
                segments: <ButtonSegment<int>>[
                  for (final index in options)
                    ButtonSegment<int>(
                      value: index,
                      label: Text(
                        l10n.candidateMixCandidate(index + 1),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
                selected: <int>{_choices[slot]},
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                onSelectionChanged: (selection) =>
                    setState(() => _choices[slot] = selection.first),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            text,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: context.paper.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}
