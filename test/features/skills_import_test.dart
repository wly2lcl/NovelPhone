import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/app/theme.dart';
import 'package:novelphone/data/data_providers.dart';
import 'package:novelphone/data/db.dart';
import 'package:novelphone/data/repositories/settings_repository.dart';
import 'package:novelphone/data/secure_key_store.dart';
import 'package:novelphone/features/settings/skills_page.dart';
import 'package:novelphone/l10n/generated/app_localizations.dart';

/// ENH-21：技能 front matter 粘贴导入全流程（解析 → 预览 → 落库）。
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
  });

  tearDown(() async {
    await db.close();
  });

  Future<SettingsRepository> pumpSkills(WidgetTester tester) async {
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
          home: const SkillsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return SettingsRepository(db, InMemoryKeyStore());
  }

  /// 走一遍「粘贴导入 → 预览确认」，留下对话框打开状态。
  Future<void> pasteAndPreview(WidgetTester tester, String raw) async {
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('粘贴导入'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), raw);
    await tester.tap(find.text('导入技能'));
    await tester.pumpAndSettle();
  }

  /// 让 SnackBar 的定时器到期，避免测试结束仍有挂起计时器。
  Future<void> flushSnackBar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  testWidgets('粘贴导入：预览确认后落库并在列表展示简介', (tester) async {
    final repo = await pumpSkills(tester);

    await pasteAndPreview(tester, '''
---
name: 短句流
description: 只用短句，拒绝长难句
allowed-tools:
  - get_chapter
enabled: true
---
保持{{tone}}的短句节奏，结尾留一个钩子。
''');

    // 预览对话框展示名称、简介、工具白名单与指令正文
    expect(find.text('确认导入技能'), findsOneWidget);
    expect(find.text('短句流'), findsOneWidget);
    expect(find.text('只用短句，拒绝长难句'), findsOneWidget);
    expect(find.textContaining('get_chapter'), findsOneWidget);
    expect(find.textContaining('短句节奏'), findsOneWidget);

    await tester.tap(find.text('导入技能'));
    await tester.pump();

    final skills = await repo.listSkills();
    expect(skills, hasLength(1));
    final skill = skills.single;
    expect(skill.name, '短句流');
    expect(skill.description, '只用短句，拒绝长难句');
    expect(skill.allowedTools, <String>['get_chapter']);
    expect(skill.instruction, contains('{{tone}}'));
    expect(skill.parameters, isEmpty);
    expect(skill.enabled, isTrue);

    // 列表已刷新：标题 + 简介 + 成功提示
    await tester.pumpAndSettle();
    expect(find.text('已导入「短句流」'), findsOneWidget);
    expect(find.textContaining('只用短句，拒绝长难句'), findsOneWidget);
    await flushSnackBar(tester);
  });

  testWidgets('粘贴导入：enabled=false 时导入后保持停用', (tester) async {
    final repo = await pumpSkills(tester);

    await pasteAndPreview(tester, '''
---
name: 冷峻笔调
enabled: false
---
用冷峻克制的笔调叙述。
''');
    await tester.tap(find.text('导入技能'));
    await tester.pumpAndSettle();

    final skills = await repo.listSkills();
    expect(skills, hasLength(1));
    expect(skills.single.enabled, isFalse);
    await flushSnackBar(tester);
  });

  testWidgets('粘贴导入：缺少 front matter 报错且不落库', (tester) async {
    final repo = await pumpSkills(tester);

    await pasteAndPreview(tester, '没有 front matter 的普通文本');

    // 解析失败直接提示，不弹预览
    expect(find.text('确认导入技能'), findsNothing);
    expect(find.textContaining('导入失败'), findsOneWidget);
    expect(await repo.listSkills(), isEmpty);
    await flushSnackBar(tester);
  });
}
