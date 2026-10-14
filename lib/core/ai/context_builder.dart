import '../../data/db.dart';
import '../../data/repositories/chapter_repository.dart';
import '../../data/repositories/character_repository.dart';
import '../../data/repositories/outline_repository.dart';
import '../../data/repositories/setting_repository.dart';
import '../../data/repositories/work_repository.dart';
import '../../models/setting_type.dart';
import 'ai_client.dart';

/// 组装后的一段上下文，供待确认面板"上下文详情"展开查看
/// （ARCHITECTURE 5.3：作者能看见 AI 看到了什么，是产品信任的一部分）。
class ContextSection {
  const ContextSection({
    required this.label,
    required this.content,
    this.truncated = false,
  });

  final String label;
  final String content;
  final bool truncated;
}

/// 上下文组装结果。
class BuiltContext {
  const BuiltContext({
    required this.system,
    required this.messages,
    required this.sections,
    required this.truncated,
    required this.estimatedTokens,
    required this.budgetTokens,
  });

  final String system;
  final List<ChatMessage> messages;
  final List<ContextSection> sections;

  /// 是否发生过截断（面板据此提示"已省略较早前文"）。
  final bool truncated;
  final int estimatedTokens;
  final int budgetTokens;

  /// 注入附加 system 文本（B-03 用户 SKILL），并同步上下文详情的段落与 token 估算。
  BuiltContext withSystem(String newSystem, {ContextSection? section}) {
    return BuiltContext(
      system: newSystem,
      messages: messages,
      sections: section == null
          ? sections
          : <ContextSection>[section, ...sections],
      truncated: truncated,
      estimatedTokens: estimatedTokens + newSystem.length - system.length,
      budgetTokens: budgetTokens,
    );
  }

  ChatRequest toRequest({
    required String model,
    required double temperature,
    required int maxTokens,
    List<ToolSpec> tools = const <ToolSpec>[],
  }) {
    return ChatRequest(
      model: model,
      system: system,
      messages: messages,
      temperature: temperature,
      maxTokens: maxTokens,
      tools: tools,
    );
  }
}

/// token 估算（M3-10）：中文 1 字 ≈ 1 token，按字符数近似即可（ARCHITECTURE 5.3）。
int estimateTokens(String text) => text.length;

/// 本地摘要（M3-11）：按段落抽首句拼接，超长再截断。
String summarizeText(String content, {int maxChars = 500}) {
  final paragraphs = content
      .split(RegExp(r'\n+'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty);
  final buffer = StringBuffer();
  for (final paragraph in paragraphs) {
    if (buffer.isNotEmpty) buffer.write(' ');
    buffer.write(_firstSentence(paragraph));
    if (buffer.length >= maxChars) break;
  }
  final result = buffer.toString();
  if (result.length <= maxChars) return result;
  return '${result.substring(0, maxChars)}…';
}

String _firstSentence(String text) {
  final match = RegExp(r'[^。！？!?…]*[。！？!?…]').firstMatch(text);
  if (match != null) return match.group(0)!;
  return text.length > 40 ? text.substring(0, 40) : text;
}

/// 角色卡相关性匹配（M3-12）：按本章正文出现的姓名匹配，出现次数多者优先，
/// 最多 [max] 张（默认 8）。
List<Character> matchCharacters(
  List<Character> all,
  String chapterText, {
  int max = 8,
}) {
  final scored = <({Character character, int count})>[];
  for (final character in all) {
    final name = character.name;
    if (name.isEmpty) continue;
    var count = 0;
    var index = chapterText.indexOf(name);
    while (index != -1) {
      count++;
      index = chapterText.indexOf(name, index + name.length);
    }
    if (count > 0) scored.add((character: character, count: count));
  }
  scored.sort((a, b) => b.count.compareTo(a.count));
  return scored.take(max).map((e) => e.character).toList(growable: false);
}

/// 上下文组装（M3-09 / M3-10）：按 PRD 6.2 优先级装配并受 token 预算约束。
class ContextBuilder {
  ContextBuilder({
    required this.works,
    required this.chapters,
    required this.characters,
    required this.outline,
    this.settings,
  });

  /// 本章尾部保留字数（ARCHITECTURE 5.3）。
  static const int tailChars = 3000;

  /// 前文摘要取最近几章。
  static const int previousChapters = 2;

  /// 超预算时角色卡保留张数。
  static const int minCharacters = 3;

  final WorkRepository works;
  final ChapterRepository chapters;
  final CharacterRepository characters;
  final OutlineRepository outline;

  /// 设定集（B-09）：世界观 / 地点 / 道具，纳入 AI 上下文（可空，未注入则跳过）。
  final SettingRepository? settings;

  /// 续写上下文：system → 本章尾部 → 本章章纲 → 前文摘要 → 相关角色卡 → 卷级大纲。
  /// [contextWindow] 为模型上下文窗口，预算 = 其 50%（ARCHITECTURE 5.3）。
  Future<BuiltContext> buildContinue({
    required int workId,
    required int chapterId,
    int contextWindow = 32000,
    String? direction,
    int? length,
  }) async {
    final budget = (contextWindow * 0.5).round();
    final work = await works.getWork(workId);
    final chapter = await chapters.getChapter(chapterId);
    final allChapters = await chapters.watchChapters(workId).first;
    final volume = chapter == null
        ? null
        : await _volumeOf(workId, chapter.volumeId);

    final chapterText = chapter?.content ?? '';
    final outlineEntries = await outline.listOutline(workId);
    final allCharacters = await characters.listCharacters(workId);

    // 本章章纲
    final chapterOutline = outlineEntries
        .where((e) => e.chapterId == chapterId && e.summary.trim().isNotEmpty)
        .map((e) => e.summary.trim())
        .join('\n');

    // 前情摘要：本卷前情回顾（ENH-06）+ 前 1-2 章摘要（按作品内章节顺序），
    // 跨卷首章额外注入上一卷回顾（ENH-07 O5）。
    final previousSummary = _previousSummary(
      allChapters,
      chapterId,
      volume?.summary.trim() ?? '',
      previousVolumeSummary: _isVolumeHead(allChapters, chapterId)
          ? await _previousVolumeSummary(workId, volume)
          : '',
    );

    // 相关角色卡
    final matched = matchCharacters(allCharacters, chapterText);

    // 卷级大纲：同卷其他章节梗概
    final volumeOutline = _volumeOutline(outlineEntries, volume?.id, chapterId);

    // 设定集（世界观 / 地点 / 道具）：排在角色卡之后
    final settingsText = await _settingsText(workId);

    return _assemble(
      workTitle: work?.title ?? '',
      budget: budget,
      tail: _tailOf(chapterText),
      chapterOutline: chapterOutline,
      previousSummary: previousSummary,
      matchedCharacters: matched,
      settingsText: settingsText,
      volumeOutline: volumeOutline,
      task: _continueTask(direction: direction, length: length),
    );
  }

  /// 开篇助手上下文（M3-16）：作品基调 + 作者方向指令。
  Future<BuiltContext> buildOpening({
    required int workId,
    String? direction,
    int contextWindow = 32000,
  }) async {
    final budget = (contextWindow * 0.5).round();
    final work = await works.getWork(workId);
    final outlineEntries = await outline.listOutline(workId);
    final allCharacters = await characters.listCharacters(workId);

    final buffer = StringBuffer();
    if (work != null && work.title.isNotEmpty) {
      buffer.writeln('作品名：${work.title}');
    }
    final summaries = outlineEntries
        .where((e) => e.summary.trim().isNotEmpty)
        .map((e) => '- ${e.summary.trim()}')
        .take(20)
        .join('\n');
    if (summaries.isNotEmpty) buffer.writeln('已有章纲：\n$summaries');

    final characterList = allCharacters
        .take(8)
        .map((c) => '- ${c.name}${c.identity.isEmpty ? '' : '（${c.identity}）'}')
        .join('\n');
    if (characterList.isNotEmpty) buffer.writeln('主要角色：\n$characterList');

    return _assemble(
      workTitle: work?.title ?? '',
      budget: budget,
      tail: '',
      chapterOutline: '',
      previousSummary: '',
      matchedCharacters: const <Character>[],
      settingsText: await _settingsText(workId),
      volumeOutline: buffer.toString().trim(),
      task: _openingTask(direction),
    );
  }

  /// 改写上下文（ENH-04）：选中原文即主材料，不注入本章尾部，避免与原文重复。
  Future<BuiltContext> buildRewrite({
    required int workId,
    required int chapterId,
    required String selectedText,
    required String intent,
    String? instruction,
    int contextWindow = 32000,
  }) async {
    final budget = (contextWindow * 0.5).round();
    final work = await works.getWork(workId);
    final chapter = await chapters.getChapter(chapterId);
    final allChapters = await chapters.watchChapters(workId).first;
    final volume = chapter == null
        ? null
        : await _volumeOf(workId, chapter.volumeId);

    final outlineEntries = await outline.listOutline(workId);
    final allCharacters = await characters.listCharacters(workId);

    // 本章章纲
    final chapterOutline = outlineEntries
        .where((e) => e.chapterId == chapterId && e.summary.trim().isNotEmpty)
        .map((e) => e.summary.trim())
        .join('\n');

    // 角色卡按「选中原文」匹配（而非整章），更贴近改写语境。
    final matched = matchCharacters(allCharacters, selectedText);

    // 前情摘要（含跨卷首章的上一卷回顾，ENH-07 O5）。
    final previousSummary = _previousSummary(
      allChapters,
      chapterId,
      volume?.summary.trim() ?? '',
      previousVolumeSummary: _isVolumeHead(allChapters, chapterId)
          ? await _previousVolumeSummary(workId, volume)
          : '',
    );

    return _assemble(
      workTitle: work?.title ?? '',
      budget: budget,
      tail: '',
      chapterOutline: chapterOutline,
      previousSummary: previousSummary,
      matchedCharacters: matched,
      settingsText: await _settingsText(workId),
      volumeOutline: _volumeOutline(outlineEntries, volume?.id, chapterId),
      task: _rewriteTask(intent, instruction),
      payload: '【待改写原文】\n$selectedText',
      systemOverride: _rewriteSystem(),
    );
  }

  /// 逐章摘要上下文（ENH-05）：以本章正文为主材料，产出供后续章节衔接的摘要。
  /// 超长章节按预算截断并标记（不做分段 map-reduce，见方案「明确不做」）。
  Future<BuiltContext> buildSummary({
    required int workId,
    required int chapterId,
    int contextWindow = 32000,
  }) async {
    final budget = (contextWindow * 0.5).round();
    final work = await works.getWork(workId);
    final chapter = await chapters.getChapter(chapterId);
    final title = (chapter?.title ?? '').trim();
    final content = chapter?.content ?? '';
    final system = _summarySystem();
    final header = '作品：《${work?.title ?? ''}》\n'
        '本章：${title.isEmpty ? '未命名章节' : title}\n\n'
        '【本章正文】\n';
    final room =
        (budget - estimateTokens(system) - estimateTokens(header)).clamp(0, budget);
    final body =
        content.length > room ? content.substring(0, room) : content;
    final truncated = body.length < content.length;
    final payload = '$header$body';
    return BuiltContext(
      system: system,
      messages: <ChatMessage>[ChatMessage.user(payload)],
      sections: <ContextSection>[
        ContextSection(
          label: '本章正文',
          content: body,
          truncated: truncated,
        ),
        const ContextSection(label: '任务模式', content: '生成本章摘要（直接产出摘要正文，非对话）'),
      ],
      truncated: truncated,
      estimatedTokens: estimateTokens(system) + estimateTokens(payload),
      budgetTokens: budget,
    );
  }

  /// 章纲扩写上下文（ENH-05）：以本章一句话梗概为种子，产出分场大纲。
  Future<BuiltContext> buildOutlineExpand({
    required int workId,
    required int chapterId,
    required String seed,
    int contextWindow = 32000,
  }) async {
    final budget = (contextWindow * 0.5).round();
    final work = await works.getWork(workId);
    final chapter = await chapters.getChapter(chapterId);
    final title = (chapter?.title ?? '').trim();
    final system = _outlineSystem();
    final payload = '作品：《${work?.title ?? ''}》\n'
        '本章：${title.isEmpty ? '未命名章节' : title}\n\n'
        '【本章一句话梗概】\n${seed.trim()}';
    return BuiltContext(
      system: system,
      messages: <ChatMessage>[ChatMessage.user(payload)],
      sections: <ContextSection>[
        ContextSection(label: '本章梗概', content: seed.trim()),
        const ContextSection(label: '任务模式', content: '章纲扩写（一句话梗概 → 分场大纲）'),
      ],
      truncated: false,
      estimatedTokens: estimateTokens(system) + estimateTokens(payload),
      budgetTokens: budget,
    );
  }

  /// 本卷前情回顾上下文（ENH-06）：以本卷「当前章及之前」的章节摘要为素材，
  /// 归并为一段卷级前情摘要（全量归并，不做增量滚动）。超预算按字符截断并标记。
  Future<BuiltContext> buildVolumeSummary({
    required int workId,
    required int chapterId,
    int contextWindow = 32000,
  }) async {
    final budget = (contextWindow * 0.5).round();
    final work = await works.getWork(workId);
    final chapter = await chapters.getChapter(chapterId);
    final allChapters = await chapters.watchChapters(workId).first;
    final volume = chapter == null
        ? null
        : await _volumeOf(workId, chapter.volumeId);

    // 本卷「当前章及之前」的章节（按既有「卷排序 + 章排序」顺序，截到当前章含）。
    final index = allChapters.indexWhere((c) => c.id == chapterId);
    final end = index < 0 ? allChapters.length : index + 1;
    final scoped = allChapters
        .take(end)
        .where((c) => c.volumeId == chapter?.volumeId)
        .toList(growable: false);

    String digestOf(Chapter c) {
      final title = c.title.isEmpty ? '未命名章节' : c.title;
      final cached = c.summary.trim();
      final digest = cached.isEmpty ? summarizeText(c.content) : cached;
      return '《$title》$digest';
    }

    // 增量归并（ENH-07 O6）：素材 = 上一版卷回顾 + 上次归并之后的新增章节摘要；
    // 无上一版（summaryChapterId=0 或未命中覆盖章）时退化为全量，行为与旧版一致。
    final prevRecap = volume?.summary.trim() ?? '';
    final coveredId = volume?.summaryChapterId ?? 0;
    var freshStart = 0;
    if (coveredId != 0) {
      final coveredIndex = scoped.indexWhere((c) => c.id == coveredId);
      if (coveredIndex >= 0) freshStart = coveredIndex + 1;
    }
    final freshMaterial = scoped
        .sublist(freshStart)
        .where((c) =>
            c.content.trim().isNotEmpty || c.summary.trim().isNotEmpty)
        .map(digestOf)
        .join('\n');

    final blocks = <String>[];
    if (prevRecap.isEmpty) {
      if (freshMaterial.isNotEmpty) blocks.add(freshMaterial);
    } else {
      blocks.add('【上一版本卷回顾】\n$prevRecap');
      if (freshMaterial.isNotEmpty) {
        blocks.add('【新增章节摘要】\n$freshMaterial');
      }
    }
    final material = blocks.join('\n\n');

    final system = _volumeSummarySystem();
    final header = '作品：《${work?.title ?? ''}》\n'
        '本卷：${volume?.name ?? ''}\n\n'
        '【本卷素材】\n';
    final room = (budget - estimateTokens(system) - estimateTokens(header))
        .clamp(0, budget);
    final body = material.length > room ? material.substring(0, room) : material;
    final truncated = body.length < material.length;
    final payload = '$header$body';
    return BuiltContext(
      system: system,
      messages: <ChatMessage>[ChatMessage.user(payload)],
      sections: <ContextSection>[
        ContextSection(
          label: '本卷素材（上一版回顾 + 新增章节）',
          content: body,
          truncated: truncated,
        ),
        const ContextSection(label: '任务模式', content: '生成本卷前情回顾（直接产出回顾正文，非对话）'),
      ],
      truncated: truncated,
      estimatedTokens: estimateTokens(system) + estimateTokens(payload),
      budgetTokens: budget,
    );
  }

  /// 灵感上下文补丁（ENH-07 O7）：桥段点子为工具模式（不经过 _assemble），
  /// 这里额外提供「前文摘要（含卷 / 前卷前情）」与「本章章纲」，让点子贴合剧情。
  Future<({String previousSummary, String chapterOutline})> buildInspireContext({
    required int workId,
    int? chapterId,
  }) async {
    if (chapterId == null) {
      return (previousSummary: '', chapterOutline: '');
    }
    final chapter = await chapters.getChapter(chapterId);
    if (chapter == null) {
      return (previousSummary: '', chapterOutline: '');
    }
    final allChapters = await chapters.watchChapters(workId).first;
    final outlineEntries = await outline.listOutline(workId);
    final volume = await _volumeOf(workId, chapter.volumeId);
    final previousSummary = _previousSummary(
      allChapters,
      chapterId,
      volume?.summary.trim() ?? '',
      previousVolumeSummary: _isVolumeHead(allChapters, chapterId)
          ? await _previousVolumeSummary(workId, volume)
          : '',
    );
    final chapterOutline = outlineEntries
        .where((e) => e.chapterId == chapterId && e.summary.trim().isNotEmpty)
        .map((e) => e.summary.trim())
        .join('\n');
    return (previousSummary: previousSummary, chapterOutline: chapterOutline);
  }

  BuiltContext _assemble({
    required String workTitle,
    required int budget,
    required String tail,
    required String chapterOutline,
    required String previousSummary,
    required List<Character> matchedCharacters,
    required String settingsText,
    required String volumeOutline,
    required String task,
    // ENH-04：改写时追加在 messages 末尾的主材料（不参与丢弃/截断），默认空 → 对续写零影响。
    String payload = '',
    // ENH-04：改写时替换 system（默认 null → 沿用续写 system）。
    String? systemOverride,
  }) {
    final system = systemOverride ?? _systemPrompt(workTitle);

    var volumeText = volumeOutline;
    var charactersText =
        matchedCharacters.map(formatCharacter).join('\n');
    var settingsBlock = settingsText;
    var summaryText = previousSummary;
    var tailText = tail;
    final outlineText = chapterOutline;
    var truncated = false;

    int total() =>
        estimateTokens(system) +
        estimateTokens(task) +
        estimateTokens(outlineText) +
        estimateTokens(tailText) +
        estimateTokens(volumeText) +
        estimateTokens(summaryText) +
        estimateTokens(settingsBlock) +
        estimateTokens(charactersText) +
        estimateTokens(payload);

    // 超预算时从优先级最低项开始丢弃（ARCHITECTURE 5.3 / PRD 6.2）。
    if (total() > budget && volumeText.isNotEmpty) {
      volumeText = '';
      truncated = true;
    }
    if (total() > budget && settingsBlock.isNotEmpty) {
      settingsBlock = '';
      truncated = true;
    }
    if (total() > budget &&
        matchedCharacters.length > minCharacters) {
      charactersText =
          matchedCharacters.take(minCharacters).map(formatCharacter).join('\n');
      truncated = true;
    }
    if (total() > budget && summaryText.length > 120) {
      summaryText = _compressPreviousSummary(summaryText);
      truncated = true;
    }
    if (total() > budget) {
      final others = estimateTokens(system) +
          estimateTokens(task) +
          estimateTokens(outlineText) +
          estimateTokens(volumeText) +
          estimateTokens(summaryText) +
          estimateTokens(settingsBlock) +
          estimateTokens(charactersText);
      final room = budget - others;
      if (room <= 0) {
        // 其余内容已占满预算，尾部完全放不下：整段丢弃并提示截断。
        tailText = '';
        truncated = true;
      } else if (tailText.length > room) {
        tailText = '（前文略）${tailText.substring(tailText.length - room)}';
        truncated = true;
      }
    }

    final sections = <ContextSection>[
      if (volumeText.isNotEmpty)
        ContextSection(label: '卷级大纲', content: volumeText),
      if (summaryText.isNotEmpty)
        ContextSection(label: '前文摘要', content: summaryText),
      if (charactersText.isNotEmpty)
        ContextSection(label: '相关角色卡', content: charactersText, truncated: matchedCharacters.length > minCharacters && truncated),
      if (settingsBlock.isNotEmpty)
        ContextSection(label: '设定集', content: settingsBlock),
      if (outlineText.isNotEmpty)
        ContextSection(label: '本章章纲', content: outlineText),
      if (tailText.isNotEmpty)
        ContextSection(
          label: '本章已写内容（尾部）',
          content: tailText,
          truncated: tailText.startsWith('（前文略）'),
        ),
    ];

    final userContent = <String>[
      for (final section in sections) '【${section.label}】\n${section.content}',
      task,
      if (payload.isNotEmpty) payload,
    ].join('\n\n');

    return BuiltContext(
      system: system,
      messages: <ChatMessage>[ChatMessage.user(userContent)],
      sections: sections,
      truncated: truncated,
      estimatedTokens: total(),
      budgetTokens: budget,
    );
  }

  String _systemPrompt(String workTitle) {
    final buffer = StringBuffer()
      ..writeln('你是一位中文网络小说写作助手，正在协助作者续写作品${workTitle.isEmpty ? '' : '《$workTitle》'}。')
      ..writeln('写作要求：')
      ..writeln('1. 严格延续已有内容的人物设定、称谓、语气与叙事视角。')
      ..writeln('2. 不复述、不总结已有内容，直接接续往下写。')
      ..writeln('3. 不改变已写出的事实与情节走向。')
      ..writeln('4. 避免陈词滥调与套路化表达（如"不禁""仿佛""嘴角勾起""眸中闪过"等），句式多变，语言自然。')
      ..writeln('5. 只输出正文，不写解释、不加标题、不使用 markdown 标记。');
    return buffer.toString().trim();
  }

  String _continueTask({String? direction, int? length}) {
    final buffer = StringBuffer('【续写要求】\n接着"本章已写内容"继续写，输出纯正文。');
    if (length != null) buffer.writeln('本次续写约 $length 字。');
    final trimmed = direction?.trim() ?? '';
    if (trimmed.isNotEmpty) buffer.writeln('作者补充的方向：$trimmed');
    return buffer.toString();
  }

  String _openingTask(String? direction) {
    final buffer = StringBuffer('【任务】\n为这部作品写一个开头段落（100-300 字），输出纯正文。');
    final trimmed = direction?.trim() ?? '';
    if (trimmed.isNotEmpty) buffer.writeln('作者给定的方向：$trimmed');
    return buffer.toString();
  }

  /// 逐章摘要 system（ENH-05）：只写已发生的事实，供后续章节衔接。
  String _summarySystem() {
    final buffer = StringBuffer()
      ..writeln('你是一位中文小说编辑。请为作者给出的章节正文写一段「本章摘要」，供后续章节的 AI 续写衔接使用。')
      ..writeln('要求：')
      ..writeln('1. 篇幅 150~250 字，按时间顺序概括关键事件、人物行动与关系变化、埋下的伏笔。')
      ..writeln('2. 只写已经发生的事实，不评价、不推测、不抒情，不预告未发生的内容。')
      ..writeln('3. 不要标题、编号或 markdown 标记，直接输出摘要正文。');
    return buffer.toString().trim();
  }

  /// 章纲扩写 system（ENH-05）：一句话梗概 → 可直接指导写作的分场大纲。
  String _outlineSystem() {
    final buffer = StringBuffer()
      ..writeln('你是一位中文小说编剧。作者给出本章的一句话梗概，请扩写为可直接指导写作的「分场大纲」。')
      ..writeln('要求：')
      ..writeln('1. 按场景分 3~6 条，每条 1~2 句，写清：地点、出场人物、发生的事件与冲突、情绪转折、结尾留的钩子。')
      ..writeln('2. 严格贴合原梗概与已有设定，不新增与原梗概矛盾的主线内容。')
      ..writeln('3. 只输出分场大纲本身，不写额外解释、不加标题。');
    return buffer.toString().trim();
  }

  /// 本卷前情回顾 system（ENH-06）：把各章摘要归并为本卷主线回顾。
  String _volumeSummarySystem() {
    final buffer = StringBuffer()
      ..writeln('你是一位中文小说编辑。作者提供了某一卷各章的摘要，请把它们归并成一段「本卷前情回顾」，供后续章节的 AI 续写衔接使用。')
      ..writeln('要求：')
      ..writeln('1. 篇幅 200~400 字，按时间顺序梳理本卷主线：关键事件、人物行动与关系变化、埋下的伏笔。')
      ..writeln('2. 只写已经发生的事实，不评价、不推测、不抒情，不预告未发生的内容。')
      ..writeln('3. 不要标题、编号或 markdown 标记，直接输出回顾正文。');
    return buffer.toString().trim();
  }

  /// 改写 system（ENH-04）：只输出改写后正文，保持人称视角与既有事实，不增删情节。
  String _rewriteSystem() {
    final buffer = StringBuffer()
      ..writeln('你是一位中文网络小说改稿助手，正在协助作者修改作品正文。')
      ..writeln('改写要求：')
      ..writeln('1. 只输出改写后的正文，不写解释、不加标题、不使用 markdown 标记。')
      ..writeln('2. 保持原有的人物设定、称谓、叙事人称与视角，沿用既有事实。')
      ..writeln('3. 不增删情节，不改变剧情走向与事件结果。')
      ..writeln('4. 避免陈词滥调与套路化表达，句式多变，语言自然。');
    return buffer.toString().trim();
  }

  /// 改写任务说明（ENH-04）：[intent] 取值与 RewriteIntent 对齐（polish/expand/condense/tone）。
  String _rewriteTask(String intent, String? instruction) {
    final buffer = StringBuffer('【改写要求】\n改写"待改写原文"，输出纯正文。');
    switch (intent) {
      case 'expand':
        buffer.writeln('扩写：篇幅约为原文的 1.5~2 倍，补充细节与描写，不新增情节事实。');
      case 'condense':
        buffer.writeln('缩写：篇幅约为原文的 1/2，保留关键信息与情绪，删减冗余。');
      case 'tone':
        buffer.writeln('调整语气：按作者补充指令调整叙述语气与用词风格。');
      case 'polish':
      default:
        buffer.writeln('润色：字数与原文基本相当，只提升表达，不改变内容。');
    }
    final trimmed = instruction?.trim() ?? '';
    if (trimmed.isNotEmpty) buffer.writeln('作者补充指令：$trimmed');
    return buffer.toString();
  }

  String _tailOf(String content) {
    if (content.length <= tailChars) return content;
    return '（前文略）${content.substring(content.length - tailChars)}';
  }

  /// 压缩前情摘要（ENH-07 O2）：保留【本卷前情】/【前卷前情】等回顾行（截到 ~160 字），
  /// 只对随后的章节摘要做抽句压缩；无回顾行时退回原逻辑（零回归）。
  String _compressPreviousSummary(String summary) {
    final heads = <String>[];
    final rest = <String>[];
    for (final line in summary.split('\n')) {
      if (line.startsWith('【本卷前情】') || line.startsWith('【前卷前情】')) {
        heads.add(line.length > 161 ? '${line.substring(0, 160)}…' : line);
      } else {
        rest.add(line);
      }
    }
    if (heads.isEmpty) return summarizeText(summary, maxChars: 120);
    final body = rest.join('\n').trim();
    if (body.isEmpty) return heads.join('\n');
    return <String>[...heads, summarizeText(body, maxChars: 120)].join('\n');
  }

  /// 是否为所在卷的首章（ENH-07 O5）：上一个章节属于不同卷时为真；全书首章无前卷。
  bool _isVolumeHead(List<Chapter> ordered, int chapterId) {
    final index = ordered.indexWhere((c) => c.id == chapterId);
    if (index <= 0) return false;
    return ordered[index - 1].volumeId != ordered[index].volumeId;
  }

  /// 上一卷的本卷前情回顾（ENH-07 O5）：无上一卷或未生成时返回空串。
  Future<String> _previousVolumeSummary(int workId, Volume? volume) async {
    if (volume == null) return '';
    final volumes = await chapters.listVolumes(workId);
    final index = volumes.indexWhere((v) => v.id == volume.id);
    if (index <= 0) return '';
    return volumes[index - 1].summary.trim();
  }

  /// 前情摘要（ENH-06 / ENH-07 O5）：上一卷前情 + 本卷前情回顾 + 最近 1-2 章摘要。
  /// [volumeSummary] 为空时输出与旧版逐字一致（零回归）。
  String _previousSummary(
    List<Chapter> ordered,
    int chapterId,
    String volumeSummary, {
    String previousVolumeSummary = '',
  }) {
    final parts = <String>[];
    final lastVolume = previousVolumeSummary.trim();
    if (lastVolume.isNotEmpty) parts.add('【前卷前情】$lastVolume');

    final recap = volumeSummary.trim();
    if (recap.isNotEmpty) parts.add('【本卷前情】$recap');

    final index = ordered.indexWhere((c) => c.id == chapterId);
    if (index > 0) {
      final start = (index - previousChapters).clamp(0, index);
      parts.addAll(ordered.sublist(start, index)
          .where((c) =>
              c.content.trim().isNotEmpty || c.summary.trim().isNotEmpty)
          .map((c) {
        final title = c.title.isEmpty ? '未命名章节' : c.title;
        // ENH-05：优先使用 AI 生成的章节摘要（信息密度更高），
        // 未生成摘要的章节回退到本地抽句，行为与旧版一致。
        final cached = c.summary.trim();
        final digest = cached.isEmpty ? summarizeText(c.content) : cached;
        return '《$title》$digest';
      }));
    }
    return parts.join('\n');
  }

  String _volumeOutline(
    List<OutlineEntry> entries,
    int? volumeId,
    int chapterId,
  ) {
    final scoped = entries.where((e) {
      if (e.chapterId == chapterId) return false;
      if (e.summary.trim().isEmpty) return false;
      if (volumeId == null) return true;
      return e.volumeId == volumeId;
    });
    return scoped.map((e) => '- ${e.summary.trim()}').join('\n');
  }

  Future<Volume?> _volumeOf(int workId, int volumeId) async {
    final volumes = await chapters.listVolumes(workId);
    for (final volume in volumes) {
      if (volume.id == volumeId) return volume;
    }
    return null;
  }

  /// 设定集格式化为一段文本（按世界观 / 地点 / 道具分组），未注入 repository 时返回空。
  Future<String> _settingsText(int workId) async {
    final repository = settings;
    if (repository == null) return '';
    final entries = await repository.listEntries(workId);
    final buffer = StringBuffer();
    for (final type in SettingType.values) {
      final group = entries.where((e) =>
          e.type == type.value &&
          (e.name.trim().isNotEmpty || e.content.trim().isNotEmpty));
      if (group.isEmpty) continue;
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.writeln('${type.label}：');
      for (final entry in group) {
        final name = entry.name.trim();
        final content = entry.content.trim();
        buffer.writeln(content.isEmpty ? '- $name' : '- $name：$content');
      }
    }
    return buffer.toString().trim();
  }
}

/// 角色卡格式化（同时用于上下文与工具结果）。
String formatCharacter(Character c) {
  final parts = <String>[
    if (c.identity.isNotEmpty) '身份：${c.identity}',
    if (c.personalityTags.isNotEmpty) '性格：${c.personalityTags}',
    if (c.appearance.isNotEmpty) '外貌：${c.appearance}',
    if (c.relations.isNotEmpty) '人际关系：${c.relations}',
    if (c.arc.isNotEmpty) '弧光：${c.arc}',
  ];
  return '- ${c.name}${parts.isEmpty ? '' : '（${parts.join('；')}）'}';
}