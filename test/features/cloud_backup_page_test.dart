import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/app/theme.dart';
import 'package:novelphone/data/data_providers.dart';
import 'package:novelphone/data/db.dart';
import 'package:novelphone/data/repositories/settings_repository.dart';
import 'package:novelphone/data/secure_key_store.dart';
import 'package:novelphone/features/settings/cloud_backup_page.dart';
import 'package:novelphone/l10n/generated/app_localizations.dart';
import 'package:novelphone/models/cloud_backup_config.dart';

/// B-08：云备份设置页交互（默认关闭不联网，开启后展示并落库）。
void main() {
  testWidgets('默认关闭隐藏服务商字段，开启后展示并落库', (tester) async {
    final db = AppDatabase.memory();
    final keyStore = InMemoryKeyStore();
    final settings = SettingsRepository(db, keyStore);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          secureKeyStoreProvider.overrideWithValue(keyStore),
        ],
        child: MaterialApp(
          theme: buildPaperTheme(),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CloudBackupPage(),
        ),
      ),
    );
    for (var i = 0; i < 60; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      if (find.text('启用云备份').evaluate().isNotEmpty) break;
    }

    expect(find.text('云备份'), findsOneWidget);
    expect(find.text('启用云备份'), findsOneWidget);
    // 默认关闭：不展示服务商配置项（关闭时不联网）。
    expect(find.text('服务商'), findsNothing);

    await tester.tap(find.widgetWithText(SwitchListTile, '启用云备份'));
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      if (find.text('服务商').evaluate().isNotEmpty) break;
    }

    expect(find.text('服务商'), findsOneWidget);
    expect(find.text('Region'), findsOneWidget);

    // 开关状态已落库。
    final config = await settings.cloudBackupConfig();
    expect(config.enabled, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    await db.close();
  });

  testWidgets('开启自动备份后展示频率选项并落库', (tester) async {
    // 加高视口，保证 ListView 底部的自动备份区被构建。
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.memory();
    final keyStore = InMemoryKeyStore();
    final settings = SettingsRepository(db, keyStore);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          secureKeyStoreProvider.overrideWithValue(keyStore),
        ],
        child: MaterialApp(
          theme: buildPaperTheme(),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CloudBackupPage(),
        ),
      ),
    );
    for (var i = 0; i < 60; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      if (find.text('启用云备份').evaluate().isNotEmpty) break;
    }

    Future<void> settle() async {
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
    }

    // 先开总开关，自动备份区才可见。
    await tester.tap(find.widgetWithText(SwitchListTile, '启用云备份'));
    await settle();
    expect(find.text('自动备份'), findsOneWidget);
    expect(find.text('备份频率'), findsNothing);

    await tester.tap(find.widgetWithText(SwitchListTile, '自动备份'));
    await settle();
    expect(find.text('备份频率'), findsOneWidget);

    final config = await settings.cloudBackupConfig();
    expect(config.autoEnabled, isTrue);
    expect(config.autoInterval, CloudAutoInterval.daily);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    await db.close();
  });
}
