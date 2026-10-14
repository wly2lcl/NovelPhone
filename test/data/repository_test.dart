import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/data/db.dart';
import 'package:novelphone/data/repositories/chapter_repository.dart';
import 'package:novelphone/data/repositories/character_repository.dart';
import 'package:novelphone/data/repositories/outline_repository.dart';
import 'package:novelphone/data/repositories/settings_repository.dart';
import 'package:novelphone/data/repositories/work_repository.dart';
import 'package:novelphone/data/secure_key_store.dart';
import 'package:novelphone/models/chapter_status.dart';

void main() {
  late AppDatabase db;
  late WorkRepository works;
  late ChapterRepository chapters;
  late CharacterRepository characters;
  late OutlineRepository outlines;

  setUp(() {
    db = AppDatabase.memory();
    works = WorkRepository(db);
    chapters = ChapterRepository(db);
    characters = CharacterRepository(db);
    outlines = OutlineRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('新建作品同时创建默认卷', () async {
    final workId = await works.createWork(title: '长夜行', coverColor: 0xFFB4654A);

    final work = await works.getWork(workId);
    expect(work!.title, '长夜行');
    expect(work.wordCount, 0);
    expect(work.chapterCount, 0);

    final volumes = await chapters.listVolumes(workId);
    expect(volumes, hasLength(1));
    expect(volumes.single.name, WorkRepository.defaultVolumeName);
  });

  test('保存章节在同一事务内更新章节字数与作品汇总', () async {
    final workId = await works.createWork(title: '长夜行');
    final chapterId = await chapters.createChapter(workId: workId, title: '第一章');

    await chapters.saveChapter(
      chapterId: chapterId,
      title: '第一章',
      content: '雨下了一整夜，街道上没有人。',
      cursorOffset: 5,
      scrollOffset: 12,
    );

    final chapter = await chapters.getChapter(chapterId);
    expect(chapter!.wordCount, 12);
    expect(chapter.cursorOffset, 5);
    expect(chapter.scrollOffset, 12);

    final work = await works.getWork(workId);
    expect(work!.wordCount, 12);
    expect(work.chapterCount, 1);
  });

  test('仅保存光标位置不改变正文与字数', () async {
    final workId = await works.createWork(title: '长夜行');
    final chapterId = await chapters.createChapter(workId: workId);
    await chapters.saveChapter(chapterId: chapterId, title: '', content: '两人对坐。');

    await chapters.saveCursorPosition(
        chapterId: chapterId, cursorOffset: 3, scrollOffset: 40);

    final chapter = await chapters.getChapter(chapterId);
    expect(chapter!.content, '两人对坐。');
    expect(chapter.wordCount, 4);
    expect(chapter.cursorOffset, 3);
    expect(chapter.scrollOffset, 40);
  });

  test('章节排序上移下移与边界', () async {
    final workId = await works.createWork(title: '长夜行');
    await chapters.createChapter(workId: workId, title: '第一章');
    final second = await chapters.createChapter(workId: workId, title: '第二章');

    await chapters.moveChapter(second, up: true);
    var list = await chapters.watchChapters(workId).first;
    expect(list.map((c) => c.title), ['第二章', '第一章']);

    // 已在顶部继续上移不变
    await chapters.moveChapter(second, up: true);
    list = await chapters.watchChapters(workId).first;
    expect(list.map((c) => c.title), ['第二章', '第一章']);

    await chapters.moveChapter(second, up: false);
    list = await chapters.watchChapters(workId).first;
    expect(list.map((c) => c.title), ['第一章', '第二章']);
  });

  test('移动到其他卷落在目标卷末尾', () async {
    final workId = await works.createWork(title: '长夜行');
    final firstVolume = (await chapters.listVolumes(workId)).single;
    final secondVolumeId = await chapters.createVolume(workId, '第二卷');
    final a = await chapters.createChapter(workId: workId, title: 'A');
    await chapters.createChapter(workId: workId, volumeId: secondVolumeId, title: 'B');

    await chapters.moveChapterToVolume(a, secondVolumeId);

    final moved = await chapters.getChapter(a);
    expect(moved!.volumeId, secondVolumeId);
    expect(moved.sortOrder > 1, isTrue);
    expect(firstVolume.id, isNot(secondVolumeId));
  });

  test('章节状态切换只改状态', () async {
    final workId = await works.createWork(title: '长夜行');
    final chapterId = await chapters.createChapter(workId: workId);
    await chapters.saveChapter(chapterId: chapterId, title: '', content: '正文');

    await chapters.setChapterStatus(chapterId, ChapterStatus.revising);

    final chapter = await chapters.getChapter(chapterId);
    expect(chapter!.status, 'revising');
    expect(chapter.content, '正文');
  });

  test('保存章节 AI 摘要只改摘要字段（ENH-05）', () async {
    final workId = await works.createWork(title: '长夜行');
    final chapterId = await chapters.createChapter(workId: workId, title: '第一章');
    await chapters.saveChapter(
        chapterId: chapterId, title: '第一章', content: '第一章正文内容。');

    await chapters.saveChapterSummary(chapterId, '沈砚离乡，风起。');

    final chapter = await chapters.getChapter(chapterId);
    expect(chapter!.summary, '沈砚离乡，风起。');
    // 不触碰正文与字数汇总。
    expect(chapter.content, '第一章正文内容。');
    final work = await works.getWork(workId);
    expect(work!.wordCount, 7);
  });

  test('保存本卷前情回顾只改卷摘要字段（ENH-06）', () async {
    final workId = await works.createWork(title: '长夜行');
    final volumeId = (await chapters.listVolumes(workId)).single.id;

    await chapters.saveVolumeSummary(volumeId, '本卷：沈砚离乡。');

    final volumes = await chapters.listVolumes(workId);
    expect(volumes.single.summary, '本卷：沈砚离乡。');
    // 只改摘要，卷名等字段不变。
    expect(volumes.single.name, WorkRepository.defaultVolumeName);
  });

  test('保存章节摘要记录摘要更新时间（ENH-07 O4）', () async {
    final workId = await works.createWork(title: '长夜行');
    final chapterId = await chapters.createChapter(workId: workId, title: '第一章');

    await chapters.saveChapterSummary(chapterId, '第一章摘要。');

    final chapter = await chapters.getChapter(chapterId);
    expect(chapter!.summary, '第一章摘要。');
    expect(chapter.summaryUpdatedAt, isNotNull);
  });

  test('保存本卷前情回顾可记录归并覆盖章节（ENH-07 O6）', () async {
    final workId = await works.createWork(title: '长夜行');
    final volumeId = (await chapters.listVolumes(workId)).single.id;

    await chapters.saveVolumeSummary(volumeId, '本卷：沈砚离乡。',
        coveredChapterId: 3);

    expect((await chapters.listVolumes(workId)).single.summaryChapterId, 3);
  });

  test('删除章节后作品汇总更新且章纲引用置空', () async {
    final workId = await works.createWork(title: '长夜行');
    final chapterId = await chapters.createChapter(workId: workId, title: '第一章');
    await chapters.saveChapter(
        chapterId: chapterId, title: '第一章', content: '第一章正文内容。');
    await outlines.saveChapterSummary(
        workId: workId, chapterId: chapterId, summary: '主角登场');

    await chapters.deleteChapter(chapterId);

    final work = await works.getWork(workId);
    expect(work!.chapterCount, 0);
    expect(work.wordCount, 0);

    final entries = await outlines.listOutline(workId);
    expect(entries, hasLength(1));
    expect(entries.single.chapterId, isNull);
  });

  test('删除卷连同卷内章节与汇总一起处理', () async {
    final workId = await works.createWork(title: '长夜行');
    final volumeId = (await chapters.listVolumes(workId)).single.id;
    final chapterId = await chapters.createChapter(workId: workId);
    await chapters.saveChapter(chapterId: chapterId, title: '', content: '共八个汉字。');

    await chapters.deleteVolume(volumeId);

    expect(await chapters.listVolumes(workId), isEmpty);
    expect(await chapters.watchChapters(workId).first, isEmpty);
    final work = await works.getWork(workId);
    expect(work!.chapterCount, 0);
  });

  test('删除作品级联清理全部关联数据', () async {
    final workId = await works.createWork(title: '长夜行');
    final chapterId = await chapters.createChapter(workId: workId);
    await characters.createCharacter(workId: workId, name: '林晚');
    await outlines.saveChapterSummary(
        workId: workId, chapterId: chapterId, summary: '开场');

    await works.deleteWork(workId);

    expect(await works.getWork(workId), isNull);
    expect(await chapters.listVolumes(workId), isEmpty);
    expect(await chapters.watchChapters(workId).first, isEmpty);
    expect(await characters.listCharacters(workId), isEmpty);
    expect(await outlines.listOutline(workId), isEmpty);
  });

  test('作品列表流按置顶与最后编辑时间排序', () async {
    final oldWork = await works.createWork(title: '旧作');
    final newWork = await works.createWork(title: '新作');

    var list = await works.watchWorks().first;
    expect(list.first.id, newWork);

    await works.setPinned(oldWork, true);
    list = await works.watchWorks().first;
    expect(list.first.id, oldWork);
  });

  test('作品列表响应式流在写入后推送新数据', () async {
    final emissions = <int>[];
    final subscription = works.watchWorks().listen((rows) => emissions.add(rows.length));

    await works.createWork(title: '第一部');
    await works.createWork(title: '第二部');
    await _waitFor(() => emissions.isNotEmpty && emissions.last == 2);
    await subscription.cancel();

    expect(emissions.last, 2);
  });

  test('章纲按章节写入为 upsert', () async {
    final workId = await works.createWork(title: '长夜行');
    final chapterId = await chapters.createChapter(workId: workId);

    await outlines.saveChapterSummary(
        workId: workId, chapterId: chapterId, summary: '初稿梗概');
    await outlines.saveChapterSummary(
        workId: workId, chapterId: chapterId, summary: '改后梗概');

    final entries = await outlines.listOutline(workId);
    expect(entries, hasLength(1));
    expect(entries.single.summary, '改后梗概');
  });

  test('作品数量统计可用于上限校验', () async {
    for (var i = 0; i < 3; i++) {
      await works.createWork(title: '作品$i');
    }
    expect(await works.countWorks(), 3);
  });

  test('删除章节后再新建章节，排序号继续递增不冲突', () async {
    final workId = await works.createWork(title: '长夜行');
    final first = await chapters.createChapter(workId: workId, title: '第一章');
    await chapters.createChapter(workId: workId, title: '第二章');
    await chapters.deleteChapter(first);

    final third = await chapters.createChapter(workId: workId, title: '第三章');
    final newChapter = await chapters.getChapter(third);
    expect(newChapter!.sortOrder, 3);
  });

  test('更新作品标题与置顶状态', () async {
    final workId = await works.createWork(title: '旧名');
    await works.renameWork(workId, '新名');
    final work = await works.getWork(workId);
    expect(work!.title, '新名');
    expect(work.pinned, isFalse);
    expect(work.coverColor, isNot(0));
  });

  group('检查处置率计数（M4-12）', () {
    test('累加问题总数与已处置数', () async {
      final settings = SettingsRepository(db, InMemoryKeyStore());

      await settings.addCheckStats(total: 3, handled: 2);
      await settings.addCheckStats(total: 1, handled: 1);

      final stats = await settings.readCheckStats();
      expect(stats.total, 4);
      expect(stats.handled, 3);
    });

    test('空计数不写入', () async {
      final settings = SettingsRepository(db, InMemoryKeyStore());

      await settings.addCheckStats(total: 0, handled: 0);

      final stats = await settings.readCheckStats();
      expect(stats.total, 0);
      expect(stats.handled, 0);
    });
  });

  group('AI 首次联网告知确认（M4-16）', () {
    test('默认未确认，确认后持久为已确认', () async {
      final settings = SettingsRepository(db, InMemoryKeyStore());

      expect(await settings.hasConfirmedAiNotice(), isFalse);

      await settings.confirmAiNotice();

      expect(await settings.hasConfirmedAiNotice(), isTrue);
      // 换一个仓库实例读取（确认状态落在库中，非内存）。
      final reopened = SettingsRepository(db, InMemoryKeyStore());
      expect(await reopened.hasConfirmedAiNotice(), isTrue);
    });
  });
}

/// 等待响应式流推送（drift 流更新在当前 isolate 异步派发）。
Future<void> _waitFor(bool Function() condition) async {
  for (var i = 0; i < 200; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}