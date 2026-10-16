import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/app/theme.dart';
import 'package:novelphone/features/editor/snapshot_diff_dialog.dart';
import 'package:novelphone/l10n/generated/app_localizations.dart';

/// ENH-18：快照对比弹窗。
void main() {
  Future<void> pumpAndOpen(
    WidgetTester tester, {
    required String oldText,
    required String newText,
    Locale locale = const Locale('zh'),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPaperTheme(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showSnapshotDiffDialog(
                  context,
                  oldText: oldText,
                  newText: newText,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('中段改动：增删行按段落展示并计数（ENH-18）', (tester) async {
    await pumpAndOpen(
      tester,
      oldText: '第一段\n原文二\n原文三',
      newText: '第一段\n新增段\n原文三',
    );

    expect(find.text('与当前版本对比'), findsOneWidget);
    expect(find.text('1 段新增'), findsOneWidget);
    expect(find.text('1 段删除'), findsOneWidget);
    expect(find.text('新增段'), findsOneWidget);
    expect(find.text('原文二'), findsOneWidget);
    expect(find.text('第一段'), findsOneWidget);
    expect(find.text('原文三'), findsOneWidget);
  });

  testWidgets('无改动：提示与当前版本一致', (tester) async {
    await pumpAndOpen(tester, oldText: '正文', newText: '正文');

    expect(find.text('与当前版本一致，无改动'), findsOneWidget);
  });

  testWidgets('连续未改动行折叠为省略标记', (tester) async {
    final same = List.generate(20, (i) => '相同-$i').join('\n');
    await pumpAndOpen(
      tester,
      oldText: '开头\n$same\n结尾',
      newText: '开头\n$same\n结尾（改）',
    );

    // 开头 + 20 行相同 = 21 行连续未改动 → 保留首尾各 3 行，省略 15 行。
    expect(find.textContaining('省略 15 行未改动'), findsOneWidget);
    expect(find.text('相同-0'), findsOneWidget);
    expect(find.text('相同-19'), findsOneWidget);
    // 中间行被折叠，不应渲染。
    expect(find.text('相同-10'), findsNothing);
  });

  testWidgets('英文界面渲染英文标题与计数（i18n）', (tester) async {
    await pumpAndOpen(
      tester,
      oldText: 'One\nTwo',
      newText: 'One\nTwo\nThree',
      locale: const Locale('en'),
    );

    expect(find.text('Compare with current version'), findsOneWidget);
    expect(find.text('1 paragraph added'), findsOneWidget);
    expect(find.text('Three'), findsOneWidget);
  });
}
