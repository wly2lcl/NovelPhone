import 'dart:isolate';

import 'package:http/http.dart' as http;

import '../../core/ai/agent_core.dart';
import '../../core/ai/ai_client.dart';
import '../../core/ai/ai_client_factory.dart';
import '../../core/ai/context_builder.dart';
import '../../core/ai/flavor_check.dart';
import '../../core/ai/mcp/mcp_bridge.dart';
import '../../core/ai/skills/skill.dart';
import '../../core/ai/tools/local_tools.dart';
import '../../core/ai_flavor_rules.dart';
import '../../data/db.dart';
import '../../data/repositories/chapter_repository.dart';
import '../../data/repositories/character_repository.dart';
import '../../data/repositories/outline_repository.dart';
import '../../data/repositories/setting_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/token_stats_repository.dart';
import '../../data/repositories/work_repository.dart';
import 'mcp_credentials.dart';

/// 灵感模式。
class InspireMode {
  const InspireMode._();

  static const String ideas = 'ideas';
  static const String opening = 'opening';

  static String label(String mode) => mode == opening ? '开篇助手' : '桥段点子';
}

/// 改写意图（ENH-04）：润色 / 扩写 / 缩写 / 改语气。
class RewriteIntent {
  const RewriteIntent._();

  static const String polish = 'polish';
  static const String expand = 'expand';
  static const String condense = 'condense';
  static const String tone = 'tone';

  static const List<String> all = <String>[polish, expand, condense, tone];

  static String label(String intent) {
    switch (intent) {
      case expand:
        return '扩写';
      case condense:
        return '缩写';
      case tone:
        return '改语气';
      case polish:
      default:
        return '润色';
    }
  }
}

/// 用例产出的统一事件（ARCHITECTURE 6.1：全部用例共享同一套事件与错误处理）。
sealed class AiEvent {
  const AiEvent();
}

/// 上下文已组装完成（面板据此展示"上下文详情"，先于首个文本增量）。
class AiContextBuilt extends AiEvent {
  const AiContextBuilt(this.context);

  final BuiltContext context;
}

class AiTextChunk extends AiEvent {
  const AiTextChunk(this.text);

  final String text;
}

/// 生成结束，携带 usageId 供采纳 / 忽略回写 outcome。
class AiFinished extends AiEvent {
  const AiFinished({
    required this.usageId,
    required this.text,
    required this.promptTokens,
    required this.completionTokens,
  });

  final int usageId;
  final String text;
  final int promptTokens;
  final int completionTokens;
}

class AiFailed extends AiEvent {
  const AiFailed({
    required this.kind,
    required this.message,
    this.statusCode,
    this.code,
    this.detail,
  });

  final AiErrorKind kind;
  final String message;

  /// 结构化补充信息（来自 [ChatError]），供展示时本地化重组文案。
  final int? statusCode;
  final String? code;
  final String? detail;
}

/// 未配置可用的模型组或 key：UI 引导至设置页而非报错（PRD 5.8）。
class AiNeedsConfig extends AiEvent {
  const AiNeedsConfig();
}

// ---------- AI 感检查事件（M4-06 / M4-09）----------

sealed class CheckEvent {
  const CheckEvent();
}

/// 规则层结果（即时、免费），面板先据此渲染问题列表。
class CheckRuleResult extends CheckEvent {
  const CheckRuleResult({required this.result, required this.scope});

  final FlavorResult result;
  final CheckScope scope;
}

/// 深检开始：分段数与预估 token（PRD 5.7：面板显示预估与实测）。
class CheckDeepStarted extends CheckEvent {
  const CheckDeepStarted({
    required this.segments,
    required this.estimatedTokens,
  });

  final int segments;
  final int estimatedTokens;
}

/// 深检进度。
class CheckDeepProgress extends CheckEvent {
  const CheckDeepProgress({required this.done, required this.total});

  final int done;
  final int total;
}

/// 深检完成：返回全部问题（未去重，由面板与规则结果合并）。
class CheckDeepFinished extends CheckEvent {
  const CheckDeepFinished({
    required this.issues,
    required this.promptTokens,
    required this.completionTokens,
    required this.usageId,
    this.fallbackText,
  });

  final List<FlavorIssue> issues;
  final int promptTokens;
  final int completionTokens;
  final int usageId;

  /// JSON 解析失败时的纯文本降级内容（M4-07）。
  final String? fallbackText;
}

/// 深检失败：保留规则层结果并提示（PRD 5.7 边界异常）。
class CheckDeepFailed extends CheckEvent {
  const CheckDeepFailed({
    required this.kind,
    required this.message,
    this.statusCode,
    this.code,
    this.detail,
  });

  final AiErrorKind kind;
  final String message;

  /// 结构化补充信息（来自 [ChatError]），供展示时本地化重组文案。
  final int? statusCode;
  final String? code;
  final String? detail;
}

/// 深检需要配置模型（引导至设置页）。
class CheckNeedsConfig extends CheckEvent {
  const CheckNeedsConfig();
}

/// 测试连接结果分类（供展示时本地化）。
enum TestResultKind {
  /// 连接成功（可能携带模型回复 detail）。
  ok,

  /// 未填写模型名。
  missingModel,

  /// 未填写 API Key。
  missingApiKey,

  /// 请求失败（细节见 errorKind / code / statusCode / detail）。
  failed,
}

/// 测试连接结果。
class TestResult {
  const TestResult({
    required this.ok,
    required this.message,
    required this.kind,
    this.detail,
    this.errorKind,
    this.statusCode,
    this.code,
  });

  final bool ok;
  final String message;

  /// 结构化分类，展示时据此选择本地化文案。
  final TestResultKind kind;

  /// 成功时模型回复的可读文本；失败时插值的原始信息。
  final String? detail;

  /// [kind] 为 failed 且来自流式错误时的错误分类。
  final AiErrorKind? errorKind;

  /// 失败时的 HTTP 状态码（来自 [ChatError.statusCode]）。
  final int? statusCode;

  /// 失败时的子分类（[ChatErrorCode] 常量，来自 [ChatError.code]）。
  final String? code;
}

/// AI 用例编排（ARCHITECTURE 5.6 / 6.1）：续写、灵感、测试连接。
/// 全部用例共享同一 AiClient 与错误处理，网络调用不下沉到 Repository。
class AiService {
  AiService({
    required this.settings,
    required this.works,
    required this.chapters,
    required this.characters,
    required this.outline,
    required this.stats,
    this.settingRepository,
    this.httpClient,
    this.mcpOpener,
  }) {
    contexts = ContextBuilder(
      works: works,
      chapters: chapters,
      characters: characters,
      outline: outline,
      settings: settingRepository,
    );
  }

  final SettingsRepository settings;
  final WorkRepository works;
  final ChapterRepository chapters;
  final CharacterRepository characters;
  final OutlineRepository outline;
  final TokenStatsRepository stats;

  /// 设定集（B-09）：供上下文组装使用（可空，未注入则不参与）。
  final SettingRepository? settingRepository;

  final http.Client? httpClient;

  /// MCP 会话打开方式（默认 [openMcpTools]；测试可注入假实现避免真实联网）。
  final McpToolOpener? mcpOpener;
  late final ContextBuilder contexts;

  /// 该任务是否已具备可用配置。
  Future<bool> isReady(String task) async {
    if (task == AiTask.rewrite) return await _resolveRewriteModel() != null;
    if (task == AiTask.summary) return await _resolveSummaryModel() != null;
    if (task == AiTask.outlineExpand) {
      return await _resolveOutlineModel() != null;
    }
    if (task == AiTask.volumeSummary) {
      return await _resolveVolumeSummaryModel() != null;
    }
    return await settings.resolveTaskModelWithKey(task) != null;
  }

  // ---------- 续写（M3-14）----------

  Stream<AiEvent> continueWriting({
    required int workId,
    required int chapterId,
    String? direction,
    int? length,
    // ENH-05：多候选续写时按候选序号微调温度制造差异（0/1/2 → -0.15/+0/+0.15）。
    int? variant,
    // ENH-09：多候选共用的预组装上下文（见 prebuildContinue）；为空时现组装。
    BuiltContext? prebuilt,
  }) async* {
    final resolved = await settings.resolveTaskModelWithKey(
      AiTask.continueWriting,
    );
    if (resolved == null) {
      yield const AiNeedsConfig();
      return;
    }
    final group = resolved.group;
    final model = _firstModel(group);
    if (model == null) {
      yield _missingModelFailure(group);
      return;
    }

    // ENH-09：多候选续写三路只在温度上不同、上下文完全一致，由 prebuildContinue
    // 预先组装好传入，避免每个候选重复取数与组装。
    final injected =
        prebuilt ??
        _withSkills(
          await contexts.buildContinue(
            workId: workId,
            chapterId: chapterId,
            contextWindow: group.contextWindow,
            direction: direction,
            length: length,
          ),
          await settings.listEnabledSkills(),
        );
    yield AiContextBuilt(injected);

    final client = buildAiClient(
      provider: group.provider,
      baseUrl: group.baseUrl,
      apiKey: resolved.apiKey,
      httpClient: httpClient,
    );
    final request = injected.toRequest(
      model: model,
      temperature: _variantTemperature(group.temperature, variant),
      maxTokens: group.maxTokens,
    );

    yield* _run(
      client: client,
      request: request,
      task: AiTask.continueWriting,
      model: model,
      workId: workId,
      chapterId: chapterId,
    );
  }

  /// 预组装续写上下文（ENH-09）：多候选续写的三个候选只在温度上不同，上下文
  /// 完全一致，这里一次组装好供三路流共用，省掉两次全量取数与组装。
  /// 返回 null 表示尚未配置可用模型，此时各流会自行走 NeedsConfig 分支。
  Future<BuiltContext?> prebuildContinue({
    required int workId,
    required int chapterId,
    String? direction,
    int? length,
  }) async {
    final resolved = await settings.resolveTaskModelWithKey(
      AiTask.continueWriting,
    );
    if (resolved == null) return null;
    final group = resolved.group;
    if (_firstModel(group) == null) return null;
    final built = await contexts.buildContinue(
      workId: workId,
      chapterId: chapterId,
      contextWindow: group.contextWindow,
      direction: direction,
      length: length,
    );
    return _withSkills(built, await settings.listEnabledSkills());
  }

  /// 多候选温度微调（ENH-05）：variant 为空时沿用模型组温度。
  static double _variantTemperature(double base, int? variant) {
    if (variant == null) return base;
    return (base + (variant - 1) * 0.15).clamp(0.0, 2.0);
  }

  // ---------- 灵感（M3-16）----------

  Stream<AiEvent> inspire({
    required int workId,
    required String mode,
    int? anchorChapterId,
    String? direction,
  }) async* {
    final resolved = await settings.resolveTaskModelWithKey(AiTask.inspire);
    if (resolved == null) {
      yield const AiNeedsConfig();
      return;
    }
    final group = resolved.group;
    final model = _firstModel(group);
    if (model == null) {
      yield _missingModelFailure(group);
      return;
    }

    final client = buildAiClient(
      provider: group.provider,
      baseUrl: group.baseUrl,
      apiKey: resolved.apiKey,
      httpClient: httpClient,
    );
    // B-03：启用技能作为附加 system 指令并限定其工具白名单。
    final skills = await settings.listEnabledSkills();

    if (mode == InspireMode.opening) {
      // 开篇助手：ContextBuilder 预注入（ARCHITECTURE 5.4）。
      final built = await contexts.buildOpening(
        workId: workId,
        direction: direction,
        contextWindow: group.contextWindow,
      );
      final injected = _withSkills(built, skills);
      yield AiContextBuilt(injected);
      final request = injected.toRequest(
        model: model,
        temperature: group.temperature,
        maxTokens: group.maxTokens,
      );
      yield* _run(
        client: client,
        request: request,
        task: AiTask.inspire,
        model: model,
        workId: workId,
        chapterId: anchorChapterId,
      );
      return;
    }

    // 桥段点子：走工具按需取数（ARCHITECTURE 5.4）。
    // ENH-07 O7：额外补「前文摘要」与「本章章纲」，让点子贴合剧情。
    final extra = await contexts.buildInspireContext(
      workId: workId,
      chapterId: anchorChapterId,
    );
    final prompt = await _ideasPrompt(
      workId,
      anchorChapterId,
      direction,
      previousSummary: extra.previousSummary,
      chapterOutline: extra.chapterOutline,
    );
    final system = composeSkillSystem(_ideasSystem, skills);
    yield AiContextBuilt(
      BuiltContext(
        system: system,
        messages: <ChatMessage>[ChatMessage.user(prompt)],
        sections: <ContextSection>[
          ContextSection(label: '任务模式', content: '桥段点子（AI 可按需调用工具取数）'),
          if (extra.previousSummary.isNotEmpty)
            ContextSection(label: '前文摘要', content: extra.previousSummary),
          if (extra.chapterOutline.isNotEmpty)
            ContextSection(label: '本章章纲', content: extra.chapterOutline),
          ContextSection(label: '生成要求', content: prompt),
          if (skills.isNotEmpty)
            ContextSection(
              label: '用户技能',
              content: skills.map((s) => s.name).join('、'),
            ),
        ],
        truncated: false,
        estimatedTokens: estimateTokens(system) + estimateTokens(prompt),
        budgetTokens: (group.contextWindow * 0.5).round(),
      ),
    );
    final agent = AgentCore(client: client);
    final request = ChatRequest(
      model: model,
      system: system,
      messages: <ChatMessage>[ChatMessage.user(prompt)],
      temperature: group.temperature,
      maxTokens: group.maxTokens,
    );
    var tools = buildLocalTools(
      chapters: chapters,
      characters: characters,
      outline: outline,
    );
    // B-02：把已启用的远程 MCP server 工具并入同一套 Tool，用完即关闭会话。
    final sessions = <McpToolSession>[];
    try {
      for (final server in await settings.listEnabledMcpServers()) {
        try {
          final session = await (mcpOpener ?? openMcpTools)(
            server,
            await resolveMcpCredentials(
              settings,
              server,
              httpClient: httpClient,
            ),
          );
          if (session.tools.isEmpty) {
            await session.close();
            continue;
          }
          sessions.add(session);
          tools.addAll(session.tools);
        } catch (_) {
          // 单个 MCP server 连接失败不阻断生成（可在设置页单独「测试连接」）。
        }
      }
      yield* _run(
        chunks: agent.run(
          request: request,
          tools: filterToolsBySkills(tools, skills),
        ),
        task: AiTask.inspire,
        model: model,
        workId: workId,
        chapterId: anchorChapterId,
      );
    } finally {
      for (final session in sessions) {
        await session.close();
      }
    }
  }

  // ---------- 改写（ENH-04）----------

  /// 改写选中段落：润色 / 扩写 / 缩写 / 改语气。未单独配置改写模型组时回退续写组。
  Stream<AiEvent> rewrite({
    required int workId,
    required int chapterId,
    required String selectedText,
    String intent = RewriteIntent.polish,
    String? instruction,
  }) async* {
    final resolved = await _resolveRewriteModel();
    if (resolved == null) {
      yield const AiNeedsConfig();
      return;
    }
    final group = resolved.group;
    final model = _firstModel(group);
    if (model == null) {
      yield _missingModelFailure(group);
      return;
    }

    final built = await contexts.buildRewrite(
      workId: workId,
      chapterId: chapterId,
      selectedText: selectedText,
      intent: intent,
      instruction: instruction,
      contextWindow: group.contextWindow,
    );
    // B-03：把启用技能作为附加 system 指令注入。
    final injected = _withSkills(built, await settings.listEnabledSkills());
    yield AiContextBuilt(injected);

    final client = buildAiClient(
      provider: group.provider,
      baseUrl: group.baseUrl,
      apiKey: resolved.apiKey,
      httpClient: httpClient,
    );
    final request = injected.toRequest(
      model: model,
      temperature: group.temperature,
      maxTokens: group.maxTokens,
    );

    yield* _run(
      client: client,
      request: request,
      task: AiTask.rewrite,
      model: model,
      workId: workId,
      chapterId: chapterId,
    );
  }

  /// 改写模型组解析：优先改写专用配置，其次回退续写组（零配置也可用）。
  Future<ResolvedModel?> _resolveRewriteModel() async =>
      await settings.resolveTaskModelWithKey(AiTask.rewrite) ??
      await settings.resolveTaskModelWithKey(AiTask.continueWriting);

  // ---------- 逐章摘要（ENH-05）----------

  /// 为本章正文生成摘要，写回 CHAPTER.summary 后供后续章节上下文衔接。
  Stream<AiEvent> summarizeChapter({
    required int workId,
    required int chapterId,
  }) async* {
    final resolved = await _resolveSummaryModel();
    if (resolved == null) {
      yield const AiNeedsConfig();
      return;
    }
    final group = resolved.group;
    final model = _firstModel(group);
    if (model == null) {
      yield _missingModelFailure(group);
      return;
    }

    final built = await contexts.buildSummary(
      workId: workId,
      chapterId: chapterId,
      contextWindow: group.contextWindow,
    );
    final injected = _withSkills(built, await settings.listEnabledSkills());
    yield AiContextBuilt(injected);

    final client = buildAiClient(
      provider: group.provider,
      baseUrl: group.baseUrl,
      apiKey: resolved.apiKey,
      httpClient: httpClient,
    );
    final request = injected.toRequest(
      model: model,
      temperature: group.temperature,
      maxTokens: group.maxTokens,
    );

    yield* _run(
      client: client,
      request: request,
      task: AiTask.summary,
      model: model,
      workId: workId,
      chapterId: chapterId,
    );
  }

  /// 摘要模型组解析：未单独配置时回退续写组（零配置也可用）。
  Future<ResolvedModel?> _resolveSummaryModel() async =>
      await settings.resolveTaskModelWithKey(AiTask.summary) ??
      await settings.resolveTaskModelWithKey(AiTask.continueWriting);

  // ---------- 章纲扩写（ENH-05）----------

  /// 把本章一句话梗概扩写为分场大纲，结果由 UI 写回本章章纲。
  Stream<AiEvent> expandOutline({
    required int workId,
    required int chapterId,
    required String seed,
  }) async* {
    final resolved = await _resolveOutlineModel();
    if (resolved == null) {
      yield const AiNeedsConfig();
      return;
    }
    final group = resolved.group;
    final model = _firstModel(group);
    if (model == null) {
      yield _missingModelFailure(group);
      return;
    }

    final built = await contexts.buildOutlineExpand(
      workId: workId,
      chapterId: chapterId,
      seed: seed,
      contextWindow: group.contextWindow,
    );
    final injected = _withSkills(built, await settings.listEnabledSkills());
    yield AiContextBuilt(injected);

    final client = buildAiClient(
      provider: group.provider,
      baseUrl: group.baseUrl,
      apiKey: resolved.apiKey,
      httpClient: httpClient,
    );
    final request = injected.toRequest(
      model: model,
      temperature: group.temperature,
      maxTokens: group.maxTokens,
    );

    yield* _run(
      client: client,
      request: request,
      task: AiTask.outlineExpand,
      model: model,
      workId: workId,
      chapterId: chapterId,
    );
  }

  /// 章纲扩写模型组解析：未单独配置时回退续写组（零配置也可用）。
  Future<ResolvedModel?> _resolveOutlineModel() async =>
      await settings.resolveTaskModelWithKey(AiTask.outlineExpand) ??
      await settings.resolveTaskModelWithKey(AiTask.continueWriting);

  // ---------- 本卷前情回顾（ENH-06）----------

  /// 以本卷「当前章及之前」的章节摘要归并生成本卷前情回顾，结果由 UI 写回 VOLUME.summary。
  Stream<AiEvent> summarizeVolume({
    required int workId,
    required int chapterId,
  }) async* {
    final resolved = await _resolveVolumeSummaryModel();
    if (resolved == null) {
      yield const AiNeedsConfig();
      return;
    }
    final group = resolved.group;
    final model = _firstModel(group);
    if (model == null) {
      yield _missingModelFailure(group);
      return;
    }

    final built = await contexts.buildVolumeSummary(
      workId: workId,
      chapterId: chapterId,
      contextWindow: group.contextWindow,
    );
    final injected = _withSkills(built, await settings.listEnabledSkills());
    yield AiContextBuilt(injected);

    final client = buildAiClient(
      provider: group.provider,
      baseUrl: group.baseUrl,
      apiKey: resolved.apiKey,
      httpClient: httpClient,
    );
    final request = injected.toRequest(
      model: model,
      temperature: group.temperature,
      maxTokens: group.maxTokens,
    );

    yield* _run(
      client: client,
      request: request,
      task: AiTask.volumeSummary,
      model: model,
      workId: workId,
      chapterId: chapterId,
    );
  }

  /// 卷回顾模型组解析：未单独配置时回退续写组（零配置也可用）。
  Future<ResolvedModel?> _resolveVolumeSummaryModel() async =>
      await settings.resolveTaskModelWithKey(AiTask.volumeSummary) ??
      await settings.resolveTaskModelWithKey(AiTask.continueWriting);

  // ---------- AI 感检查（M4-06）----------

  /// AI 感检查：先跑本地规则引擎（即时），[deep] 为 true 时再走 LLM 深检。
  /// [chapterId] 为 null 表示整部作品（PRD 5.7 范围选择）。
  Stream<CheckEvent> checkFlavor({
    required int workId,
    int? chapterId,
    bool deep = false,
  }) async* {
    // ENH-13：单章检查只需该章正文，整部作品检查才需要全书；避免为单章读全书。
    final List<Chapter> scoped;
    if (chapterId == null) {
      scoped = await chapters.watchChapters(workId).first;
    } else {
      final one = await chapters.getChapter(chapterId);
      scoped = one == null ? const <Chapter>[] : <Chapter>[one];
    }
    final scope = buildCheckScope(scoped);

    // 第一层：本地规则引擎。整部作品可达数十万字，词库与段落分析耗时可见，
    // 放到独立 isolate 执行，避免阻塞 UI 线程（ENH-11）。
    final scopeText = scope.text;
    final ruleResult = await Isolate.run(() => runFlavorRules(scopeText));
    yield CheckRuleResult(result: ruleResult, scope: scope);
    if (!deep || scope.isEmpty) return;

    // 第二层：LLM 深检（需配置检查任务所用模型）。
    final resolved = await settings.resolveTaskModelWithKey(AiTask.check);
    if (resolved == null) {
      yield const CheckNeedsConfig();
      return;
    }
    final group = resolved.group;
    final model = _firstModel(group);
    if (model == null) {
      yield CheckDeepFailed(
        kind: AiErrorKind.badRequest,
        message: '模型组「${group.name}」未填写模型名，请到设置页补充',
      );
      return;
    }

    final system = buildDeepCheckSystem();
    final segments = splitDeepCheckSegments(scope.text);
    final estimatedTokens =
        estimateTokens(system) +
        segments.fold<int>(0, (sum, s) => sum + estimateTokens(s.text));
    yield CheckDeepStarted(
      segments: segments.length,
      estimatedTokens: estimatedTokens,
    );

    final client = buildAiClient(
      provider: group.provider,
      baseUrl: group.baseUrl,
      apiKey: resolved.apiKey,
      httpClient: httpClient,
    );

    final collected = <FlavorIssue>[];
    var promptTokens = 0;
    var completionTokens = 0;
    String? fallbackText;
    var index = 0;

    for (final segment in segments) {
      final request = ChatRequest(
        model: model,
        system: system,
        messages: <ChatMessage>[ChatMessage.user(segment.text)],
        temperature: group.temperature,
        maxTokens: group.maxTokens,
      );
      final buffer = StringBuffer();
      AiErrorKind? failure;
      String failureMessage = '';
      int? failureStatus;
      String? failureCode;
      String? failureDetail;

      await for (final chunk in client.streamChat(request)) {
        switch (chunk) {
          case ChatTextDelta():
            buffer.write(chunk.text);
          case ChatUsage():
            promptTokens += chunk.promptTokens;
            completionTokens += chunk.completionTokens;
          case ChatError():
            failure = chunk.kind;
            failureMessage = chunk.message;
            failureStatus = chunk.statusCode;
            failureCode = chunk.code;
            failureDetail = chunk.detail;
          case ChatDone():
          case ChatToolCalls():
            break;
        }
        if (failure != null) break;
      }

      index++;
      yield CheckDeepProgress(done: index, total: segments.length);

      if (failure != null) {
        await _recordCheckUsage(
          model: model,
          workId: workId,
          chapterId: chapterId,
          promptTokens: promptTokens,
          completionTokens: completionTokens,
        );
        yield CheckDeepFailed(
          kind: failure,
          message: failureMessage,
          statusCode: failureStatus,
          code: failureCode,
          detail: failureDetail,
        );
        return;
      }

      final outcome = parseDeepCheckResponse(
        buffer.toString(),
        segmentText: segment.text,
        segmentOffset: segment.start,
      );
      if (outcome.parseFailed && outcome.fallbackText != null) {
        fallbackText = outcome.fallbackText;
      }
      collected.addAll(outcome.issues);
    }

    final usageId = await _recordCheckUsage(
      model: model,
      workId: workId,
      chapterId: chapterId,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
    );
    yield CheckDeepFinished(
      issues: collected,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      usageId: usageId,
      fallbackText: fallbackText,
    );
  }

  Future<int> _recordCheckUsage({
    required String model,
    required int workId,
    required int? chapterId,
    required int promptTokens,
    required int completionTokens,
  }) {
    return stats.record(
      task: AiTask.check,
      model: model,
      workId: workId,
      chapterId: chapterId,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
    );
  }

  // ---------- 测试连接（M3-18）----------

  Future<TestResult> testConnection({
    required ModelGroup group,
    required String apiKey,
  }) async {
    final model = _firstModel(group);
    if (model == null) {
      return const TestResult(
        ok: false,
        kind: TestResultKind.missingModel,
        message: '请先填写模型名',
      );
    }
    if (apiKey.isEmpty) {
      return const TestResult(
        ok: false,
        kind: TestResultKind.missingApiKey,
        message: '请先填写 API Key',
      );
    }

    final client = buildAiClient(
      provider: group.provider,
      baseUrl: group.baseUrl,
      apiKey: apiKey,
      httpClient: httpClient,
    );
    final request = ChatRequest(
      model: model,
      system: '你是连接测试助手。',
      messages: <ChatMessage>[ChatMessage.user('请只回复：连接成功')],
      temperature: 0,
      maxTokens: 32,
    );
    final buffer = StringBuffer();
    await for (final chunk in client.streamChat(request)) {
      if (chunk is ChatTextDelta) {
        buffer.write(chunk.text);
      } else if (chunk is ChatError) {
        return TestResult(
          ok: false,
          kind: TestResultKind.failed,
          message: chunk.message,
          errorKind: chunk.kind,
          statusCode: chunk.statusCode,
          code: chunk.code,
          detail: chunk.detail,
        );
      }
    }
    final reply = buffer.isEmpty ? null : buffer.toString().trim();
    return TestResult(
      ok: true,
      kind: TestResultKind.ok,
      message: reply == null ? '连接成功' : '连接成功：$reply',
      detail: reply,
    );
  }

  // ---------- 统计回写 ----------

  Future<void> markOutcome(
    int usageId,
    String outcome, {
    int adoptedChars = 0,
  }) {
    if (outcome == AiOutcome.adopted) {
      return stats.markAdopted(usageId, adoptedChars);
    }
    return stats.updateOutcome(usageId, outcome);
  }

  // ---------- 内部 ----------

  Stream<AiEvent> _run({
    AiClient? client,
    ChatRequest? request,
    Stream<ChatChunk>? chunks,
    required String task,
    required String model,
    required int workId,
    int? chapterId,
  }) async* {
    final stream = chunks ?? client!.streamChat(request!);
    final buffer = StringBuffer();
    var promptTokens = 0;
    var completionTokens = 0;

    await for (final chunk in stream) {
      switch (chunk) {
        case ChatTextDelta():
          buffer.write(chunk.text);
          yield AiTextChunk(chunk.text);
        case ChatUsage():
          promptTokens = chunk.promptTokens;
          completionTokens = chunk.completionTokens;
        case ChatError():
          // 已生成内容保留在面板中可手动保存（PRD 5.5 边界异常）。
          if (buffer.isNotEmpty) {
            await stats.record(
              task: task,
              model: model,
              workId: workId,
              chapterId: chapterId,
              promptTokens: promptTokens,
              completionTokens: completionTokens,
              outputChars: buffer.length,
              outcome: AiOutcome.aborted,
            );
            yield AiFinished(
              usageId: -1,
              text: buffer.toString(),
              promptTokens: promptTokens,
              completionTokens: completionTokens,
            );
          }
          yield AiFailed(
            kind: chunk.kind,
            message: chunk.message,
            statusCode: chunk.statusCode,
            code: chunk.code,
            detail: chunk.detail,
          );
          return;
        case ChatDone():
        case ChatToolCalls():
          break;
      }
    }

    final usageId = await stats.record(
      task: task,
      model: model,
      workId: workId,
      chapterId: chapterId,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      outputChars: buffer.length,
    );
    yield AiFinished(
      usageId: usageId,
      text: buffer.toString(),
      promptTokens: promptTokens,
      completionTokens: completionTokens,
    );
  }

  static const String _ideasSystem = '''
你是一位中文网络小说创意策划。请基于作者的作品设定，提出 3-5 个差异明显的桥段/冲突点子。
每个点子包含：一句话概括 + 2-3 句展开说明（如何制造冲突或转折）。
要求：点子之间方向差异明显，不与已有情节矛盾；可使用工具查询作品的角色卡、章纲与具体章节。
只输出编号列表，不写多余解释。''';

  Future<String> _ideasPrompt(
    int workId,
    int? anchorChapterId,
    String? direction, {
    String previousSummary = '',
    String chapterOutline = '',
  }) async {
    final work = await works.getWork(workId);
    final buffer = StringBuffer();
    if (work != null) buffer.writeln('作品：《${work.title}》（作品 id=$workId）');
    if (anchorChapterId != null) {
      final chapter = await chapters.getChapter(anchorChapterId);
      if (chapter != null) {
        buffer.writeln(
          '当前进度所在章节：${chapter.title.isEmpty ? '未命名章节' : chapter.title}（章节 id=$anchorChapterId）',
        );
      }
    }
    // ENH-07 O7：把前文摘要与本章章纲直接写进 prompt，点子更贴合剧情。
    if (chapterOutline.isNotEmpty) buffer.writeln('【本章章纲】\n$chapterOutline');
    if (previousSummary.isNotEmpty) {
      buffer.writeln('【前文摘要】\n$previousSummary');
    }
    final trimmed = direction?.trim() ?? '';
    if (trimmed.isNotEmpty) buffer.writeln('作者希望的方向：$trimmed');
    buffer.writeln('请先用工具了解作品设定与剧情走向，再给出点子。');
    return buffer.toString().trim();
  }

  String? _firstModel(ModelGroup group) {
    final models = SettingsRepository.parseModels(group.models);
    return models.isEmpty ? null : models.first;
  }

  /// 把启用技能注入组装结果的 system，并在上下文详情中列出技能名（B-03）。
  BuiltContext _withSkills(BuiltContext built, List<Skill> skills) {
    if (skills.isEmpty) return built;
    return built.withSystem(
      composeSkillSystem(built.system, skills),
      section: ContextSection(
        label: '用户技能',
        content: skills.map((s) => s.name).join('、'),
      ),
    );
  }

  AiEvent _missingModelFailure(ModelGroup group) {
    return AiFailed(
      kind: AiErrorKind.badRequest,
      message: '模型组「${group.name}」未填写模型名，请到设置页补充',
    );
  }
}
