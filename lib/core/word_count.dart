import '../l10n/l10n.dart';

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

/// 字数展示：中文界面按「万」折算，英文界面按 K / M 折算。
String formatWordCount(int words, AppLocalizations l10n) {
  if (l10n.localeName.startsWith('zh')) {
    if (words < 10000) return l10n.wordCountExact('$words');
    return l10n.wordCountWan((words / 10000).toStringAsFixed(1));
  }
  if (words < 1000) return l10n.wordCountExact('$words');
  if (words < 1000000) {
    final k = words / 1000;
    return l10n.wordCountK(k.toStringAsFixed(k >= 100 ? 0 : 1));
  }
  return l10n.wordCountM((words / 1000000).toStringAsFixed(1));
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
