import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';

class NovelPhoneApp extends ConsumerWidget {
  const NovelPhoneApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 深浅模式：设置页写入后 invalidate，此处自动切换；未加载完先跟随系统。
    final themeMode =
        ref.watch(appThemeModeProvider).value?.themeMode ?? ThemeMode.system;
    return MaterialApp.router(
      title: 'NovelPhone',
      debugShowCheckedModeBanner: false,
      theme: buildPaperTheme(),
      darkTheme: buildPaperTheme(Brightness.dark),
      themeMode: themeMode,
      routerConfig: appRouter,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const <Locale>[Locale('zh', 'CN'), Locale('en')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
