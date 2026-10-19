import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/text_diff.dart';
import '../../l10n/l10n.dart';

/// 快照对比弹窗（ENH-18）：行级增删着色 + 大段未改动折叠。
Future<void> showSnapshotDiffDialog(
  BuildContext context, {
  required String oldText,
  required String newText,
  String? title,
}) async {
  final lines = diffParagraphs(oldText, newText);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final l10n = dialogContext.l10n;
      return Dialog(
        child: SizedBox(
          width: 640,
          height: 440,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 8, 0),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        title ?? l10n.snapshotDiffTitle,
                        style: Theme.of(dialogContext).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.commonClose,
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                  child: _SnapshotDiffBody(lines: lines),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _SnapshotDiffBody extends StatelessWidget {
  const _SnapshotDiffBody({required this.lines});

  final List<DiffLine> lines;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final added = lines.where((l) => l.kind == DiffKind.added).length;
    final removed = lines.where((l) => l.kind == DiffKind.removed).length;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final addedColor = isDark
        ? const Color(0xFF81C784)
        : const Color(0xFF2E7D32);
    final removedColor = isDark
        ? const Color(0xFFE57373)
        : const Color(0xFFB3261E);

    if (added == 0 && removed == 0) {
      return SizedBox(
        height: 80,
        child: Center(
          child: Text(
            l10n.snapshotDiffNoChanges,
            style: TextStyle(color: context.paper.inkSoft),
          ),
        ),
      );
    }

    final rows = _buildRows(lines);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: <Widget>[
              if (added > 0)
                _CountChip(
                  label: l10n.snapshotDiffAdded(added),
                  color: addedColor,
                ),
              if (added > 0 && removed > 0) const SizedBox(width: 8),
              if (removed > 0)
                _CountChip(
                  label: l10n.snapshotDiffRemoved(removed),
                  color: removedColor,
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) => _buildRow(
              context,
              rows[index],
              addedColor: addedColor,
              removedColor: removedColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(
    BuildContext context,
    Object row, {
    required Color addedColor,
    required Color removedColor,
  }) {
    if (row is int) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Text(
            context.l10n.snapshotDiffHidden(row),
            style: TextStyle(fontSize: 12, color: context.paper.inkSoft),
          ),
        ),
      );
    }
    final line = row as DiffLine;
    final (Color color, String marker) = switch (line.kind) {
      DiffKind.added => (addedColor, '+'),
      DiffKind.removed => (removedColor, '−'),
      DiffKind.same => (context.paper.inkSoft, ' '),
    };
    return Container(
      color: line.kind == DiffKind.same ? null : color.withValues(alpha: 0.10),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 16,
            child: Text(
              marker,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                height: 1.5,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              line.text.isEmpty ? ' ' : line.text,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: line.kind == DiffKind.same
                    ? context.paper.inkSoft
                    : context.paper.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 连续未改动超过 8 行时只保留首尾各 3 行，中间折叠为计数标记。
  static List<Object> _buildRows(List<DiffLine> lines) {
    final rows = <Object>[];
    var i = 0;
    while (i < lines.length) {
      if (lines[i].kind != DiffKind.same) {
        rows.add(lines[i]);
        i++;
        continue;
      }
      var j = i;
      while (j < lines.length && lines[j].kind == DiffKind.same) {
        j++;
      }
      final run = j - i;
      if (run > 8) {
        rows
          ..add(lines[i])
          ..add(lines[i + 1])
          ..add(lines[i + 2])
          ..add(run - 6)
          ..add(lines[j - 3])
          ..add(lines[j - 2])
          ..add(lines[j - 1]);
      } else {
        for (var k = i; k < j; k++) {
          rows.add(lines[k]);
        }
      }
      i = j;
    }
    return rows;
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: color)),
    );
  }
}
