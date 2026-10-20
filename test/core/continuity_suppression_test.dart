import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/core/ai/continuity_suppression.dart';
import 'package:novelphone/core/ai/structured_response.dart';

void main() {
  group('ENH-41 忽略指纹', () {
    test('空白、引号与来源标点不影响指纹', () {
      const first = ContinuityIssue(quote: '「苏晚今年十六岁」', source: '角色卡·苏晚');
      const second = ContinuityIssue(quote: '苏晚 今年十六岁', source: '角色卡-苏晚');
      expect(
        ContinuitySuppressions.fingerprint(first),
        ContinuitySuppressions.fingerprint(second),
      );
    });

    test('原文相同、来源标签不同仍视为同一处差异', () {
      final entry = ContinuitySuppression.fromIssue(
        const ContinuityIssue(quote: '沈砚没有出声', source: '角色卡·沈砚'),
      );
      expect(
        entry.matches(
          const ContinuityIssue(quote: '「沈砚没有出声」', source: '故事状态·沈砚'),
        ),
        isTrue,
      );
      expect(
        entry.matches(const ContinuityIssue(quote: '沈砚大笑出声', source: '角色卡·沈砚')),
        isFalse,
      );
    });

    test('新增置顶去重并限制条数', () {
      var entries = const <ContinuitySuppression>[];
      for (var i = 0; i < ContinuitySuppressions.maxEntries + 3; i++) {
        entries = ContinuitySuppressions.add(
          entries,
          ContinuitySuppression.fromIssue(
            ContinuityIssue(quote: '冲突原文 $i', source: '角色卡·沈砚'),
          ),
        );
      }
      expect(entries, hasLength(ContinuitySuppressions.maxEntries));
      expect(
        entries.first.quote,
        '冲突原文 ${ContinuitySuppressions.maxEntries + 2}',
      );

      final duplicate = ContinuitySuppression.fromIssue(
        const ContinuityIssue(quote: '冲突原文 3', source: '角色卡·沈砚'),
      );
      entries = ContinuitySuppressions.add(entries, duplicate);
      expect(entries.where((entry) => entry.quote == '冲突原文 3'), hasLength(1));
    });

    test('解析容忍脏数据并按指纹去重', () {
      final parsed = ContinuitySuppressions.parse(
        '[{"quote":"沈砚没有出声","source":"角色卡·沈砚","reason":"有意保留"},'
        '{"quote":" 沈砚没有出声 ","source":"角色卡-沈砚"},'
        '{"quote":""},{"reason":"无原文"}]',
      );
      expect(parsed, hasLength(1));
      expect(parsed.single.reason, '有意保留');
      expect(ContinuitySuppressions.parse('not-json'), isEmpty);
    });

    test('提示块包含来源与原因并限制条数', () {
      final entries = <ContinuitySuppression>[
        for (var i = 0; i < ContinuitySuppressions.maxPromptEntries + 2; i++)
          ContinuitySuppression.fromIssue(
            ContinuityIssue(quote: '差异 $i', source: '角色卡·沈砚'),
            reason: '有意保留',
          ),
      ];
      final block = ContinuitySuppressions.promptBlock(entries);
      expect(block, contains('有意保留'));
      expect(block, contains('来源：角色卡·沈砚'));
      expect(block, isNot(contains('差异 20')));
      expect(ContinuitySuppressions.promptBlock(const []), isEmpty);
    });
  });

  group('ENH-41 结果过滤', () {
    test('移除命中项、统计忽略数并保留其他冲突', () {
      final entries = <ContinuitySuppression>[
        ContinuitySuppression.fromIssue(
          const ContinuityIssue(quote: '沈砚没有出声', source: '角色卡·沈砚'),
        ),
      ];
      final result = ContinuitySuppressions.filterResult(
        const ContinuityCheckResult(
          summary: '发现 2 处冲突',
          issues: <ContinuityIssue>[
            ContinuityIssue(quote: '沈砚没有出声', source: '角色卡-沈砚'),
            ContinuityIssue(quote: '屋里没有点灯', source: '设定集·客栈'),
          ],
        ),
        entries,
      );
      expect(result.issues.single.quote, '屋里没有点灯');
      expect(result.summary, '发现 2 处冲突');
      expect(
        ContinuitySuppressions.filterIssues(const <ContinuityIssue>[
          ContinuityIssue(quote: '沈砚没有出声', source: '角色卡·沈砚'),
        ], entries).ignored,
        1,
      );
    });

    test('解析失败时保留原文不做过滤', () {
      const result = ContinuityCheckResult(rawText: '模型输出', parseFailed: true);
      final filtered =
          ContinuitySuppressions.filterResult(result, <ContinuitySuppression>[
            ContinuitySuppression.fromIssue(
              const ContinuityIssue(quote: '模型输出', source: '角色卡'),
            ),
          ]);
      expect(filtered.parseFailed, isTrue);
      expect(filtered.rawText, '模型输出');
    });
  });
}
