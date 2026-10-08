import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/core/ai/context_builder.dart';
import 'package:novelphone/data/db.dart';
import 'package:novelphone/data/repositories/chapter_repository.dart';
import 'package:novelphone/data/repositories/character_repository.dart';
import 'package:novelphone/data/repositories/outline_repository.dart';
import 'package:novelphone/data/repositories/work_repository.dart';

/// M3-13：不同作品规模下的上下文装配结果与预算遵守。
void main() {
  late AppDatabase db;
  late WorkRepository works;
  late ChapterRepository chapters;
  late CharacterRepository characters;
  late OutlineRepository outline;
  late ContextBuilder builder;

  setUp(() {
    db = AppDatabase.memory();
    works = WorkRepository(db);
    chapters = ChapterRepository(db);
    characters = CharacterRepository(db);
    outline = OutlineRepository(db);
    builder = ContextBuilder(
      works: works,
      chapters: chapters,
      characters: characters,
      outline: outline,
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> seedWork() async {
    final workId = await works.createWork(title: '长夜行');
    final first = await chapters.createChapter(workId: workId, title: '第一章');
    await chapters.saveChapter(
      chapterId: first,
      title: '第一章',
      content: '少年推开木门，风灌了进来。他叫沈砚。',
      cursorOffset: 0,
      scrollOffset: 0,
    );
    final second = await chapters.createChapter(workId: workId, title: '第二章');
    await chapters.saveChapter(
      chapterId: second,
      title: '第二章',
      content: '沈砚在雨里走了很久。苏晚在灯下等他。',
      cursorOffset: 0,
      scrollOffset: 0,
    );
    await outline.saveChapterSummary(
      workId: workId,
      chapterId: first,
      summary: '开篇：沈砚离乡。',
    );
    return workId;
  }

  test('按优先级装配：章纲 / 前文摘要 / 角色卡 / 本章尾部', () async {
    final workId = await seedWork();
    final third = await chapters.createChapter(workId: workId, title: '第三章');
    await chapters.saveChapter(
      chapterId: third,
      title: '第三章',
      content: '沈砚握紧了刀。苏晚站在他身后，没有说话。',
      cursorOffset: 0,
      scrollOffset: 0,
    );
    await outline.saveChapterSummary(
      workId: workId,
      chapterId: third,
      summary: '沈砚与苏晚对峙。',
    );
    await characters.createCharacter(
      workId: workId,
      name: '沈砚',
      identity: '游侠',
    );
    await characters.createCharacter(
      workId: workId,
      name: '苏晚',
      identity: '医女',
    );
    await characters.createCharacter(workId: workId, name: '无关角色');

    final context = await builder.buildContinue(
      workId: workId,
      chapterId: third,
      contextWindow: 32000,
      length: 500,
    );

    final labels = context.sections.map((s) => s.label).toList();
    expect(labels, containsAll(<String>['本章章纲', '前文摘要', '相关角色卡', '本章已写内容（尾部）']));

    final charactersSection =
        context.sections.firstWhere((s) => s.label == '相关角色卡');
    expect(charactersSection.content, contains('沈砚'));
    expect(charactersSection.content, contains('苏晚'));
    // 未在本章出现的角色不进入上下文
    expect(charactersSection.content, isNot(contains('无关角色')));

    // 预算充足时不截断，且不超预算
    expect(context.truncated, isFalse);
    expect(context.estimatedTokens, lessThanOrEqualTo(context.budgetTokens));
    expect(context.budgetTokens, 16000);
    // 单一 user 消息承载全部片段 + 续写要求
    expect(context.messages, hasLength(1));
    expect(context.messages.single.content, contains('【续写要求】'));
  });

  test('超预算时从最低优先级截断并给出截断标记', () async {
    final workId = await seedWork();
    final third = await chapters.createChapter(workId: workId, title: '第三章');
    await chapters.saveChapter(
      chapterId: third,
      title: '第三章',
      content: '沈砚' * 200,
      cursorOffset: 0,
      scrollOffset: 0,
    );
    await outline.saveChapterSummary(
      workId: workId,
      chapterId: third,
      summary: '本章梗概。',
    );

    final context = await builder.buildContinue(
      workId: workId,
      chapterId: third,
      contextWindow: 400, // 预算 200 token，必然超限
    );

    expect(context.truncated, isTrue);
    // 优先级最低的卷级大纲最先被丢弃
    expect(context.sections.map((s) => s.label), isNot(contains('卷级大纲')));
    // 预算已被高优先级内容占满时，尾部整段丢弃
    expect(context.sections.map((s) => s.label),
        isNot(contains('本章已写内容（尾部）')));
  });

  test('本章正文超过尾部保留量时只取尾部并标记省略', () async {
    final workId = await seedWork();
    final third = await chapters.createChapter(workId: workId, title: '第三章');
    final content = '${'前' * (ContextBuilder.tailChars + 500)}尾部标记';
    await chapters.saveChapter(
      chapterId: third,
      title: '第三章',
      content: content,
      cursorOffset: 0,
      scrollOffset: 0,
    );

    final context = await builder.buildContinue(
      workId: workId,
      chapterId: third,
      contextWindow: 32000,
    );

    final tail =
        context.sections.firstWhere((s) => s.label == '本章已写内容（尾部）');
    expect(tail.truncated, isTrue);
    expect(tail.content, startsWith('（前文略）'));
    expect(tail.content, endsWith('尾部标记'));
  });

  test('角色卡匹配按出现次数排序', () {
    final matched = matchCharacters(
      <Character>[
        Character(
          id: 1,
          workId: 1,
          name: '沈砚',
          identity: '',
          personalityTags: '',
          appearance: '',
          relations: '',
          arc: '',
        ),
        Character(
          id: 2,
          workId: 1,
          name: '苏晚',
          identity: '',
          personalityTags: '',
          appearance: '',
          relations: '',
          arc: '',
        ),
      ],
      '沈砚说。沈砚走了。苏晚点头。',
    );
    expect(matched.map((c) => c.name).toList(), <String>['沈砚', '苏晚']);
  });
}