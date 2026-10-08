import '../../data/db.dart';
import '../../data/repositories/chapter_repository.dart';
import '../../data/repositories/character_repository.dart';
import '../../data/repositories/outline_repository.dart';
import '../../data/repositories/work_repository.dart';
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

    // 前 1-2 章摘要（按作品内章节顺序）
    final previousSummary = _previousSummary(allChapters, chapterId);

    // 相关角色卡
    final matched = matchCharacters(allCharacters, chapterText);

    // 卷级大纲：同卷其他章节梗概
    final volumeOutline = _volumeOutline(outlineEntries, volume?.id, chapterId);

    return _assemble(
      workTitle: work?.title ?? '',
      budget: budget,
      tail: _tailOf(chapterText),
      chapterOutline: chapterOutline,
      previousSummary: previousSummary,
      matchedCharacters: matched,
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
      volumeOutline: buffer.toString().trim(),
      task: _openingTask(direction),
    );
  }

  BuiltContext _assemble({
    required String workTitle,
    required int budget,
    required String tail,
    required String chapterOutline,
    required String previousSummary,
    required List<Character> matchedCharacters,
    required String volumeOutline,
    required String task,
  }) {
    final system = _systemPrompt(workTitle);

    var volumeText = volumeOutline;
    var charactersText =
        matchedCharacters.map(formatCharacter).join('\n');
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
        estimateTokens(charactersText);

    // 超预算时从优先级最低项开始丢弃（ARCHITECTURE 5.3 / PRD 6.2）。
    if (total() > budget && volumeText.isNotEmpty) {
      volumeText = '';
      truncated = true;
    }
    if (total() > budget &&
        matchedCharacters.length > minCharacters) {
      charactersText =
          matchedCharacters.take(minCharacters).map(formatCharacter).join('\n');
      truncated = true;
    }
    if (total() > budget && summaryText.length > 120) {
      summaryText = summarizeText(summaryText, maxChars: 120);
      truncated = true;
    }
    if (total() > budget) {
      final others = estimateTokens(system) +
          estimateTokens(task) +
          estimateTokens(outlineText) +
          estimateTokens(volumeText) +
          estimateTokens(summaryText) +
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

  String _tailOf(String content) {
    if (content.length <= tailChars) return content;
    return '（前文略）${content.substring(content.length - tailChars)}';
  }

  String _previousSummary(List<Chapter> ordered, int chapterId) {
    final index = ordered.indexWhere((c) => c.id == chapterId);
    if (index <= 0) return '';
    final start = (index - previousChapters).clamp(0, index);
    final picked = ordered.sublist(start, index);
    return picked
        .where((c) => c.content.trim().isNotEmpty)
        .map((c) {
          final title = c.title.isEmpty ? '未命名章节' : c.title;
          return '《$title》${summarizeText(c.content)}';
        })
        .join('\n');
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