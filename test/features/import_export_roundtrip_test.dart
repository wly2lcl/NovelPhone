import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/core/ai_flavor_rules.dart';
import 'package:novelphone/core/exporter/text_exporter.dart';
import 'package:novelphone/core/importer/chapter_splitter.dart';
import 'package:novelphone/data/db.dart';
import 'package:novelphone/data/repositories/chapter_repository.dart';
import 'package:novelphone/data/repositories/character_repository.dart';
import 'package:novelphone/data/repositories/outline_repository.dart';
import 'package:novelphone/data/repositories/settings_repository.dart';
import 'package:novelphone/data/repositories/token_stats_repository.dart';
import 'package:novelphone/data/repositories/work_repository.dart';
import 'package:novelphone/data/secure_key_store.dart';
import 'package:novelphone/features/ai/ai_service.dart';

/// M2-15 / M2-16：30 万字 txt 导入 → 分章 → 写入 → 导出 markdown → 再导入一致。
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

  /// M4-14 主链路回归：导入 → 写作保存 → AI 感检查（规则层，不联网）→ 导出。
  test('主链路无阻断：导入 → 续写保存 → 规则检查 → 导出 markdown（M4-14）', () async {
    // 1. 导入：按「第 X 章」自动分章后写入。
    final drafts = splitIntoChapters('第1章 起风\n\n他走进房间。\n\n第2章 落雨\n\n她不禁笑了。\n');
    expect(drafts, hasLength(2));
    final workId = await works.createWork(title: '长夜行');
    final imported = await chapters.importChapters(
      workId: workId,
      volumeName: '长夜行',
      drafts: <ChapterImportDraft>[
        for (final draft in drafts)
          ChapterImportDraft(title: draft.title, content: draft.content),
      ],
    );
    expect(imported, 2);

    var saved = await chapters.watchChapters(workId).first;
    final first = saved.firstWhere((c) => c.title == '第1章 起风');
    final second = saved.firstWhere((c) => c.title == '第2章 落雨');

    // 2. 写作：续写第一章并保存（编辑器自动保存走同一路径）。
    await chapters.saveChapter(
      chapterId: first.id,
      title: first.title,
      content: '${first.content}\n\n他坐下来，翻开书。',
    );
    final updated = await chapters.getChapter(first.id);
    expect(updated!.content, contains('他坐下来，翻开书。'));
    // 作品汇总字数与章节数随保存同步（M1 无退化）。
    final work = await works.getWork(workId);
    expect(work!.chapterCount, 2);

    // 3. AI 感检查：命中套话的章节被标记，干净章节不被标记。
    final service = AiService(
      settings: SettingsRepository(db, InMemoryKeyStore()),
      works: works,
      chapters: chapters,
      characters: CharacterRepository(db),
      outline: OutlineRepository(db),
      stats: TokenStatsRepository(db),
    );
    final flagged = await service
        .checkFlavor(workId: workId, chapterId: second.id)
        .toList();
    final ruleResult = flagged.whereType<CheckRuleResult>().single;
    expect(isFlavorFlagged(ruleResult.result), isTrue);
    expect(
      ruleResult.result.issues.any((i) => i.excerpt.contains('不禁')),
      isTrue,
    );

    final clean = await service
        .checkFlavor(workId: workId, chapterId: first.id)
        .toList();
    expect(
      isFlavorFlagged(clean.whereType<CheckRuleResult>().single.result),
      isFalse,
    );

    // 4. 导出：整作 markdown 含刚写入的续写内容与全部章节标题。
    saved = await chapters.watchChapters(workId).first;
    final markdown = buildWorkMarkdown(<ExportChapter>[
      for (final chapter in saved)
        ExportChapter(title: chapter.title, content: chapter.content),
    ]);
    expect(markdown, contains('# 第1章 起风'));
    expect(markdown, contains('# 第2章 落雨'));
    expect(markdown, contains('他坐下来，翻开书。'));
    expect(markdown, contains('她不禁笑了。'));
  });

  /// 造一篇约 30 万字、含 [chapterCount] 章的长篇 txt（GBK 无关，纯 UTF-8 文本）。
  String buildLongNovel(int chapterCount) {
    final buffer = StringBuffer();
    for (var i = 1; i <= chapterCount; i++) {
      buffer.write('第$i章 第$i次转折\n\n');
      // 每章约 3000 字，100 章 ≈ 30 万字。
      for (var p = 0; p < 30; p++) {
        buffer.write('${'雨下了很久，街道上没有人。' * 10}\n');
      }
      buffer.write('\n');
    }
    return buffer.toString();
  }

  test('30 万字 txt 分章 → 写入 → 导出 markdown → 再导入结构一致', () async {
    final text = buildLongNovel(100);
    expect(text.length, greaterThan(300000));

    // 分章预览
    final drafts = splitIntoChapters(text, fallbackTitle: '长夜行');
    expect(drafts, hasLength(100));
    expect(drafts.first.title, '第1章 第1次转折');
    expect(drafts.last.title, '第100章 第100次转折');

    // 确认写入（事务）
    final workId = await works.createWork(title: '长夜行');
    final count = await chapters.importChapters(
      workId: workId,
      volumeName: '长夜行',
      drafts: <ChapterImportDraft>[
        for (final draft in drafts)
          ChapterImportDraft(title: draft.title, content: draft.content),
      ],
    );
    expect(count, 100);
    final saved = await chapters.watchChapters(workId).first;
    expect(saved, hasLength(100));

    // 导出 markdown 后再导入，章节结构与正文一致
    final markdown = buildWorkMarkdown(<ExportChapter>[
      for (final chapter in saved)
        ExportChapter(title: chapter.title, content: chapter.content),
    ]);
    final reimported = splitIntoChapters(markdown);

    expect(reimported, hasLength(saved.length));
    for (var i = 0; i < saved.length; i++) {
      expect(reimported[i].title, saved[i].title);
      expect(reimported[i].content, saved[i].content);
    }
  });

  test('导入后作品汇总字数与章节数同步更新（M1 功能无退化）', () async {
    final drafts = splitIntoChapters(buildLongNovel(20));
    final workId = await works.createWork(title: '孤舟');
    await chapters.importChapters(
      workId: workId,
      volumeName: '孤舟',
      drafts: <ChapterImportDraft>[
        for (final draft in drafts)
          ChapterImportDraft(title: draft.title, content: draft.content),
      ],
    );

    final work = await works.getWork(workId);
    expect(work!.chapterCount, 20);
    expect(
      work.wordCount,
      drafts.fold<int>(0, (sum, draft) => sum + draft.wordCount),
    );
  });
}
