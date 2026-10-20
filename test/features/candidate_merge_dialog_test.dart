import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/app/theme.dart';
import 'package:novelphone/features/editor/candidate_merge_dialog.dart';
import 'package:novelphone/l10n/generated/app_localizations.dart';

/// ENH-36：跨候选段落组合的默认选择与逐段切换。
void main() {
  testWidgets('默认跟随当前候选，可逐段改选其他候选', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? mixed;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildPaperTheme(),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  mixed = await showCandidateMergeDialog(
                    context,
                    candidates: const <String>[
                      '一。\n二。',
                      'A。\nB。\nC。',
                      '甲。\n乙。',
                    ],
                    selectedIndex: 1,
                  );
                },
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.text('跨候选组合'), findsOneWidget);
    expect(find.text('第 1 段'), findsOneWidget);
    expect(find.text('第 3 段'), findsOneWidget);
    expect(find.text('组合并采纳 3 段'), findsOneWidget);
    expect(find.text('A。'), findsOneWidget);

    // 第 1 段切到候选 3，第 2 段切回候选 1。
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey<String>('mix-slot-0')),
        matching: find.text('候选 3'),
      ),
    );
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey<String>('mix-slot-1')),
        matching: find.text('候选 1'),
      ),
    );
    await tester.pump();
    expect(find.text('甲。'), findsOneWidget);
    expect(find.text('二。'), findsOneWidget);

    // 第 3 段只有候选 2 有内容，不显示选择器。
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('mix-slot-2')),
        matching: find.byType(SegmentedButton<int>),
      ),
      findsNothing,
    );

    await tester.tap(find.text('组合并采纳 3 段'));
    await tester.pumpAndSettle();
    expect(mixed, '甲。\n二。\nC。');
  });
}
