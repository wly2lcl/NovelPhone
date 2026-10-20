import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/app/theme.dart';
import 'package:novelphone/data/data_providers.dart';
import 'package:novelphone/data/db.dart';
import 'package:novelphone/data/repositories/settings_repository.dart';
import 'package:novelphone/data/repositories/token_stats_repository.dart';
import 'package:novelphone/data/secure_key_store.dart';
import 'package:novelphone/features/settings/task_mapping_page.dart';
import 'package:novelphone/l10n/generated/app_localizations.dart';

/// ENH-37：任务映射页根据近 30 天采纳质量给出推荐并可一键切换。
void main() {
  testWidgets(
    '推荐高采纳模型，点击后写回映射并消失',
    timeout: const Timeout(Duration(seconds: 60)),
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final db = AppDatabase.memory();
      final settings = SettingsRepository(db, InMemoryKeyStore());
      final lowId = await settings.createModelGroup(
        name: '低成本',
        provider: 'openai_compat',
        baseUrl: 'https://api.example.com/v1',
        models: <String>['m1'],
        apiKey: 'sk-test',
      );
      final highId = await settings.createModelGroup(
        name: '高质量',
        provider: 'openai_compat',
        baseUrl: 'https://api.example.com/v1',
        models: <String>['m2'],
        apiKey: 'sk-test',
      );
      await settings.setTaskModel(AiTask.continueWriting, lowId);

      final stats = TokenStatsRepository(db);
      // m1：3 次调用、采纳率 10%；m2：3 次调用、采纳率 90%。
      for (var i = 0; i < 3; i++) {
        final low = await stats.record(
          task: AiTask.continueWriting,
          model: 'm1',
          outputChars: 100,
        );
        await stats.markAdopted(low, 10, editPercent: 60);
        final high = await stats.record(
          task: AiTask.continueWriting,
          model: 'm2',
          outputChars: 100,
        );
        await stats.markAdopted(high, 90, editPercent: 5);
      }

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            secureKeyStoreProvider.overrideWithValue(InMemoryKeyStore()),
          ],
          child: MaterialApp(
            theme: buildPaperTheme(),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const TaskMappingPage(),
          ),
        ),
      );

      for (var i = 0; i < 100; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
        if (find.text('按采纳质量推荐').evaluate().isNotEmpty) break;
      }

      expect(find.text('按采纳质量推荐'), findsOneWidget);
      expect(find.textContaining('采纳率 90%'), findsOneWidget);
      expect(find.text('当前：m1'), findsOneWidget);
      expect(find.text('改用「高质量」'), findsOneWidget);

      await tester.tap(find.text('改用「高质量」'));
      for (var i = 0; i < 50; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(await settings.taskModelId(AiTask.continueWriting), highId);
      expect(find.text('已切换到「高质量」'), findsOneWidget);
      expect(find.text('按采纳质量推荐'), findsNothing);

      // 卸载页面并让 Drift 的关闭流 / SnackBar 定时器走完，再关闭数据库。
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
      await db.close();
    },
  );
}
