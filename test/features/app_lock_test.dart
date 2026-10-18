import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/app/app_lock_gate.dart';
import 'package:novelphone/app/theme.dart';
import 'package:novelphone/core/security/app_lock_auth.dart';
import 'package:novelphone/data/data_providers.dart';
import 'package:novelphone/data/db.dart';
import 'package:novelphone/data/repositories/settings_repository.dart';
import 'package:novelphone/data/secure_key_store.dart';
import 'package:novelphone/features/settings/app_lock_controller.dart';
import 'package:novelphone/l10n/generated/app_localizations.dart';

class _FakeAuthenticator implements AppLockAuthenticator {
  bool available = true;
  bool result = true;
  int calls = 0;
  String? lastReason;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate({required String reason}) async {
    calls++;
    lastReason = reason;
    return result;
  }
}

void main() {
  late AppDatabase db;
  late SettingsRepository settings;
  late _FakeAuthenticator auth;

  setUp(() async {
    db = AppDatabase.memory();
    settings = SettingsRepository(db, InMemoryKeyStore());
    auth = _FakeAuthenticator();
  });

  tearDown(() async {
    await db.close();
  });

  test('初始化时开启则锁定，验证通过后解锁', () async {
    await settings.setAppLockEnabled(true);
    final controller = AppLockController(
      settings: settings,
      authenticator: auth,
    );

    await controller.initialize();
    expect(controller.locked, isTrue);

    expect(await controller.unlock(reason: '解锁 NovelPhone'), isTrue);
    expect(controller.locked, isFalse);
    expect(auth.calls, 1);
    expect(auth.lastReason, '解锁 NovelPhone');
  });

  test('回到前台时锁定一次，验证失败保持锁定', () async {
    await settings.setAppLockEnabled(true);
    final controller = AppLockController(
      settings: settings,
      authenticator: auth,
    );
    await controller.initialize();
    await controller.unlock(reason: '解锁');
    expect(controller.locked, isFalse);

    auth.result = false;
    controller.onBackground();
    expect(controller.consumePendingLock(), isTrue);
    expect(controller.locked, isTrue);
    expect(await controller.unlock(reason: '解锁'), isFalse);
    expect(controller.locked, isTrue);
    expect(controller.lastAuthFailed, isTrue);

    auth.result = true;
    expect(await controller.unlock(reason: '解锁'), isTrue);
    expect(controller.locked, isFalse);
  });

  test('开启应用锁需要系统验证，不可用时拒绝开启', () async {
    final controller = AppLockController(
      settings: settings,
      authenticator: auth,
    );
    await controller.initialize();

    auth.available = false;
    expect(
      await controller.enable(reason: '验证身份'),
      AppLockToggleResult.unavailable,
    );
    expect(await settings.appLockEnabled(), isFalse);
    expect(auth.calls, 0);

    auth.available = true;
    auth.result = false;
    expect(await controller.enable(reason: '验证身份'), AppLockToggleResult.denied);
    expect(await settings.appLockEnabled(), isFalse);

    auth.result = true;
    expect(
      await controller.enable(reason: '验证身份'),
      AppLockToggleResult.enabled,
    );
    expect(await settings.appLockEnabled(), isTrue);
    expect(controller.enabled, isTrue);
  });

  test('关闭应用锁同样需要验证', () async {
    await settings.setAppLockEnabled(true);
    final controller = AppLockController(
      settings: settings,
      authenticator: auth,
    );
    await controller.initialize();
    await controller.unlock(reason: '解锁');

    auth.result = false;
    expect(
      await controller.disable(reason: '验证身份'),
      AppLockToggleResult.denied,
    );
    expect(await settings.appLockEnabled(), isTrue);

    auth.result = true;
    expect(
      await controller.disable(reason: '验证身份'),
      AppLockToggleResult.disabled,
    );
    expect(await settings.appLockEnabled(), isFalse);
    expect(await settings.appLockEnabled(), isFalse);
  });

  testWidgets('锁屏覆盖层：验证失败保留内容，验证通过后恢复', (tester) async {
    await settings.setAppLockEnabled(true);
    auth.result = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          secureKeyStoreProvider.overrideWithValue(InMemoryKeyStore()),
          appLockAuthenticatorProvider.overrideWithValue(auth),
        ],
        child: MaterialApp(
          theme: buildPaperTheme(),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) =>
              AppLockGate(child: child ?? const SizedBox.shrink()),
          home: const Scaffold(body: Text('秘密正文')),
        ),
      ),
    );

    for (var i = 0; i < 60; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      if (find.text('验证未通过，请重试').evaluate().isNotEmpty) break;
    }

    expect(find.text('应用已锁定'), findsOneWidget);
    expect(find.text('验证未通过，请重试'), findsOneWidget);
    expect(find.text('秘密正文'), findsNothing);

    auth.result = true;
    await tester.tap(find.widgetWithText(FilledButton, '解锁'));
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      if (find.text('秘密正文').evaluate().isNotEmpty) break;
    }

    expect(find.text('应用已锁定'), findsNothing);
    expect(find.text('秘密正文'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('关闭应用锁时不遮挡内容', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          secureKeyStoreProvider.overrideWithValue(InMemoryKeyStore()),
          appLockAuthenticatorProvider.overrideWithValue(auth),
        ],
        child: MaterialApp(
          theme: buildPaperTheme(),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) =>
              AppLockGate(child: child ?? const SizedBox.shrink()),
          home: const Scaffold(body: Text('秘密正文')),
        ),
      ),
    );

    for (var i = 0; i < 60; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      if (find.text('秘密正文').evaluate().isNotEmpty) break;
    }

    expect(find.text('应用已锁定'), findsNothing);
    expect(find.text('秘密正文'), findsOneWidget);
    expect(auth.calls, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
}
