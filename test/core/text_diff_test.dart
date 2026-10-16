import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/core/text_diff.dart';

/// ENH-18：段落级文本 Diff（快照对比）。
void main() {
  group('diffParagraphs', () {
    test('完全相同 → 全部 same，无增删', () {
      final lines = diffParagraphs('第一段\n第二段', '第一段\n第二段');
      expect(lines.length, 2);
      expect(lines.every((l) => l.kind == DiffKind.same), isTrue);
    });

    test('两稿皆空 → 空列表', () {
      expect(diffParagraphs('', ''), isEmpty);
    });

    test('空快照 → 全部为新增', () {
      final lines = diffParagraphs('', '新段落一\n新段落二');
      expect(lines.length, 2);
      expect(lines.every((l) => l.kind == DiffKind.added), isTrue);
      expect(lines.map((l) => l.text), ['新段落一', '新段落二']);
    });

    test('当前清空 → 全部为删除', () {
      final lines = diffParagraphs('旧段落', '');
      expect(lines.single.kind, DiffKind.removed);
      expect(lines.single.text, '旧段落');
    });

    test('中段插入与删除：公共前后缀被正确裁剪', () {
      final lines = diffParagraphs('开头\n原文二\n原文三\n结尾', '开头\n插入段\n原文三\n结尾');
      // 期望：same(开头) + removed(原文二) + added(插入段) + same(原文三) + same(结尾)
      expect(lines.map((l) => l.kind), [
        DiffKind.same,
        DiffKind.removed,
        DiffKind.added,
        DiffKind.same,
        DiffKind.same,
      ]);
      expect(lines[1].text, '原文二');
      expect(lines[2].text, '插入段');
    });

    test('仅末尾追加 → 前缀全部 same，尾部为新增', () {
      final lines = diffParagraphs('甲\n乙', '甲\n乙\n丙');
      expect(lines.map((l) => l.kind), [
        DiffKind.same,
        DiffKind.same,
        DiffKind.added,
      ]);
    });

    test('改写段落呈现为一删一增', () {
      final lines = diffParagraphs('她说：“走吧。”', '她说：“再等等。”');
      expect(lines.length, 2);
      expect(lines[0].kind, DiffKind.removed);
      expect(lines[1].kind, DiffKind.added);
    });

    test('尾部换行差异按空段落处理', () {
      final lines = diffParagraphs('正文\n', '正文');
      expect(lines.map((l) => l.kind), [DiffKind.same, DiffKind.removed]);
      expect(lines.last.text, isEmpty);
    });

    test('超大规模回退：不做逐行对齐也不崩溃', () {
      // 2000 x 2000 = 4M > 2M 阈值，且两稿无公共行 → 直接块级删 + 块级增。
      final oldText = List.generate(2000, (i) => '旧-$i').join('\n');
      final newText = List.generate(2000, (i) => '新-$i').join('\n');
      final stopwatch = Stopwatch()..start();
      final lines = diffParagraphs(oldText, newText);
      stopwatch.stop();
      expect(lines.length, 4000);
      expect(lines.take(2000).every((l) => l.kind == DiffKind.removed), isTrue);
      expect(lines.skip(2000).every((l) => l.kind == DiffKind.added), isTrue);
      // 回退路径应远快于 LCS；仅防御性断言，不苛求精确耗时。
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
    });

    test('10 万字章节仅改动一处时保持线性开销', () {
      final base = List.generate(1200, (i) => '这是第 $i 段正文，略述其事。').join('\n');
      final changed = base.replaceFirst('第 600 段', '第 600 段（改）');
      final stopwatch = Stopwatch()..start();
      final lines = diffParagraphs(base, changed);
      stopwatch.stop();
      expect(lines.where((l) => l.kind == DiffKind.added).length, 1);
      expect(lines.where((l) => l.kind == DiffKind.removed).length, 1);
      expect(stopwatch.elapsedMilliseconds, lessThan(500));
    });
  });
}
