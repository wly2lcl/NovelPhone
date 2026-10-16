import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/app/theme.dart';
import 'package:novelphone/data/db.dart';
import 'package:novelphone/features/works/works_page.dart';
import 'package:novelphone/features/works/works_providers.dart';

void main() {
  Widget wrap(List<Work> works) {
    return ProviderScope(
      overrides: [
        worksProvider.overrideWith((ref) => Stream<List<Work>>.value(works)),
      ],
      child: MaterialApp(theme: buildPaperTheme(), home: const WorksPage()),
    );
  }

  Work buildWork({int wordCount = 0, int chapterCount = 0}) => Work(
    id: 1,
    title: '长夜行',
    coverColor: 0xFFB4654A,
    wordCount: wordCount,
    chapterCount: chapterCount,
    lastEditedAt: DateTime(2026, 9, 30, 12),
    pinned: false,
    createdAt: DateTime(2026, 9, 30, 12),
  );

  testWidgets('无作品时展示空状态引导', (tester) async {
    await tester.pumpWidget(wrap(const <Work>[]));
    await tester.pumpAndSettle();

    expect(find.text('还没有作品'), findsOneWidget);
    expect(find.text('创建第一部作品'), findsOneWidget);
  });

  testWidgets('已有作品时展示卡片信息', (tester) async {
    await tester.pumpWidget(wrap(<Work>[buildWork()]));
    await tester.pumpAndSettle();

    expect(find.text('长夜行'), findsOneWidget);
    expect(find.textContaining('0 字 · 0 章'), findsOneWidget);
    expect(find.textContaining('最后编辑'), findsOneWidget);
  });

  testWidgets('卡片展示字数与章节数', (tester) async {
    await tester.pumpWidget(
      wrap(<Work>[buildWork(wordCount: 12345, chapterCount: 7)]),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('1.2 万字 · 7 章'), findsOneWidget);
  });
}
