import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/app/reading_appearance.dart';
import 'package:novelphone/app/theme.dart';
import 'package:novelphone/data/data_providers.dart';
import 'package:novelphone/data/db.dart';
import 'package:novelphone/data/repositories/chapter_repository.dart';
import 'package:novelphone/data/repositories/settings_repository.dart';
import 'package:novelphone/data/repositories/work_repository.dart';
import 'package:novelphone/data/secure_key_store.dart';
import 'package:novelphone/features/editor/editor_page.dart';
import 'package:novelphone/features/settings/appearance_page.dart';

void main() {
  group('ReadingAppearance 解析', () {
    test('缺省与脏数据回落到默认外观', () {
      for (final raw in <String?>[null, '', 'not-json', '[]']) {
        final appearance = ReadingAppearance.decode(raw);
        expect(appearance.dark, isFalse);
        expect(appearance.fontSize, 17);
        expect(appearance.lineHeight, 1.8);
      }
    });

    test('encode / decode 往返', () {
      const appearance = ReadingAppearance(
        dark: true,
        fontSize: 21,
        lineHeight: 2.2,
      );
      final restored = ReadingAppearance.decode(appearance.encode());
      expect(restored.dark, isTrue);
      expect(restored.fontSize, 21);
      expect(restored.lineHeight, 2.2);
    });

    test('越界数值被夹到合法区间', () {
      final big = ReadingAppearance.decode(
        '{"dark":true,"fontSize":99,"lineHeight":9}',
      );
      expect(big.fontSize, ReadingAppearance.maxFontSize);
      expect(big.lineHeight, ReadingAppearance.maxLineHeight);

      final small = ReadingAppearance.decode('{"fontSize":1,"lineHeight":0.1}');
      expect(small.fontSize, ReadingAppearance.minFontSize);
      expect(small.lineHeight, ReadingAppearance.minLineHeight);
    });

    test('夜间与纸质配色解析', () {
      expect(
        ReadingPalette.of(const ReadingAppearance()).surface,
        PaperPalette.light.surface,
      );
      expect(
        ReadingPalette.of(const ReadingAppearance(dark: true)).surface,
        ReadingPalette.night.surface,
      );
      expect(ReadingPalette.night.ink, isNot(PaperPalette.light.ink));
    });
  });

  group('全局深浅模式', () {
    test('buildPaperTheme 亮/暗各挂载对应调色板', () {
      final light = buildPaperTheme();
      expect(light.brightness, Brightness.light);
      expect(light.extension<PaperPalette>(), PaperPalette.light);
      expect(light.scaffoldBackgroundColor, PaperPalette.light.background);

      final dark = buildPaperTheme(Brightness.dark);
      expect(dark.brightness, Brightness.dark);
      expect(dark.extension<PaperPalette>(), PaperPalette.dark);
      expect(dark.scaffoldBackgroundColor, PaperPalette.dark.background);
    });

    test('AppThemeMode.decode 解析与脏数据回落', () {
      expect(AppThemeMode.decode('dark'), AppThemeMode.dark);
      expect(AppThemeMode.decode('light'), AppThemeMode.light);
      expect(AppThemeMode.decode('system'), AppThemeMode.system);
      expect(AppThemeMode.decode(null), AppThemeMode.system);
      expect(AppThemeMode.decode(''), AppThemeMode.system);
      expect(AppThemeMode.decode('乱码'), AppThemeMode.system);
    });

    test('AppThemeMode 映射到 ThemeMode', () {
      expect(AppThemeMode.dark.themeMode, ThemeMode.dark);
      expect(AppThemeMode.light.themeMode, ThemeMode.light);
      expect(AppThemeMode.system.themeMode, ThemeMode.system);
    });
  });

  group('写作外观落地', () {
    late AppDatabase db;
    late SettingsRepository settings;
    late int workId;
    late int chapterId;

    Future<void> seed(ReadingAppearance appearance) async {
      db = AppDatabase.memory();
      settings = SettingsRepository(db, InMemoryKeyStore());
      final works = WorkRepository(db);
      final chapters = ChapterRepository(db);
      workId = await works.createWork(title: '长夜行');
      chapterId = await chapters.createChapter(workId: workId, title: '第一章');
      await chapters.saveChapter(
        chapterId: chapterId,
        title: '第一章',
        content: '她不禁笑了。',
      );
      await settings.setSetting(
        ReadingAppearance.settingKey,
        appearance.encode(),
      );
    }

    tearDown(() async {
      await db.close();
    });

    Widget wrap(Widget child) {
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          secureKeyStoreProvider.overrideWithValue(InMemoryKeyStore()),
        ],
        child: MaterialApp(theme: buildPaperTheme(), home: child),
      );
    }

    /// 推进真实事件循环：drift 查询是真实异步。
    Future<void> settle(WidgetTester tester, Finder until) async {
      for (var i = 0; i < 40; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
        if (until.evaluate().isNotEmpty) return;
      }
    }

    Future<void> closePage(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
    }

    testWidgets('夜间外观下编辑器用夜间配色与自定义字号', (tester) async {
      await seed(
        const ReadingAppearance(dark: true, fontSize: 21, lineHeight: 2.2),
      );
      await tester.pumpWidget(
        wrap(EditorPage(workId: workId, chapterId: chapterId)),
      );
      await settle(tester, find.byType(TextField));
      // 等外观 FutureProvider 完成加载
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.style!.color, ReadingPalette.night.ink);
      expect(field.style!.fontSize, 21);
      expect(field.style!.height, 2.2);

      final container = tester.widget<Container>(
        find
            .ancestor(
              of: find.byType(TextField),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(container.color, ReadingPalette.night.surface);

      await closePage(tester);
    });

    testWidgets('设置页切换夜间后写入设置并刷新读取结果', (tester) async {
      await seed(const ReadingAppearance());
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          secureKeyStoreProvider.overrideWithValue(InMemoryKeyStore()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildPaperTheme(),
            home: const AppearancePage(),
          ),
        ),
      );
      await settle(tester, find.text('夜间纸张'));

      await tester.tap(find.byType(Switch));
      await tester.pump();

      final saved = ReadingAppearance.decode(
        await settings.getSetting(ReadingAppearance.settingKey),
      );
      expect(saved.dark, isTrue);
      // 读取结果已失效并按新值重算
      final reloaded = await container.read(readingAppearanceProvider.future);
      expect(reloaded.dark, isTrue);

      await closePage(tester);
    });
  });
}
