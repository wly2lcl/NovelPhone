import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data_providers.dart';

/// 暖色纸质调色板（PRD 5.3）：亮/暗两套，作为 ThemeExtension 挂在 ThemeData 上，
/// 调用侧用 `context.paper.x` 读取——依赖 Theme 才能在切换深浅模式时自动重建。
@immutable
class PaperPalette extends ThemeExtension<PaperPalette> {
  const PaperPalette({
    required this.background,
    required this.surface,
    required this.ink,
    required this.inkSoft,
    required this.accent,
    required this.divider,
  });

  /// 亮色纸张（原 PaperColors 色值）。
  static const PaperPalette light = PaperPalette(
    background: Color(0xFFF4EDE1),
    surface: Color(0xFFFBF6EC),
    ink: Color(0xFF3A342C),
    inkSoft: Color(0xFF837868),
    accent: Color(0xFFA2673F),
    divider: Color(0xFFE2D7C3),
  );

  /// 夜间纸张：深墨底 + 暖白字，避免纯黑纯白的高对比刺眼。
  static const PaperPalette dark = PaperPalette(
    background: Color(0xFF1E1B17),
    surface: Color(0xFF252119),
    ink: Color(0xFFE8DFD0),
    inkSoft: Color(0xFF9C9080),
    accent: Color(0xFFC68A5A),
    divider: Color(0xFF3A342B),
  );

  /// 页面底色：纸张米黄 / 夜间深墨。
  final Color background;

  /// 卡片/面板底色：略浅的纸面。
  final Color surface;

  /// 正文墨色。
  final Color ink;

  /// 次级文字（字数、时间、提示）。
  final Color inkSoft;

  /// 主强调色：赭石。
  final Color accent;

  /// 分隔线与描边。
  final Color divider;

  static PaperPalette of(BuildContext context) =>
      Theme.of(context).extension<PaperPalette>() ?? light;

  @override
  PaperPalette copyWith({
    Color? background,
    Color? surface,
    Color? ink,
    Color? inkSoft,
    Color? accent,
    Color? divider,
  }) {
    return PaperPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      ink: ink ?? this.ink,
      inkSoft: inkSoft ?? this.inkSoft,
      accent: accent ?? this.accent,
      divider: divider ?? this.divider,
    );
  }

  @override
  PaperPalette lerp(ThemeExtension<PaperPalette>? other, double t) {
    if (other is! PaperPalette) return this;
    return PaperPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
    );
  }
}

/// 便捷读取当前调色板：`context.paper.ink`。
extension PaperPaletteContext on BuildContext {
  PaperPalette get paper => PaperPalette.of(this);
}

/// 衬线字体族：优先系统自带的中文衬线字体，末位回落到通用 serif。
const String kSerifFontFamily = 'serif';
const List<String> kSerifFontFallback = <String>[
  'Songti SC',
  'Noto Serif CJK SC',
  'Noto Serif SC',
  'Source Han Serif SC',
];

/// 全局深浅模式：跟随系统 / 浅色 / 深色。落 APP_SETTING 的键 [settingKey]。
enum AppThemeMode {
  system('system', '跟随系统'),
  light('light', '浅色'),
  dark('dark', '深色');

  const AppThemeMode(this.value, this.label);

  /// 持久化值（也用于反序列化）。
  final String value;

  /// 设置页展示文案。
  final String label;

  /// 落 APP_SETTING 的键。
  static const String settingKey = 'app_theme_mode';

  ThemeMode get themeMode => switch (this) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };

  /// 解析设置值；缺失或脏数据一律回落到「跟随系统」。
  static AppThemeMode decode(String? raw) {
    for (final mode in AppThemeMode.values) {
      if (mode.value == raw) return mode;
    }
    return AppThemeMode.system;
  }
}

/// 当前深浅模式（设置页写入后 `ref.invalidate` 使全局立即生效）。
final appThemeModeProvider = FutureProvider<AppThemeMode>((ref) async {
  final raw = await ref
      .watch(settingsRepositoryProvider)
      .getSetting(AppThemeMode.settingKey);
  return AppThemeMode.decode(raw);
});

/// 按亮度构建主题；亮/暗各注册一套 [PaperPalette] 供 `context.paper` 读取。
ThemeData buildPaperTheme([Brightness brightness = Brightness.light]) {
  final palette = brightness == Brightness.dark
      ? PaperPalette.dark
      : PaperPalette.light;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: palette.accent,
        brightness: brightness,
      ).copyWith(
        surface: palette.surface,
        onSurface: palette.ink,
        primary: palette.accent,
        onPrimary: Colors.white,
        outlineVariant: palette.divider,
      );

  final base = brightness == Brightness.dark
      ? Typography.material2021().white
      : Typography.material2021().black;
  TextStyle serif(TextStyle? style, {FontWeight? weight}) =>
      (style ?? const TextStyle()).copyWith(
        fontFamily: kSerifFontFamily,
        fontFamilyFallback: kSerifFontFallback,
        fontWeight: weight,
        color: palette.ink,
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
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.background,
    textTheme: textTheme,
    extensions: <ThemeExtension<dynamic>>[palette],
    appBarTheme: AppBarTheme(
      backgroundColor: palette.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: palette.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: kSerifFontFamily,
        fontFamilyFallback: kSerifFontFallback,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: palette.ink,
      ),
    ),
    cardTheme: CardThemeData(
      color: palette.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    dividerTheme: DividerThemeData(
      color: palette.divider,
      space: 1,
      thickness: 1,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: palette.accent,
      unselectedLabelColor: palette.inkSoft,
      indicatorColor: palette.accent,
      dividerColor: palette.divider,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: palette.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: palette.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: palette.accent, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: palette.accent,
      foregroundColor: Colors.white,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: palette.ink,
      contentTextStyle: TextStyle(color: palette.background),
    ),
  );
}
