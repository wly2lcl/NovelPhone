import 'dart:isolate';

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/ai/agent_core.dart';
import '../../core/ai/ai_client.dart';
import '../../core/ai/ai_client_factory.dart';
import '../../core/ai/collaboration_rules.dart';
import '../../core/ai/context_builder.dart';
import '../../core/ai/continuity_suppression.dart';
import '../../core/ai/empty_output_retry.dart';
import '../../core/ai/flavor_check.dart';
import '../../core/ai/mcp/mcp_bridge.dart';
import '../../core/ai/skills/skill.dart';
import '../../core/ai/structured_response.dart';
import '../../core/ai/tools/local_tools.dart';
import '../../core/ai/writing_preferences.dart';
import '../../core/ai_flavor_rules.dart';
import '../../data/db.dart';
import '../../data/repositories/chapter_repository.dart';
import '../../data/repositories/character_repository.dart';
import '../../data/repositories/mcp_audit_repository.dart';
import '../../data/repositories/outline_repository.dart';
import '../../data/repositories/setting_repository.dart';
import '../../data/repositories/story_state_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/token_stats_repository.dart';
import '../../data/repositories/work_repository.dart';
import '../../models/mcp_audit_entry.dart';
import '../../models/work_style_guide.dart';
import 'mcp_credentials.dart';

typedef _CollectedText = ({
  String text,
  int promptTokens,
  int completionTokens,
});

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

/// 多候选续写的叙事侧重（ENH-36）：三路共用资料，但各自聚焦不同写法。
class ContinueStrategy {
  const ContinueStrategy._();

  static const String dialogue = 'dialogue';
  static const String action = 'action';
  static const String atmosphere = 'atmosphere';

  static const List<String> all = <String>[dialogue, action, atmosphere];

  static String prompt(String strategy) {
    switch (strategy) {
      case dialogue:
        return '本候选以对话推进：用人物对白承载冲突与信息，'
            '叙述只保留必要的动作和停顿，让人物自己把话说完。';
      case action:
        return '本候选以动作推进：让人物用具体行动改变局面，'
            '少写解释性心理，用可见的动作和后果带出情绪。';
      case atmosphere:
        return '本候选以氛围推进：多用环境、感官与细节营造张力，'
            '节奏可以更慢，但每个细节都要服务当下处境。';
      default:
        return '';
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

// ---------- 设定一致性检查（ENH-22）----------

/// 设定一致性检查结果（一次性调用，不流式）。
class ContinuityReport {
  const ContinuityReport({
    required this.text,
    required this.promptTokens,
    required this.completionTokens,
    required this.usageId,
    required this.truncated,
    required this.result,
    this.ignoredCount = 0,
  });

  final String text;

  /// 结构化冲突列表（ENH-38）；解析失败时 [ContinuityCheckResult.parseFailed]。
  final ContinuityCheckResult result;
  final int promptTokens;
  final int completionTokens;
  final int usageId;

  /// 命中作者忽略清单、已从 [result] 中过滤的冲突数（ENH-41）。
  final int ignoredCount;

  /// 上下文超出模型窗口、已省略部分设定资料（结果可能不完整）。
  final bool truncated;
}

/// 设定一致性检查失败（携带结构化信息供展示时本地化）。
class ContinuityException implements Exception {
  const ContinuityException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.code,
    this.detail,
  });

  final AiErrorKind kind;
  final String message;
  final int? statusCode;
  final String? code;
  final String? detail;
}

/// 尚未配置可用模型组：UI 引导至设置页。
class ContinuityNeedsConfig implements Exception {
  const ContinuityNeedsConfig();
}

// ---------- 一次性结构化解说结果（ENH-23）----------

/// 尚未配置可用模型组（ENH-23 新任务）。
class AiServiceNeedsConfig implements Exception {
  const AiServiceNeedsConfig();
}

/// 一次性调用失败（保留结构化信息供 UI 本地化）。
class AiServiceException implements Exception {
  const AiServiceException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.code,
    this.detail,
  });

  final AiErrorKind kind;
  final String message;
  final int? statusCode;
  final String? code;
  final String? detail;
}

/// 一次性调用的原始返回与用量。
class AiOneShotResult {
  const AiOneShotResult({
    required this.text,
    required this.promptTokens,
    required this.completionTokens,
    required this.usageId,
    required this.truncated,
  });

  final String text;
  final int promptTokens;
  final int completionTokens;
  final int usageId;
  final bool truncated;
}

/// 文风提取结果（ENH-23）。
class StyleExtractionResult {
  const StyleExtractionResult({required this.guide, required this.result});

  final WorkStyleGuide guide;
  final AiOneShotResult result;
}

/// 设定补全结果（ENH-23）。
class EntityExtractionResult {
  const EntityExtractionResult({
    required this.extraction,
    required this.result,
  });

  final EntityExtraction extraction;
  final AiOneShotResult result;
}

/// 剧情推演结果（ENH-23）。
class PlotPlanResult {
  const PlotPlanResult({required this.plan, required this.result});

  final PlotPlan plan;
  final AiOneShotResult result;
}

/// 本章状态变化提取结果（ENH-35）。
class StoryStateExtractionResult {
  const StoryStateExtractionResult({
    required this.extraction,
    required this.result,
  });

  final StoryStateExtraction extraction;
  final AiOneShotResult result;
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
    this.storyStateRepository,
    this.httpClient,
    this.mcpOpener,
    this.mcpAudit,
  }) {
    contexts = ContextBuilder(
      works: works,
      chapters: chapters,
      characters: characters,
      outline: outline,
      settings: settingRepository,
      storyStates: storyStateRepository,
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

  /// 故事状态卡（ENH-31）：供上下文组装使用（可空，未注入则不参与）。
  final StoryStateRepository? storyStateRepository;

  final http.Client? httpClient;

  /// MCP 会话打开方式（默认 [openMcpTools]；测试可注入假实现避免真实联网）。
  final McpToolOpener? mcpOpener;

  /// MCP 工具调用审计（ENH-22；可空，未注入则不记录）。
  final McpAuditRepository? mcpAudit;
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
    if (task == AiTask.continuity) {
      return await _resolveContinuityModel() != null;
    }
    if (task == AiTask.style) return await _resolveStyleModel() != null;
    if (task == AiTask.extract) return await _resolveExtractModel() != null;
    if (task == AiTask.plan) return await _resolvePlanModel() != null;
    if (task == AiTask.chat) return await _resolveChatModel() != null;
    if (task == AiTask.storyState) {
      return await _resolveStoryStateModel() != null;
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
    // ENH-36：多候选各自的叙事侧重（对白 / 动作 / 氛围），共用资料只改 system。
    String? strategy,
    // ENH-09：多候选共用的预组装上下文（见 prebuildContinue）；为空时现组装。
    BuiltContext? prebuilt,
    // ENH-27：结果内多轮修改（当前草稿 + 作者意见）。
    String? revisionDraft,
    String? revisionInstruction,
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

    // ENH-09：多候选续写共用预组装上下文，避免每个候选重复取数与组装。
    // ENH-36：各候选在此之上只追加自己的叙事侧重，资料部分仍完全一致。
    final base =
        prebuilt ??
        _withSkills(
          await contexts.buildContinue(
            workId: workId,
            chapterId: chapterId,
            contextWindow: group.contextWindow,
            direction: direction,
            length: length,
            preferenceText: await _preferenceText(
              workId,
              task: AiTask.continueWriting,
            ),
            revisionDraft: revisionDraft,
            revisionInstruction: revisionInstruction,
          ),
          await settings.listEnabledSkills(),
        );
    final injected = strategy == null || strategy.isEmpty
        ? base
        : _withContinueStrategy(base, strategy);
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
      contextWindow: group.contextWindow,
    );
  }

  /// 预组装续写上下文（ENH-09）：多候选续写的公共资料一次组装好供三路流共用；
  /// 各候选的叙事侧重由 [continueWriting] 的 `strategy` 在 system 上追加（ENH-36）。
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
      preferenceText: await _preferenceText(
        workId,
        task: AiTask.continueWriting,
      ),
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
        preferenceText: await _preferenceText(workId, task: AiTask.inspire),
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
        contextWindow: group.contextWindow,
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
    // ENH-46：桥段点子同样参考作者协作偏好（守则、套话与采纳片段）。
    final preference = await _preferenceText(workId, task: AiTask.inspire);
    final ideasSystem = preference.isEmpty ? system : '$system\n\n$preference';
    yield AiContextBuilt(
      BuiltContext(
        system: ideasSystem,
        messages: <ChatMessage>[ChatMessage.user(prompt)],
        sections: <ContextSection>[
          ContextSection(label: '任务模式', content: '桥段点子（AI 可按需调用工具取数）'),
          if (preference.isNotEmpty)
            ContextSection(label: '作者协作偏好', content: preference),
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
        estimatedTokens: estimateTokens(ideasSystem) + estimateTokens(prompt),
        budgetTokens: (group.contextWindow * 0.5).round(),
      ),
    );
    final agent = AgentCore(client: client);
    final request = ChatRequest(
      model: model,
      system: ideasSystem,
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
    // openMcpTools 使用命名参数，不能直接按位置参数调用（运行时 NoSuchMethodError）。
    final opener =
        mcpOpener ??
        (McpServerConfig config, McpCredentials credentials) =>
            openMcpTools(config: config, credentials: credentials);
    try {
      for (final server in await settings.listEnabledMcpServers()) {
        try {
          final session = await opener(
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
          for (final tool in session.tools) {
            tools.add(_withAudit(tool, session.serverName));
          }
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
        contextWindow: group.contextWindow,
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
    // ENH-27：结果内多轮修改（当前改写草稿 + 作者意见）。
    String? revisionDraft,
    String? revisionInstruction,
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
      preferenceText: await _preferenceText(workId, task: AiTask.rewrite),
      revisionDraft: revisionDraft,
      revisionInstruction: revisionInstruction,
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
      contextWindow: group.contextWindow,
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
      contextWindow: group.contextWindow,
    );
  }

  /// 摘要模型组解析：未单独配置时回退续写组（零配置也可用）。
  Future<ResolvedModel?> _resolveSummaryModel() async =>
      await settings.resolveTaskModelWithKey(AiTask.summary) ??
      await settings.resolveTaskModelWithKey(AiTask.continueWriting);

  // ---------- 设定一致性检查（ENH-22）----------

  /// 检查本章正文与角色卡 / 设定集 / 前情摘要 / 本章章纲是否冲突。
  /// 结果一次性返回（非流式），由 UI 以报告对话框展示。
  Future<ContinuityReport> checkContinuity({
    required int workId,
    required int chapterId,
  }) async {
    final resolved = await _resolveContinuityModel();
    if (resolved == null) throw const ContinuityNeedsConfig();
    final group = resolved.group;
    final model = _firstModel(group);
    if (model == null) {
      throw ContinuityException(
        kind: AiErrorKind.badRequest,
        message: '模型组「${group.name}」未填写模型名，请到设置页补充',
      );
    }

    final suppressions = await settings.readContinuitySuppressions(workId);
    final built = await contexts.buildContinuityCheck(
      workId: workId,
      chapterId: chapterId,
      contextWindow: group.contextWindow,
      suppressions: suppressions,
    );
    final injected = _withSkills(built, await settings.listEnabledSkills());
    final client = buildAiClient(
      provider: group.provider,
      baseUrl: group.baseUrl,
      apiKey: resolved.apiKey,
      httpClient: httpClient,
    );
    var request = injected.toRequest(
      model: model,
      temperature: group.temperature,
      maxTokens: group.maxTokens,
    );

    _CollectedText collected;
    try {
      collected = await _collectText(client: client, request: request);
    } on AiServiceException catch (e) {
      throw ContinuityException(
        kind: e.kind,
        message: e.message,
        statusCode: e.statusCode,
        code: e.code,
        detail: e.detail,
      );
    }
    var usageId = await stats.record(
      task: AiTask.continuity,
      model: model,
      workId: workId,
      chapterId: chapterId,
      promptTokens: collected.promptTokens,
      completionTokens: collected.completionTokens,
      outputChars: collected.text.length,
    );

    final retryTokens = collected.text.isEmpty
        ? nextRetryMaxTokens(
            maxTokens: request.maxTokens,
            contextWindow: group.contextWindow,
          )
        : null;
    if (retryTokens != null) {
      request = injected.toRequest(
        model: model,
        temperature: group.temperature,
        maxTokens: retryTokens,
      );
      try {
        collected = await _collectText(client: client, request: request);
      } on AiServiceException catch (e) {
        throw ContinuityException(
          kind: e.kind,
          message: e.message,
          statusCode: e.statusCode,
          code: e.code,
          detail: e.detail,
        );
      }
      usageId = await stats.record(
        task: AiTask.continuity,
        model: model,
        workId: workId,
        chapterId: chapterId,
        promptTokens: collected.promptTokens,
        completionTokens: collected.completionTokens,
        outputChars: collected.text.length,
      );
    }

    if (collected.text.isEmpty) {
      throw const ContinuityException(
        kind: AiErrorKind.badRequest,
        message: 'AI 未返回内容（已自动提高输出上限重试），请再次尝试或改用非推理模型',
      );
    }
    final parsed = parseContinuityResponse(collected.text);
    final filtered = ContinuitySuppressions.filterResult(parsed, suppressions);
    return ContinuityReport(
      text: collected.text,
      result: filtered,
      promptTokens: collected.promptTokens,
      completionTokens: collected.completionTokens,
      usageId: usageId,
      truncated: injected.truncated,
      ignoredCount: parsed.issues.length - filtered.issues.length,
    );
  }

  /// 检查模型组解析：优先专用配置，其次 AI 感深检组，最后回退续写组。
  Future<ResolvedModel?> _resolveContinuityModel() async =>
      await settings.resolveTaskModelWithKey(AiTask.continuity) ??
      await settings.resolveTaskModelWithKey(AiTask.check) ??
      await settings.resolveTaskModelWithKey(AiTask.continueWriting);

  // ---------- ENH-23：文风提取 / 设定补全 / 剧情推演 / 作品问答 ----------

  /// 从最近章节提取文风档案；未配置时抛 [AiServiceNeedsConfig]。
  Future<StyleExtractionResult> extractStyleGuide({required int workId}) async {
    final resolved = await _resolveStyleModel();
    if (resolved == null) throw const AiServiceNeedsConfig();
    final chapterList = await chapters.listChapters(workId);
    if (chapterList.every((c) => c.content.trim().isEmpty)) {
      throw const AiServiceException(
        kind: AiErrorKind.badRequest,
        message: '作品还没有正文，先写几章再提取文风',
      );
    }
    final work = await works.getWork(workId);
    final built = await contexts.buildStyleExtraction(
      workId: workId,
      chapterList: chapterList,
      contextWindow: resolved.group.contextWindow,
    );
    final result = await _completeOnce(
      resolved: resolved,
      built: built,
      task: AiTask.style,
      workId: workId,
    );
    final current = WorkStyleGuide.decode(work?.styleGuide ?? '');
    final guide = parseStyleGuideResponse(result.text, fallback: current);
    if (guide == null) {
      throw const AiServiceException(
        kind: AiErrorKind.badRequest,
        message: 'AI 返回的文风档案无法解析，请重试',
      );
    }
    return StyleExtractionResult(guide: guide, result: result);
  }

  /// 从正文抽取角色与设定条目（设定补全）。
  Future<EntityExtractionResult> extractEntities({required int workId}) async {
    final resolved = await _resolveExtractModel();
    if (resolved == null) throw const AiServiceNeedsConfig();
    final chapterList = await chapters.listChapters(workId);
    if (chapterList.every((c) => c.content.trim().isEmpty)) {
      throw const AiServiceException(
        kind: AiErrorKind.badRequest,
        message: '作品还没有正文，无法抽取设定',
      );
    }
    final built = await contexts.buildEntityExtraction(
      workId: workId,
      chapterList: chapterList,
      contextWindow: resolved.group.contextWindow,
    );
    final result = await _completeOnce(
      resolved: resolved,
      built: built,
      task: AiTask.extract,
      workId: workId,
    );
    final extraction = parseEntityExtractionResponse(result.text);
    return EntityExtractionResult(extraction: extraction, result: result);
  }

  /// 从单章正文提取故事状态卡变化（ENH-35），结果由 UI 勾选后再落库。
  Future<StoryStateExtractionResult> extractStoryStates({
    required int workId,
    required int chapterId,
  }) async {
    final resolved = await _resolveStoryStateModel();
    if (resolved == null) throw const AiServiceNeedsConfig();
    final chapter = await chapters.getChapter(chapterId);
    if (chapter == null) {
      throw const AiServiceException(
        kind: AiErrorKind.badRequest,
        message: '章节不存在，无法提取状态变化',
      );
    }
    if (chapter.content.trim().isEmpty) {
      throw const AiServiceException(
        kind: AiErrorKind.badRequest,
        message: '本章还没有正文，先写一些内容再提取状态变化',
      );
    }
    final built = await contexts.buildStoryStateExtraction(
      workId: workId,
      chapterId: chapterId,
      contextWindow: resolved.group.contextWindow,
    );
    final result = await _completeOnce(
      resolved: resolved,
      built: built,
      task: AiTask.storyState,
      workId: workId,
      chapterId: chapterId,
    );
    final extraction = parseStoryStateExtractionResponse(result.text);
    if (extraction.parseFailed) {
      throw const AiServiceException(
        kind: AiErrorKind.badRequest,
        message: 'AI 返回的状态变化无法解析，请重试',
      );
    }
    return StoryStateExtractionResult(extraction: extraction, result: result);
  }

  /// 基于已有章纲与最近正文推演后续剧情。
  Future<PlotPlanResult> planPlot({
    required int workId,
    String? direction,
  }) async {
    final resolved = await _resolvePlanModel();
    if (resolved == null) throw const AiServiceNeedsConfig();
    final chapterList = await chapters.listChapters(workId);
    final built = await contexts.buildPlotPlan(
      workId: workId,
      chapterList: chapterList,
      direction: direction,
      contextWindow: resolved.group.contextWindow,
      preferenceText: await _preferenceText(workId, task: AiTask.plan),
    );
    final result = await _completeOnce(
      resolved: resolved,
      built: built,
      task: AiTask.plan,
      workId: workId,
    );
    final plan = parsePlotPlanResponse(result.text);
    return PlotPlanResult(plan: plan, result: result);
  }

  /// 作品问答：注入作品资料 + 本地检索工具，多轮对话由 UI 持久化。
  Stream<AiEvent> chat({
    required int workId,
    required List<ChatContextTurn> history,
    required String message,
  }) async* {
    final resolved = await _resolveChatModel();
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
    final chapterList = await chapters.listChapters(workId);
    final built = await contexts.buildChat(
      workId: workId,
      chapterList: chapterList,
      history: history,
      message: message,
      contextWindow: group.contextWindow,
    );
    final injected = _withSkills(built, await settings.listEnabledSkills());
    yield AiContextBuilt(injected);
    final tools = buildLocalTools(
      chapters: chapters,
      characters: characters,
      outline: outline,
      settings: settingRepository,
    );
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
      tools: tools.map((t) => t.spec).toList(),
    );
    yield* _run(
      chunks: AgentCore(client: client).run(request: request, tools: tools),
      task: AiTask.chat,
      model: model,
      workId: workId,
      contextWindow: group.contextWindow,
    );
  }

  /// 流式设定一致性检查（ENH-23）：可取消，已收内容保留在报告中。
  Stream<AiEvent> streamContinuity({
    required int workId,
    required int chapterId,
  }) async* {
    final resolved = await _resolveContinuityModel();
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
    final suppressions = await settings.readContinuitySuppressions(workId);
    final built = await contexts.buildContinuityCheck(
      workId: workId,
      chapterId: chapterId,
      contextWindow: group.contextWindow,
      suppressions: suppressions,
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
      task: AiTask.continuity,
      model: model,
      workId: workId,
      chapterId: chapterId,
      contextWindow: group.contextWindow,
    );
  }

  Future<ResolvedModel?> _resolveStyleModel() async =>
      await settings.resolveTaskModelWithKey(AiTask.style) ??
      await settings.resolveTaskModelWithKey(AiTask.continueWriting);

  Future<ResolvedModel?> _resolveExtractModel() async =>
      await settings.resolveTaskModelWithKey(AiTask.extract) ??
      await settings.resolveTaskModelWithKey(AiTask.continueWriting);

  Future<ResolvedModel?> _resolvePlanModel() async =>
      await settings.resolveTaskModelWithKey(AiTask.plan) ??
      await settings.resolveTaskModelWithKey(AiTask.outlineExpand) ??
      await settings.resolveTaskModelWithKey(AiTask.continueWriting);

  Future<ResolvedModel?> _resolveChatModel() async =>
      await settings.resolveTaskModelWithKey(AiTask.chat) ??
      await settings.resolveTaskModelWithKey(AiTask.continueWriting);

  Future<ResolvedModel?> _resolveStoryStateModel() async =>
      await settings.resolveTaskModelWithKey(AiTask.storyState) ??
      await settings.resolveTaskModelWithKey(AiTask.extract) ??
      await settings.resolveTaskModelWithKey(AiTask.continueWriting);

  /// 非流式一次性调用（文风 / 设定补全 / 剧情推演共用）。
  Future<AiOneShotResult> _completeOnce({
    required ResolvedModel resolved,
    required BuiltContext built,
    required String task,
    required int workId,
    int? chapterId,
  }) async {
    final group = resolved.group;
    final model = _firstModel(group);
    if (model == null) {
      throw AiServiceException(
        kind: AiErrorKind.badRequest,
        message: '模型组「${group.name}」未填写模型名，请到设置页补充',
      );
    }
    final injected = _withSkills(built, await settings.listEnabledSkills());
    final client = buildAiClient(
      provider: group.provider,
      baseUrl: group.baseUrl,
      apiKey: resolved.apiKey,
      httpClient: httpClient,
    );
    ChatRequest buildRequest(int maxTokens) => injected.toRequest(
      model: model,
      temperature: group.temperature,
      maxTokens: maxTokens,
    );

    var request = buildRequest(group.maxTokens);
    var collected = await _collectText(client: client, request: request);
    var usageId = await stats.record(
      task: task,
      model: model,
      workId: workId,
      chapterId: chapterId,
      promptTokens: collected.promptTokens,
      completionTokens: collected.completionTokens,
      outputChars: collected.text.length,
    );

    final retryTokens = collected.text.isEmpty
        ? nextRetryMaxTokens(
            maxTokens: request.maxTokens,
            contextWindow: group.contextWindow,
          )
        : null;
    if (retryTokens != null) {
      request = buildRequest(retryTokens);
      collected = await _collectText(client: client, request: request);
      usageId = await stats.record(
        task: task,
        model: model,
        workId: workId,
        chapterId: chapterId,
        promptTokens: collected.promptTokens,
        completionTokens: collected.completionTokens,
        outputChars: collected.text.length,
      );
    }

    if (collected.text.isEmpty) {
      // 推理模型可能把输出上限全部耗在推理阶段，重试后仍为空则明确失败。
      throw const AiServiceException(
        kind: AiErrorKind.badRequest,
        message: 'AI 未返回内容（已自动提高输出上限重试），请再次尝试或改用非推理模型',
      );
    }
    return AiOneShotResult(
      text: collected.text,
      promptTokens: collected.promptTokens,
      completionTokens: collected.completionTokens,
      usageId: usageId,
      truncated: injected.truncated,
    );
  }

  /// 收集一次完整流（非流式结果）；空正文的重试由调用方决定。
  Future<_CollectedText> _collectText({
    required AiClient client,
    required ChatRequest request,
  }) async {
    final buffer = StringBuffer();
    var promptTokens = 0;
    var completionTokens = 0;
    await for (final chunk in client.streamChat(request)) {
      switch (chunk) {
        case ChatTextDelta():
          buffer.write(chunk.text);
        case ChatUsage():
          // ENH-23：工具循环可能多轮返回 usage，逐轮累加而非覆盖。
          promptTokens += chunk.promptTokens;
          completionTokens += chunk.completionTokens;
        case ChatError():
          throw AiServiceException(
            kind: chunk.kind,
            message: chunk.message,
            statusCode: chunk.statusCode,
            code: chunk.code,
            detail: chunk.detail,
          );
        case ChatDone():
        case ChatToolCalls():
          break;
      }
    }
    return (
      text: buffer.toString().trim(),
      promptTokens: promptTokens,
      completionTokens: completionTokens,
    );
  }

  // ---------- AI 感检查（M4-06）----------

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
      preferenceText: await _preferenceText(workId, task: AiTask.outlineExpand),
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
      contextWindow: group.contextWindow,
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
      contextWindow: group.contextWindow,
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
    int? adoptedEditPercent,
  }) {
    if (outcome == AiOutcome.adopted) {
      return stats.markAdopted(
        usageId,
        adoptedChars,
        editPercent: adoptedEditPercent,
      );
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
    int? contextWindow,
  }) async* {
    var currentRequest = request;
    Stream<ChatChunk>? pendingChunks = chunks;

    // 首次空正文时提高输出上限重试一次；已通过工具循环产出的流不重放，
    // 避免重复触发远程工具副作用。
    for (var attempt = 0; ; attempt++) {
      final stream = pendingChunks ?? client!.streamChat(currentRequest!);
      pendingChunks = null;
      final buffer = StringBuffer();
      var promptTokens = 0;
      var completionTokens = 0;

      await for (final chunk in stream) {
        switch (chunk) {
          case ChatTextDelta():
            buffer.write(chunk.text);
            yield AiTextChunk(chunk.text);
          case ChatUsage():
            // ENH-23：工具循环可能多轮返回 usage，逐轮累加而非覆盖。
            promptTokens += chunk.promptTokens;
            completionTokens += chunk.completionTokens;
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

      final text = buffer.toString();
      final retryTokens = text.trim().isEmpty && attempt == 0
          ? nextRetryMaxTokens(
              maxTokens: currentRequest?.maxTokens ?? 0,
              contextWindow: contextWindow ?? 0,
            )
          : null;
      final usageId = await stats.record(
        task: task,
        model: model,
        workId: workId,
        chapterId: chapterId,
        promptTokens: promptTokens,
        completionTokens: completionTokens,
        outputChars: text.length,
      );
      if (retryTokens != null && currentRequest != null) {
        currentRequest = ChatRequest(
          model: currentRequest.model,
          system: currentRequest.system,
          messages: currentRequest.messages,
          temperature: currentRequest.temperature,
          maxTokens: retryTokens,
          tools: currentRequest.tools,
        );
        continue;
      }
      if (text.trim().isEmpty) {
        yield const AiFailed(
          kind: AiErrorKind.badRequest,
          message: 'AI 未返回内容（已自动提高输出上限重试），请再次尝试或改用非推理模型',
        );
        return;
      }
      yield AiFinished(
        usageId: usageId,
        text: text,
        promptTokens: promptTokens,
        completionTokens: completionTokens,
      );
      return;
    }
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

  /// 追加候选的叙事侧重（ENH-36）：只改 system 与上下文详情，
  /// 角色卡 / 前文等资料三路仍共用同一份。
  BuiltContext _withContinueStrategy(BuiltContext built, String strategy) {
    final prompt = ContinueStrategy.prompt(strategy);
    if (prompt.isEmpty) return built;
    return built.withSystem(
      '${built.system}\n\n【本候选侧重】\n$prompt',
      section: ContextSection(label: '候选侧重', content: prompt),
    );
  }

  /// 本地协作偏好（ENH-27 / ENH-29 / ENH-44）：整篇放弃与分段未采纳的原因合并计数，
  /// 采纳片段优先取与本次任务同类的，并叠加作者手写的守则与套话黑名单。
  Future<String> _preferenceText(int workId, {required String task}) async {
    if (!await settings.readAiPreferencesEnabled(workId)) return '';
    final counts = await settings.readAiFeedback(workId);
    final paragraph = await settings.readAiParagraphFeedback(workId);
    for (final entry in paragraph.entries) {
      counts[entry.key] = (counts[entry.key] ?? 0) + entry.value;
    }
    final samples = await settings.readAdoptedSamples(workId);
    final collaboration = await settings.readCollaborationRules(workId);
    return <String>[
      WritingPreferences.promptBlock(
        reasonCounts: counts,
        samples: samples,
        preferredTask: task,
      ),
      CollaborationRules.promptBlock(
        rules: collaboration.rules,
        banned: collaboration.banned,
        scopes: collaboration.scopes,
        task: task,
      ),
    ].where((block) => block.isNotEmpty).join('\n\n');
  }

  /// 包装远程工具（ENH-22）：记录每次调用的参数 / 结果摘要与耗时。
  /// 审计写入失败不影响工具调用本身。
  Tool _withAudit(Tool tool, String serverName) {
    final audit = mcpAudit;
    if (audit == null) return tool;
    return Tool(
      name: tool.name,
      description: tool.description,
      inputSchema: tool.inputSchema,
      execute: (args) async {
        final stopwatch = Stopwatch()..start();
        try {
          final result = await tool.execute(args);
          stopwatch.stop();
          await _recordAudit(
            audit,
            serverName: serverName,
            toolName: tool.name,
            args: args,
            result: result,
            success: !result.startsWith(mcpToolErrorPrefix),
            durationMs: stopwatch.elapsedMilliseconds,
          );
          return result;
        } catch (error) {
          stopwatch.stop();
          await _recordAudit(
            audit,
            serverName: serverName,
            toolName: tool.name,
            args: args,
            result: '工具执行失败：$error',
            success: false,
            durationMs: stopwatch.elapsedMilliseconds,
          );
          rethrow;
        }
      },
    );
  }

  Future<void> _recordAudit(
    McpAuditRepository audit, {
    required String serverName,
    required String toolName,
    required Map<String, dynamic> args,
    required String result,
    required bool success,
    required int durationMs,
  }) async {
    try {
      await audit.add(
        McpAuditEntry(
          serverName: serverName,
          toolName: toolName,
          argumentsSummary: _summarize(jsonEncode(args)),
          resultSummary: _summarize(result),
          success: success,
          durationMs: durationMs,
          createdAt: DateTime.now(),
        ),
      );
    } catch (_) {
      // 审计失败不阻断生成。
    }
  }

  static String _summarize(String text, {int max = 300}) =>
      text.length <= max ? text : '${text.substring(0, max)}…';

  AiEvent _missingModelFailure(ModelGroup group) {
    return AiFailed(
      kind: AiErrorKind.badRequest,
      message: '模型组「${group.name}」未填写模型名，请到设置页补充',
    );
  }
}
