import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/app/theme.dart';
import 'package:novelphone/features/settings/about_page.dart';
import 'package:novelphone/l10n/generated/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// ENH-19：关于页（版本、隐私说明与开源许可）。
void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'NovelPhone',
      packageName: 'com.novelphone.app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  Future<void> pumpAbout(
    WidgetTester tester, {
    Locale locale = const Locale('zh'),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPaperTheme(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AboutPage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('展示版本号、隐私说明与开源许可入口（zh）', (tester) async {
    await pumpAbout(tester);

    expect(find.text('关于 NovelPhone'), findsOneWidget);
    expect(find.text('版本 1.0.0 (1)'), findsOneWidget);
    expect(find.text('隐私说明'), findsOneWidget);
    expect(find.text('默认不收集任何数据：无账号、无广告、无遥测。'), findsOneWidget);
    expect(find.text('开源许可'), findsOneWidget);
    expect(find.text('查看许可清单'), findsOneWidget);
  });

  testWidgets('点击查看许可清单进入许可页', (tester) async {
    await pumpAbout(tester);

    await tester.tap(find.text('查看许可清单'));
    await tester.pumpAndSettle();

    expect(find.byType(LicensePage), findsOneWidget);
  });

  testWidgets('英文界面渲染英文文案（i18n）', (tester) async {
    await pumpAbout(tester, locale: const Locale('en'));

    expect(find.text('About NovelPhone'), findsOneWidget);
    expect(find.text('Version 1.0.0 (1)'), findsOneWidget);
    expect(find.text('Privacy'), findsOneWidget);
    expect(find.text('View licenses'), findsOneWidget);
  });
}
