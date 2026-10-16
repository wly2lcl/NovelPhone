/// 文本查找 / 替换的纯函数（编辑面板与全书替换共用同一口径，ENH-19）。
library;

/// 一段命中的 UTF-16 区间 [start, end)。
class TextMatch {
  const TextMatch(this.start, this.end);

  final int start;
  final int end;
}

/// [text] 中 [keyword] 的全部非重叠命中。忽略大小写时先整体折叠再查找，
/// 命中区间仍落在原文偏移上（与编辑器查找替换口径一致）。
List<TextMatch> findTextMatches(
  String text,
  String keyword, {
  bool caseSensitive = false,
}) {
  if (keyword.isEmpty) return const <TextMatch>[];
  final haystack = caseSensitive ? text : text.toLowerCase();
  final needle = caseSensitive ? keyword : keyword.toLowerCase();
  final matches = <TextMatch>[];
  var index = haystack.indexOf(needle);
  while (index != -1) {
    matches.add(TextMatch(index, index + needle.length));
    index = haystack.indexOf(needle, index + needle.length);
  }
  return matches;
}

/// 将 [text] 中 [keyword] 的全部命中替换为 [replacement]；
/// 无命中时原样返回，替换处数为 0。
({String text, int count}) replaceTextMatches(
  String text,
  String keyword,
  String replacement, {
  bool caseSensitive = false,
}) {
  final matches = findTextMatches(text, keyword, caseSensitive: caseSensitive);
  if (matches.isEmpty) return (text: text, count: 0);
  final buffer = StringBuffer();
  var last = 0;
  for (final match in matches) {
    buffer.write(text.substring(last, match.start));
    buffer.write(replacement);
    last = match.end;
  }
  buffer.write(text.substring(last));
  return (text: buffer.toString(), count: matches.length);
}
