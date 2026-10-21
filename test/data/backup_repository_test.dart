import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/data/db.dart';
import 'package:novelphone/data/repositories/backup_repository.dart';
import 'package:novelphone/data/repositories/chapter_repository.dart';
import 'package:novelphone/data/repositories/character_repository.dart';
import 'package:novelphone/data/repositories/inspiration_repository.dart';
import 'package:novelphone/data/repositories/outline_repository.dart';
import 'package:novelphone/data/repositories/setting_repository.dart';
import 'package:novelphone/data/repositories/story_state_repository.dart';
import 'package:novelphone/data/repositories/work_repository.dart';
import 'package:novelphone/models/setting_type.dart';
import 'package:novelphone/models/story_state_kind.dart';
import 'package:novelphone/models/work_style_guide.dart';

/// M2-10 / M2-11：整库备份导出与恢复（覆盖 / 合并）。
void main() {
  late AppDatabase db;
  late BackupRepository backup;
  late WorkRepository works;
  late ChapterRepository chapters;
  late CharacterRepository characters;
  late OutlineRepository outlines;
  late InspirationRepository inspirations;
  late SettingRepository settings;
  late StoryStateRepository storyStates;

  setUp(() {
    db = AppDatabase.memory();
    backup = BackupRepository(db);
    works = WorkRepository(db);
    chapters = ChapterRepository(db);
    characters = CharacterRepository(db);
    outlines = OutlineRepository(db);
    inspirations = InspirationRepository(db);
    settings = SettingRepository(db);
    storyStates = StoryStateRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  /// 建一部带完整关联数据的作品，返回作品 id。
  Future<int> seedWork({String title = '长夜行'}) async {
    final workId = await works.createWork(title: title, coverColor: 0xFFB4654A);
    final chapterId = await chapters.createChapter(
      workId: workId,
      title: '第一章 雨',
    );
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
      aliases: '["沈公子"]',
      voice: '话少，句子短。',
    );
    await chapters.saveChapterIntent(
      chapterId,
      '{"goal":"在雨夜找到线索","beats":["发现脚印"]}',
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
    expect(restoredChapters.single.intent, contains('在雨夜找到线索'));
    final restoredCharacters = await characters.listCharacters(workId);
    expect(restoredCharacters.single.name, '沈砚');
    expect(restoredCharacters.single.aliases, '["沈公子"]');
    expect(restoredCharacters.single.voice, '话少，句子短。');
    final restoredInspirations = await inspirations.listInspirations(workId);
    expect(restoredInspirations.single.content, '开篇用雨夜作引子');
    final entry = await outlines.findByChapter(restoredChapters.single.id);
    expect(entry!.summary, '主角在雨夜遇到线索。');
  });

  test('旧备份缺少角色别名列时按空串恢复（ENH-40）', () async {
    final workId = await seedWork();
    final data = await backup.exportData();
    final tables = data['tables'] as Map<String, dynamic>;
    tables['characters'] = (tables['characters'] as List)
        .map((row) => Map<String, dynamic>.from(row as Map)..remove('aliases'))
        .toList();

    await works.deleteWork(workId);
    await backup.restore(data, overwrite: true);

    final restored = await characters.listCharacters(workId);
    expect(restored.single.aliases, '');
  });

  test('旧备份缺少章节目标与角色口吻列时按空串恢复（ENH-51/52）', () async {
    final workId = await seedWork();
    final data = await backup.exportData();
    final tables = data['tables'] as Map<String, dynamic>;
    tables['chapters'] = (tables['chapters'] as List)
        .map((row) => Map<String, dynamic>.from(row as Map)..remove('intent'))
        .toList();
    tables['characters'] = (tables['characters'] as List)
        .map((row) => Map<String, dynamic>.from(row as Map)..remove('voice'))
        .toList();

    await works.deleteWork(workId);
    await backup.restore(data, overwrite: true);

    final restoredChapters = await chapters.watchChapters(workId).first;
    expect(restoredChapters.single.intent, '');
    final restored = await characters.listCharacters(workId);
    expect(restored.single.voice, '');
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

  test('恢复时叶表批量写入并保持外键映射（ENH-15）', () async {
    final workId = await seedWork();
    final chapterId = (await chapters.watchChapters(workId).first).single.id;
    await chapters.createSnapshot(
      chapterId: chapterId,
      title: '第一章 雨',
      content: '雨下了一整夜，街道上没有人。',
    );
    await settings.createEntry(
      workId: workId,
      type: SettingType.location,
      name: '雾港',
      content: '终年多雾的港口城市。',
    );
    final characterId = (await characters.listCharacters(workId)).single.id;
    final otherId = await characters.createCharacter(
      workId: workId,
      name: '阿七',
    );
    await characters.createRelation(
      workId: workId,
      fromCharacterId: characterId,
      toCharacterId: otherId,
      label: '同僚',
    );

    final data = await backup.exportData();
    await works.deleteWork(workId);
    expect(await works.countWorks(), 0);

    final report = await backup.restore(data, overwrite: true);

    expect(report.works, 1);
    // 覆盖恢复保留原 id，故仍可用删除前的 id 查回各叶表数据。
    expect(await chapters.listSnapshots(chapterId), hasLength(1));
    final entries = await settings.listEntries(workId);
    expect(entries.single.name, '雾港');
    expect(entries.single.type, SettingType.location.value);
    final relations = await db.select(db.characterRelations).get();
    expect(relations, hasLength(1));
    expect(relations.single.workId, workId);
    expect(relations.single.fromCharacterId, characterId);
    expect(relations.single.toCharacterId, otherId);
    expect(relations.single.label, '同僚');
    // 每日写作统计（保存正文时写入）也在批量路径中保留。
    expect(await db.select(db.dailyWritingStats).get(), isNotEmpty);
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

  test('旧备份章节缺少 summary 字段仍可恢复（ENH-05）', () async {
    final workId = await seedWork();
    final data = await backup.exportData();
    // 模拟 v6 之前的备份：章节行里没有 summary 键。
    for (final row in (data['tables'] as Map)['chapters'] as List) {
      (row as Map).remove('summary');
    }
    await works.deleteWork(workId);

    final report = await backup.restore(data, overwrite: true);

    expect(report.chapters, 1);
    final restored = await chapters.watchChapters(workId).first;
    expect(restored.single.summary, '');
    expect(restored.single.content, '雨下了一整夜，街道上没有人。');
  });

  test('旧备份卷缺少 summary 字段仍可恢复（ENH-06）', () async {
    final workId = await seedWork();
    final data = await backup.exportData();
    // 模拟 v7 之前的备份：卷行里没有 summary 键。
    for (final row in (data['tables'] as Map)['volumes'] as List) {
      (row as Map).remove('summary');
    }
    await works.deleteWork(workId);

    final report = await backup.restore(data, overwrite: true);

    expect(report.works, 1);
    final volumes = await chapters.listVolumes(workId);
    expect(volumes.single.summary, '');
  });

  test('旧备份缺摘要更新时间与归并覆盖章仍可恢复（ENH-07 O4/O6）', () async {
    final workId = await seedWork();
    final data = await backup.exportData();
    // 模拟 v8 之前的备份：章节无 summaryUpdatedAt、卷无 summaryChapterId。
    for (final row in (data['tables'] as Map)['chapters'] as List) {
      (row as Map).remove('summaryUpdatedAt');
    }
    for (final row in (data['tables'] as Map)['volumes'] as List) {
      (row as Map).remove('summaryChapterId');
    }
    await works.deleteWork(workId);

    final report = await backup.restore(data, overwrite: true);

    expect(report.chapters, 1);
    final restored = await chapters.watchChapters(workId).first;
    expect(restored.single.summaryUpdatedAt, isNull);
    final volumes = await chapters.listVolumes(workId);
    expect(volumes.single.summaryChapterId, 0);
  });

  test('文风档案随备份导出与恢复（ENH-23）', () async {
    final workId = await seedWork();
    const guide = WorkStyleGuide(
      perspective: '第三人称限知',
      tone: '克制、冷峻',
      taboos: '不用网络流行语',
      sample: '雨落在瓦上，像谁在数更漏。',
    );
    await works.updateStyleGuide(workId, guide);
    final data = await backup.exportData();
    await works.deleteWork(workId);

    final report = await backup.restore(data, overwrite: true);

    expect(report.works, 1);
    final restored = await works.getWork(workId);
    expect(WorkStyleGuide.decode(restored!.styleGuide), guide);
  });

  test('旧备份作品缺少 styleGuide 字段仍可恢复（ENH-23）', () async {
    final workId = await seedWork();
    final data = await backup.exportData();
    // 模拟 v12 之前的备份：作品行里没有 styleGuide 键。
    for (final row in (data['tables'] as Map)['works'] as List) {
      (row as Map).remove('styleGuide');
    }
    await works.deleteWork(workId);

    final report = await backup.restore(data, overwrite: true);

    expect(report.works, 1);
    final restored = await works.getWork(workId);
    expect(restored!.styleGuide, '');
  });

  test('故事状态卡随备份恢复，合并模式重映射章节外键（ENH-31）', () async {
    final workId = await seedWork();
    final chapterId = (await chapters.watchChapters(workId).first).single.id;
    await storyStates.createEntry(
      workId: workId,
      kind: StoryStateKind.foreshadow,
      title: '铜印来历',
      detail: '尚未揭晓',
      chapterId: chapterId,
      sortOrder: 2,
    );
    await storyStates.createEntry(
      workId: workId,
      kind: StoryStateKind.character,
      title: '沈砚',
      detail: '左臂受伤',
      status: 'closed',
    );

    final data = await backup.exportData();
    expect((data['tables'] as Map)['storyStates'], hasLength(2));

    // 合并恢复生成新作品，状态卡的作品 / 章节外键需随之重映射。
    await backup.restore(data, overwrite: false);
    final newWork = (await works.listWorks()).firstWhere((w) => w.id != workId);
    final newChapterId =
        (await chapters.watchChapters(newWork.id).first).single.id;
    expect(newChapterId, isNot(chapterId));
    final merged = await storyStates.listEntries(newWork.id);
    expect(merged, hasLength(2));
    final mergedForeshadow = merged.firstWhere(
      (e) => e.kind == StoryStateKind.foreshadow.value,
    );
    expect(mergedForeshadow.title, '铜印来历');
    expect(mergedForeshadow.chapterId, newChapterId);
    expect(mergedForeshadow.sortOrder, 2);
    final mergedCharacter = merged.firstWhere(
      (e) => e.kind == StoryStateKind.character.value,
    );
    expect(mergedCharacter.status, 'closed');
    expect(mergedCharacter.chapterId, isNull);

    // 覆盖恢复保留原 id，章节关联仍指向原章节。
    await backup.restore(data, overwrite: true);
    final overwritten = await storyStates.listEntries(workId);
    expect(overwritten, hasLength(2));
    expect(
      overwritten
          .firstWhere((e) => e.kind == StoryStateKind.foreshadow.value)
          .chapterId,
      chapterId,
    );
  });

  test('旧备份没有 storyStates 表仍可恢复（ENH-31）', () async {
    final workId = await seedWork();
    final data = await backup.exportData();
    (data['tables'] as Map).remove('storyStates');
    await works.deleteWork(workId);

    final report = await backup.restore(data, overwrite: true);

    expect(report.works, 1);
    expect(await storyStates.listEntries(workId), isEmpty);
  });
}
