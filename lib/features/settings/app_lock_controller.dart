import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/app_lock_auth.dart';
import '../../data/data_providers.dart';
import '../../data/repositories/settings_repository.dart';

/// 应用锁开关操作结果（设置页据此提示，不抛异常到 UI）。
enum AppLockToggleResult { enabled, disabled, denied, unavailable, busy }

/// 应用锁状态机（ENH-25）：启动 / 回前台锁定，验证通过后解锁。
/// 原生验证通过 [AppLockAuthenticator] 注入，便于 widget / 单元测试。
class AppLockController extends ChangeNotifier {
  AppLockController({required this.settings, required this.authenticator});

  final SettingsRepository settings;
  final AppLockAuthenticator authenticator;

  bool _initialized = false;
  bool _enabled = false;
  bool _locked = false;
  bool _busy = false;
  bool _pendingLock = false;
  bool _lastAuthFailed = false;

  bool get initialized => _initialized;
  bool get enabled => _enabled;
  bool get locked => _locked;

  /// 系统验证进行中：期间忽略前后台切换，避免验证弹窗自身触发再次锁定。
  bool get busy => _busy;
  bool get lastAuthFailed => _lastAuthFailed;

  Future<void> initialize() async {
    if (_initialized) return;
    _enabled = await settings.appLockEnabled();
    _locked = _enabled;
    _initialized = true;
    notifyListeners();
  }

  /// App 进入后台：仅在已开启、已解锁且未在验证时挂起一次锁定。
  void onBackground() {
    if (!_initialized || !_enabled || _busy || _locked) return;
    _pendingLock = true;
  }

  /// 回到前台：消费挂起的锁定并返回是否需要立即验证。
  bool consumePendingLock() {
    if (!_pendingLock) return false;
    _pendingLock = false;
    if (!_enabled || _busy) return false;
    _locked = true;
    notifyListeners();
    return true;
  }

  /// 解锁；已解锁时直接返回 true。
  Future<bool> unlock({required String reason}) async {
    if (!_locked) return true;
    if (_busy) return false;
    _busy = true;
    _lastAuthFailed = false;
    notifyListeners();
    try {
      final ok = await authenticator.authenticate(reason: reason);
      if (ok) {
        _locked = false;
      } else {
        _lastAuthFailed = true;
      }
      return ok;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// 开启应用锁：必须先通过一次系统验证，避免他人远程开启后把机主锁在门外。
  Future<AppLockToggleResult> enable({required String reason}) async {
    if (_enabled) return AppLockToggleResult.enabled;
    if (_busy) return AppLockToggleResult.busy;
    if (!await authenticator.isAvailable()) {
      return AppLockToggleResult.unavailable;
    }
    _busy = true;
    notifyListeners();
    try {
      final ok = await authenticator.authenticate(reason: reason);
      if (!ok) return AppLockToggleResult.denied;
      await settings.setAppLockEnabled(true);
      _enabled = true;
      _locked = false;
      _pendingLock = false;
      _lastAuthFailed = false;
      return AppLockToggleResult.enabled;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// 关闭应用锁：同样要求先验证，防止他人直接关闭保护。
  Future<AppLockToggleResult> disable({required String reason}) async {
    if (!_enabled) return AppLockToggleResult.disabled;
    if (_busy) return AppLockToggleResult.busy;
    _busy = true;
    notifyListeners();
    try {
      final ok = await authenticator.authenticate(reason: reason);
      if (!ok) return AppLockToggleResult.denied;
      await settings.setAppLockEnabled(false);
      _enabled = false;
      _locked = false;
      _pendingLock = false;
      _lastAuthFailed = false;
      return AppLockToggleResult.disabled;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}

final appLockAuthenticatorProvider = Provider<AppLockAuthenticator>(
  (ref) => LocalAuthAppLockAuthenticator(),
);

final appLockControllerProvider = Provider<AppLockController>((ref) {
  final controller = AppLockController(
    settings: ref.watch(settingsRepositoryProvider),
    authenticator: ref.watch(appLockAuthenticatorProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

/// 设置页开关状态（落库事实来源，控制器操作后由 drift 流自动刷新）。
final appLockEnabledProvider = StreamProvider<bool>(
  (ref) => ref.watch(settingsRepositoryProvider).watchAppLockEnabled(),
);
