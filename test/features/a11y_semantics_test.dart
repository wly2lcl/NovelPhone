import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/app/theme.dart';
import 'package:novelphone/data/data_providers.dart';
import 'package:novelphone/data/db.dart';
import 'package:novelphone/data/repositories/settings_repository.dart';
import 'package:novelphone/data/secure_key_store.dart';
import 'package:novelphone/features/settings/skills_page.dart';
import 'package:novelphone/features/works/new_work_page.dart';
import 'package:novelphone/features/works/works_page.dart';
import 'package:novelphone/features/works/works_providers.dart';
import 'package:novelphone/l10n/generated/app_localizations.dart';

/// ENH-21：无障碍 Semantics 抽查（开关标签、色块按钮、长按操作自定义动作）。
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
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
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('技能开关带「启用「名称」」语义标签', (tester) async {
    final settings = SettingsRepository(db, InMemoryKeyStore());
    await settings.createSkill(name: '短句流', instruction: '保持短句');
    final handle = tester.ensureSemantics();
    await pump(tester, const SkillsPage());

    expect(find.bySemanticsLabel('启用「短句流」'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('新建作品色块是可点击的按钮节点', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, const NewWorkPage());

    expect(find.bySemanticsLabel('封面色块 1'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('作品卡把长按操作暴露为自定义语义动作', (tester) async {
    // 用 Stream.value 覆盖流查询，避免真实 drift 流在测试结束时留下待处理计时器。
    final work = Work(
      id: 1,
      title: '长夜行',
      coverColor: 0xFFB4654A,
      wordCount: 12,
      chapterCount: 1,
      lastEditedAt: DateTime(2026, 9, 30, 12),
      pinned: false,
      createdAt: DateTime(2026, 9, 30, 12),
    );
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          worksProvider.overrideWith(
            (ref) => Stream<List<Work>>.value(<Work>[work]),
          ),
        ],
        child: MaterialApp(
          theme: buildPaperTheme(),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const WorksPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('长夜行'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('长夜行')),
      isSemantics(
        customActions: <CustomSemanticsAction>[
          CustomSemanticsAction(label: '更多操作'),
        ],
      ),
    );
    handle.dispose();
  });
}
