import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/writing_stats.dart';
import '../../l10n/l10n.dart';

/// 写作趋势（ENH-18）：近 7 / 30 天每日字数柱状图。
class WordTrendChart extends StatefulWidget {
  const WordTrendChart({super.key, required this.wordsByDay});

  final Map<String, int> wordsByDay;

  @override
  State<WordTrendChart> createState() => _WordTrendChartState();
}

class _WordTrendChartState extends State<WordTrendChart> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final series = recentDayWords(widget.wordsByDay, _days);
    var total = 0;
    var max = 0;
    for (final entry in series) {
      total += entry.words;
      if (entry.words > max) max = entry.words;
    }
    final todayKey = writingDayKey(DateTime.now());

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
                Icons.insights_outlined,
                size: 20,
                color: context.paper.inkSoft,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.statsTrendTitle,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              SegmentedButton<int>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: <ButtonSegment<int>>[
                  ButtonSegment<int>(
                    value: 7,
                    label: Text(l10n.statsTrendRange7),
                  ),
                  ButtonSegment<int>(
                    value: 30,
                    label: Text(l10n.statsTrendRange30),
                  ),
                ],
                selected: <int>{_days},
                onSelectionChanged: (selection) =>
                    setState(() => _days = selection.first),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (total == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  l10n.statsTrendEmpty,
                  style: TextStyle(fontSize: 13, color: context.paper.inkSoft),
                ),
              ),
            )
          else ...<Widget>[
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  for (var i = 0; i < series.length; i++)
                    Expanded(
                      key: ValueKey<String>('trend-bar-$i'),
                      child: _TrendBar(
                        words: series[i].words,
                        max: max,
                        isToday: series[i].day == todayKey,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                _Label(series.first.day),
                _Label(series[series.length ~/ 2].day),
                _Label(series.last.day, highlight: true),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            l10n.statsTrendTotal(_days, total),
            style: TextStyle(fontSize: 12, color: context.paper.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _TrendBar extends StatelessWidget {
  const _TrendBar({
    required this.words,
    required this.max,
    required this.isToday,
  });

  final int words;
  final int max;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final factor = max <= 0 ? 0.0 : words / max;
    final color = isToday
        ? context.paper.accent
        : context.paper.accent.withValues(alpha: 0.45);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1.5),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: words == 0 ? 0.0 : factor.clamp(0.06, 1.0),
          widthFactor: 0.72,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.day, {this.highlight = false});

  /// 日期键 yyyy-MM-dd。
  final String day;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final month = int.parse(day.substring(5, 7));
    final date = int.parse(day.substring(8, 10));
    return Text(
      '$month/$date',
      style: TextStyle(
        fontSize: 10,
        color: highlight ? context.paper.accent : context.paper.inkSoft,
        fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }
}
