import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/ai/adoption_metrics.dart';
import '../../core/ai/ai_client.dart';
import '../../core/ai/collaboration_rules.dart';
import '../../core/ai/context_builder.dart';
import '../../core/ai/sanitize_ai_text.dart';
import '../../core/ai/writing_preferences.dart' show AiFeedbackReason;
import '../../data/data_providers.dart';
import '../../data/repositories/settings_repository.dart' show AiTask;
import '../../l10n/error_text.dart';
import '../../l10n/l10n.dart';
import '../ai/ai_providers.dart';
import '../ai/ai_service.dart';
import 'ai_feedback_dialog.dart';
import 'ai_merge_dialog.dart';
import 'ai_revision_history.dart';
import 'candidate_merge_dialog.dart';
import 'snapshot_diff_dialog.dart';

/// 面板模式：续写 / 桥段点子 / 开篇助手 / 改写 / 逐章摘要 / 章纲扩写。
enum AiPanelMode {
  continueWriting,
  inspireIdeas,
  inspireOpening,
  rewrite,

  /// ENH-05：AI 逐章摘要（前情回顾）。
  summarize,

  /// ENH-05：AI 章纲扩写（一句话梗概 → 分场大纲）。
  outlineExpand,

  /// ENH-06：本卷前情回顾（滚动摘要）。
  volumeSummary,
}

/// AI 待确认面板（PRD 5.5 / 5.6，M3-15）：流式产出、可编辑后插入、可重跑可放弃，
/// 上下文详情可展开（作者能看见 AI 看到了什么）。
class AiConfirmPanel extends ConsumerStatefulWidget {
  const AiConfirmPanel({
    super.key,
    required this.workId,
    required this.chapterId,
    required this.initialMode,
    required this.onInsert,
    required this.onClose,
    this.onBeforeApply,
    this.rewriteText,
    this.rewriteInstruction,
    this.onReplace,
    this.outlineSeed,
    this.onSaveSummary,
    this.onSaveOutline,
    this.onSaveVolumeSummary,
  });

  final int workId;
  final int chapterId;
  final AiPanelMode initialMode;

  /// 插入到编辑器光标处（走编辑器撤销栈）。
  final void Function(String text) onInsert;

  /// 首次写入正文前的回调（ENH-30）：由编辑器创建「AI 采纳前」快照。
  final Future<void> Function()? onBeforeApply;

  /// 改写模式（ENH-04）：待改写原文与「替换原文」回调（走编辑器撤销栈）。
  final String? rewriteText;

  /// 改写指令预填（ENH-38）：由一致性冲突生成。
  final String? rewriteInstruction;

  final void Function(String text)? onReplace;

  /// 章纲扩写（ENH-05）：作者的一句话梗概种子。
  final String? outlineSeed;

  /// 逐章摘要（ENH-05）：保存摘要回调（写回 CHAPTER.summary）。
  final void Function(String text)? onSaveSummary;

  /// 章纲扩写（ENH-05）：保存大纲回调（写回本章章纲）。
  final void Function(String text)? onSaveOutline;

  /// 本卷前情回顾（ENH-06）：保存回调（写回 VOLUME.summary）。
  final void Function(String text)? onSaveVolumeSummary;

  final VoidCallback onClose;

  @override
  ConsumerState<AiConfirmPanel> createState() => _AiConfirmPanelState();
}

class _AiConfirmPanelState extends ConsumerState<AiConfirmPanel> {
  late AiPanelMode _mode = widget.initialMode;

  /// 结果缓冲（ENH-05）：多候选续写 3 个（各自可编辑），其余模式只用第 0 个。
  final List<TextEditingController> _results =
      List<TextEditingController>.generate(3, (_) => TextEditingController());

  /// 多候选续写（ENH-05）：仅对续写生效，默认开。
  bool _multiCandidate = true;

  /// 当前展示 / 采纳的候选下标（非多候选时恒为 0）。
  int _selected = 0;

  List<StreamSubscription<AiEvent>> _subs =
      const <StreamSubscription<AiEvent>>[];

  bool _streaming = false;

  /// 每个候选的失败信息与 usageId（索引与 [_results] 对齐）。
  final List<String?> _errors = <String?>[null, null, null];
  final List<int?> _usageIds = <int?>[null, null, null];
  AiErrorKind? _errorKind;
  int _pending = 0;

  bool _needsConfig = false;
  BuiltContext? _context;

  /// 多候选续写共用的预组装上下文（ENH-09）：三路只在温度上不同。
  BuiltContext? _prebuilt;
  bool _contextExpanded = false;

  /// 生成耗时反馈（ENH-07 O9）：流式期间每秒刷新已用秒数。
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;

  double _length = 500;
  String _lastDirection = '';

  /// 改写模式（ENH-04）：意图与作者补充指令。
  String _intent = RewriteIntent.polish;
  String _instruction = '';

  /// 结果内多轮修改（ENH-27）：基于当前候选继续改，而不是整段重生成。
  final TextEditingController _revisionInstruction = TextEditingController();
  String _revisionInstructionText = '';
  String _revisionDraft = '';
  int? _revisionIndex;
  bool _revisionTextStarted = false;
  bool _revising = false;

  /// 修订开始前的 usageId（ENH-29）：首个新文本到达才记为 regenerated，
  /// 修订失败时旧结果与统计仍有效。
  int? _revisionPreviousUsage;

  /// 当前结果的处置是否已回写（ENH-29）：面板被其他工具直接卸载时兜底记 ignored。
  bool _outcomesMarked = false;
  AiService? _aiService;

  /// 本次生成是否已创建「AI 采纳前」快照（ENH-30）：同一轮只留一版。
  bool _snapshotTaken = false;

  /// 模型原始输出（ENH-30）：与作者编辑后的结果对比，计算采纳编辑比例。
  final List<String> _rawOutputs = <String>['', '', ''];

  /// 修订历史（ENH-27.3）：每个候选各自保留最近 5 版。
  final List<AiRevisionHistory> _revisionHistory =
      List<AiRevisionHistory>.generate(3, (_) => AiRevisionHistory());

  /// ENH-48：当前作品的协作守则，用于结果内本地自检。
  CollaborationRules _collabRules = const CollaborationRules();
  String _ruleCheckKey = '';
  RuleCheckResult _ruleCheck = const RuleCheckResult();

  /// 是否处于多候选状态（仅续写生效）。
  bool get _multiMode =>
      _mode == AiPanelMode.continueWriting && _multiCandidate;

  /// 当前候选下标。
  int get _activeIndex => _multiMode ? _selected : 0;

  /// 当前候选的文本控制器。
  TextEditingController get _activeResult => _results[_activeIndex];

  /// 当前候选的失败信息（错误横幅只展示当前候选）。
  String? get _activeError => _errors[_activeIndex];

  @override
  void initState() {
    super.initState();
    _instruction = widget.rewriteInstruction ?? '';
    _aiService = ref.read(aiServiceProvider);
    _loadCollabRules();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    for (final sub in _subs) {
      sub.cancel();
    }
    // ENH-29：由其他工具 / 页面卸载面板时，未处置的生成结果记 ignored，
    // 避免 AI_USAGE 长期停在 pending 拉低统计口径。
    if (!_outcomesMarked) {
      for (final id in _usageIds) {
        if (id != null) unawaited(_aiService?.markOutcome(id, 'ignored'));
      }
    }
    for (final controller in _results) {
      controller.dispose();
    }
    _revisionInstruction.dispose();
    super.dispose();
  }

  /// 启动生成耗时计时（ENH-07 O9）。
  void _startElapsed() {
    _elapsedTimer?.cancel();
    _elapsedSeconds = 0;
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  /// 停止生成耗时计时（保留最后一次秒数供作者参考）。
  void _stopElapsed() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
  }

  String _title(AppLocalizations l10n) {
    switch (_mode) {
      case AiPanelMode.continueWriting:
        return l10n.aiPanelTitleContinue;
      case AiPanelMode.inspireIdeas:
        return l10n.aiPanelTitleInspireIdeas;
      case AiPanelMode.inspireOpening:
        return l10n.aiPanelTitleInspireOpening;
      case AiPanelMode.rewrite:
        return l10n.aiPanelTitleRewrite;
      case AiPanelMode.summarize:
        return l10n.aiPanelTitleSummarize;
      case AiPanelMode.outlineExpand:
        return l10n.aiPanelTitleOutlineExpand;
      case AiPanelMode.volumeSummary:
        return l10n.aiPanelTitleVolumeSummary;
    }
  }

  /// 改写意图的展示映射（zh 沿用 RewriteIntent 原值，en 走本地化）。
  String _intentLabel(AppLocalizations l10n, String intent) {
    switch (intent) {
      case RewriteIntent.expand:
        return l10n.rewriteIntentExpand;
      case RewriteIntent.condense:
        return l10n.rewriteIntentCondense;
      case RewriteIntent.tone:
        return l10n.rewriteIntentTone;
      case RewriteIntent.polish:
      default:
        return l10n.rewriteIntentPolish;
    }
  }

  /// 上下文段落标题的展示映射（原始 label 来自 ContextBuilder，未知值原样展示）。
  String _sectionLabel(AppLocalizations l10n, String label) {
    switch (label) {
      case '本章正文':
        return l10n.aiSectionChapterText;
      case '任务模式':
        return l10n.aiSectionTaskMode;
      case '本章梗概':
        return l10n.aiSectionChapterSynopsis;
      case '本卷素材（上一版回顾 + 新增章节）':
        return l10n.aiSectionVolumeMaterial;
      case '卷级大纲':
        return l10n.aiSectionVolumeOutline;
      case '前文摘要':
        return l10n.aiSectionPreviousSummary;
      case '相关角色卡':
        return l10n.aiSectionCharacters;
      case '设定集':
        return l10n.aiSectionSettings;
      case '本章章纲':
        return l10n.aiSectionChapterOutline;
      case '本章已写内容（尾部）':
        return l10n.aiSectionChapterTail;
      case '生成要求':
        return l10n.aiSectionRequirements;
      case '用户技能':
        return l10n.aiSectionUserSkills;
      case '作者协作偏好':
        return l10n.aiSectionPreferences;
      case '候选侧重':
        return l10n.aiSectionCandidateStrategy;
      default:
        return label;
    }
  }

  Future<void> _start({String? direction}) async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs = const <StreamSubscription<AiEvent>>[];
    // 重新生成 / 切换意图或候选数：旧结果统一记为 regenerated，不污染采纳率。
    await _markOutcomeForAll('regenerated');
    if (!mounted) return;
    setState(() {
      _streaming = true;
      _outcomesMarked = false;
      _snapshotTaken = false;
      _errorKind = null;
      _needsConfig = false;
      _context = null;
      _selected = 0;
      _revising = false;
      _revisionDraft = '';
      _revisionInstructionText = '';
      _revisionIndex = null;
      _revisionTextStarted = false;
      _revisionPreviousUsage = null;
      _revisionInstruction.clear();
      for (final history in _revisionHistory) {
        history.clear();
      }
      for (var i = 0; i < _errors.length; i++) {
        _errors[i] = null;
        _usageIds[i] = null;
      }
      for (final controller in _results) {
        controller.text = '';
      }
      for (var i = 0; i < _rawOutputs.length; i++) {
        _rawOutputs[i] = '';
      }
      if (direction != null) _lastDirection = direction;
    });

    // 多候选仅对续写生效（ENH-05）。
    final count = _multiMode ? 3 : 1;
    // ENH-09：多候选三路上下文一致，先组装一次供三路共用。
    _prebuilt = null;
    if (_mode == AiPanelMode.continueWriting && count > 1) {
      _prebuilt = await ref
          .read(aiServiceProvider)
          .prebuildContinue(
            workId: widget.workId,
            chapterId: widget.chapterId,
            direction: _lastDirection.isEmpty ? null : _lastDirection,
            length: _length.round(),
          );
      if (!mounted) return;
    }
    _pending = count;
    _subs = <StreamSubscription<AiEvent>>[
      for (var i = 0; i < count; i++)
        _buildStream(i).listen((event) => _onEvent(event, i)),
    ];
    _startElapsed();
  }

  /// 按模式构造某一路生成流（索引仅用于多候选续写）。
  Stream<AiEvent> _buildStream(int index) {
    final service = ref.read(aiServiceProvider);
    switch (_mode) {
      case AiPanelMode.continueWriting:
        return service.continueWriting(
          workId: widget.workId,
          chapterId: widget.chapterId,
          direction: _lastDirection.isEmpty ? null : _lastDirection,
          length: _length.round(),
          variant: _revising ? null : (_multiMode ? index : null),
          // ENH-36：三路各用一种叙事侧重，共用同一份预组装资料。
          strategy: _revising || !_multiMode
              ? null
              : ContinueStrategy.all[index % ContinueStrategy.all.length],
          prebuilt: _revising ? null : _prebuilt,
          revisionDraft: _revising ? _revisionDraft : null,
          revisionInstruction: _revising ? _revisionInstructionText : null,
        );
      case AiPanelMode.inspireIdeas:
      case AiPanelMode.inspireOpening:
        return service.inspire(
          workId: widget.workId,
          mode: _mode == AiPanelMode.inspireOpening
              ? InspireMode.opening
              : InspireMode.ideas,
          anchorChapterId: widget.chapterId,
          direction: _lastDirection.isEmpty ? null : _lastDirection,
        );
      case AiPanelMode.rewrite:
        return service.rewrite(
          workId: widget.workId,
          chapterId: widget.chapterId,
          selectedText: widget.rewriteText ?? '',
          intent: _intent,
          instruction: _instruction.isEmpty ? null : _instruction,
          revisionDraft: _revising ? _revisionDraft : null,
          revisionInstruction: _revising ? _revisionInstructionText : null,
        );
      case AiPanelMode.summarize:
        return service.summarizeChapter(
          workId: widget.workId,
          chapterId: widget.chapterId,
        );
      case AiPanelMode.outlineExpand:
        return service.expandOutline(
          workId: widget.workId,
          chapterId: widget.chapterId,
          seed: widget.outlineSeed ?? '',
        );
      case AiPanelMode.volumeSummary:
        return service.summarizeVolume(
          workId: widget.workId,
          chapterId: widget.chapterId,
        );
    }
  }

  void _onEvent(AiEvent event, int index) {
    if (!mounted) return;
    switch (event) {
      case AiContextBuilt():
        // 多候选共享同一上下文，取首个即可。
        if (_context == null) setState(() => _context = event.context);
      case AiTextChunk():
        // ENH-29：旧结果确实被新文本替换时才记为「重新生成」；
        // 若修订在首个文本块前失败，_usageIds 仍指向旧结果。
        final replacing =
            _revising && index == _revisionIndex && !_revisionTextStarted;
        if (replacing) {
          _revisionTextStarted = true;
          final previousUsage = _revisionPreviousUsage;
          _revisionPreviousUsage = null;
          _usageIds[index] = null;
          _rawOutputs[index] = event.text;
          if (previousUsage != null) {
            unawaited(
              ref
                  .read(aiServiceProvider)
                  .markOutcome(previousUsage, 'regenerated'),
            );
          }
        } else {
          _rawOutputs[index] = _rawOutputs[index] + event.text;
        }
        setState(() {
          final controller = _results[index];
          // ENH-27：多轮修改的第一段直接替换旧草稿，失败时旧结果仍可保留。
          controller.text = replacing
              ? event.text
              : controller.text + event.text;
        });
      case AiFinished():
        _usageIds[index] = event.usageId < 0 ? null : event.usageId;
        // ENH-27.3：每次生成 / 修订完成后记一版，供切换与对比。
        final text = _results[index].text;
        if (text.trim().isNotEmpty) {
          _revisionHistory[index].record(
            text,
            instruction: _revising && index == _revisionIndex
                ? _revisionInstructionText
                : '',
          );
        }
        _finishOne();
      case AiFailed():
        _errors[index] = aiFailureText(
          context.l10n,
          kind: event.kind,
          message: event.message,
          statusCode: event.statusCode,
          code: event.code,
          detail: event.detail,
        );
        _errorKind = event.kind;
        _finishOne();
      case AiNeedsConfig():
        _stopElapsed();
        setState(() {
          _streaming = false;
          _pending = 0;
          _needsConfig = true;
        });
    }
  }

  /// 一路候选结束（成功或失败）：全部结束后解除流式态。
  void _finishOne() {
    if (_pending > 0) _pending--;
    if (_pending == 0 && mounted) {
      _stopElapsed();
      // 修订失败且尚未产出新文本：旧候选仍有效，清除待替换标记。
      _revisionPreviousUsage = null;
      setState(() => _streaming = false);
    }
  }

  /// 停止当前生成（ENH-29）：取消所有流并复位流式状态。
  void _stopStreaming() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs = const <StreamSubscription<AiEvent>>[];
    _stopElapsed();
    _revisionPreviousUsage = null;
    if (!mounted) return;
    setState(() {
      _streaming = false;
      _pending = 0;
    });
  }

  void _changeMode(AiPanelMode mode) {
    if (mode == _mode) return;
    setState(() => _mode = mode);
    _start();
  }

  Future<void> _retryWithDirection() async {
    // 不使用外部 TextEditingController：弹窗退场动画期间 builder 会再次执行，
    // 过早 dispose 会导致「controller used after being disposed」。
    var text = _lastDirection;
    final direction = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.aiPanelNewDirection),
        content: TextFormField(
          initialValue: _lastDirection,
          onChanged: (value) => text = value,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: context.l10n.aiPanelDirectionHint,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(text.trim()),
            child: Text(context.l10n.aiPanelRegenerate),
          ),
        ],
      ),
    );
    if (direction == null) return;
    await _start(direction: direction);
  }

  /// 把全部候选（含多候选）按 [outcome] 回写统计（ENH-05）。
  Future<void> _markOutcomeForAll(String outcome) async {
    final service = ref.read(aiServiceProvider);
    for (var i = 0; i < _usageIds.length; i++) {
      final id = _usageIds[i];
      if (id == null) continue;
      await service.markOutcome(id, outcome);
    }
  }

  /// 采纳当前候选：选中记 adopted，其余候选（仅续写多候选）记 ignored。
  /// [sourceText] 为模型原稿（ENH-30），用于计算编辑后采纳比例。
  Future<void> _markAdoption(
    int chars, {
    String? adoptedText,
    String? sourceText,
  }) async {
    final finalText = adoptedText?.trim() ?? '';
    final source = sourceText?.trim() ?? '';
    final editPercent = source.isNotEmpty && finalText.isNotEmpty
        ? adoptionEditPercent(source, finalText)
        : null;
    final service = ref.read(aiServiceProvider);
    for (var i = 0; i < _usageIds.length; i++) {
      final id = _usageIds[i];
      if (id == null) continue;
      if (i == _activeIndex) {
        await service.markOutcome(
          id,
          'adopted',
          adoptedChars: chars,
          adoptedEditPercent: editPercent,
        );
      } else if (_mode == AiPanelMode.continueWriting) {
        await service.markOutcome(id, 'ignored');
      }
    }
    _outcomesMarked = true;
    // ENH-27：续写 / 改写的采纳样本仅存本机，供后续生成的语气参考。
    // ENH-30：大改后的文本不代表模型语气，超过阈值不采集样本。
    // ENH-42：轻度～中度修改（10% < 编辑比例 ≤ 30%）时保留原稿对照。
    final sample = finalText;
    final task = _mode == AiPanelMode.rewrite
        ? AiTask.rewrite
        : AiTask.continueWriting;
    if (sample.isNotEmpty &&
        _isWritingMode &&
        (editPercent == null || editPercent <= adoptionSampleMaxEditPercent)) {
      final paired = source.isNotEmpty && adoptionKeepsSource(editPercent);
      await ref
          .read(settingsRepositoryProvider)
          .recordAdoptedSample(
            widget.workId,
            text: sample,
            source: paired ? source : '',
            task: task,
          );
    } else if (sample.isNotEmpty &&
        _isWritingMode &&
        source.isNotEmpty &&
        editPercent != null) {
      // ENH-50：大改样本仅本地分析（蒸馏），不进入提示样本。
      await ref
          .read(settingsRepositoryProvider)
          .recordAnalysisSample(
            widget.workId,
            text: sample,
            source: source,
            task: task,
          );
    }
  }

  /// 采纳时的模型原稿（ENH-30）：切到旧修订版本时以该版文本为基线。
  String? _adoptionSource() {
    final index = _activeIndex;
    final history = _revisionHistory[index];
    if (history.selectedIndex >= 0 &&
        history.selectedIndex != history.length - 1) {
      return history.selected?.text;
    }
    final raw = _rawOutputs[index].trim();
    return raw.isEmpty ? null : raw;
  }

  /// 首次写入正文前创建快照（ENH-30）。快照失败不阻断采纳。
  Future<void> _snapshotBeforeApply() async {
    if (_snapshotTaken) return;
    _snapshotTaken = true;
    try {
      await widget.onBeforeApply?.call();
    } catch (_) {
      // 版本留档失败不应让作者丢掉已生成的正文。
    }
  }

  bool get _isWritingMode =>
      _mode == AiPanelMode.continueWriting || _mode == AiPanelMode.rewrite;

  /// 结果内多轮修改（ENH-27）：把当前候选 + 修改意见交给模型重写。
  Future<void> _startRevision() async {
    if (_streaming) return;
    final instruction = _revisionInstruction.text.trim();
    if (instruction.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.aiPanelReviseNeedInstruction)),
      );
      return;
    }
    final draft = sanitizeAiText(_activeResult.text).trim();
    if (draft.isEmpty) return;
    final index = _activeIndex;
    // 把作者在候选框里的直接编辑写回当前版本，切换历史时不丢失。
    _revisionHistory[index].updateSelected(draft);
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs = const <StreamSubscription<AiEvent>>[];
    // 旧结果被替换前记为「重新生成」，不污染采纳率（ENH-29：延后到首个新文本块）。
    _revisionPreviousUsage = _usageIds[index];
    if (!mounted) return;
    setState(() {
      _revising = true;
      _revisionDraft = draft;
      _revisionInstructionText = instruction;
      _revisionIndex = index;
      _revisionTextStarted = false;
      _streaming = true;
      _errorKind = null;
      _needsConfig = false;
      _context = null;
      _pending = 1;
      _errors[index] = null;
      _usageIds[index] = null;
      _revisionInstruction.clear();
    });
    _startElapsed();
    _subs = <StreamSubscription<AiEvent>>[
      _buildStream(index).listen((event) => _onEvent(event, index)),
    ];
  }

  Future<void> _abandon() async {
    final hasOutput =
        _results.any((c) => c.text.trim().isNotEmpty) &&
        _usageIds.any((id) => id != null);
    var reason = '';
    if (hasOutput) {
      final picked = await showAiDiscardReasonDialog(context);
      if (picked == null) return;
      reason = picked;
    }
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs = const <StreamSubscription<AiEvent>>[];
    await _markOutcomeForAll('ignored');
    _outcomesMarked = true;
    if (reason.isNotEmpty) {
      await ref
          .read(settingsRepositoryProvider)
          .recordAiFeedback(widget.workId, reason);
      // ENH-44：整篇因「太 AI」被放弃时留存摘要，用于发现高频套话。
      if (reason == AiFeedbackReason.tooAi) {
        for (final controller in _results) {
          final text = sanitizeAiText(controller.text).trim();
          if (text.isEmpty) continue;
          await ref
              .read(settingsRepositoryProvider)
              .recordRejectedAiText(widget.workId, text);
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.aiFeedbackRecorded)),
        );
      }
    }
    widget.onClose();
  }

  /// 分段采纳（ENH-27）：按段落合并后再写入 / 替换，仍走编辑器撤销栈。
  /// ENH-29：有段落被取消勾选时采集一次主要原因，用于后续生成避雷。
  Future<void> _merge() async {
    if (_streaming || !_isWritingMode) return;
    final source = sanitizeAiText(_activeResult.text).trim();
    if (source.isEmpty) return;
    final result = await showAiMergeDialog(
      context,
      text: source,
      baseText: _mode == AiPanelMode.rewrite
          ? sanitizeAiText(widget.rewriteText ?? '').trim()
          : null,
    );
    if (!mounted || result == null) return;
    final text = sanitizeAiText(result.text).trim();
    if (text.isEmpty) return;
    if (result.rejectedCount > 0) {
      final picked = await showAiDiscardReasonDialog(
        context,
        title: context.l10n.aiMergeRejectTitle,
        hint: context.l10n.aiMergeRejectHint(result.rejectedCount),
        confirmLabel: context.l10n.aiMergeRejectConfirm,
      );
      if (!mounted || picked == null) return;
      if (picked.isNotEmpty) {
        await ref
            .read(settingsRepositoryProvider)
            .recordAiParagraphFeedback(widget.workId, picked);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.aiFeedbackRecorded)),
          );
        }
      }
    }
    await _snapshotBeforeApply();
    if (_mode == AiPanelMode.rewrite) {
      widget.onReplace?.call(text);
    } else {
      widget.onInsert(text);
    }
    await _markAdoption(
      text.length,
      adoptedText: text,
      sourceText: _adoptionSource() ?? source,
    );
    if (mounted) widget.onClose();
  }

  /// 跨候选组合（ENH-36）：逐段挑选后替换当前候选的结果，供继续修订或采纳。
  Future<void> _mixCandidates() async {
    if (_streaming || !_multiMode) return;
    final mixed = await showCandidateMergeDialog(
      context,
      candidates: <String>[for (final controller in _results) controller.text],
      selectedIndex: _selected,
    );
    if (!mounted || mixed == null) return;
    setState(() => _results[_selected].text = mixed);
  }

  /// 改写模式（ENH-29）：把当前结果与待改写原文并排对比。
  void _compareWithOriginal() {
    showSnapshotDiffDialog(
      context,
      oldText: sanitizeAiText(widget.rewriteText ?? '').trim(),
      newText: sanitizeAiText(_activeResult.text).trim(),
      title: context.l10n.aiPanelCompareOriginalTitle,
    );
  }

  Future<void> _insert() async {
    // ENH-09：与三处摘要路径一致，写进正文前统一清洗 markdown 标记与多余空行。
    final text = sanitizeAiText(_activeResult.text).trim();
    if (text.isEmpty) return;
    await _snapshotBeforeApply();
    widget.onInsert(text);
    await _markAdoption(
      text.length,
      adoptedText: text,
      sourceText: _adoptionSource(),
    );
    widget.onClose();
  }

  /// 改写模式（ENH-04）：把 AI 改写结果替换回原文选中区间（走编辑器撤销栈）。
  Future<void> _replace() async {
    // ENH-09：替换回正文前同样清洗，避免 `**加粗**`/行首编号等混入正文。
    final text = sanitizeAiText(_activeResult.text).trim();
    if (text.isEmpty) return;
    final replace = widget.onReplace;
    if (replace == null) return;
    await _snapshotBeforeApply();
    replace(text);
    await _markAdoption(
      text.length,
      adoptedText: text,
      sourceText: _adoptionSource(),
    );
    widget.onClose();
  }

  /// 逐章摘要（ENH-05）：把摘要写回 CHAPTER.summary。
  Future<void> _saveSummary() async {
    final text = _activeResult.text.trim();
    if (text.isEmpty) return;
    final save = widget.onSaveSummary;
    if (save == null) return;
    save(text);
    await _markAdoption(
      text.length,
      adoptedText: text,
      sourceText: _adoptionSource(),
    );
    widget.onClose();
  }

  /// 章纲扩写（ENH-05）：把分场大纲写回本章章纲。
  Future<void> _saveOutline() async {
    final text = _activeResult.text.trim();
    if (text.isEmpty) return;
    final save = widget.onSaveOutline;
    if (save == null) return;
    save(text);
    await _markAdoption(
      text.length,
      adoptedText: text,
      sourceText: _adoptionSource(),
    );
    widget.onClose();
  }

  /// 本卷前情回顾（ENH-06）：把回顾写回 VOLUME.summary。
  Future<void> _saveVolumeSummary() async {
    final text = _activeResult.text.trim();
    if (text.isEmpty) return;
    final save = widget.onSaveVolumeSummary;
    if (save == null) return;
    save(text);
    await _markAdoption(
      text.length,
      adoptedText: text,
      sourceText: _adoptionSource(),
    );
    widget.onClose();
  }

  Future<void> _saveToInspiration() async {
    final text = _activeResult.text.trim();
    if (text.isEmpty) return;
    await ref
        .read(inspirationRepositoryProvider)
        .createInspiration(widget.workId, text);
    final isInspire =
        _mode == AiPanelMode.inspireIdeas ||
        _mode == AiPanelMode.inspireOpening;
    if (isInspire) {
      await _markAdoption(
        text.length,
        adoptedText: text,
        sourceText: _adoptionSource(),
      );
    } else {
      // ENH-30：续写 / 改写存入灵感箱不等于写入正文，不计入采纳率。
      await _markOutcomeForAll('ignored');
      _outcomesMarked = true;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.aiPanelSavedToInspiration)),
    );
    widget.onClose();
  }

  void _goSettings() {
    widget.onClose();
    context.push('/settings');
  }

  @override
  Widget build(BuildContext context) {
    final isInspire =
        _mode == AiPanelMode.inspireIdeas ||
        _mode == AiPanelMode.inspireOpening;
    final isRewrite = _mode == AiPanelMode.rewrite;
    // 面板内容较长：限高并内部滚动，避免键盘弹出时挤压编辑器造成溢出。
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: context.paper.surface,
          border: Border(
            top: BorderSide(color: context.paper.divider, width: 2),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _buildHeader(),
                  if (isInspire) _buildModeSwitch(),
                  if (isRewrite) _buildIntentRow(),
                  if (isInspire || _mode == AiPanelMode.continueWriting)
                    _buildLengthRow(),
                  if (_mode == AiPanelMode.continueWriting)
                    _buildCandidateControls(),
                  if (isRewrite) _buildInstructionField(),
                  if (_context != null) _buildContextDetails(_context!),
                  const SizedBox(height: 6),
                  _buildResult(),
                  if (_isWritingMode) _buildRevisionHistoryRow(),
                  if (_isWritingMode) _buildRuleCheckRow(),
                  if (_isWritingMode) _buildCollaborationRow(),
                  if (_activeError != null) _buildError(),
                  const SizedBox(height: 8),
                  _buildActions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: <Widget>[
        Icon(Icons.auto_awesome, size: 18, color: context.paper.accent),
        const SizedBox(width: 6),
        Text(
          _title(context.l10n),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 8),
        if (_streaming)
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.6),
          ),
        // ENH-07 O9：生成耗时反馈（流式期间每秒刷新，结束后保留最后一次秒数）。
        if (_elapsedSeconds > 0) ...<Widget>[
          const SizedBox(width: 6),
          Text(
            context.l10n.aiPanelElapsedSeconds(_elapsedSeconds),
            style: TextStyle(fontSize: 12, color: context.paper.inkSoft),
          ),
        ],
        const Spacer(),
        IconButton(
          tooltip: context.l10n.commonClose,
          icon: const Icon(Icons.close, size: 20),
          // ENH-29：关闭与「放弃」一致，先采集原因并回写统计，避免结果被静默丢弃。
          onPressed: _abandon,
        ),
      ],
    );
  }

  Widget _buildModeSwitch() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SegmentedButton<AiPanelMode>(
        segments: <ButtonSegment<AiPanelMode>>[
          ButtonSegment<AiPanelMode>(
            value: AiPanelMode.inspireIdeas,
            label: Text(context.l10n.aiPanelModeIdeas),
          ),
          ButtonSegment<AiPanelMode>(
            value: AiPanelMode.inspireOpening,
            label: Text(context.l10n.aiPanelModeOpening),
          ),
        ],
        selected: <AiPanelMode>{_mode},
        onSelectionChanged: (selection) => _changeMode(selection.first),
      ),
    );
  }

  /// 改写意图选择（ENH-04）：切换即重新生成。
  Widget _buildIntentRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<String>(
          segments: <ButtonSegment<String>>[
            for (final intent in RewriteIntent.all)
              ButtonSegment<String>(
                value: intent,
                label: Text(_intentLabel(context.l10n, intent)),
              ),
          ],
          selected: <String>{_intent},
          onSelectionChanged: _streaming
              ? null
              : (selection) {
                  setState(() => _intent = selection.first);
                  _start();
                },
        ),
      ),
    );
  }

  /// 作者补充指令（ENH-04）：替代「换个方向」弹窗，点「重新生成」时生效。
  Widget _buildInstructionField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: TextFormField(
        initialValue: _instruction,
        maxLines: 2,
        minLines: 1,
        onChanged: (value) => _instruction = value,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: context.l10n.aiPanelInstructionHint,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildLengthRow() {
    if (_mode != AiPanelMode.continueWriting) return const SizedBox.shrink();
    // 合并篇幅标签与滑杆，读屏可听到「篇幅：N 字」并直接调整。
    return MergeSemantics(
      child: Row(
        children: <Widget>[
          Text(
            context.l10n.aiPanelLengthLabel(_length.round()),
            style: TextStyle(fontSize: 12, color: context.paper.inkSoft),
          ),
          Expanded(
            child: Slider(
              value: _length,
              min: 300,
              max: 800,
              divisions: 10,
              activeColor: context.paper.accent,
              onChanged: _streaming
                  ? null
                  : (value) =>
                        setState(() => _length = (value / 50).round() * 50.0),
            ),
          ),
        ],
      ),
    );
  }

  /// 多候选续写（ENH-05）：开关「3 个候选」，开启后可切换查看 / 采纳某一路。
  /// ENH-36：候选就绪后可跨候选逐段组合。
  Widget _buildCandidateControls() {
    final canMix =
        !_streaming &&
        _results
                .where((controller) => controller.text.trim().isNotEmpty)
                .length >=
            2;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              FilterChip(
                label: Text(context.l10n.aiPanelCandidateCount),
                selected: _multiCandidate,
                onSelected: _streaming
                    ? null
                    : (value) {
                        setState(() => _multiCandidate = value);
                        _start();
                      },
              ),
              if (_multiMode) ...<Widget>[
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<int>(
                      segments: <ButtonSegment<int>>[
                        for (var i = 0; i < 3; i++)
                          ButtonSegment<int>(
                            value: i,
                            label: Text(context.l10n.aiPanelVersion(i + 1)),
                          ),
                      ],
                      selected: <int>{_selected},
                      onSelectionChanged: _streaming
                          ? null
                          : (selection) =>
                                setState(() => _selected = selection.first),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (_multiMode && canMix)
            TextButton.icon(
              onPressed: _mixCandidates,
              icon: const Icon(Icons.merge_type, size: 18),
              label: Text(context.l10n.aiPanelMixCandidates),
            ),
        ],
      ),
    );
  }

  Widget _buildContextDetails(BuiltContext built) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      // 用 Material 承载底色：ExpansionTile 内部是 ListTile，若直接放在带底色的
      // DecoratedBox 里，debug 下会触发「ListTile 背景/水波纹不可见」断言。
      child: Material(
        color: context.paper.background,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          initiallyExpanded: _contextExpanded,
          onExpansionChanged: (v) => _contextExpanded = v,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: Text(
            context.l10n.aiPanelContextTitle(
              built.estimatedTokens,
              built.budgetTokens,
            ),
            style: TextStyle(fontSize: 12, color: context.paper.inkSoft),
          ),
          subtitle: built.truncated
              ? Text(
                  context.l10n.aiPanelTruncated,
                  style: TextStyle(fontSize: 11, color: context.paper.accent),
                )
              : null,
          // ENH-07 O1：详情区限高并内部滚动，展开后无需与外层 / 输出框抢滚动手势。
          children: <Widget>[
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.26,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: built.sections
                      .map(
                        (section) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                _sectionLabel(context.l10n, section.label),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                section.content,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.paper.inkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 修订历史（ENH-27.3）：切换原稿 / 各修订版，并与上一版对比。
  Widget _buildRevisionHistoryRow() {
    final history = _revisionHistory[_activeIndex];
    if (_streaming || history.length < 2) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            for (var i = 0; i < history.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(
                    i == 0 ? l10n.aiRevisionOriginal : l10n.aiRevisionNumber(i),
                  ),
                  selected: history.selectedIndex == i,
                  onSelected: (_) => _switchRevision(i),
                ),
              ),
            if (history.canCompare)
              TextButton.icon(
                onPressed: _compareRevisions,
                icon: const Icon(Icons.difference_outlined, size: 18),
                label: Text(l10n.aiRevisionCompare),
              ),
          ],
        ),
      ),
    );
  }

  void _switchRevision(int index) {
    final history = _revisionHistory[_activeIndex];
    history.updateSelected(_activeResult.text);
    final text = history.select(index);
    if (text == null) return;
    setState(() {
      _activeResult.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    });
  }

  void _compareRevisions() {
    final history = _revisionHistory[_activeIndex];
    history.updateSelected(_activeResult.text);
    final previous = history.previous;
    final current = history.selected;
    if (previous == null || current == null) return;
    showSnapshotDiffDialog(
      context,
      oldText: previous.text,
      newText: current.text,
      title: context.l10n.aiRevisionCompareTitle,
    );
  }

  Future<void> _loadCollabRules() async {
    final rules = await ref
        .read(settingsRepositoryProvider)
        .readCollaborationRules(widget.workId);
    if (!mounted) return;
    setState(() {
      _collabRules = rules;
      _ruleCheckKey = '';
    });
  }

  /// ENH-48：按当前文本缓存自检结果，避免每次重建都跑完整词库。
  RuleCheckResult _ruleCheckFor(String text) {
    final key =
        '${text.length}:${text.hashCode}:'
        '${_collabRules.rules.length}:${_collabRules.banned.length}';
    if (key != _ruleCheckKey) {
      _ruleCheckKey = key;
      _ruleCheck = CollaborationRules.inspectText(
        text,
        rules: _collabRules.rules,
        banned: _collabRules.banned,
      );
    }
    return _ruleCheck;
  }

  Future<void> _banRuleIssue(RuleCheckIssue issue) async {
    await ref
        .read(settingsRepositoryProvider)
        .addBannedPhrase(widget.workId, issue.phrase);
    await _loadCollabRules();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.aiRuleCheckBanned)));
  }

  void _startRuleRewrite(RuleCheckResult check) {
    if (_streaming || check.isEmpty) return;
    final words = check.issues
        .take(5)
        .map((issue) => '「${issue.phrase}」')
        .join('、');
    _revisionInstruction.value = TextEditingValue(
      text: context.l10n.aiRuleCheckRewritePrompt(words),
      selection: TextSelection.collapsed(
        offset: context.l10n.aiRuleCheckRewritePrompt(words).length,
      ),
    );
    setState(() {});
    _startRevision();
  }

  /// ENH-48：生成结果内联守则自检，作者能直接看到规则是否生效。
  Widget _buildRuleCheckRow() {
    if (_streaming) return const SizedBox.shrink();
    final text = _activeResult.text.trim();
    if (text.isEmpty) return const SizedBox.shrink();
    final configured =
        _collabRules.rules.isNotEmpty || _collabRules.banned.isNotEmpty;
    final check = _ruleCheckFor(text);
    if (!configured && check.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final inkSoft = context.paper.inkSoft;
    final hit = !check.isEmpty;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      decoration: BoxDecoration(
        color: hit
            ? const Color(0xFFB3261E).withValues(alpha: 0.06)
            : context.paper.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                hit ? Icons.fact_check_outlined : Icons.verified_outlined,
                size: 16,
                color: hit ? const Color(0xFFB3261E) : inkSoft,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hit
                      ? l10n.aiRuleCheckHits(check.total)
                      : l10n.aiRuleCheckClear,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: hit ? const Color(0xFFB3261E) : inkSoft,
                  ),
                ),
              ),
              if (hit)
                TextButton(
                  onPressed: () => _startRuleRewrite(check),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: Text(
                    l10n.aiRuleCheckRewrite,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
          if (hit)
            for (final issue in check.issues.take(4))
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        <String>[
                          '「${issue.phrase}」×${issue.count}',
                          if (issue.replacement != null)
                            issue.replacement!.isEmpty
                                ? l10n.aiRuleCheckDeleteHint
                                : l10n.aiRuleCheckReplacement(
                                    issue.replacement!,
                                  ),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: inkSoft),
                      ),
                    ),
                    if (!issue.isBanned)
                      TextButton(
                        onPressed: () => _banRuleIssue(issue),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        child: Text(
                          l10n.aiRuleCheckBan,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  /// 结果内协作（ENH-27）：分段采纳 + 基于当前结果继续修改。
  Widget _buildCollaborationRow() {
    final l10n = context.l10n;
    final hasText = _activeResult.text.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              TextButton.icon(
                onPressed: hasText && !_streaming ? _merge : null,
                icon: const Icon(Icons.checklist, size: 18),
                label: Text(l10n.aiPanelMerge),
              ),
              if (_mode == AiPanelMode.rewrite)
                TextButton.icon(
                  onPressed: hasText && !_streaming
                      ? _compareWithOriginal
                      : null,
                  icon: const Icon(Icons.difference_outlined, size: 18),
                  label: Text(l10n.aiPanelCompareOriginal),
                ),
              const Spacer(),
              if (_revising && _streaming)
                Text(
                  l10n.aiPanelRevising,
                  style: TextStyle(fontSize: 12, color: context.paper.inkSoft),
                ),
            ],
          ),
          if (!_streaming)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 2,
                children: <Widget>[
                  for (final quick in _quickRevisions(l10n))
                    ActionChip(
                      label: Text(quick),
                      onPressed: () => _useQuickRevision(quick),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _revisionInstruction,
                  enabled: !_streaming,
                  minLines: 1,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: l10n.aiPanelReviseHint,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: hasText && !_streaming ? _startRevision : null,
                child: Text(l10n.aiPanelRevise),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 修订快捷指令（ENH-29）：点一下填入输入框，仍可继续编辑。
  List<String> _quickRevisions(AppLocalizations l10n) => <String>[
    l10n.aiReviseQuickMoreDetail,
    l10n.aiReviseQuickTighter,
    l10n.aiReviseQuickDialog,
    l10n.aiReviseQuickEnding,
    l10n.aiReviseQuickRemoveAi,
  ];

  void _useQuickRevision(String instruction) {
    _revisionInstruction.value = TextEditingValue(
      text: instruction,
      selection: TextSelection.collapsed(offset: instruction.length),
    );
    setState(() {});
  }

  Widget _buildResult() {
    return TextField(
      key: ValueKey<int>(_activeIndex),
      controller: _activeResult,
      minLines: 4,
      // ENH-07 O1：输出框限高，避免过长正文吞掉垂直滚动手势、挤占上下文详情区。
      maxLines: 6,
      style: TextStyle(fontSize: 15, height: 1.6, color: context.paper.ink),
      // 手动编辑后刷新按钮可用态（分段采纳 / 继续修改 / 主操作）。
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: context.l10n.aiPanelResultHint,
        fillColor: context.paper.background,
        contentPadding: const EdgeInsets.all(12),
      ),
    );
  }

  Widget _buildError() {
    final canGoSettings =
        _errorKind == AiErrorKind.auth || _errorKind == AiErrorKind.badRequest;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFB3261E).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.error_outline, size: 18, color: Color(0xFFB3261E)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _activeError!,
              style: const TextStyle(fontSize: 12, color: Color(0xFFB3261E)),
            ),
          ),
          if (canGoSettings)
            TextButton(
              onPressed: _goSettings,
              child: Text(context.l10n.editorGoSettings),
            ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    if (_needsConfig) {
      return Row(
        children: <Widget>[
          Expanded(
            child: Text(
              context.l10n.aiPanelNeedsConfig,
              style: TextStyle(fontSize: 13, color: context.paper.inkSoft),
            ),
          ),
          FilledButton(
            onPressed: _goSettings,
            child: Text(context.l10n.editorGoSettings),
          ),
        ],
      );
    }

    final hasText = _activeResult.text.trim().isNotEmpty;
    final isInspire =
        _mode == AiPanelMode.inspireIdeas ||
        _mode == AiPanelMode.inspireOpening;
    final isRewrite = _mode == AiPanelMode.rewrite;
    final isSummarize = _mode == AiPanelMode.summarize;
    final isOutlineExpand = _mode == AiPanelMode.outlineExpand;
    final isVolumeSummary = _mode == AiPanelMode.volumeSummary;
    // 主操作按钮：摘要 / 章纲扩写 / 卷回顾写回对应字段，改写替换原文，其余插入光标处。
    final l10n = context.l10n;
    final String primaryLabel = isRewrite
        ? l10n.aiPanelReplaceOriginal
        : isSummarize
        ? l10n.aiPanelSaveSummary
        : isOutlineExpand
        ? l10n.aiPanelSaveToOutline
        : isVolumeSummary
        ? l10n.aiPanelSaveVolumeSummary
        : l10n.aiPanelInsertAtCursor;
    final VoidCallback? onPrimary = hasText && !_streaming
        ? (isRewrite
              ? _replace
              : isSummarize
              ? _saveSummary
              : isOutlineExpand
              ? _saveOutline
              : isVolumeSummary
              ? _saveVolumeSummary
              : _insert)
        : null;
    return Row(
      children: <Widget>[
        if (_streaming)
          OutlinedButton(
            onPressed: _stopStreaming,
            child: Text(l10n.aiPanelStop),
          )
        else ...<Widget>[
          TextButton(
            onPressed: () => _start(),
            child: Text(l10n.aiPanelRegenerate),
          ),
          // 改写用「补充指令」输入框替代方向弹窗（ENH-04）；
          // 摘要 / 章纲扩写 / 卷回顾目标明确，无需「换个方向」（ENH-05 / ENH-06）。
          if (!isRewrite &&
              !isSummarize &&
              !isOutlineExpand &&
              !isVolumeSummary)
            TextButton(
              onPressed: _retryWithDirection,
              child: Text(l10n.aiPanelNewDirection),
            ),
        ],
        const Spacer(),
        if (isInspire || _isWritingMode)
          TextButton(
            onPressed: hasText && !_streaming ? _saveToInspiration : null,
            child: Text(l10n.aiPanelSaveToInspiration),
          ),
        TextButton(onPressed: _abandon, child: Text(l10n.aiPanelDiscard)),
        const SizedBox(width: 4),
        FilledButton(onPressed: onPrimary, child: Text(primaryLabel)),
      ],
    );
  }
}
