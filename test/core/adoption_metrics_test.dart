import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/core/ai/adoption_metrics.dart';

/// ENH-30：AI 原稿到最终采纳文本的编辑比例。
void main() {
  test('原样采纳（含空白差异）为 0', () {
    expect(adoptionEditPercent('沈砚推开门。', '沈砚推开门。'), 0);
    expect(adoptionEditPercent('沈砚推开门。', ' 沈砚推开门。\n'), 0);
  });

  test('少量词语改动低于原样阈值', () {
    final percent = adoptionEditPercent(
      '沈砚推开门，风从走廊尽头灌了进来。',
      '沈砚推开门，冷风从走廊尽头灌了进来。',
    );
    expect(percent, greaterThan(0));
    expect(percent, lessThanOrEqualTo(adoptionVerbatimPercent));
  });

  test('大幅改写接近 100', () {
    final percent = adoptionEditPercent(
      '沈砚推开门，风从走廊尽头灌了进来。',
      '海面起了雾，灯塔的光在远处缓慢旋转。',
    );
    expect(percent, greaterThan(70));
  });

  test('删除整段计入编辑比例', () {
    final percent = adoptionEditPercent(
      '第一段内容。\n第二段内容。\n第三段内容。',
      '第一段内容。\n第三段内容。',
    );
    expect(percent, greaterThan(10));
  });

  test('空文本边界', () {
    expect(adoptionEditPercent('', ''), 0);
    expect(adoptionEditPercent('有内容', ''), 100);
    expect(adoptionEditPercent('', '有内容'), 100);
    expect(adoptionEditPercent('单', '字'), 100);
  });
}
