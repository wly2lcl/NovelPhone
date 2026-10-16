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
