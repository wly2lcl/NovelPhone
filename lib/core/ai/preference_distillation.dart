/// 改写偏好蒸馏（ENH-45）：从「模型原稿 → 作者定稿」的配对样本中
/// 提炼可读的改写倾向，由作者确认后加入协作守则。
///
/// 纯本地统计，不调用模型；只在有配对样本时给出结论。
library;

import 'collaboration_rules.dart';
import 'writing_preferences.dart';

/// 一条可确认的偏好结论。
class DistilledHint {
  const DistilledHint({
    required this.text,
    required this.evidence,
    this.analysisEvidence = 0,
  });

  /// 可直接作为协作守则的文本。
  final String text;

  /// 支撑该结论的配对样本数。
  final int evidence;

  /// ENH-50：其中来自「大改样本」的组数（仅本地分析，不注入提示）。
  final int analysisEvidence;
}

class PreferenceDistillation {
  const PreferenceDistillation._();

  /// 至少需要一组原稿对照。
  static const int minPairs = 1;

  static List<DistilledHint> distill(
    List<AdoptedSample> samples, {
    List<AdoptedSample> analysisSamples = const <AdoptedSample>[],
  }) {
    bool valid(AdoptedSample s) =>
        s.hasSource && s.text.trim().isNotEmpty && s.source.trim().isNotEmpty;
    final lightPairs = samples.where(valid).toList(growable: false);
    // ENH-50：编辑幅度超过 30% 的样本只参与本地分析，不进入提示样本。
    final heavyPairs = analysisSamples.where(valid).toList(growable: false);
    final pairs = <AdoptedSample>[...lightPairs, ...heavyPairs];
    if (pairs.length < minPairs) return const <DistilledHint>[];
    final heavy = heavyPairs.length;

    final hints = <DistilledHint>[];
    final ratio = _averageRatio(pairs);
    if (ratio != null && ratio <= 0.85) {
      final percent = ((1 - ratio) * 100).round();
      hints.add(
        DistilledHint(
          text:
              '改写时倾向压缩：定稿平均比原稿精简约 $percent%，'
              '请删去冗词与重复铺垫，保留关键动作与信息。',
          evidence: pairs.length,
          analysisEvidence: heavy,
        ),
      );
    } else if (ratio != null && ratio >= 1.2) {
      final percent = ((ratio - 1) * 100).round();
      hints.add(
        DistilledHint(
          text:
              '改写时倾向补充细节：定稿平均比原稿扩写约 $percent%，'
              '可适度展开场景、动作与心理，但不要注水。',
          evidence: pairs.length,
          analysisEvidence: heavy,
        ),
      );
    }

    final dialogue = _dialogueDirection(pairs);
    if (dialogue > 0) {
      hints.add(
        DistilledHint(
          text: '改写时倾向增加对话与引语，用人物交流替代概述性叙述。',
          evidence: dialogue,
          analysisEvidence: heavy,
        ),
      );
    } else if (dialogue < 0) {
      hints.add(
        DistilledHint(
          text: '改写时倾向减少对话，改用动作、场景与感官细节推进。',
          evidence: -dialogue,
          analysisEvidence: heavy,
        ),
      );
    }

    final paragraph = _paragraphDirection(pairs);
    if (paragraph > 0) {
      hints.add(
        DistilledHint(
          text: '改写时倾向拆短段落，单段更紧凑，避免大段铺陈。',
          evidence: paragraph,
          analysisEvidence: heavy,
        ),
      );
    } else if (paragraph < 0) {
      hints.add(
        DistilledHint(
          text: '改写时倾向合并长段，保持叙述连贯，减少零碎断行。',
          evidence: -paragraph,
          analysisEvidence: heavy,
        ),
      );
    }

    final removed = _removedCliches(pairs);
    if (removed.isNotEmpty) {
      hints.add(
        DistilledHint(
          text:
              '改写时删去了${removed.map((e) => '「$e」').join('、')}等套话，'
              '生成时请避免使用。',
          evidence: pairs.length,
          analysisEvidence: heavy,
        ),
      );
    }
    return hints.take(4).toList(growable: false);
  }

  static double? _averageRatio(List<AdoptedSample> pairs) {
    var totalSource = 0;
    var totalFinal = 0;
    for (final pair in pairs) {
      totalSource += _length(pair.source);
      totalFinal += _length(pair.text);
    }
    if (totalSource == 0) return null;
    return totalFinal / totalSource;
  }

  /// 正数表示多数样本增加了引语，负数表示减少，0 表示无明显倾向。
  static int _dialogueDirection(List<AdoptedSample> pairs) {
    var more = 0;
    var less = 0;
    for (final pair in pairs) {
      final before = _quotes(pair.source);
      final after = _quotes(pair.text);
      if (after > before) more++;
      if (after < before) less++;
    }
    final threshold = (pairs.length * 0.6).ceil();
    if (more >= threshold && more > less) return more;
    if (less >= threshold && less > more) return -less;
    return 0;
  }

  /// 正数表示多数样本把段落拆短，负数表示合并。
  static int _paragraphDirection(List<AdoptedSample> pairs) {
    var shorter = 0;
    var longer = 0;
    for (final pair in pairs) {
      final before = _averageParagraphLength(pair.source);
      final after = _averageParagraphLength(pair.text);
      if (before <= 0 || after <= 0) continue;
      if (after <= before * 0.75) shorter++;
      if (after >= before * 1.3) longer++;
    }
    final threshold = (pairs.length * 0.6).ceil();
    if (shorter >= threshold && shorter > longer) return shorter;
    if (longer >= threshold && longer > shorter) return -longer;
    return 0;
  }

  /// 原稿里有、定稿里没有再出现的套话，按删除次数排序取前三。
  static List<String> _removedCliches(List<AdoptedSample> pairs) {
    final totals = <String, int>{};
    for (final pair in pairs) {
      final before = AiCliche.count(pair.source);
      final after = AiCliche.count(pair.text);
      for (final entry in before.entries) {
        final removed = entry.value - (after[entry.key] ?? 0);
        if (removed > 0) {
          totals[entry.key] = (totals[entry.key] ?? 0) + removed;
        }
      }
    }
    final entries = totals.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return b.key.length.compareTo(a.key.length);
      });
    return entries.take(3).map((e) => e.key).toList(growable: false);
  }

  static int _length(String text) => text.trim().runes.length;

  static int _quotes(String text) => RegExp(r'[「“"]').allMatches(text).length;

  static double _averageParagraphLength(String text) {
    final paragraphs = text
        .split(RegExp(r'\n+'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList(growable: false);
    if (paragraphs.isEmpty) return 0;
    final total = paragraphs.fold<int>(0, (sum, p) => sum + p.runes.length);
    return total / paragraphs.length;
  }
}
