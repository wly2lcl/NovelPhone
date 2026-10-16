import 'package:intl/intl.dart';

import '../l10n/l10n.dart';

/// 最后编辑时间的展示文案（列表与详情页共用）。
String formatRelativeTime(
  DateTime time,
  AppLocalizations l10n, {
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final diff = current.difference(time);
  if (diff.inMinutes < 1) return l10n.timeJustNow;
  if (diff.inMinutes < 60) return l10n.timeMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l10n.timeHoursAgo(diff.inHours);
  if (diff.inDays == 1) return l10n.timeYesterday;
  if (diff.inDays < 7) return l10n.timeDaysAgo(diff.inDays);
  final zh = l10n.localeName.startsWith('zh');
  if (time.year == current.year) {
    return zh
        ? '${_two(time.month)}-${_two(time.day)}'
        : DateFormat('MMM d').format(time);
  }
  return zh
      ? '${time.year}-${_two(time.month)}-${_two(time.day)}'
      : DateFormat('MMM d, y').format(time);
}

String _two(int value) => value.toString().padLeft(2, '0');

/// token 数量展示（统计页）：中文界面按「万」折算，英文界面按 K / M 折算。
String formatTokenCount(int value, AppLocalizations l10n) {
  final zh = l10n.localeName.startsWith('zh');
  if (zh) {
    if (value < 10000) return _grouped(value);
    final wan = value / 10000;
    return l10n.tokenCountScaled(wan.toStringAsFixed(wan >= 100 ? 0 : 1));
  }
  if (value >= 1000000) {
    final m = value / 1000000;
    return l10n.tokenCountMega(m.toStringAsFixed(m >= 100 ? 0 : 1));
  }
  if (value >= 1000) {
    final k = value / 1000;
    return l10n.tokenCountScaled(k.toStringAsFixed(k >= 100 ? 0 : 1));
  }
  return _grouped(value);
}

/// 千分位分组。
String _grouped(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) buffer.write(',');
    buffer.write(text[i]);
  }
  return buffer.toString();
}
