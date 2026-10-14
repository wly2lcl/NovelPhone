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

/// 面板模式：续写 / 桥段点子 / 开篇助手 / 改写。
enum AiPanelMode { continueWriting, inspireIdeas, inspireOpening, rewrite }

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
  });

  final int workId;
  final int chapterId;
  final AiPanelMode initialMode;

  /// 插入到编辑器光标处（走编辑器撤销栈）。
  final void Function(String text) onInsert;

  /// 改写模式（ENH-04）：待改写原文与「替换原文」回调（走编辑器撤销栈）。
  final String? rewriteText;
  final void Function(String text)? onReplace;

  final VoidCallback onClose;

  @override
  ConsumerState<AiConfirmPanel> createState() => _AiConfirmPanelState();
}

class _AiConfirmPanelState extends ConsumerState<AiConfirmPanel> {
  final TextEditingController _result = TextEditingController();

  late AiPanelMode _mode = widget.initialMode;
  StreamSubscription<AiEvent>? _subscription;

  bool _streaming = false;
  String? _error;
  AiErrorKind? _errorKind;
  bool _needsConfig = false;
  BuiltContext? _context;
  bool _contextExpanded = false;
  int? _usageId;

  double _length = 500;
  String _lastDirection = '';

  /// 改写模式（ENH-04）：意图与作者补充指令。
  String _intent = RewriteIntent.polish;
  String _instruction = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _result.dispose();
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
    }
  }

  Future<void> _start({String? direction}) async {
    await _subscription?.cancel();
    if (!mounted) return;
    setState(() {
      _streaming = true;
      _error = null;
      _errorKind = null;
      _needsConfig = false;
      _context = null;
      _usageId = null;
      _result.text = '';
      if (direction != null) _lastDirection = direction;
    });

    final service = ref.read(aiServiceProvider);
    final Stream<AiEvent> stream;
    switch (_mode) {
      case AiPanelMode.continueWriting:
        stream = service.continueWriting(
          workId: widget.workId,
          chapterId: widget.chapterId,
          direction: _lastDirection.isEmpty ? null : _lastDirection,
          length: _length.round(),
        );
      case AiPanelMode.inspireIdeas:
      case AiPanelMode.inspireOpening:
        stream = service.inspire(
          workId: widget.workId,
          mode: _mode == AiPanelMode.inspireOpening
              ? InspireMode.opening
              : InspireMode.ideas,
          anchorChapterId: widget.chapterId,
          direction: _lastDirection.isEmpty ? null : _lastDirection,
        );
      case AiPanelMode.rewrite:
        stream = service.rewrite(
          workId: widget.workId,
          chapterId: widget.chapterId,
          selectedText: widget.rewriteText ?? '',
          intent: _intent,
          instruction: _instruction.isEmpty ? null : _instruction,
        );
    }

    _subscription = stream.listen(_onEvent);
  }

  void _onEvent(AiEvent event) {
    if (!mounted) return;
    switch (event) {
      case AiContextBuilt():
        setState(() => _context = event.context);
      case AiTextChunk():
        setState(() => _result.text = _result.text + event.text);
      case AiFinished():
        setState(() {
          _streaming = false;
          _usageId = event.usageId < 0 ? null : event.usageId;
        });
      case AiFailed():
        setState(() {
          _streaming = false;
          _error = event.message;
          _errorKind = event.kind;
        });
      case AiNeedsConfig():
        setState(() {
          _streaming = false;
          _needsConfig = true;
        });
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
    if (_usageId != null) {
      await ref.read(aiServiceProvider).markOutcome(_usageId!, 'regenerated');
    }
    await _start(direction: direction);
  }

  Future<void> _abandon() async {
    if (_usageId != null) {
      await ref.read(aiServiceProvider).markOutcome(_usageId!, 'ignored');
    }
    widget.onClose();
  }

  Future<void> _insert() async {
    final text = _result.text.trim();
    if (text.isEmpty) return;
    widget.onInsert(text);
    if (_usageId != null) {
      await ref
          .read(aiServiceProvider)
          .markOutcome(_usageId!, 'adopted', adoptedChars: text.length);
    }
    widget.onClose();
  }

  /// 改写模式（ENH-04）：把 AI 改写结果替换回原文选中区间（走编辑器撤销栈）。
  Future<void> _replace() async {
    final text = _result.text.trim();
    if (text.isEmpty) return;
    final replace = widget.onReplace;
    if (replace == null) return;
    replace(text);
    if (_usageId != null) {
      await ref
          .read(aiServiceProvider)
          .markOutcome(_usageId!, 'adopted', adoptedChars: text.length);
    }
    widget.onClose();
  }

  Future<void> _saveToInspiration() async {
    final text = _result.text.trim();
    if (text.isEmpty) return;
    await ref
        .read(inspirationRepositoryProvider)
        .createInspiration(widget.workId, text);
    if (_usageId != null) {
      await ref
          .read(aiServiceProvider)
          .markOutcome(_usageId!, 'adopted', adoptedChars: text.length);
    }
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
                  if (isRewrite) _buildInstructionField(),
                  if (_context != null) _buildContextDetails(_context!),
                  const SizedBox(height: 6),
                  _buildResult(),
                  if (_error != null) _buildError(),
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
            _subscription?.cancel();
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
      controller: _result,
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
            child: Text(_error!,
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

    final hasText = _result.text.trim().isNotEmpty;
    final isInspire = _mode == AiPanelMode.inspireIdeas ||
        _mode == AiPanelMode.inspireOpening;
    final isRewrite = _mode == AiPanelMode.rewrite;
    return Row(
      children: <Widget>[
        if (_streaming)
          OutlinedButton(
            onPressed: () {
              _subscription?.cancel();
              setState(() => _streaming = false);
            },
            child: const Text('停止'),
          )
        else ...<Widget>[
          TextButton(
            onPressed: () => _start(),
            child: const Text('重新生成'),
          ),
          // 改写用「补充指令」输入框替代方向弹窗（ENH-04）。
          if (!isRewrite)
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
          onPressed: hasText && !_streaming
              ? (isRewrite ? _replace : _insert)
              : null,
          child: Text(isRewrite ? '替换原文' : '插入光标处'),
        ),
      ],
    );
  }
}
