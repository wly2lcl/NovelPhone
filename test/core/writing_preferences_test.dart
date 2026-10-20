import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/core/ai/writing_preferences.dart';

void main() {
  group('忽略原因 → prompt 约束', () {
    test('单次放弃不计入，达到阈值才注入对应规则', () {
      expect(
        WritingPreferences.promptBlock(
          reasonCounts: <String, int>{AiFeedbackReason.tooAi: 1},
          samples: const <AdoptedSample>[],
        ),
        isEmpty,
      );

      final block = WritingPreferences.promptBlock(
        reasonCounts: <String, int>{AiFeedbackReason.tooAi: 2},
        samples: const <AdoptedSample>[],
      );
      expect(block, contains('【作者协作偏好】'));
      expect(block, contains('避免空泛抒情'));
      expect(block, isNot(contains('角色出戏')));
    });

    test('各原因映射到不同约束，other 不产生规则', () {
      expect(
        AiFeedbackReason.rule(AiFeedbackReason.offCharacter),
        contains('OOC'),
      );
      expect(AiFeedbackReason.rule(AiFeedbackReason.slowPace), contains('节奏'));
      expect(
        AiFeedbackReason.rule(AiFeedbackReason.offSetting),
        contains('设定集'),
      );
      expect(AiFeedbackReason.rule(AiFeedbackReason.other), isNull);

      final block = WritingPreferences.promptBlock(
        reasonCounts: <String, int>{
          AiFeedbackReason.offCharacter: 2,
          AiFeedbackReason.slowPace: 3,
          AiFeedbackReason.other: 9,
        },
        samples: const <AdoptedSample>[],
      );
      expect(block, contains('OOC'));
      expect(block, contains('节奏'));
      expect(
        block.split('\n').where((line) => line.startsWith('- ')),
        hasLength(2),
      );
    });
  });

  group('本地采纳样本', () {
    test('置顶、去重、限制条数与单条长度', () {
      var samples = <AdoptedSample>[];
      for (var i = 0; i < WritingPreferences.maxSamples + 3; i++) {
        samples = WritingPreferences.addSample(
          samples,
          AdoptedSample(text: '片段$i', task: 'continue'),
        );
      }
      expect(samples, hasLength(WritingPreferences.maxSamples));
      expect(samples.first.text, '片段7');

      samples = WritingPreferences.addSample(
        samples,
        const AdoptedSample(text: '片段7', task: 'continue'),
      );
      expect(samples.where((s) => s.text == '片段7'), hasLength(1));
      expect(samples.first.text, '片段7');

      final long = '长' * (WritingPreferences.maxSampleChars + 20);
      samples = WritingPreferences.addSample(
        samples,
        AdoptedSample(text: long, task: 'rewrite'),
      );
      expect(
        samples.first.text.runes.length,
        WritingPreferences.maxSampleChars + 1, // 截断后追加省略号
      );
    });

    test('prompt 最多参考 3 段，单行化并截断', () {
      final samples = <AdoptedSample>[
        for (var i = 0; i < 5; i++)
          AdoptedSample(text: '第$i段\n第二行${'补' * 300}', task: 'continue'),
      ];
      final block = WritingPreferences.promptBlock(
        reasonCounts: const <String, int>{},
        samples: samples,
      );
      expect(block, contains('最近采纳的写法片段'));
      expect(
        RegExp(r'^\d\. ', multiLine: true).allMatches(block),
        hasLength(3),
      );
      expect(block, isNot(contains('\n第二行')));
    });

    test('prompt 优先选取同类任务的采纳片段，超出上限时仍截断', () {
      final samples = <AdoptedSample>[
        const AdoptedSample(text: '新改写一', task: 'rewrite'),
        const AdoptedSample(text: '新改写二', task: 'rewrite'),
        const AdoptedSample(text: '旧续写一', task: 'continue'),
        const AdoptedSample(text: '旧续写二', task: 'continue'),
      ];
      final block = WritingPreferences.promptBlock(
        reasonCounts: const <String, int>{},
        samples: samples,
        preferredTask: 'continue',
      );
      expect(block.indexOf('旧续写一'), lessThan(block.indexOf('新改写一')));
      expect(
        RegExp(r'^\d\. ', multiLine: true).allMatches(block),
        hasLength(WritingPreferences.promptSampleCount),
      );
      expect(block, contains('旧续写二'));
      expect(block, isNot(contains('新改写二')));
    });

    test('原稿→定稿配对随样本保存并注入 prompt（ENH-42）', () {
      var samples = WritingPreferences.addSample(
        <AdoptedSample>[],
        const AdoptedSample(
          text: '他把刀放回鞘里，没再说话。',
          source: '他将长刀收回鞘中，沉默不语。',
          task: 'continue',
        ),
      );
      expect(samples.single.hasSource, isTrue);

      final block = WritingPreferences.promptBlock(
        reasonCounts: const <String, int>{},
        samples: samples,
      );
      expect(block, contains('模型原稿：他将长刀收回鞘中，沉默不语。'));
      expect(block, contains('作者定稿：他把刀放回鞘里，没再说话。'));

      final decoded = WritingPreferences.parseSamples(
        WritingPreferences.encodeSamples(samples),
      );
      expect(decoded.single.source, '他将长刀收回鞘中，沉默不语。');

      samples = WritingPreferences.addSample(
        <AdoptedSample>[],
        const AdoptedSample(text: '同一段。', source: '同一段。', task: 'continue'),
      );
      expect(samples.single.hasSource, isFalse);
      expect(
        WritingPreferences.parseSamples(
          WritingPreferences.encodeSamples(samples),
        ).single.source,
        isEmpty,
      );
    });

    test('JSON 往返与脏数据容错', () {
      final samples = <AdoptedSample>[
        AdoptedSample(
          text: '雨落在刀鞘上。',
          task: 'continue',
          createdAt: DateTime.utc(2026, 10, 19),
        ),
        const AdoptedSample(text: '他笑了。', task: 'rewrite'),
      ];
      final decoded = WritingPreferences.parseSamples(
        WritingPreferences.encodeSamples(samples),
      );
      expect(decoded, hasLength(2));
      expect(decoded.first.text, '雨落在刀鞘上。');
      expect(decoded.first.task, 'continue');
      expect(decoded.first.createdAt, DateTime.utc(2026, 10, 19));

      expect(WritingPreferences.parseSamples('not-json'), isEmpty);
      expect(WritingPreferences.parseSamples('{"x":1}'), isEmpty);
      expect(WritingPreferences.parseReasonCounts('not-json'), isEmpty);
      expect(
        WritingPreferences.parseReasonCounts(
          '{"counts":{"too_ai":2,"off_character":"1","unknown":9}}',
        ),
        <String, int>{
          AiFeedbackReason.tooAi: 2,
          AiFeedbackReason.offCharacter: 1,
        },
      );
    });
  });
}
