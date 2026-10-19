import 'package:flutter/services.dart';

/// 截屏 / 录屏 / 后台缩略图保护（ENH-26）。
///
/// Android 通过 `FLAG_SECURE` 阻止截屏、录屏与最近任务缩略图；
/// iOS 在应用失活时以原生遮罩覆盖窗口（系统快照不含正文）。
/// 桌面与 widget 测试环境没有原生实现，调用失败时静默跳过。
class ScreenProtection {
  const ScreenProtection._();

  static const MethodChannel channel = MethodChannel('novelphone/security');

  static Future<void> setEnabled(bool enabled) async {
    try {
      await channel.invokeMethod<void>('setSecureScreen', <String, dynamic>{
        'enabled': enabled,
      });
    } on MissingPluginException {
      // 无原生实现的平台不影响设置保存与业务。
    } on PlatformException {
      // 原生调用失败时保持当前窗口状态。
    }
  }
}
