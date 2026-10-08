import 'package:flutter/material.dart';

/// 暖色纸质主题配色（PRD 5.3：正文编辑区衬线字体 + 暖色纸质背景）。
class PaperColors {
  const PaperColors._();

  /// 页面底色：纸张米黄。
  static const Color background = Color(0xFFF4EDE1);

  /// 卡片/面板底色：略浅的纸面。
  static const Color surface = Color(0xFFFBF6EC);

  /// 正文墨色。
  static const Color ink = Color(0xFF3A342C);

  /// 次级文字（字数、时间、提示）。
  static const Color inkSoft = Color(0xFF837868);

  /// 主强调色：赭石。
  static const Color accent = Color(0xFFA2673F);

  /// 分隔线与描边。
  static const Color divider = Color(0xFFE2D7C3);
}

/// 衬线字体族：优先系统自带的中文衬线字体，末位回落到通用 serif。
const String kSerifFontFamily = 'serif';
const List<String> kSerifFontFallback = <String>[
  'Songti SC',
  'Noto Serif CJK SC',
  'Noto Serif SC',
  'Source Han Serif SC',
];

ThemeData buildPaperTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: PaperColors.accent,
    brightness: Brightness.light,
  ).copyWith(
    surface: PaperColors.surface,
    onSurface: PaperColors.ink,
    primary: PaperColors.accent,
    onPrimary: Colors.white,
    outlineVariant: PaperColors.divider,
  );

  final base = Typography.material2021().black;
  TextStyle serif(TextStyle? style, {FontWeight? weight}) => (style ?? const TextStyle())
      .copyWith(
    fontFamily: kSerifFontFamily,
    fontFamilyFallback: kSerifFontFallback,
    fontWeight: weight,
    color: PaperColors.ink,
  );

  final textTheme = base.copyWith(
    displaySmall: serif(base.displaySmall, weight: FontWeight.w600),
    headlineMedium: serif(base.headlineMedium, weight: FontWeight.w600),
    headlineSmall: serif(base.headlineSmall, weight: FontWeight.w600),
    titleLarge: serif(base.titleLarge, weight: FontWeight.w600),
    titleMedium: serif(base.titleMedium, weight: FontWeight.w600),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: PaperColors.background,
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: PaperColors.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: PaperColors.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: kSerifFontFamily,
        fontFamilyFallback: kSerifFontFallback,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: PaperColors.ink,
      ),
    ),
    cardTheme: const CardThemeData(
      color: PaperColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(
      color: PaperColors.divider,
      space: 1,
      thickness: 1,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: PaperColors.accent,
      unselectedLabelColor: PaperColors.inkSoft,
      indicatorColor: PaperColors.accent,
      dividerColor: PaperColors.divider,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: PaperColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: PaperColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: PaperColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: PaperColors.accent, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: PaperColors.accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: PaperColors.accent,
      foregroundColor: Colors.white,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: PaperColors.surface,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: PaperColors.ink,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
  );
}