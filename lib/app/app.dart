import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import 'locale.dart';
import 'router.dart';
import 'theme.dart';

class NovelPhoneApp extends ConsumerWidget {
  const NovelPhoneApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 深浅模式：设置页写入后 invalidate，此处自动切换；未加载完先跟随系统。
    final themeMode =
        ref.watch(appThemeModeProvider).value?.themeMode ?? ThemeMode.system;
    // 语言：null 表示跟随系统；设置页写入后 invalidate 立即生效。
    final locale = ref.watch(appLocaleProvider).value?.locale;
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildPaperTheme(),
      darkTheme: buildPaperTheme(Brightness.dark),
      themeMode: themeMode,
      locale: locale,
      routerConfig: appRouter,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
