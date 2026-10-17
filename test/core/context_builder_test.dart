import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/core/ai/context_builder.dart';
import 'package:novelphone/data/db.dart';
import 'package:novelphone/data/repositories/chapter_repository.dart';
import 'package:novelphone/data/repositories/character_repository.dart';
import 'package:novelphone/data/repositories/outline_repository.dart';
import 'package:novelphone/data/repositories/setting_repository.dart';
import 'package:novelphone/data/repositories/work_repository.dart';
import 'package:novelphone/models/setting_type.dart';
import 'package:novelphone/models/work_style_guide.dart';

/// 计数用的章节仓储替身（ENH-12）：整部作品正文读取与按 id 取正文各发生几次。
class _CountingChapters extends ChapterRepository {
  _CountingChapters(super._db);

  int fullWorkReads = 0;
  final List<int> contentReads = <int>[];

  @override
  Stream<List<Chapter>> watchChapters(int workId) {
    fullWorkReads++;
    return super.watchChapters(workId);
  }

  @override
  Future<Chapter?> getChapter(int chapterId) {
    contentReads.add(chapterId);
    return super.getChapter(chapterId);
  }
}

/// M3-13：不同作品规模下的上下文装配结果与预算遵守。
void main() {
  late AppDatabase db;
  late WorkRepository works;
  late ChapterRepository chapters;
  late CharacterRepository characters;
  late OutlineRepository outline;
  late SettingRepository settings;
  late ContextBuilder builder;

  setUp(() {
    db = AppDatabase.memory();
    works = WorkRepository(db);
    chapters = ChapterRepository(db);
    characters = CharacterRepository(db);
    outline = OutlineRepository(db);
    settings = SettingRepository(db);
    builder = ContextBuilder(
      works: works,
      chapters: chapters,
      characters: characters,
      outline: outline,
      settings: settings,
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
    expect(
      labels,
      containsAll(<String>['本章章纲', '前文摘要', '相关角色卡', '本章已写内容（尾部）']),
    );

    final charactersSection = context.sections.firstWhere(
      (s) => s.label == '相关角色卡',
    );
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
    expect(context.sections.map((s) => s.label), isNot(contains('本章已写内容（尾部）')));
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

    final tail = context.sections.firstWhere((s) => s.label == '本章已写内容（尾部）');
    expect(tail.truncated, isTrue);
    expect(tail.content, startsWith('（前文略）'));
    expect(tail.content, endsWith('尾部标记'));
  });

  test('设定集纳入上下文并排在角色卡之后', () async {
    final workId = await seedWork();
    final third = await chapters.createChapter(workId: workId, title: '第三章');
    await chapters.saveChapter(
      chapterId: third,
      title: '第三章',
      content: '沈砚握紧了刀。',
      cursorOffset: 0,
      scrollOffset: 0,
    );
    await characters.createCharacter(
      workId: workId,
      name: '沈砚',
      identity: '游侠',
    );
    await settings.createEntry(
      workId: workId,
      type: SettingType.worldview,
      name: '玄洲',
      content: '灵气复苏的东方大陆。',
    );
    await settings.createEntry(
      workId: workId,
      type: SettingType.item,
      name: '断魂刀',
      content: '沈砚家传兵器。',
    );

    final context = await builder.buildContinue(
      workId: workId,
      chapterId: third,
      contextWindow: 32000,
    );

    final labels = context.sections.map((s) => s.label).toList();
    expect(labels, contains('设定集'));
    // 设定集排在相关角色卡之后（优先级更低）
    expect(labels.indexOf('设定集'), greaterThan(labels.indexOf('相关角色卡')));

    final section = context.sections.firstWhere((s) => s.label == '设定集');
    expect(section.content, contains('世界观：'));
    expect(section.content, contains('玄洲'));
    expect(section.content, contains('道具：'));
    expect(section.content, contains('断魂刀'));
  });

  test('改写上下文把选中原文放在 messages 末尾且不注入本章尾部（ENH-04）', () async {
    final workId = await seedWork();
    final third = await chapters.createChapter(workId: workId, title: '第三章');
    await chapters.saveChapter(
      chapterId: third,
      title: '第三章',
      content: '沈砚握紧了刀。苏晚站在他身后，没有说话。',
      cursorOffset: 0,
      scrollOffset: 0,
    );
    await characters.createCharacter(
      workId: workId,
      name: '沈砚',
      identity: '游侠',
    );

    final context = await builder.buildRewrite(
      workId: workId,
      chapterId: third,
      selectedText: '沈砚握紧了刀。',
      intent: 'polish',
      contextWindow: 32000,
    );

    // 选中原文是主材料，追加在 messages 末尾。
    expect(context.messages.single.content, endsWith('【待改写原文】\n沈砚握紧了刀。'));
    // 不注入本章尾部，避免与原文重复。
    expect(context.sections.map((s) => s.label), isNot(contains('本章已写内容（尾部）')));
    // 改写专用 system，不再是续写 system。
    expect(context.system, contains('改稿助手'));
    expect(context.system, isNot(contains('续写')));
    // 角色卡按选中原文匹配。
    final charactersSection = context.sections.firstWhere(
      (s) => s.label == '相关角色卡',
    );
    expect(charactersSection.content, contains('沈砚'));
  });

  test('改写超预算时选中原文不被截断（ENH-04）', () async {
    final workId = await seedWork();
    final third = await chapters.createChapter(workId: workId, title: '第三章');
    final selected = '沈砚' * 300;
    await chapters.saveChapter(
      chapterId: third,
      title: '第三章',
      content: selected,
      cursorOffset: 0,
      scrollOffset: 0,
    );
    await settings.createEntry(
      workId: workId,
      type: SettingType.worldview,
      name: '玄洲',
      content: '灵气复苏的东方大陆。',
    );

    final context = await builder.buildRewrite(
      workId: workId,
      chapterId: third,
      selectedText: selected,
      intent: 'polish',
      contextWindow: 400, // 预算 200 token，必然超限
    );

    expect(context.truncated, isTrue);
    // 低优先级的设定集先被丢弃。
    expect(context.sections.map((s) => s.label), isNot(contains('设定集')));
    // 选中原文完整保留（不参与丢弃/截断）。
    expect(context.messages.single.content, contains('【待改写原文】\n$selected'));
  });

  test('角色卡匹配按出现次数排序', () {
    final matched = matchCharacters(<Character>[
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
    ], '沈砚说。沈砚走了。苏晚点头。');
    expect(matched.map((c) => c.name).toList(), <String>['沈砚', '苏晚']);
  });

  test('前文摘要优先使用 AI 缓存摘要（ENH-05）', () async {
    final workId = await seedWork();
    final ordered = await chapters.watchChapters(workId).first;
    // 为第一章写入 AI 摘要：续写第三章时前文摘要应直接采用缓存内容。
    await chapters.saveChapterSummary(ordered.first.id, 'AI 摘要：沈砚离乡，风从山口灌下。');

    final third = await chapters.createChapter(workId: workId, title: '第三章');
    await chapters.saveChapter(
      chapterId: third,
      title: '第三章',
      content: '沈砚握紧了刀。',
      cursorOffset: 0,
      scrollOffset: 0,
    );

    final context = await builder.buildContinue(
      workId: workId,
      chapterId: third,
      contextWindow: 32000,
    );

    final summarySection = context.sections.firstWhere(
      (s) => s.label == '前文摘要',
    );
    expect(summarySection.content, contains('AI 摘要：沈砚离乡，风从山口灌下。'));
  });

  test('buildSummary 以本章正文为材料，超预算时截断并标记（ENH-05）', () async {
    final workId = await seedWork();
    final third = await chapters.createChapter(workId: workId, title: '第三章');
    await chapters.saveChapter(
      chapterId: third,
      title: '第三章',
      content: '沈砚握紧了刀，风从山口灌下来。',
      cursorOffset: 0,
      scrollOffset: 0,
    );

    final context = await builder.buildSummary(
      workId: workId,
      chapterId: third,
      contextWindow: 32000,
    );
    expect(context.sections.map((s) => s.label), contains('本章正文'));
    expect(context.messages.single.content, contains('沈砚握紧了刀'));
    expect(context.truncated, isFalse);

    // 极小预算：正文按预算截断并标记。
    final tight = await builder.buildSummary(
      workId: workId,
      chapterId: third,
      contextWindow: 40, // 预算 20 token，装不下 system + header
    );
    expect(tight.truncated, isTrue);
    expect(tight.messages.single.content, isNot(contains('风从山口灌下来')));
  });

  test('buildOutlineExpand 把一句话梗概作为扩写种子（ENH-05）', () async {
    final workId = await seedWork();
    final third = await chapters.createChapter(workId: workId, title: '第三章');

    final context = await builder.buildOutlineExpand(
      workId: workId,
      chapterId: third,
      seed: '沈砚与苏晚在雨中摊牌',
      contextWindow: 32000,
    );

    final section = context.sections.firstWhere((s) => s.label == '本章梗概');
    expect(section.content, contains('沈砚与苏晚在雨中摊牌'));
    expect(context.messages.single.content, contains('沈砚与苏晚在雨中摊牌'));
    expect(context.truncated, isFalse);
  });

  test('本卷前情回顾并入前文摘要，卷摘要为空时零回归（ENH-06）', () async {
    final workId = await seedWork();
    final ordered = await chapters.watchChapters(workId).first;
    final third = await chapters.createChapter(workId: workId, title: '第三章');
    await chapters.saveChapter(
      chapterId: third,
      title: '第三章',
      content: '沈砚握紧了刀。',
      cursorOffset: 0,
      scrollOffset: 0,
    );

    // 未生成本卷前情回顾：输出与旧版逐字一致，无【本卷前情】前缀。
    final plain = await builder.buildContinue(
      workId: workId,
      chapterId: third,
      contextWindow: 32000,
    );
    final plainSummary = plain.sections.firstWhere((s) => s.label == '前文摘要');
    expect(plainSummary.content, startsWith('《第一章》'));
    expect(plainSummary.content, isNot(contains('【本卷前情】')));

    // 生成后：本卷前情回顾前置，最近章摘要随后。
    await chapters.saveVolumeSummary(ordered.first.volumeId, '本卷：沈砚离乡，苏晚登场。');
    final withRecap = await builder.buildContinue(
      workId: workId,
      chapterId: third,
      contextWindow: 32000,
    );
    final recapSummary = withRecap.sections.firstWhere(
      (s) => s.label == '前文摘要',
    );
    expect(recapSummary.content, startsWith('【本卷前情】本卷：沈砚离乡，苏晚登场。'));
    expect(recapSummary.content, contains('《第一章》'));
  });

  test('buildVolumeSummary 归并本卷当前章及之前的章节摘要（ENH-06）', () async {
    final workId = await seedWork();
    final ordered = await chapters.watchChapters(workId).first;
    await chapters.saveChapterSummary(ordered[0].id, '第一章摘要：沈砚离乡。');
    await chapters.saveChapterSummary(ordered[1].id, '第二章摘要：苏晚登场。');
    final third = await chapters.createChapter(workId: workId, title: '第三章');
    await chapters.saveChapter(
      chapterId: third,
      title: '第三章',
      content: '沈砚握紧了刀。',
      cursorOffset: 0,
      scrollOffset: 0,
    );

    final context = await builder.buildVolumeSummary(
      workId: workId,
      chapterId: third,
      contextWindow: 32000,
    );

    expect(
      context.sections.map((s) => s.label),
      contains('本卷素材（上一版回顾 + 新增章节）'),
    );
    final material = context.sections.firstWhere(
      (s) => s.label == '本卷素材（上一版回顾 + 新增章节）',
    );
    expect(material.content, contains('第一章摘要：沈砚离乡。'));
    expect(material.content, contains('第二章摘要：苏晚登场。'));
    // 当前章也在素材内。
    expect(material.content, contains('《第三章》'));
    expect(context.truncated, isFalse);

    // 极小预算：素材按预算截断并标记。
    final tight = await builder.buildVolumeSummary(
      workId: workId,
      chapterId: third,
      contextWindow: 40,
    );
    expect(tight.truncated, isTrue);
    expect(tight.messages.single.content, isNot(contains('第二章摘要：苏晚登场。')));
  });

  test('buildVolumeSummary 首章时素材仅含本章（ENH-06）', () async {
    final workId = await seedWork();
    final ordered = await chapters.watchChapters(workId).first;

    final context = await builder.buildVolumeSummary(
      workId: workId,
      chapterId: ordered.first.id,
      contextWindow: 32000,
    );

    final material = context.sections.firstWhere(
      (s) => s.label == '本卷素材（上一版回顾 + 新增章节）',
    );
    expect(material.content, contains('《第一章》'));
    expect(material.content, isNot(contains('《第二章》')));
  });

  group('前情摘要按需取正文（ENH-12）', () {
    test('续写上下文不整部读正文，只取无摘要的近期章', () async {
      final counting = _CountingChapters(db);
      final localBuilder = ContextBuilder(
        works: works,
        chapters: counting,
        characters: characters,
        outline: outline,
        settings: settings,
      );
      // seedWork：第一章无 AI 摘要、第二章也只有正文（都需要本地抽句兜底）。
      final workId = await seedWork();
      final ordered = await chapters.watchChapters(workId).first;
      // 第一章补一条 AI 摘要：走摘要即不再需要正文。
      await chapters.saveChapterSummary(ordered[0].id, '第一章摘要：沈砚离乡。');
      final third = await chapters.createChapter(workId: workId, title: '第三章');
      await chapters.saveChapter(
        chapterId: third,
        title: '第三章',
        content: '沈砚握紧了刀。',
        cursorOffset: 0,
        scrollOffset: 0,
      );

      final context = await localBuilder.buildContinue(
        workId: workId,
        chapterId: third,
        contextWindow: 32000,
      );

      // 顺序与摘要都取自元数据流，不再为一段回顾把整部作品正文读进内存。
      expect(counting.fullWorkReads, 0);
      // 正文只取当前章与「没有 AI 摘要的第二章」。
      expect(counting.contentReads.toSet(), <int>{third, ordered[1].id});

      final summarySection = context.sections.firstWhere(
        (s) => s.label == '前文摘要',
      );
      // 有 AI 摘要的章节直接用摘要。
      expect(summarySection.content, contains('第一章摘要：沈砚离乡。'));
      // 无摘要的章节回退本地抽句，行为与旧版一致。
      expect(summarySection.content, contains('《第二章》沈砚在雨里走了很久'));
    });

    test('灵感上下文同样不整部读正文', () async {
      final counting = _CountingChapters(db);
      final localBuilder = ContextBuilder(
        works: works,
        chapters: counting,
        characters: characters,
        outline: outline,
        settings: settings,
      );
      final workId = await seedWork();
      final third = await chapters.createChapter(workId: workId, title: '第三章');

      final recap = await localBuilder.buildInspireContext(
        workId: workId,
        chapterId: third,
      );

      expect(counting.fullWorkReads, 0);
      expect(recap.previousSummary, contains('《第二章》沈砚在雨里走了很久'));
    });
  });

  group('卷回顾省略整部正文读取（ENH-13）', () {
    test('buildVolumeSummary 不整部读正文，仅取本卷无摘要章正文', () async {
      final counting = _CountingChapters(db);
      final localBuilder = ContextBuilder(
        works: works,
        chapters: counting,
        characters: characters,
        outline: outline,
        settings: settings,
      );
      final workId = await seedWork();
      final ordered = await chapters.watchChapters(workId).first;
      // 第一章补一条 AI 摘要：走摘要即不再需要正文。
      await chapters.saveChapterSummary(ordered[0].id, '第一章摘要：沈砚离乡。');
      final third = await chapters.createChapter(workId: workId, title: '第三章');
      await chapters.saveChapter(
        chapterId: third,
        title: '第三章',
        content: '沈砚握紧了刀。',
        cursorOffset: 0,
        scrollOffset: 0,
      );

      final context = await localBuilder.buildVolumeSummary(
        workId: workId,
        chapterId: third,
        contextWindow: 32000,
      );

      // 顺序与摘要取自元数据流，不再为一段卷回顾读整部作品正文。
      expect(counting.fullWorkReads, 0);
      // 正文只取当前章与「没有 AI 摘要的第二章」。
      expect(counting.contentReads.toSet(), <int>{third, ordered[1].id});

      final material = context.sections.firstWhere(
        (s) => s.label == '本卷素材（上一版回顾 + 新增章节）',
      );
      expect(material.content, contains('第一章摘要：沈砚离乡。'));
      expect(material.content, contains('《第二章》沈砚在雨里走了很久'));
    });
  });

  test('超预算压缩前情摘要时保留【本卷前情】（ENH-07 O2）', () async {
    final workId = await seedWork();
    final ordered = await chapters.watchChapters(workId).first;
    final third = await chapters.createChapter(workId: workId, title: '第三章');
    await chapters.saveChapter(
      chapterId: third,
      title: '第三章',
      content: '沈砚握紧了刀。',
      cursorOffset: 0,
      scrollOffset: 0,
    );
    // 长本卷前情（> 120 字），确保触发压缩分支。
    await chapters.saveVolumeSummary(
      ordered.first.volumeId,
      '本卷：${'沈砚离乡，苏晚同行。' * 20}',
    );

    final context = await builder.buildContinue(
      workId: workId,
      chapterId: third,
      contextWindow: 400,
    );

    expect(context.truncated, isTrue);
    final summary = context.sections.firstWhere((s) => s.label == '前文摘要');
    expect(summary.content, contains('【本卷前情】'));
  });

  test('跨卷首章注入【前卷前情】、同卷章不注入（ENH-07 O5）', () async {
    final workId = await seedWork();
    final ordered = await chapters.watchChapters(workId).first;
    final firstVolume = (await chapters.listVolumes(workId)).first;
    await chapters.saveVolumeSummary(firstVolume.id, '第一卷：沈砚离乡。');
    final secondVolume = await chapters.createVolume(workId, '第二卷 风起');
    final head = await chapters.createChapter(
      workId: workId,
      volumeId: secondVolume,
      title: '第二卷 第一章',
    );
    await chapters.saveChapter(
      chapterId: head,
      title: '第二卷 第一章',
      content: '沈砚回到了长安。',
      cursorOffset: 0,
      scrollOffset: 0,
    );

    // 跨卷首章：注入上一卷回顾。
    final cross = await builder.buildContinue(
      workId: workId,
      chapterId: head,
      contextWindow: 32000,
    );
    final crossSummary = cross.sections.firstWhere((s) => s.label == '前文摘要');
    expect(crossSummary.content, contains('【前卷前情】第一卷：沈砚离乡。'));

    // 同卷非首章：只有本卷前情，没有前卷前情。
    final same = await builder.buildContinue(
      workId: workId,
      chapterId: ordered[1].id,
      contextWindow: 32000,
    );
    final sameSummary = same.sections.firstWhere((s) => s.label == '前文摘要');
    expect(sameSummary.content, contains('【本卷前情】第一卷：沈砚离乡。'));
    expect(sameSummary.content, isNot(contains('【前卷前情】')));
  });

  test('卷回顾增量归并：上一版回顾 + 新增章节摘要（ENH-07 O6）', () async {
    final workId = await seedWork();
    final ordered = await chapters.watchChapters(workId).first;
    final volumeId = ordered.first.volumeId;
    await chapters.saveChapterSummary(ordered[0].id, '第一章摘要：沈砚离乡。');
    await chapters.saveChapterSummary(ordered[1].id, '第二章摘要：苏晚登场。');

    // 首次全量归并：无上一版回顾，素材为全部章节摘要。
    final full = await builder.buildVolumeSummary(
      workId: workId,
      chapterId: ordered[1].id,
      contextWindow: 32000,
    );
    final fullMaterial = full.sections.firstWhere(
      (s) => s.label == '本卷素材（上一版回顾 + 新增章节）',
    );
    expect(fullMaterial.content, isNot(contains('【上一版本卷回顾】')));
    expect(fullMaterial.content, contains('第一章摘要：沈砚离乡。'));

    // 记录覆盖到第二章后，新增第三章 → 增量素材 = 上一版回顾 + 新增第三章。
    await chapters.saveVolumeSummary(
      volumeId,
      '本卷：沈砚离乡，苏晚登场。',
      coveredChapterId: ordered[1].id,
    );
    final third = await chapters.createChapter(workId: workId, title: '第三章');
    await chapters.saveChapterSummary(third, '第三章摘要：刀光乍起。');

    final inc = await builder.buildVolumeSummary(
      workId: workId,
      chapterId: third,
      contextWindow: 32000,
    );
    final incMaterial = inc.sections.firstWhere(
      (s) => s.label == '本卷素材（上一版回顾 + 新增章节）',
    );
    expect(incMaterial.content, contains('【上一版本卷回顾】'));
    expect(incMaterial.content, contains('本卷：沈砚离乡，苏晚登场。'));
    expect(incMaterial.content, contains('【新增章节摘要】'));
    expect(incMaterial.content, contains('第三章摘要：刀光乍起。'));
    // 已归并过的第一、二章摘要不再重复注入。
    expect(incMaterial.content, isNot(contains('第一章摘要：沈砚离乡。')));
  });

  test('buildInspireContext 补前文摘要与本章章纲（ENH-07 O7）', () async {
    final workId = await seedWork();
    final third = await chapters.createChapter(workId: workId, title: '第三章');
    await outline.saveChapterSummary(
      workId: workId,
      chapterId: third,
      summary: '沈砚与苏晚对峙。',
    );

    // 未指定章节：不补任何上下文，保持旧行为。
    final none = await builder.buildInspireContext(workId: workId);
    expect(none.previousSummary, isEmpty);
    expect(none.chapterOutline, isEmpty);

    final ctx = await builder.buildInspireContext(
      workId: workId,
      chapterId: third,
    );
    // 前文摘要取第三章之前的最近章节（本地抽句）。
    expect(ctx.previousSummary, contains('《第一章》'));
    expect(ctx.previousSummary, contains('《第二章》'));
    // 本章章纲来自大纲条目的摘要。
    expect(ctx.chapterOutline, contains('沈砚与苏晚对峙。'));
  });

  // ---------- ENH-22：设定一致性检查上下文 ----------

  test('buildContinuityCheck 汇总角色卡 / 设定集 / 前情摘要 / 章纲 / 正文', () async {
    final workId = await seedWork();
    final third = await chapters.createChapter(workId: workId, title: '第三章');
    await chapters.saveChapter(
      chapterId: third,
      title: '第三章',
      content: '沈砚在北境拔刀，苏晚却说他人在江南。',
      cursorOffset: 0,
      scrollOffset: 0,
    );
    await outline.saveChapterSummary(
      workId: workId,
      chapterId: third,
      summary: '沈砚北境拔刀。',
    );
    await characters.createCharacter(
      workId: workId,
      name: '沈砚',
      identity: '游侠',
    );
    await settings.createEntry(
      workId: workId,
      type: SettingType.worldview,
      name: '玄洲',
      content: '北境终年积雪。',
    );

    final context = await builder.buildContinuityCheck(
      workId: workId,
      chapterId: third,
      contextWindow: 32000,
    );

    expect(context.sections.map((s) => s.label), <String>[
      '角色卡',
      '设定集',
      '前情摘要',
      '本章章纲',
      '本章正文',
    ]);
    expect(context.system, contains('设定一致性校对'));
    final prompt = context.messages.single.content;
    expect(prompt, contains('作品：《长夜行》'));
    expect(prompt, contains('沈砚在北境拔刀'));
    expect(prompt, contains('北境终年积雪'));
    expect(prompt, contains('沈砚北境拔刀'));
    expect(prompt, contains('只列冲突'));
    expect(context.truncated, isFalse);
  });

  test('buildContinuityCheck 超预算时依次丢弃低优先资料并截断正文', () async {
    final workId = await seedWork();
    final third = await chapters.createChapter(workId: workId, title: '第三章');
    await chapters.saveChapter(
      chapterId: third,
      title: '第三章',
      content: '雨' * 600,
      cursorOffset: 0,
      scrollOffset: 0,
    );
    await outline.saveChapterSummary(
      workId: workId,
      chapterId: third,
      summary: '沈砚北境拔刀。',
    );
    await characters.createCharacter(
      workId: workId,
      name: '沈砚',
      identity: '游侠',
    );
    await settings.createEntry(
      workId: workId,
      type: SettingType.worldview,
      name: '玄洲',
      content: '北境终年积雪。',
    );

    final context = await builder.buildContinuityCheck(
      workId: workId,
      chapterId: third,
      contextWindow: 900,
    );

    expect(context.truncated, isTrue);
    final labels = context.sections.map((s) => s.label).toList();
    // 低优先资料先被丢弃，正文保留但截断。
    expect(labels, isNot(contains('前情摘要')));
    expect(labels, isNot(contains('本章章纲')));
    expect(labels, isNot(contains('设定集')));
    final body = context.sections.firstWhere((s) => s.label == '本章正文');
    expect(body.content, contains('本章过长，已截断'));
    expect(context.estimatedTokens, lessThanOrEqualTo(context.budgetTokens));
  });

  test('文风档案只进入 system 与上下文详情，不重复进入用户消息（ENH-23）', () async {
    final workId = await seedWork();
    await works.updateStyleGuide(
      workId,
      const WorkStyleGuide(
        perspective: '第三人称限知，跟随沈砚',
        tone: '冷峻克制，短句为主',
        taboos: '不用网络流行语',
        sample: '雨落在刀鞘上，他没有回头。',
      ),
    );
    final third = await chapters.createChapter(workId: workId, title: '第三章');
    await chapters.saveChapter(
      chapterId: third,
      title: '第三章',
      content: '沈砚握紧了刀。',
      cursorOffset: 0,
      scrollOffset: 0,
    );

    final context = await builder.buildContinue(
      workId: workId,
      chapterId: third,
      contextWindow: 32000,
    );

    expect(context.system, contains('【作品文风档案】'));
    expect(context.system, contains('第三人称限知，跟随沈砚'));
    expect(context.system, contains('雨落在刀鞘上，他没有回头。'));
    expect(context.messages.single.content, isNot(contains('雨落在刀鞘上')));
    expect(context.sections.map((s) => s.label), contains('作品文风档案'));
    expect(context.estimatedTokens, lessThanOrEqualTo(context.budgetTokens));
  });

  test('文风提取注入近期章节与已有档案（ENH-23）', () async {
    final workId = await seedWork();
    await works.updateStyleGuide(workId, const WorkStyleGuide(tone: '克制的白描'));
    final chapterList = await chapters.listChapters(workId);

    final context = await builder.buildStyleExtraction(
      workId: workId,
      chapterList: chapterList,
      contextWindow: 32000,
    );

    final prompt = context.messages.single.content;
    expect(prompt, contains('作品：《长夜行》'));
    expect(prompt, contains('【近期正文节选】'));
    expect(prompt, contains('少年推开木门'));
    expect(prompt, contains('克制的白描'));
    expect(context.system, contains('perspective'));
    expect(context.truncated, isFalse);
  });

  test('设定补全携带已有角色与设定，避免重复建档（ENH-23）', () async {
    final workId = await seedWork();
    await characters.createCharacter(
      workId: workId,
      name: '沈砚',
      identity: '游侠',
    );
    await settings.createEntry(
      workId: workId,
      type: SettingType.location,
      name: '长夜城',
      content: '北境边城。',
    );
    final chapterList = await chapters.listChapters(workId);

    final context = await builder.buildEntityExtraction(
      workId: workId,
      chapterList: chapterList,
      contextWindow: 32000,
    );

    final prompt = context.messages.single.content;
    expect(prompt, contains('【已有角色】'));
    expect(prompt, contains('- 沈砚（游侠）'));
    expect(prompt, contains('【已有设定】'));
    expect(prompt, contains('长夜城'));
    expect(prompt, contains('【正文节选】'));
    final labels = context.sections.map((s) => s.label).toList();
    expect(labels, containsAll(<String>['已有角色', '已有设定', '正文节选']));
  });

  test('剧情推演携带章纲、角色与作者方向（ENH-23）', () async {
    final workId = await seedWork();
    await characters.createCharacter(
      workId: workId,
      name: '沈砚',
      identity: '游侠',
    );
    final chapterList = await chapters.listChapters(workId);

    final context = await builder.buildPlotPlan(
      workId: workId,
      chapterList: chapterList,
      direction: '让苏晚主动摊牌',
      contextWindow: 32000,
    );

    final prompt = context.messages.single.content;
    expect(prompt, contains('【已有章纲】'));
    expect(prompt, contains('开篇：沈砚离乡。'));
    expect(prompt, contains('【主要角色】'));
    expect(prompt, contains('沈砚'));
    expect(prompt, contains('作者希望的方向：让苏晚主动摊牌'));
    expect(context.messages, hasLength(1));
  });

  test('作品问答按顺序注入历史并在超预算时丢弃最早一轮（ENH-23）', () async {
    final workId = await seedWork();
    final chapterList = await chapters.listChapters(workId);
    final history = <ChatContextTurn>[
      ChatContextTurn(role: 'user', content: '第一章讲了什么？'),
      ChatContextTurn(role: 'assistant', content: '沈砚离乡。'),
    ];

    final context = await builder.buildChat(
      workId: workId,
      chapterList: chapterList,
      history: history,
      message: '苏晚是谁？',
      contextWindow: 32000,
    );

    expect(context.messages, hasLength(3));
    expect(context.messages[0].role, 'user');
    expect(context.messages[1].role, 'assistant');
    expect(context.messages.last.role, 'user');
    expect(context.messages.last.content, '苏晚是谁？');
    expect(context.system, contains('【作品资料】'));
    expect(context.system, contains('章节目录'));
    expect(
      context.sections.map((s) => s.label),
      containsAll(<String>['作品资料', '对话历史']),
    );

    final tight = await builder.buildChat(
      workId: workId,
      chapterList: chapterList,
      history: history,
      message: '苏晚是谁？',
      contextWindow: 200,
    );
    expect(tight.truncated, isTrue);
    expect(tight.messages.length, lessThan(3));
    expect(tight.messages.last.content, '苏晚是谁？');
  });
}
