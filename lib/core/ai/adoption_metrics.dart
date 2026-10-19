/// 采纳质量指标（ENH-30）：AI 原稿到最终插入正文的编辑比例。
///
/// 以去空白后的字符 bigram 多重集做 Dice 相似度，再取补值：
/// 0 表示原样采纳，100 表示完全重写。相比逐字符 LCS，O(n) 复杂度对
/// 长篇结果也不会阻塞 UI，且对少量标点 / 词语改动不敏感。
library;

/// 原样采纳阈值（百分比）：不超过该值视为「基本原样采用」。
const int adoptionVerbatimPercent = 10;

/// 偏好样本上限（百分比）：编辑超过该值的采纳不作为作者语气参考。
const int adoptionSampleMaxEditPercent = 30;

int adoptionEditPercent(String original, String edited) {
  final a = original.replaceAll(RegExp(r'\s+'), '');
  final b = edited.replaceAll(RegExp(r'\s+'), '');
  if (a == b) return 0;
  if (a.isEmpty || b.isEmpty) return 100;
  if (a.length < 2 || b.length < 2) return 100;

  final left = _bigrams(a);
  final right = _bigrams(b);
  var intersection = 0;
  for (final entry in left.entries) {
    final count = right[entry.key];
    if (count != null) {
      intersection += entry.value < count ? entry.value : count;
    }
  }
  final total = _count(left) + _count(right);
  final similarity = total == 0 ? 0.0 : 2 * intersection / total;
  return ((1 - similarity) * 100).round().clamp(0, 100);
}

Map<String, int> _bigrams(String text) {
  final map = <String, int>{};
  for (var i = 0; i < text.length - 1; i++) {
    final gram = text.substring(i, i + 2);
    map[gram] = (map[gram] ?? 0) + 1;
  }
  return map;
}

int _count(Map<String, int> grams) =>
    grams.values.fold(0, (sum, count) => sum + count);
