import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/ai/ai_client.dart';
import '../../core/ai/context_builder.dart';
import '../../data/data_providers.dart';
import '../ai/ai_providers.dart';
import '../ai/ai_service.dart';

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
    this.rewriteText,
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

  /// 改写模式（ENH-04）：待改写原文与「替换原文」回调（走编辑器撤销栈）。
  final String? rewriteText;
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

  List<StreamSubscription<AiEvent>> _subs = const <StreamSubscription<AiEvent>>[];

  bool _streaming = false;

  /// 每个候选的失败信息与 usageId（索引与 [_results] 对齐）。
  final List<String?> _errors = <String?>[null, null, null];
  final List<int?> _usageIds = <int?>[null, null, null];
  AiErrorKind? _errorKind;
  int _pending = 0;

  bool _needsConfig = false;
  BuiltContext? _context;
  bool _contextExpanded = false;

  double _length = 500;
  String _lastDirection = '';

  /// 改写模式（ENH-04）：意图与作者补充指令。
  String _intent = RewriteIntent.polish;
  String _instruction = '';

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    for (final controller in _results) {
      controller.dispose();
    }
    super.dispose();
  }

  String get _title {
    switch (_mode) {
      case AiPanelMode.continueWriting:
        return 'AI 续写';
      case AiPanelMode.inspireIdeas:
        return 'AI 灵感 · 桥段点子';
      case AiPanelMode.inspireOpening:
        return 'AI 灵感 · 开篇助手';
      case AiPanelMode.rewrite:
        return 'AI 改写';
      case AiPanelMode.summarize:
        return 'AI 逐章摘要';
      case AiPanelMode.outlineExpand:
        return 'AI 章纲扩写';
      case AiPanelMode.volumeSummary:
        return 'AI 本卷前情回顾';
    }
  }

  Future<void> _start({String? direction}) async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs = const <StreamSubscription<AiEvent>>[];
    if (!mounted) return;
    setState(() {
      _streaming = true;
      _errorKind = null;
      _needsConfig = false;
      _context = null;
      _selected = 0;
      for (var i = 0; i < _errors.length; i++) {
        _errors[i] = null;
        _usageIds[i] = null;
      }
      for (final controller in _results) {
        controller.text = '';
      }
      if (direction != null) _lastDirection = direction;
    });

    // 多候选仅对续写生效（ENH-05）。
    final count = _multiMode ? 3 : 1;
    _pending = count;
    _subs = <StreamSubscription<AiEvent>>[
      for (var i = 0; i < count; i++)
        _buildStream(i).listen((event) => _onEvent(event, i)),
    ];
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
          variant: _multiMode ? index : null,
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
        setState(() => _results[index].text = _results[index].text + event.text);
      case AiFinished():
        _usageIds[index] = event.usageId < 0 ? null : event.usageId;
        _finishOne();
      case AiFailed():
        _errors[index] = event.message;
        _errorKind = event.kind;
        _finishOne();
      case AiNeedsConfig():
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
      setState(() => _streaming = false);
    }
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
        title: const Text('换个方向'),
        content: TextFormField(
          initialValue: _lastDirection,
          onChanged: (value) => text = value,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: '补充一句方向指令，例如：让两人在此摊牌',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(text.trim()),
            child: const Text('重新生成'),
          ),
        ],
      ),
    );
    if (direction == null) return;
    await _markOutcomeForAll('regenerated');
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
  Future<void> _markAdoption(int chars) async {
    final service = ref.read(aiServiceProvider);
    for (var i = 0; i < _usageIds.length; i++) {
      final id = _usageIds[i];
      if (id == null) continue;
      if (i == _activeIndex) {
        await service.markOutcome(id, 'adopted', adoptedChars: chars);
      } else if (_mode == AiPanelMode.continueWriting) {
        await service.markOutcome(id, 'ignored');
      }
    }
  }

  Future<void> _abandon() async {
    await _markOutcomeForAll('ignored');
    widget.onClose();
  }

  Future<void> _insert() async {
    final text = _activeResult.text.trim();
    if (text.isEmpty) return;
    widget.onInsert(text);
    await _markAdoption(text.length);
    widget.onClose();
  }

  /// 改写模式（ENH-04）：把 AI 改写结果替换回原文选中区间（走编辑器撤销栈）。
  Future<void> _replace() async {
    final text = _activeResult.text.trim();
    if (text.isEmpty) return;
    final replace = widget.onReplace;
    if (replace == null) return;
    replace(text);
    await _markAdoption(text.length);
    widget.onClose();
  }

  /// 逐章摘要（ENH-05）：把摘要写回 CHAPTER.summary。
  Future<void> _saveSummary() async {
    final text = _activeResult.text.trim();
    if (text.isEmpty) return;
    final save = widget.onSaveSummary;
    if (save == null) return;
    save(text);
    await _markAdoption(text.length);
    widget.onClose();
  }

  /// 章纲扩写（ENH-05）：把分场大纲写回本章章纲。
  Future<void> _saveOutline() async {
    final text = _activeResult.text.trim();
    if (text.isEmpty) return;
    final save = widget.onSaveOutline;
    if (save == null) return;
    save(text);
    await _markAdoption(text.length);
    widget.onClose();
  }

  /// 本卷前情回顾（ENH-06）：把回顾写回 VOLUME.summary。
  Future<void> _saveVolumeSummary() async {
    final text = _activeResult.text.trim();
    if (text.isEmpty) return;
    final save = widget.onSaveVolumeSummary;
    if (save == null) return;
    save(text);
    await _markAdoption(text.length);
    widget.onClose();
  }

  Future<void> _saveToInspiration() async {
    final text = _activeResult.text.trim();
    if (text.isEmpty) return;
    await ref
        .read(inspirationRepositoryProvider)
        .createInspiration(widget.workId, text);
    await _markAdoption(text.length);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已存入灵感箱')),
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
          border: Border(top: BorderSide(color: context.paper.divider, width: 2)),
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
        Text(_title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        if (_streaming)
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.6),
          ),
        const Spacer(),
        IconButton(
          tooltip: '收起',
          icon: const Icon(Icons.close, size: 20),
          onPressed: () {
            for (final sub in _subs) {
              sub.cancel();
            }
            widget.onClose();
          },
        ),
      ],
    );
  }

  Widget _buildModeSwitch() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SegmentedButton<AiPanelMode>(
        segments: const <ButtonSegment<AiPanelMode>>[
          ButtonSegment<AiPanelMode>(
            value: AiPanelMode.inspireIdeas,
            label: Text('桥段点子'),
          ),
          ButtonSegment<AiPanelMode>(
            value: AiPanelMode.inspireOpening,
            label: Text('开篇助手'),
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
                label: Text(RewriteIntent.label(intent)),
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
        decoration: const InputDecoration(
          hintText: '补充指令（可选），例如：让她的话更冷淡',
          isDense: true,
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildLengthRow() {
    if (_mode != AiPanelMode.continueWriting) return const SizedBox.shrink();
    return Row(
      children: <Widget>[
        Text('篇幅 ${_length.round()} 字',
            style: TextStyle(fontSize: 12, color: context.paper.inkSoft)),
        Expanded(
          child: Slider(
            value: _length,
            min: 300,
            max: 800,
            divisions: 10,
            activeColor: context.paper.accent,
            onChanged: _streaming
                ? null
                : (value) => setState(() => _length = (value / 50).round() * 50.0),
          ),
        ),
      ],
    );
  }

  /// 多候选续写（ENH-05）：开关「3 个候选」，开启后可切换查看 / 采纳某一路。
  Widget _buildCandidateControls() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          FilterChip(
            label: const Text('3 个候选'),
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
                  segments: const <ButtonSegment<int>>[
                    ButtonSegment<int>(value: 0, label: Text('版本 1')),
                    ButtonSegment<int>(value: 1, label: Text('版本 2')),
                    ButtonSegment<int>(value: 2, label: Text('版本 3')),
                  ],
                  selected: <int>{_selected},
                  onSelectionChanged: (selection) =>
                      setState(() => _selected = selection.first),
                ),
              ),
            ),
          ],
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
            'AI 看到的上下文（估算 ${built.estimatedTokens} / 预算 ${built.budgetTokens} token）',
            style: TextStyle(fontSize: 12, color: context.paper.inkSoft),
          ),
          subtitle: built.truncated
              ? Text('已省略较早前文',
                  style: TextStyle(fontSize: 11, color: context.paper.accent))
              : null,
          children: built.sections
              .map((section) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(section.label,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(section.content,
                            style: TextStyle(
                                fontSize: 12, color: context.paper.inkSoft)),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildResult() {
    return TextField(
      key: ValueKey<int>(_activeIndex),
      controller: _activeResult,
      minLines: 4,
      maxLines: 10,
      style: TextStyle(fontSize: 15, height: 1.6, color: context.paper.ink),
      decoration: InputDecoration(
        hintText: 'AI 产出将在这里流式显示，可直接编辑后再插入正文',
        fillColor: context.paper.background,
        contentPadding: const EdgeInsets.all(12),
      ),
    );
  }

  Widget _buildError() {
    final canGoSettings = _errorKind == AiErrorKind.auth || _errorKind == AiErrorKind.badRequest;
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
            child: Text(_activeError!,
                style: const TextStyle(fontSize: 12, color: Color(0xFFB3261E))),
          ),
          if (canGoSettings)
            TextButton(onPressed: _goSettings, child: const Text('去设置')),
        ],
      ),
    );
  }

  Widget _buildActions() {
    if (_needsConfig) {
      return Row(
        children: <Widget>[
          Expanded(
            child: Text('尚未配置可用的模型与 API Key',
                style: TextStyle(fontSize: 13, color: context.paper.inkSoft)),
          ),
          FilledButton(onPressed: _goSettings, child: const Text('去设置')),
        ],
      );
    }

    final hasText = _activeResult.text.trim().isNotEmpty;
    final isInspire = _mode == AiPanelMode.inspireIdeas ||
        _mode == AiPanelMode.inspireOpening;
    final isRewrite = _mode == AiPanelMode.rewrite;
    final isSummarize = _mode == AiPanelMode.summarize;
    final isOutlineExpand = _mode == AiPanelMode.outlineExpand;
    final isVolumeSummary = _mode == AiPanelMode.volumeSummary;
    // 主操作按钮：摘要 / 章纲扩写 / 卷回顾写回对应字段，改写替换原文，其余插入光标处。
    final String primaryLabel = isRewrite
        ? '替换原文'
        : isSummarize
            ? '保存摘要'
            : isOutlineExpand
                ? '保存到章纲'
                : isVolumeSummary
                    ? '保存前情回顾'
                    : '插入光标处';
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
            onPressed: () {
              for (final sub in _subs) {
                sub.cancel();
              }
              setState(() => _streaming = false);
            },
            child: const Text('停止'),
          )
        else ...<Widget>[
          TextButton(
            onPressed: () => _start(),
            child: const Text('重新生成'),
          ),
          // 改写用「补充指令」输入框替代方向弹窗（ENH-04）；
          // 摘要 / 章纲扩写 / 卷回顾目标明确，无需「换个方向」（ENH-05 / ENH-06）。
          if (!isRewrite && !isSummarize && !isOutlineExpand && !isVolumeSummary)
            TextButton(
              onPressed: _retryWithDirection,
              child: const Text('换个方向'),
            ),
        ],
        const Spacer(),
        if (isInspire)
          TextButton(
            onPressed: hasText && !_streaming ? _saveToInspiration : null,
            child: const Text('存入灵感箱'),
          ),
        TextButton(
          onPressed: _abandon,
          child: const Text('放弃'),
        ),
        const SizedBox(width: 4),
        FilledButton(
          onPressed: onPrimary,
          child: Text(primaryLabel),
        ),
      ],
    );
  }
}
