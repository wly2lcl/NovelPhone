import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/data/db.dart';
import 'package:novelphone/data/repositories/backup_repository.dart';
import 'package:novelphone/data/repositories/chapter_repository.dart';
import 'package:novelphone/data/repositories/work_repository.dart';
import 'package:novelphone/features/editor/editor_controller.dart';

/// B-05：章节快照 / 版本历史。
void main() {
  late AppDatabase db;
  late WorkRepository works;
  late ChapterRepository chapters;
  late BackupRepository backup;
  late int workId;
  late int chapterId;

  setUp(() async {
    db = AppDatabase.memory();
    works = WorkRepository(db);
    chapters = ChapterRepository(db);
    backup = BackupRepository(db);
    workId = await works.createWork(title: '长夜行');
    chapterId = await chapters.createChapter(workId: workId, title: '第一章');
  });

  tearDown(() async {
    await db.close();
  });

  test('创建快照记录标题、正文与字数，最新的排在最前', () async {
    await chapters.createSnapshot(
        chapterId: chapterId, title: '第一章', content: '初稿。');
    await chapters.createSnapshot(
        chapterId: chapterId, title: '第一章 改', content: '二稿，加了一段。');

    final list = await chapters.listSnapshots(chapterId);

    expect(list, hasLength(2));
    expect(list.first.title, '第一章 改');
    expect(list.first.wordCount, greaterThan(0));
    expect(list.last.content, '初稿。');
  });

  test('超过上限自动清理最旧的快照', () async {
    final limit = ChapterRepository.maxSnapshotsPerChapter;
    for (var i = 0; i < limit + 2; i++) {
      await chapters.createSnapshot(
          chapterId: chapterId, title: '第 $i 版', content: '内容 $i');
    }

    final list = await chapters.listSnapshots(chapterId);

    expect(list, hasLength(limit));
    expect(list.first.title, '第 ${limit + 1} 版');
    expect(list.last.title, '第 2 版');
  });

  test('删除章节时快照随外键级联删除', () async {
    await chapters.createSnapshot(
        chapterId: chapterId, title: '第一章', content: '正文');
    await chapters.deleteChapter(chapterId);

    expect(await chapters.listSnapshots(chapterId), isEmpty);
  });

  test('删除指定快照', () async {
    final id = await chapters.createSnapshot(
        chapterId: chapterId, title: '第一章', content: '正文');

    await chapters.deleteSnapshot(id);

    expect(await chapters.listSnapshots(chapterId), isEmpty);
  });

  test('恢复版本写回标题与正文并落库，且可撤销', () async {
    await chapters.saveChapter(
        chapterId: chapterId, title: '第一章', content: '当前正文。');
    await chapters.createSnapshot(
        chapterId: chapterId, title: '旧标题', content: '旧正文。');
    final target = (await chapters.listSnapshots(chapterId)).single;

    final controller = EditorController(
        repository: chapters, workId: workId, chapterId: chapterId);
    await controller.load();
    expect(controller.textController.text, '当前正文。');

    await controller.restoreVersion(
        title: target.title, content: target.content);

    expect(controller.title, '旧标题');
    expect(controller.textController.text, '旧正文。');
    expect(controller.canUndo, isTrue);
    final stored = await chapters.getChapter(chapterId);
    expect(stored!.title, '旧标题');
    expect(stored.content, '旧正文。');

    controller.dispose();
  });

  test('备份导出与覆盖恢复保留快照并重映射章节外键', () async {
    await chapters.createSnapshot(
        chapterId: chapterId, title: '第一章', content: '留档正文。');
    final data = await backup.exportData();
    expect((data['tables'] as Map)['chapterSnapshots'], hasLength(1));

    await works.deleteWork(workId);
    await backup.restore(data, overwrite: true);

    final restoredWorkId = (await works.listWorks()).single.id;
    final restoredChapter =
        (await chapters.watchChapters(restoredWorkId).first).single;
    final snapshots = await chapters.listSnapshots(restoredChapter.id);
    expect(snapshots, hasLength(1));
    expect(snapshots.single.content, '留档正文。');
  });
}