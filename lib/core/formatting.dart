/// 最后编辑时间的展示文案（列表与详情页共用）。
String formatRelativeTime(DateTime time, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final diff = current.difference(time);
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
  if (diff.inHours < 24) return '${diff.inHours} 小时前';
  if (diff.inDays == 1) return '昨天';
  if (diff.inDays < 7) return '${diff.inDays} 天前';
  if (time.year == current.year) {
    return '${_two(time.month)}-${_two(time.day)}';
  }
  return '${time.year}-${_two(time.month)}-${_two(time.day)}';
}

String _two(int value) => value.toString().padLeft(2, '0');

/// token 数量展示（统计页）：带千分位，超过一万折算为「万」。
String formatTokenCount(int value) {
  if (value >= 10000) {
    final wan = value / 10000;
    return '${wan.toStringAsFixed(wan >= 100 ? 0 : 1)} 万';
  }
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) buffer.write(',');
    buffer.write(text[i]);
  }
  return buffer.toString();
}
