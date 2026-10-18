import 'package:local_auth/local_auth.dart';

/// 应用锁的系统验证入口（ENH-25）：测试可注入假实现，避免依赖原生插件。
abstract interface class AppLockAuthenticator {
  Future<bool> isAvailable();

  Future<bool> authenticate({required String reason});
}

/// 真机实现：优先指纹 / 面容，允许回退到锁屏密码 / 图案。
class LocalAuthAppLockAuthenticator implements AppLockAuthenticator {
  LocalAuthAppLockAuthenticator({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } on Exception {
      return false;
    }
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
        sensitiveTransaction: true,
      );
    } on Exception {
      return false;
    }
  }
}
