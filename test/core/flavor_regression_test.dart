import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/core/ai_flavor_rules.dart';

import 'fixtures/flavor_regression_samples.dart';

/// AI 感检查回归集（M4-05）：每个版本跑一次，核对 PRD 6.3 的通过标准。
void main() {
  test('回归集召回 ≥ 80%、误报 ≤ 20%', () {
    var truePositive = 0;
    var falseNegative = 0;
    var falsePositive = 0;
    var trueNegative = 0;
    final missed = <String>[];
    final misfired = <String>[];

    for (final sample in flavorRegressionSamples) {
      final flagged = isFlavorFlagged(runFlavorRules(sample.text));
      if (sample.aiFlavored) {
        if (flagged) {
          truePositive++;
        } else {
          falseNegative++;
          missed.add(sample.note ?? sample.text);
        }
      } else if (flagged) {
        falsePositive++;
        misfired.add(sample.text);
      } else {
        trueNegative++;
      }
    }

    final recall = truePositive / (truePositive + falseNegative);
    final falsePositiveRate = falsePositive / (falsePositive + trueNegative);

    expect(
      recall,
      greaterThanOrEqualTo(0.8),
      reason: '召回不达标，漏检样本：$missed',
    );
    expect(
      falsePositiveRate,
      lessThanOrEqualTo(0.2),
      reason: '误报超限，误报样本：$misfired',
    );
  });
}