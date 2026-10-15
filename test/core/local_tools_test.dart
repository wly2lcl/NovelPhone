import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/core/ai/tools/local_tools.dart';
import 'package:novelphone/data/db.dart';
import 'package:novelphone/data/repositories/chapter_repository.dart';
import 'package:novelphone/data/repositories/character_repository.dart';
import 'package:novelphone/data/repositories/outline_repository.dart';
import 'package:novelphone/data/repositories/work_repository.dart';

/// 计数用的章节仓储替身（ENH-12）：整部作品正文读取发生几次。
class _CountingChapters extends ChapterRepository {
  _CountingChapters(super._db);

  int fullWorkReads = 0;

  @override
  Stream<List<Chapter>> watchChapters(int workId) {
    fullWorkReads++;
    return super.watchChapters(workId);
  }
}

/// M3-07 内置工具的取数范围（ENH-12）：只用到章节标题时不应读入整部作品正文。
void main() {
  late AppDatabase db;
  late WorkRepository works;
  late _CountingChapters chapters;
  late CharacterRepository characters;
  late OutlineRepository outline;

  setUp(() {
    db = AppDatabase.memory();
    works = WorkRepository(db);
    chapters = _CountingChapters(db);
    characters = CharacterRepository(db);
    outline = OutlineRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('get_outline 只读章节元数据，不整部读正文（ENH-12）', () async {
    final workId = await works.createWork(title: '长夜行');
    final first = await chapters.createChapter(workId: workId, title: '第一章');
    await chapters.saveChapter(
      chapterId: first,
      title: '第一章',
      content: '少年推开木门，风灌了进来。',
      cursorOffset: 0,
      scrollOffset: 0,
    );
    await outline.saveChapterSummary(
      workId: workId,
      chapterId: first,
      summary: '开篇：沈砚离乡。',
    );

    final tool = buildLocalTools(
      chapters: chapters,
      characters: characters,
      outline: outline,
    ).firstWhere((t) => t.name == 'get_outline');

    final result = await tool.execute(<String, dynamic>{'workId': workId});

    expect(result, contains('第一章：开篇：沈砚离乡。'));
    expect(chapters.fullWorkReads, 0);
  });
}
