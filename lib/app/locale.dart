import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data_providers.dart';

/// 界面语言：跟随系统 / 简体中文 / English。落 APP_SETTING 的键 [settingKey]。
enum AppLocale {
  system('system', '跟随系统'),
  zh('zh', '简体中文'),
  en('en', 'English');

  const AppLocale(this.value, this.label);

  /// 持久化值（也用于反序列化）。
  final String value;

  /// 设置页展示文案。
  final String label;

  /// 落 APP_SETTING 的键。
  static const String settingKey = 'app_locale';

  /// 显式语言；跟随系统时为 null，交由 MaterialApp 走系统解析。
  Locale? get locale => switch (this) {
    AppLocale.system => null,
    AppLocale.zh => const Locale('zh'),
    AppLocale.en => const Locale('en'),
  };

  /// 解析设置值；缺失或脏数据一律回落到「跟随系统」。
  static AppLocale decode(String? raw) {
    for (final locale in AppLocale.values) {
      if (locale.value == raw) return locale;
    }
    return AppLocale.system;
  }
}

/// 当前界面语言（设置页写入后 `ref.invalidate` 使全局立即生效）。
final appLocaleProvider = FutureProvider<AppLocale>((ref) async {
  final raw = await ref
      .watch(settingsRepositoryProvider)
      .getSetting(AppLocale.settingKey);
  return AppLocale.decode(raw);
});
