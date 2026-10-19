import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/app/theme.dart';
import 'package:novelphone/core/ai/writing_preferences.dart';
import 'package:novelphone/features/editor/ai_feedback_dialog.dart';
import 'package:novelphone/l10n/generated/app_localizations.dart';

/// ENH-27：放弃原因采集弹窗的三种出口（取消 / 跳过 / 记录原因）。
void main() {
  Widget host(void Function(BuildContext) onOpen) {
    return MaterialApp(
      theme: buildPaperTheme(),
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => onOpen(context),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('选择原因后返回对应 reason', (tester) async {
    String? result;
    await tester.pumpWidget(
      host((context) async {
        result = await showAiDiscardReasonDialog(context);
      }),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('角色出戏'));
    await tester.pump();
    await tester.tap(find.text('记录并放弃'));
    await tester.pumpAndSettle();

    expect(result, AiFeedbackReason.offCharacter);
  });

  testWidgets('直接放弃返回空串，取消返回 null', (tester) async {
    String? result;
    await tester.pumpWidget(
      host((context) async {
        result = await showAiDiscardReasonDialog(context);
      }),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('直接放弃'));
    await tester.pumpAndSettle();
    expect(result, '');

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
