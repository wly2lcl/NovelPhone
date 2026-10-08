import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data_providers.dart';
import 'theme.dart';

/// 写作/阅读外观（B-04）：夜间纸张 + 正文字号 + 行距。
/// 仅作用于写作场景（编辑器写作区与其工具栏/状态栏），对齐 PRD「深夜沉浸」。
class ReadingAppearance {
  const ReadingAppearance({
    this.dark = false,
    this.fontSize = 17,
    this.lineHeight = 1.8,
  });

  /// 夜间纸张（护眼深色）。
  final bool dark;

  /// 正文字号（[minFontSize] ~ [maxFontSize]）。
  final double fontSize;

  /// 正文行距倍数（[minLineHeight] ~ [maxLineHeight]）。
  final double lineHeight;

  /// 落 APP_SETTING 的键（值为 JSON 字符串）。
  static const String settingKey = 'reader_appearance';

  static const double minFontSize = 14;
  static const double maxFontSize = 24;
  static const double minLineHeight = 1.4;
  static const double maxLineHeight = 2.4;

  ReadingAppearance copyWith({bool? dark, double? fontSize, double? lineHeight}) {
    return ReadingAppearance(
      dark: dark ?? this.dark,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
    );
  }

  String encode() => jsonEncode(<String, dynamic>{
        'dark': dark,
        'fontSize': fontSize,
        'lineHeight': lineHeight,
      });

  /// 解析设置值；缺失或脏数据一律回落到默认外观，并把数值夹到合法区间。
  factory ReadingAppearance.decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const ReadingAppearance();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final map = decoded.cast<String, dynamic>();
        return ReadingAppearance(
          dark: map['dark'] as bool? ?? false,
          fontSize: _clampDouble(
            map['fontSize'],
            17,
            minFontSize,
            maxFontSize,
          ),
          lineHeight: _clampDouble(
            map['lineHeight'],
            1.8,
            minLineHeight,
            maxLineHeight,
          ),
        );
      }
    } catch (_) {
      // 容忍历史脏数据
    }
    return const ReadingAppearance();
  }
}

double _clampDouble(Object? value, double fallback, double min, double max) {
  final number = value is num ? value.toDouble() : fallback;
  return number.clamp(min, max).toDouble();
}

/// 写作场景配色：纸质（亮）/ 夜间（暗）。
class ReadingPalette {
  const ReadingPalette({
    required this.background,
    required this.surface,
    required this.ink,
    required this.inkSoft,
    required this.accent,
    required this.divider,
  });

  final Color background;
  final Color surface;
  final Color ink;
  final Color inkSoft;
  final Color accent;
  final Color divider;

  static const ReadingPalette paper = ReadingPalette(
    background: PaperColors.background,
    surface: PaperColors.surface,
    ink: PaperColors.ink,
    inkSoft: PaperColors.inkSoft,
    accent: PaperColors.accent,
    divider: PaperColors.divider,
  );

  /// 夜间纸张：深墨底 + 暖白字，避免纯黑纯白的高对比刺眼。
  static const ReadingPalette night = ReadingPalette(
    background: Color(0xFF1E1B17),
    surface: Color(0xFF252119),
    ink: Color(0xFFE8DFD0),
    inkSoft: Color(0xFF9C9080),
    accent: Color(0xFFC68A5A),
    divider: Color(0xFF3A342B),
  );

  static ReadingPalette of(ReadingAppearance appearance) =>
      appearance.dark ? night : paper;
}

/// 当前写作外观（设置页写入后 `ref.invalidate` 使编辑器立即生效）。
final readingAppearanceProvider = FutureProvider<ReadingAppearance>((ref) async {
  final raw = await ref
      .watch(settingsRepositoryProvider)
      .getSetting(ReadingAppearance.settingKey);
  return ReadingAppearance.decode(raw);
});