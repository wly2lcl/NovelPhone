import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/app/theme.dart';
import 'package:novelphone/core/exporter/backup_archive.dart';
import 'package:novelphone/features/settings/backup_actions.dart';
import 'package:novelphone/l10n/generated/app_localizations.dart';

void main() {
  const preview = BackupPreview(
    checksumVerified: true,
    schemaVersion: 11,
    works: 1,
    chapters: 2,
    characters: 3,
  );

  Widget wrap(ValueChanged<Future<bool>> onResult, BackupPreview value) {
    return MaterialApp(
      theme: buildPaperTheme(),
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => onResult(showBackupPreviewDialog(context, value)),
            child: const Text('open'),
          ),
        ),
      ),
    );
  }

  testWidgets('预览展示数量与校验状态，取消不恢复', (tester) async {
    late Future<bool> result;
    await tester.pumpWidget(wrap((value) => result = value, preview));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('恢复前确认'), findsOneWidget);
    expect(find.text('1 部作品 · 2 章 · 3 个角色卡'), findsOneWidget);
    expect(find.text('数据版本：v11'), findsOneWidget);
    expect(find.text('SHA-256 完整性校验通过'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(await result, isFalse);
  });

  testWidgets('旧版备份提示未校验，继续恢复返回 true', (tester) async {
    late Future<bool> result;
    await tester.pumpWidget(
      wrap(
        (value) => result = value,
        const BackupPreview(checksumVerified: false, works: 1),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('旧版备份，未包含完整性校验信息'), findsOneWidget);

    await tester.tap(find.text('继续恢复'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
  });
}
