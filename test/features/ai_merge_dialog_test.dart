import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/app/theme.dart';
import 'package:novelphone/features/editor/ai_merge_dialog.dart';
import 'package:novelphone/l10n/generated/app_localizations.dart';

/// ENH-27：段落级采纳弹窗的默认勾选、行内编辑与局部取消。
void main() {
  testWidgets('默认全选，可编辑文字并取消部分段落', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    AiMergeResult? mergedResult;

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
                  mergedResult = await showAiMergeDialog(
                    context,
                    text: '第一段。\n第二段。\n第三段。',
                    baseText: '第一段。',
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

    expect(find.text('分段采纳 AI 结果'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(3));
    expect(find.text('已选 3/3 段'), findsOneWidget);
    expect(find.text('改动'), findsNWidgets(2));

    await tester.enterText(find.byType(TextField).at(1), '第二段改。');
    await tester.tap(find.byType(Checkbox).at(2));
    await tester.pump();
    expect(find.text('已选 2/3 段'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '采用 2 段'));
    await tester.pumpAndSettle();
    expect(mergedResult?.text, '第一段。\n第二段改。');
    expect(mergedResult?.rejectedCount, 1);
  });

  testWidgets('全不选时不可确认，取消返回 null', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Object? result = '未变';

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
                  result = await showAiMergeDialog(context, text: '唯一一段。');
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
    await tester.tap(find.text('全不选'));
    await tester.pump();
    expect(find.text('已选 0/1 段'), findsOneWidget);
    final apply = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '采用 0 段'),
    );
    expect(apply.onPressed, isNull);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
