/// AI 结果插入光标处时的段落分隔（ENH-27.1）。
///
/// AI 文本本身已去除首尾空白；这里只根据插入点两侧已有内容补足空行，
/// 避免续写结果与原文粘成一句（如 `listened.屋里没有点灯`）。
String composeAiInsertion({
  required String document,
  required int offset,
  required String text,
}) {
  if (text.isEmpty) return text;
  final clamped = offset.clamp(0, document.length);
  final before = document.substring(0, clamped);
  final after = document.substring(clamped);
  final buffer = StringBuffer();
  if (before.trim().isNotEmpty) {
    final trailing = _trailingNewlines(before);
    if (trailing == 0) {
      buffer.write('\n\n');
    } else if (trailing == 1) {
      buffer.write('\n');
    }
  }
  buffer.write(text);
  if (after.trim().isNotEmpty) {
    final leading = _leadingNewlines(after);
    if (leading == 0) {
      buffer.write('\n\n');
    } else if (leading == 1) {
      buffer.write('\n');
    }
  }
  return buffer.toString();
}

int _trailingNewlines(String text) {
  var count = 0;
  for (var i = text.length - 1; i >= 0 && text[i] == '\n'; i--) {
    count++;
  }
  return count;
}

int _leadingNewlines(String text) {
  var count = 0;
  for (var i = 0; i < text.length && text[i] == '\n'; i++) {
    count++;
  }
  return count;
}
