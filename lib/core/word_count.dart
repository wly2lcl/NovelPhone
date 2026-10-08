/// 中文字数统计（PRD 5.3 实时字数）。
///
/// 口径：中日韩字符（含假名、谚文）按 1 字计；连续的拉丁字母/数字串按 1 词计；
/// 空白与标点不计入。全角标点同样不计。
int countWords(String text) {
  var count = 0;
  var inLatinRun = false;
  for (final rune in text.runes) {
    if (_isCjk(rune)) {
      count++;
      inLatinRun = false;
    } else if (_isLatinLetterOrDigit(rune)) {
      if (!inLatinRun) {
        count++;
        inLatinRun = true;
      }
    } else {
      inLatinRun = false;
    }
  }
  return count;
}

/// 字数展示：小于 1 万直接显示，超过按"万"保留 1 位小数。
String formatWordCount(int words) {
  if (words < 10000) return '$words 字';
  return '${(words / 10000).toStringAsFixed(1)} 万字';
}

bool _isCjk(int rune) {
  return (rune >= 0x3400 && rune <= 0x4DBF) || // 扩展 A
      (rune >= 0x4E00 && rune <= 0x9FFF) || // 基本区
      (rune >= 0xF900 && rune <= 0xFAFF) || // 兼容表意
      (rune >= 0x3040 && rune <= 0x30FF) || // 日文假名
      (rune >= 0xAC00 && rune <= 0xD7AF); // 谚文
}

bool _isLatinLetterOrDigit(int rune) {
  return (rune >= 0x30 && rune <= 0x39) || // 0-9
      (rune >= 0x41 && rune <= 0x5A) || // A-Z
      (rune >= 0x61 && rune <= 0x7A); // a-z
}