import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/core/ai_flavor_rules.dart';
import 'package:novelphone/core/flavor_lexicon.dart';

void main() {
  group('套话词库（M4-01）', () {
    test('规模约 200 条且无重复', () {
      expect(flavorLexicon.length, greaterThanOrEqualTo(180));
      final words = flavorLexicon.map((e) => e.word).toSet();
      expect(words.length, flavorLexicon.length);
    });

    test('权重只取高/中/低三级', () {
      for (final entry in flavorLexicon) {
        expect(entry.weight, anyOf(1, 2, 3));
      }
    });
  });

  group('规则引擎 —— 套话命中（M4-01/M4-04）', () {
    test('强套话按高严重度报出', () {
      final result = runFlavorRules('她不禁笑了，仿佛一切都结束了。');
      final words = result.issues.map((i) => i.excerpt).toSet();
      expect(words, containsAll(<String>['不禁', '仿佛']));
      final issue = result.issues.firstWhere((i) => i.excerpt == '不禁');
      expect(issue.type, FlavorType.cliche);
      expect(issue.severity, FlavorSeverity.high);
      expect(issue.start, 1);
      expect(issue.end, 3);
    });

    test('低权重词只计入密度、不逐条报问题', () {
      final result = runFlavorRules('他慢慢地走过来。');
      expect(result.issues.where((i) => i.excerpt == '慢慢'), isEmpty);
      expect(result.metrics.clicheHits, greaterThan(0));
    });

    test('重叠词条取更长匹配，不重复计数', () {
      final result = runFlavorRules('他不由自主地站了起来。');
      final hits = result.issues.where((i) => i.type == FlavorType.cliche).toList();
      expect(hits.length, 1);
      expect(hits.single.excerpt, '不由自主地');
      expect(result.metrics.clicheHits, 1);
    });

    test('词条互为前缀时仍取更长匹配（ENH-10 单趟匹配）', () {
      // 词库中「顿了顿」排在「顿了顿又道」之前，组合正则必须优先命中更长的词条。
      final result = runFlavorRules('他顿了顿又道：「算了。」', minWeight: 1);
      final hits = result.issues.where((i) => i.type == FlavorType.cliche).toList();
      expect(hits.single.excerpt, '顿了顿又道');
      expect(result.metrics.clicheHits, 1);
    });

    test('同一套话重复出现时给出句式重复提示', () {
      final result = runFlavorRules('她不禁笑了。\n她不禁摇头。\n她不禁皱眉。\n她不禁叹气。');
      final repeated = result.issues.where(
        (i) => i.type == FlavorType.repetition && i.message.contains('不禁'),
      );
      expect(repeated, isNotEmpty);
    });

    test('空章节返回空结果', () {
      expect(runFlavorRules('').issues, isEmpty);
      expect(runFlavorRules('   \n  ').isEmpty, isTrue);
    });
  });

  group('规则引擎 —— 句式模式（M4-02）', () {
    test('模式化对话标签', () {
      final result = runFlavorRules('“你走吧。”他淡淡地说道。');
      expect(
        result.issues.any((i) => i.type == FlavorType.repetition && i.message.contains('对话标签')),
        isTrue,
      );
    });

    test('翻译腔句式', () {
      final result = runFlavorRules('对于他来说，这一切并不难。');
      expect(result.issues.any((i) => i.type == FlavorType.translationese), isTrue);
    });

    test('段尾感悟句', () {
      final result = runFlavorRules('他站在原地，看着远去的车灯。这一切，就是人生。');
      expect(result.issues.any((i) => i.type == FlavorType.oversummary), isTrue);
    });

    test('连续同结构段落', () {
      final result = runFlavorRules('他的手指停在半空。\n他的声音有些发抖。\n他的眼神躲闪了一下。');
      expect(
        result.issues.any((i) => i.message.contains('连续 3 段结构相同')),
        isTrue,
      );
    });
  });

  group('规则引擎 —— 指标（M4-03）', () {
    test('指标与密度计算', () {
      final text = List<String>.filled(100, '她不禁笑了。').join('\n');
      final result = runFlavorRules(text);
      expect(result.metrics.clicheHits, 100);
      expect(result.metrics.clicheDensity, greaterThan(clicheDensityThreshold));
      expect(result.metrics.paragraphCount, 100);
      expect(result.metrics.wordCount, greaterThanOrEqualTo(densityMinWords));
      // 套话密度超阈值时给出全文级提示（不可定位）。
      expect(
        result.issues.any((i) => i.isDocumentLevel && i.type == FlavorType.cliche),
        isTrue,
      );
    });

    test('短章不做密度告警，避免误报', () {
      final result = runFlavorRules('她不禁笑了。');
      expect(result.issues.any((i) => i.isDocumentLevel), isFalse);
    });

    test('破折号与省略号频率', () {
      final text = List<String>.filled(100, '他……沉默——很久。').join('\n');
      final result = runFlavorRules(text);
      expect(result.metrics.ellipsisCount, greaterThan(0));
      expect(result.metrics.dashCount, greaterThan(0));
      expect(
        result.issues.any((i) => i.isDocumentLevel && i.type == FlavorType.pacing),
        isTrue,
      );
    });

    test('干净文本不产生问题', () {
      final result = runFlavorRules('院子里的老槐树落了一地叶子，扫帚划过青砖，发出沙沙的响。');
      expect(result.issues, isEmpty);
    });
  });

  group('两层合并与排序（M4-08）', () {
    test('同位置同类型去重，保留严重度更高者', () {
      final merged = mergeFlavorIssues(<FlavorIssue>[
        const FlavorIssue(
          type: FlavorType.cliche,
          severity: FlavorSeverity.low,
          start: 3,
          end: 5,
          message: '规则命中',
        ),
        const FlavorIssue(
          type: FlavorType.cliche,
          severity: FlavorSeverity.high,
          start: 3,
          end: 5,
          message: 'LLM 命中',
          suggestion: '改写建议',
          source: FlavorSource.llm,
        ),
      ]);
      expect(merged.length, 1);
      expect(merged.single.severity, FlavorSeverity.high);
      expect(merged.single.message, 'LLM 命中');
    });

    test('按严重度降序、同级按位置升序', () {
      final issues = <FlavorIssue>[
        const FlavorIssue(
          type: FlavorType.cliche,
          severity: FlavorSeverity.low,
          start: 1,
          end: 2,
          message: 'a',
        ),
        const FlavorIssue(
          type: FlavorType.cliche,
          severity: FlavorSeverity.high,
          start: 8,
          end: 9,
          message: 'b',
        ),
        const FlavorIssue(
          type: FlavorType.cliche,
          severity: FlavorSeverity.high,
          start: 4,
          end: 5,
          message: 'c',
        ),
      ];
      sortFlavorIssues(issues);
      expect(issues.map((i) => i.message).toList(), <String>['c', 'b', 'a']);
    });
  });
}