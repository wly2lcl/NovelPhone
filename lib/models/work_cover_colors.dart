import 'package:flutter/material.dart';

/// 作品封面预设色板（PRD 5.1：8 色预设，默认随机）。
class WorkCoverColors {
  const WorkCoverColors._();

  static const List<Color> palette = <Color>[
    Color(0xFFB4654A), // 赭红
    Color(0xFFA8763E), // 秋栗
    Color(0xFF7C8B5A), // 苔绿
    Color(0xFF5B7C86), // 黛青
    Color(0xFF6B6B8D), // 紫灰
    Color(0xFF8C6E7A), // 绛紫
    Color(0xFF9C7B52), // 陶土
    Color(0xFF5F6B5A), // 松墨
  ];

  /// 随机取一个预设色（转换为 ARGB 存储值）。
  static int random() => palette[DateTime.now().microsecond % palette.length].toARGB32();

  static Color of(int argb) => Color(argb);
}