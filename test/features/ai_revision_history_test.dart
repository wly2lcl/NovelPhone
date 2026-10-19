import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/features/editor/ai_revision_history.dart';

/// ENH-27.3：修订历史保留、切换、直接编辑回写与上限裁剪。
void main() {
  test('记录原稿与多轮修订，默认选中最新版', () {
    final history = AiRevisionHistory();
    history.record('原稿。');
    history.record('修订一。', instruction: '更克制');
    history.record('修订二。');

    expect(history.length, 3);
    expect(history.selectedIndex, 2);
    expect(history.selected?.text, '修订二。');
    expect(history.previous?.text, '修订一。');
    expect(history.canCompare, isTrue);
  });

  test('连续相同文本不重复入栈', () {
    final history = AiRevisionHistory();
    history.record('原稿。');
    history.record('  原稿。  ');

    expect(history.length, 1);
    expect(history.selectedIndex, 0);
  });

  test('切换版本返回文本，越界返回 null', () {
    final history = AiRevisionHistory();
    history.record('原稿。');
    history.record('修订一。');

    expect(history.select(0), '原稿。');
    expect(history.selectedIndex, 0);
    expect(history.canCompare, isFalse);
    expect(history.select(9), isNull);
    expect(history.selectedIndex, 0);
  });

  test('直接编辑回写当前版本，切换时不丢改动', () {
    final history = AiRevisionHistory();
    history.record('原稿。');
    history.record('修订一。', instruction: '更克制');
    history.select(1);
    history.updateSelected('修订一（作者改）。');

    expect(history.versions[1].text, '修订一（作者改）。');
    expect(history.versions[1].instruction, '更克制');
  });

  test('只保留最近 5 版', () {
    final history = AiRevisionHistory();
    for (var i = 0; i < 8; i++) {
      history.record('版本$i。');
    }

    expect(history.length, 5);
    expect(history.versions.first.text, '版本3。');
    expect(history.selected?.text, '版本7。');
  });

  test('清空后回到空历史', () {
    final history = AiRevisionHistory();
    history.record('原稿。');
    history.clear();

    expect(history.length, 0);
    expect(history.selectedIndex, -1);
    expect(history.selected, isNull);
    expect(history.canCompare, isFalse);
  });
}
