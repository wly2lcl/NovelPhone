import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/data/db.dart';
import 'package:novelphone/data/repositories/backup_repository.dart';
import 'package:novelphone/data/repositories/chapter_repository.dart';
import 'package:novelphone/data/repositories/character_repository.dart';
import 'package:novelphone/data/repositories/inspiration_repository.dart';
import 'package:novelphone/data/repositories/outline_repository.dart';
import 'package:novelphone/data/repositories/work_repository.dart';

/// M2-10 / M2-11：整库备份导出与恢复（覆盖 / 合并）。
void main() {
  late AppDatabase db;
  late BackupRepository backup;
  late WorkRepository works;
  late ChapterRepository chapters;
  late CharacterRepository characters;
  late OutlineRepository outlines;
  late InspirationRepository inspirations;

  setUp(() {
    db = AppDatabase.memory();
    backup = BackupRepository(db);
    works = WorkRepository(db);
    chapters = ChapterRepository(db);
    characters = CharacterRepository(db);
    outlines = OutlineRepository(db);
    inspirations = InspirationRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  /// 建一部带完整关联数据的作品，返回作品 id。
  Future<int> seedWork({String title = '长夜行'}) async {
    final workId = await works.createWork(title: title, coverColor: 0xFFB4654A);
    final chapterId = await chapters.createChapter(workId: workId, title: '第一章 雨');
    await chapters.saveChapter(
      chapterId: chapterId,
      title: '第一章 雨',
      content: '雨下了一整夜，街道上没有人。',
      cursorOffset: 0,
      scrollOffset: 0,
    );
    await characters.createCharacter(
      workId: workId,
      name: '沈砚',
      identity: '捕快',
      personalityTags: '["寡言","执拗"]',
    );
    await inspirations.createInspiration(workId, '开篇用雨夜作引子');
    await outlines.saveChapterSummary(
      workId: workId,
      chapterId: chapterId,
      summary: '主角在雨夜遇到线索。',
    );
    return workId;
  }

  test('导出包含全部业务表且带格式标识', () async {
    await seedWork();

    final data = await backup.exportData();

    expect(data['format'], kBackupFormat);
    expect(data['version'], kBackupFormatVersion);
    final tables = data['tables'] as Map<String, dynamic>;
    expect(tables['works'], hasLength(1));
    expect(tables['volumes'], hasLength(1));
    expect(tables['chapters'], hasLength(1));
    expect(tables['characters'], hasLength(1));
    expect(tables['outlineEntries'], hasLength(1));
    expect(tables['inspirations'], hasLength(1));
  });

  test('loadWorkBundles 汇总作品章节供 markdown 输出', () async {
    await seedWork(title: '长夜行');
    await seedWork(title: '孤舟');

    final bundles = await backup.loadWorkBundles();

    expect(bundles, hasLength(2));
    for (final bundle in bundles) {
      expect(bundle.chapters, hasLength(1));
      expect(bundle.chapters.single.title, '第一章 雨');
    }
  });

  test('覆盖恢复按原 id 还原全部数据', () async {
    final workId = await seedWork();
    final data = await backup.exportData();

    // 清空后恢复：应回到备份时刻的状态。
    await works.deleteWork(workId);
    expect(await works.countWorks(), 0);

    final report = await backup.restore(data, overwrite: true);

    expect(report.works, 1);
    expect(report.chapters, 1);
    expect(report.characters, 1);
    final restored = await works.getWork(workId);
    expect(restored!.title, '长夜行');
    final restoredChapters = await chapters.watchChapters(workId).first;
    expect(restoredChapters.single.content, '雨下了一整夜，街道上没有人。');
    final restoredCharacters = await characters.listCharacters(workId);
    expect(restoredCharacters.single.name, '沈砚');
    final restoredInspirations = await inspirations.listInspirations(workId);
    expect(restoredInspirations.single.content, '开篇用雨夜作引子');
    final entry = await outlines.findByChapter(restoredChapters.single.id);
    expect(entry!.summary, '主角在雨夜遇到线索。');
  });

  test('合并恢复把备份作品作为新作品导入，不动现有数据', () async {
    await seedWork(title: '长夜行');
    final data = await backup.exportData();

    final report = await backup.restore(data, overwrite: false);

    expect(report.works, 1);
    expect(await works.countWorks(), 2);
    final titles = (await works.listWorks()).map((w) => w.title).toList();
    expect(titles.where((t) => t == '长夜行'), hasLength(2));
  });

  test('非备份文件被拒绝', () async {
    await seedWork();
    final data = await backup.exportData();
    data['format'] = 'something-else';

    expect(
      () => backup.restore(data, overwrite: true),
      throwsA(isA<FormatException>()),
    );
  });
}