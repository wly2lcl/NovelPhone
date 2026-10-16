/// 每日写作字数与连击统计的纯函数（B-07）。
library;

String _two(int value) => value.toString().padLeft(2, '0');

/// 本地时区日期键（yyyy-MM-dd），与 DAILY_WRITING_STAT.day 的存储口径一致。
String writingDayKey(DateTime date) =>
    '${date.year}-${_two(date.month)}-${_two(date.day)}';

/// 连续写作天数：以「当天字数 > 0」为达标，从今天（今天尚未写作则从昨天）向前连续计数。
/// 今天还没写不算断连，昨天也没写则连击为 0。
int writingStreak(Map<String, int> wordsByDay, {DateTime? now}) {
  var cursor = now ?? DateTime.now();
  if ((wordsByDay[writingDayKey(cursor)] ?? 0) <= 0) {
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  var streak = 0;
  while ((wordsByDay[writingDayKey(cursor)] ?? 0) > 0) {
    streak++;
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  return streak;
}

/// 趋势图的一天：日期键 yyyy-MM-dd 与当日字数。
class DayWords {
  const DayWords(this.day, this.words);

  final String day;
  final int words;
}

/// 近 [days] 天（含今天）的每日字数，按时间从早到晚；无记录的天补 0（ENH-18）。
List<DayWords> recentDayWords(
  Map<String, int> wordsByDay,
  int days, {
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final result = <DayWords>[];
  for (var offset = days - 1; offset >= 0; offset--) {
    final date = DateTime(today.year, today.month, today.day - offset);
    final key = writingDayKey(date);
    result.add(DayWords(key, wordsByDay[key] ?? 0));
  }
  return result;
}
