import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/writing_stats.dart';
import '../../l10n/l10n.dart';

/// 写作热力图（ENH-19）：近 53 周（约一年）每日写作量的日历视图。
class WritingHeatmap extends StatelessWidget {
  const WritingHeatmap({super.key, required this.wordsByDay});

  final Map<String, int> wordsByDay;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final localeName = Localizations.localeOf(context).toString();
    final weeks = heatmapWeeks(wordsByDay, now: DateTime.now());

    var maxWords = 0;
    var activeDays = 0;
    for (final column in weeks) {
      for (final cell in column) {
        if (cell == null) continue;
        if (cell.words > 0) activeDays++;
        if (cell.words > maxWords) maxWords = cell.words;
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.paper.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.grid_on_outlined,
                size: 20,
                color: context.paper.inkSoft,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.statsHeatmapTitle,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                l10n.statsHeatmapActiveDays(activeDays),
                style: TextStyle(fontSize: 12, color: context.paper.inkSoft),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            label: l10n.a11yHeatmapLabel,
            container: true,
            child: LayoutBuilder(
              builder: (context, constraints) {
                const double gap = 1.5;
                const double labelWidth = 14;
                final count = weeks.length;
                final cell =
                    ((constraints.maxWidth - labelWidth - (count - 1) * gap) /
                            count)
                        .clamp(2.5, 12.0);
                final monthLabels = _monthLabels(weeks, localeName);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(left: labelWidth),
                      child: SizedBox(
                        height: 12,
                        child: Stack(
                          children: <Widget>[
                            for (final entry in monthLabels.entries)
                              Positioned(
                                left: entry.key * (cell + gap),
                                top: 0,
                                child: Text(
                                  entry.value,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: context.paper.inkSoft,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(
                          width: labelWidth,
                          child: Column(
                            children: <Widget>[
                              for (var row = 0; row < 7; row++) ...<Widget>[
                                SizedBox(
                                  height: cell,
                                  child: (row == 0 || row == 2 || row == 4)
                                      ? Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            row == 0
                                                ? l10n.statsHeatmapWeekMon
                                                : row == 2
                                                ? l10n.statsHeatmapWeekWed
                                                : l10n.statsHeatmapWeekFri,
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: context.paper.inkSoft,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                                if (row < 6) const SizedBox(height: gap),
                              ],
                            ],
                          ),
                        ),
                        for (var w = 0; w < count; w++) ...<Widget>[
                          Column(
                            children: <Widget>[
                              for (var row = 0; row < 7; row++) ...<Widget>[
                                _cell(
                                  context,
                                  key: ValueKey<String>('heat-cell-$w-$row'),
                                  size: cell,
                                  level: weeks[w][row] == null
                                      ? null
                                      : _levelOf(
                                          weeks[w][row]!.words,
                                          maxWords,
                                        ),
                                ),
                                if (row < 6) const SizedBox(height: gap),
                              ],
                            ],
                          ),
                          if (w < count - 1) const SizedBox(width: gap),
                        ],
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Text(
                l10n.statsHeatmapLess,
                style: TextStyle(fontSize: 11, color: context.paper.inkSoft),
              ),
              const SizedBox(width: 6),
              for (var level = 0; level <= 4; level++) ...<Widget>[
                _cell(context, size: 10, level: level),
                if (level < 4) const SizedBox(width: 3),
              ],
              const SizedBox(width: 6),
              Text(
                l10n.statsHeatmapMore,
                style: TextStyle(fontSize: 11, color: context.paper.inkSoft),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _cell(
  BuildContext context, {
  Key? key,
  required double size,
  int? level,
}) {
  return Container(
    key: key,
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: level == null ? Colors.transparent : _levelColor(context, level),
      borderRadius: BorderRadius.circular(size >= 6 ? 2 : 1),
    ),
  );
}

/// 字数相对区间峰值分为 0~4 级（0 = 当天无写作）。
int _levelOf(int words, int maxWords) {
  if (words <= 0) return 0;
  if (maxWords <= 0) return 4;
  final ratio = words / maxWords;
  if (ratio <= 0.25) return 1;
  if (ratio <= 0.5) return 2;
  if (ratio <= 0.75) return 3;
  return 4;
}

Color _levelColor(BuildContext context, int level) {
  switch (level) {
    case 1:
      return context.paper.accent.withValues(alpha: 0.25);
    case 2:
      return context.paper.accent.withValues(alpha: 0.5);
    case 3:
      return context.paper.accent.withValues(alpha: 0.72);
    case 4:
      return context.paper.accent;
    default:
      return context.paper.divider;
  }
}

/// 月份标签：列首取该列第一个有效格子的月份，与上一列月份不同时标注（首列不标注）。
Map<int, String> _monthLabels(List<List<DayWords?>> weeks, String localeName) {
  final labels = <int, String>{};
  var lastMonth = 0;
  final format = DateFormat.MMM(localeName);
  for (var i = 0; i < weeks.length; i++) {
    DayWords? first;
    for (final cell in weeks[i]) {
      if (cell != null) {
        first = cell;
        break;
      }
    }
    if (first == null) continue;
    final date = DateTime.parse(first.day);
    if (date.month != lastMonth) {
      if (i > 0) labels[i] = format.format(date);
      lastMonth = date.month;
    }
  }
  return labels;
}
