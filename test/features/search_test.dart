import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:novelphone/app/theme.dart';
import 'package:novelphone/data/data_providers.dart';
import 'package:novelphone/data/db.dart';
import 'package:novelphone/data/repositories/chapter_repository.dart';
import 'package:novelphone/data/repositories/work_repository.dart';
import 'package:novelphone/data/secure_key_store.dart';
import 'package:novelphone/features/search/search_page.dart';
import 'package:novelphone/l10n/generated/app_localizations.dart';

/// B-06：全局搜索（跨作品检索章节标题与正文）。
void main() {
  late AppDatabase db;
  late WorkRepository works;
  late ChapterRepository chapters;

  setUp(() {
    db = AppDatabase.memory();
    works = WorkRepository(db);
    chapters = ChapterRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> seedChapter(int workId, String title, String content) async {
    final id = await chapters.createChapter(workId: workId, title: title);
    await chapters.saveChapter(chapterId: id, title: title, content: content);
    return id;
  }

  test('跨作品检索正文，返回作品与章节信息', () async {
    final first = await works.createWork(title: '长夜行');
    final second = await works.createWork(title: '孤舟');
    final hitChapter = await seedChapter(first, '第一章', '雨下了一整夜，街道上没有人。');
    await seedChapter(second, '第二章', '江面起了雾，谁也看不清。');

    final hits = await chapters.search('街道');

    expect(hits, hasLength(1));
    expect(hits.single.workId, first);
    expect(hits.single.workTitle, '长夜行');
    expect(hits.single.chapterId, hitChapter);
    expect(hits.single.snippet, contains('街道'));
    expect(hits.single.matchOffset, greaterThanOrEqualTo(0));
  });

  test('命中章节标题也算结果，正文无命中时 matchOffset 为 -1', () async {
    final workId = await works.createWork(title: '长夜行');
    await seedChapter(workId, '雨夜归人', '正文与关键词无关。');

    final hits = await chapters.search('雨夜');

    expect(hits, hasLength(1));
    expect(hits.single.matchOffset, -1);
  });

  test('英文关键词忽略大小写', () async {
    final workId = await works.createWork(title: 'Long Night');
    await seedChapter(workId, 'Chapter One', 'Hello World.');

    final hits = await chapters.search('hello');

    expect(hits, hasLength(1));
    expect(hits.single.matchOffset, 0);
  });

  test('正文中部命中：matchOffset 精确且片段带省略号（ENH-14）', () async {
    final workId = await works.createWork(title: '长夜行');
    final content = '${'甲' * 30}街道${'乙' * 30}';
    await seedChapter(workId, '第一章', content);

    final hits = await chapters.search('街道');

    expect(hits, hasLength(1));
    expect(hits.single.matchOffset, 30);
    expect(hits.single.matchLength, 2);
    expect(hits.single.snippet, contains('街道'));
    expect(hits.single.snippet, startsWith('…'));
    expect(hits.single.snippet, endsWith('…'));
    // 片段：前 12 字 + 关键词 2 字 + 后 24 字，再加两侧省略号。
    expect(hits.single.snippet.length, 12 + 2 + 24 + 2);
  });

  test('findMatchOffset 校正 emoji 章节的偏移（ENH-16）', () async {
    final workId = await works.createWork(title: '长夜行');
    final content = '🙂${'甲' * 10}街道${'乙' * 10}';
    final chapterId = await seedChapter(workId, '第一章', content);

    final hits = await chapters.search('街道');

    expect(hits, hasLength(1));
    // SQL 侧 INSTR/substr 按码点计数（emoji 记 1 个字符）：1 + 10 = 11。
    expect(hits.single.matchOffset, 11);
    // Dart 侧为 UTF-16 偏移（emoji 记 2 个代码单元）：2 + 10 = 12。
    expect(await chapters.findMatchOffset(chapterId, '街道'), 12);
  });

  test('findMatchOffset：ASCII 大小写折叠与 SQL lower() 口径一致（ENH-16）', () async {
    final workId = await works.createWork(title: 'Long Night');
    final chapterId = await seedChapter(workId, 'Chapter One', 'zz Hello zz');

    expect(await chapters.findMatchOffset(chapterId, 'hello'), 3);
  });

  test('findMatchOffset：关键词/章节不存在或关键词为空时返回 null（ENH-16）', () async {
    final workId = await works.createWork(title: '长夜行');
    final chapterId = await seedChapter(workId, '第一章', '雨下了一整夜。');

    expect(await chapters.findMatchOffset(chapterId, '月光'), isNull);
    expect(await chapters.findMatchOffset(chapterId, '   '), isNull);
    expect(await chapters.findMatchOffset(999999, '雨'), isNull);
  });

  test('LIKE 通配符被转义，不会误匹配全部章节', () async {
    final workId = await works.createWork(title: '长夜行');
    await seedChapter(workId, '第一章', '普通的正文。');

    expect(await chapters.search('%'), isEmpty);
    expect(await chapters.search('_'), isEmpty);
  });

  test('空白关键词返回空结果', () async {
    final workId = await works.createWork(title: '长夜行');
    await seedChapter(workId, '第一章', '普通的正文。');

    expect(await chapters.search('   '), isEmpty);
  });

  testWidgets('搜索页输入关键词展示命中章节', (tester) async {
    final workId = await works.createWork(title: '长夜行');
    await seedChapter(workId, '第一章 雨', '雨下了一整夜，街道上没有人。');

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
          home: const SearchPage(),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), '街道');
    // 输入防抖（ENH-11）：先推进防抖计时器，再等真实异步（drift 查询）返回。
    await tester.pump(const Duration(milliseconds: 350));
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      if (find.byType(ListTile).evaluate().isNotEmpty) break;
    }

    expect(find.byType(ListTile), findsOneWidget);
    expect(find.text('长夜行'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('输入防抖：未到间隔不发起检索（ENH-11）', (tester) async {
    final workId = await works.createWork(title: '长夜行');
    await seedChapter(workId, '第一章', '雨下了一整夜，街道上没有人。');

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
          home: const SearchPage(),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), '街道');
    // 未到防抖间隔：即使给足真实异步时间，也不应产生检索结果。
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(find.byType(ListTile), findsNothing);

    // 越过防抖间隔后正常出结果。
    await tester.pump(const Duration(milliseconds: 350));
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      if (find.byType(ListTile).evaluate().isNotEmpty) break;
    }
    expect(find.byType(ListTile), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('点击命中跳转编辑器时使用校正后的 UTF-16 偏移（ENH-16）', (tester) async {
    final workId = await works.createWork(title: '长夜行');
    final content = '🙂${'甲' * 10}街道${'乙' * 10}';
    await seedChapter(workId, '第一章', content);

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SearchPage()),
        GoRoute(
          path: '/work/:workId/chapter/:chapterId',
          builder: (context, state) => Text('EDITOR?${state.uri.query}'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          secureKeyStoreProvider.overrideWithValue(InMemoryKeyStore()),
        ],
        child: MaterialApp.router(
          theme: buildPaperTheme(),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), '街道');
    await tester.pump(const Duration(milliseconds: 350));
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      if (find.byType(ListTile).evaluate().isNotEmpty) break;
    }
    expect(find.byType(ListTile), findsOneWidget);

    // 点击后需读该章正文做偏移校正（真实异步），沿用 runAsync 循环等待跳转。
    await tester.tap(find.byType(ListTile));
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      if (find.textContaining('EDITOR').evaluate().isNotEmpty) break;
    }

    // 校正后的 UTF-16 偏移为 12（SQL 的码点偏移 11 + emoji 的 1 个额外代码单元）。
    expect(find.text('EDITOR?checkStart=12&checkEnd=14'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
}
