import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/core/ai/preference_distillation.dart';
import 'package:novelphone/core/ai/writing_preferences.dart';

/// ENH-45：从原稿 / 定稿配对样本中提炼改写倾向。
void main() {
  AdoptedSample pair(String source, String finalText) =>
      AdoptedSample(text: finalText, source: source, task: 'rewrite');

  test('无配对样本时不出结论', () {
    expect(PreferenceDistillation.distill(const <AdoptedSample>[]), isEmpty);
    expect(
      PreferenceDistillation.distill(<AdoptedSample>[
        const AdoptedSample(text: '只有定稿', task: 'rewrite'),
      ]),
      isEmpty,
    );
  });

  test('识别压缩倾向与删去的套话', () {
    final hints = PreferenceDistillation.distill(<AdoptedSample>[
      pair('他不由自主地站在原地，心中仿佛有千言万语，却一个字也说不出来。', '他站住，没有说话。'),
      pair('她轻轻地叹了口气，眼神深邃，仿佛看穿了一切。', '她移开目光。'),
    ]);
    expect(hints.map((hint) => hint.text).join(), contains('压缩'));
    expect(hints.map((hint) => hint.text).join(), contains('套话'));
    expect(hints.first.evidence, 2);
  });

  test('识别扩写与增加对话倾向', () {
    final hints = PreferenceDistillation.distill(<AdoptedSample>[
      pair('沈砚点头。', '沈砚点头，压低声音说：「今夜别出门。」\n苏晚没有应声。'),
      pair('苏晚离开。', '苏晚把灯芯挑亮，低声问：「你还要等多久？」\n沈砚没有回答。'),
    ]);
    final text = hints.map((hint) => hint.text).join();
    expect(text, contains('补充细节'));
    expect(text, contains('增加对话'));
  });

  test('识别减少对话与拆短段落倾向', () {
    final longParagraph =
        '苏晚说了很多话，「你今天必须留下。」「外面很危险。」'
        '「我不会走。」沈砚一直沉默，等她说完才起身。';
    final hints = PreferenceDistillation.distill(<AdoptedSample>[
      pair(longParagraph, '苏晚说完，沈砚起身。\n他推门离开。'),
      pair(longParagraph.replaceAll('很多话', '许多话'), '她停下。\n他走了。'),
    ]);
    final text = hints.map((hint) => hint.text).join();
    expect(text, contains('减少对话'));
    expect(text, contains('拆短段落'));
  });
}
