import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/ai/ai_client.dart';
import '../../core/ai/flavor_check.dart';
import '../../core/ai_flavor_rules.dart';
import '../../core/formatting.dart';
import '../../core/word_count.dart';
import '../../data/data_providers.dart';
import '../../data/db.dart';
import '../../data/repositories/settings_repository.dart';
import '../ai/ai_notice.dart';
import '../ai/ai_providers.dart';
import '../ai/ai_service.dart';
import '../work_detail/work_detail_providers.dart';
import 'editor_controller.dart';

/// AI 感检查面板（M4-08 ~ M4-13，PRD 5.7）。
///
/// 两种宿主：
/// - 编辑器内嵌（传 [controller]）：可就地高亮与一键替换（走编辑器撤销栈）；
/// - 作品详情底部弹出（不传）：只读展示与定位，修改在各章编辑器中完成。
class FlavorCheckPanel extends ConsumerStatefulWidget {
  const FlavorCheckPanel({
    super.key,
    required this.workId,
    required this.initialChapterId,
    required this.onClose,
    this.controller,
    this.heightFactor = 0.55,
  });

  final int workId;

  /// 默认检查范围：null = 整部作品，否则为指定章节。
  final int? initialChapterId;

  /// 编辑器内嵌时提供，用于就地定位与替换。
  final EditorController? controller;
  final VoidCallback onClose;

  /// 面板最大高度占屏高比例（作品详情弹层可更高）。
  final double heightFactor;

  @override
  ConsumerState<FlavorCheckPanel> createState() => _FlavorCheckPanelState();
}

class _FlavorCheckPanelState extends ConsumerState<FlavorCheckPanel> {
  /// 整部作品的哨兵值（DropdownButton 不支持 null 值项）。
  static const int _wholeWork = 0;

  StreamSubscription<CheckEvent>? _subscription;
  late final SettingsRepository _settingsRepo;

  int _scope = _wholeWork;
  CheckScope? _scopeInfo;
  FlavorMetrics? _metrics;
  List<FlavorIssue> _ruleIssues = <FlavorIssue>[];
  List<FlavorIssue> _deepIssues = <FlavorIssue>[];

  final Set<String> _seenKeys = <String>{};
  final Set<String> _typeFilter = <String>{};
  int _sessionHandled = 0;
  bool _statsPersisted = false;

  bool _deepRunning = false;
  int _deepDone = 0;
  int _deepTotal = 0;
  int? _estimatedTokens;
  int? _promptTokens;
  int? _completionTokens;
  String? _fallbackText;
  String? _error;
  AiErrorKind? _errorKind;
  bool _needsConfig = false;

  @override
  void initState() {
    super.initState();
    _settingsRepo = ref.read(settingsRepositoryProvider);
    _scope = widget.initialChapterId ?? _wholeWork;
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _persistStats();
    super.dispose();
  }

  /// 检查会话结束时写入处置率计数（ARCHITECTURE 4.2）。
  void _persistStats() {
    if (_statsPersisted) return;
    _statsPersisted = true;
    if (_seenKeys.isEmpty && _sessionHandled == 0) return;
    // 计数写入失败不影响使用（如页面销毁时数据库已关闭）。
    unawaited(_settingsRepo
        .addCheckStats(total: _seenKeys.length, handled: _sessionHandled)
        .catchError((Object _) {}));
  }

  List<FlavorIssue> get _merged =>
      mergeFlavorIssues(<FlavorIssue>[..._ruleIssues, ..._deepIssues]);

  bool get _scopeEmpty => _scopeInfo?.isEmpty ?? false;

  /// 能否就地替换：需在编辑器中且范围为该编辑器所在章节（M4-11）。
  bool get _canReplaceInPlace =>
      widget.controller != null && _scope == widget.controller!.chapterId;

  Future<void> _run({bool deep = false}) async {
    await _subscription?.cancel();
    if (!mounted) return;
    setState(() {
      _deepIssues = <FlavorIssue>[];
      _ruleIssues = <FlavorIssue>[];
      _metrics = null;
      _deepRunning = deep;
      _deepDone = 0;
      _deepTotal = 0;
      _estimatedTokens = null;
      _promptTokens = null;
      _completionTokens = null;
      _fallbackText = null;
      _error = null;
      _errorKind = null;
      _needsConfig = false;
      _typeFilter.clear();
    });

    final stream = ref.read(aiServiceProvider).checkFlavor(
          workId: widget.workId,
          chapterId: _scope == _wholeWork ? null : _scope,
          deep: deep,
        );
    _subscription = stream.listen(_onEvent, onDone: _onStreamDone);
  }

  /// LLM 深检联网，首次触发前先做告知确认（M4-16）。
  Future<void> _startDeep() async {
    if (!await ensureAiNotice(context, ref)) return;
    if (!mounted) return;
    await _run(deep: true);
  }

  void _onStreamDone() {
    if (!mounted) return;
    setState(() => _deepRunning = false);
  }

  void _onEvent(CheckEvent event) {
    if (!mounted) return;
    switch (event) {
      case CheckRuleResult():
        setState(() {
          _scopeInfo = event.scope;
          _ruleIssues = List<FlavorIssue>.of(event.result.issues);
          _metrics = event.result.metrics;
        });
        _rememberSeen();
      case CheckDeepStarted():
        setState(() {
          _deepRunning = true;
          _deepTotal = event.segments;
          _estimatedTokens = event.estimatedTokens;
        });
      case CheckDeepProgress():
        setState(() {
          _deepDone = event.done;
          _deepTotal = event.total;
        });
      case CheckDeepFinished():
        setState(() {
          _deepRunning = false;
          _deepIssues = List<FlavorIssue>.of(event.issues);
          _promptTokens = event.promptTokens;
          _completionTokens = event.completionTokens;
          _fallbackText = event.fallbackText;
        });
        _rememberSeen();
      case CheckDeepFailed():
        setState(() {
          _deepRunning = false;
          _error = event.message;
          _errorKind = event.kind;
        });
      case CheckNeedsConfig():
        setState(() {
          _deepRunning = false;
          _needsConfig = true;
        });
    }
  }

  void _rememberSeen() {
    for (final issue in _merged) {
      _seenKeys.add(_issueKey(issue));
    }
  }

  String _issueKey(FlavorIssue issue) => issue.isDocumentLevel
      ? '${issue.type}|${issue.message}'
      : '${issue.type}|${issue.start}|${issue.end}';

  FlavorIssue _withRange(FlavorIssue issue, int start, int end) => FlavorIssue(
        type: issue.type,
        severity: issue.severity,
        start: start,
        end: end,
        message: issue.message,
        excerpt: issue.excerpt,
        suggestion: issue.suggestion,
        replacement: issue.replacement,
        source: issue.source,
      );

  void _removeIssue(FlavorIssue issue) {
    final key = _issueKey(issue);
    _ruleIssues.removeWhere((i) => _issueKey(i) == key);
    _deepIssues.removeWhere((i) => _issueKey(i) == key);
  }

  /// 就地替换后同步其余问题的偏移（仅单章范围下精确）。
  void _shiftAfterReplace(int start, int end, int newLength) {
    final delta = newLength - (end - start);
    if (delta == 0) return;
    List<FlavorIssue> shift(List<FlavorIssue> list) {
      final out = <FlavorIssue>[];
      for (final issue in list) {
        if (issue.isDocumentLevel || issue.end <= start) {
          out.add(issue);
        } else if (issue.start >= end) {
          out.add(_withRange(issue, issue.start + delta, issue.end + delta));
        }
        // 与被替换区间重叠的问题已失效，直接丢弃。
      }
      return out;
    }

    _ruleIssues = shift(_ruleIssues);
    _deepIssues = shift(_deepIssues);
  }

  // ---------- 处置动作 ----------

  void _ignore(FlavorIssue issue) {
    setState(() {
      _removeIssue(issue);
      _sessionHandled++;
    });
  }

  void _ignoreType(String type) {
    final targets = _merged.where((i) => i.type == type).toList();
    if (targets.isEmpty) return;
    setState(() {
      for (final issue in targets) {
        _removeIssue(issue);
        _sessionHandled++;
      }
    });
  }

  void _replace(FlavorIssue issue) {
    final controller = widget.controller;
    final replacement = issue.replacement;
    if (controller == null || replacement == null) return;
    if (!_canReplaceInPlace) return;
    final text = controller.textController.text;
    if (issue.end > text.length || issue.start > issue.end) return;
    // 偏移漂移保护：原文已变化时不动，提示重新检查。
    if (issue.excerpt.isNotEmpty &&
        text.substring(issue.start, issue.end) != issue.excerpt) {
      _snack('原文已变化，请重新运行检查');
      return;
    }
    final start = issue.start;
    final end = issue.end;
    if (!controller.replaceRange(start, end, replacement)) return;
    setState(() {
      _removeIssue(issue);
      _sessionHandled++;
      _shiftAfterReplace(start, end, replacement.length);
    });
    _snack(replacement.isEmpty ? '已删除该词' : '已替换为「$replacement」');
  }

  void _locate(FlavorIssue issue) {
    final scope = _scopeInfo;
    if (scope == null || issue.isDocumentLevel) return;
    final target = scope.locate(issue.start);
    if (target == null) return;
    final length = issue.end - issue.start;
    final controller = widget.controller;
    if (controller != null && controller.chapterId == target.chapterId) {
      controller.revealRange(target.offsetInChapter, target.offsetInChapter + length);
      return;
    }
    context.push(
      '/work/${widget.workId}/chapter/${target.chapterId}'
      '?checkStart=${target.offsetInChapter}'
      '&checkEnd=${target.offsetInChapter + length}',
    );
  }

  void _goSettings() => context.push('/settings');

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _close() {
    _subscription?.cancel();
    _persistStats();
    widget.onClose();
  }

  // ---------- 构建 ----------

  @override
  Widget build(BuildContext context) {
    final merged = _merged;
    final visible = _typeFilter.isEmpty
        ? merged
        : merged.where((i) => _typeFilter.contains(i.type)).toList();
    final shown = visible.length > 100 ? visible.sublist(0, 100) : visible;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * widget.heightFactor,
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
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _buildHeader(merged.length),
                  _buildScopeRow(),
                  if (_metrics != null) _buildMetrics(_metrics!),
                  const SizedBox(height: 6),
                  _buildDeepRow(),
                  if (_estimatedTokens != null || _promptTokens != null)
                    _buildTokens(),
                  if (_needsConfig) _buildNeedsConfig(),
                  if (_error != null) _buildError(),
                  if (_fallbackText != null) _buildFallback(_fallbackText!),
                  if (merged.isNotEmpty) _buildFilterChips(merged),
                  const SizedBox(height: 4),
                  if (_scopeEmpty)
                    _buildEmptyHint()
                  else if (merged.isEmpty)
                    _buildCleanHint()
                  else ...<Widget>[
                    for (final issue in shown) _buildIssueCard(issue),
                    if (visible.length > shown.length)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          '仅显示前 ${shown.length} 条，共 ${visible.length} 条',
                          style: TextStyle(
                              fontSize: 12, color: context.paper.inkSoft),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int count) {
    return Row(
      children: <Widget>[
        Icon(Icons.spellcheck, size: 18, color: context.paper.accent),
        const SizedBox(width: 6),
        const Text('AI 感检查', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Text('$count 处',
            style: TextStyle(fontSize: 12, color: context.paper.inkSoft)),
        if (_deepRunning) ...<Widget>[
          const SizedBox(width: 8),
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.6),
          ),
          const SizedBox(width: 6),
          Text('深检 $_deepDone/$_deepTotal',
              style: TextStyle(fontSize: 12, color: context.paper.inkSoft)),
        ],
        const Spacer(),
        IconButton(
          tooltip: '收起',
          icon: const Icon(Icons.close, size: 20),
          onPressed: _close,
        ),
      ],
    );
  }

  Widget _buildScopeRow() {
    final chapters = ref.watch(chaptersProvider(widget.workId)).value ??
        const <Chapter>[];
    final ids = chapters.map((c) => c.id).toSet();
    final value = _scope == _wholeWork || ids.contains(_scope) ? _scope : _wholeWork;
    return Row(
      children: <Widget>[
        Text('范围', style: TextStyle(fontSize: 12, color: context.paper.inkSoft)),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButton<int>(
            isExpanded: true,
            value: value,
            underline: const SizedBox.shrink(),
            style: TextStyle(fontSize: 13, color: context.paper.ink),
            onChanged: _deepRunning
                ? null
                : (next) {
                    if (next == null || next == _scope) return;
                    setState(() => _scope = next);
                    _run();
                  },
            items: <DropdownMenuItem<int>>[
              const DropdownMenuItem<int>(
                value: _wholeWork,
                child: Text('整部作品'),
              ),
              for (var i = 0; i < chapters.length; i++)
                DropdownMenuItem<int>(
                  value: chapters[i].id,
                  child: Text(
                    '${chapters[i].title.isEmpty ? '未命名章节' : chapters[i].title}'
                    '（${formatWordCount(chapters[i].wordCount)}）',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
        Text(formatWordCount(_scopeInfo?.wordCount ?? 0),
            style: TextStyle(fontSize: 12, color: context.paper.inkSoft)),
      ],
    );
  }

  Widget _buildMetrics(FlavorMetrics metrics) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '套话 ${metrics.clicheHits} 处 · 密度 ${metrics.clicheDensity.toStringAsFixed(1)}/千字 · '
        '句式重复率 ${(metrics.patternRepeatRate * 100).toStringAsFixed(0)}% · '
        '破折号/省略号 ${metrics.ellipsisCount + metrics.dashCount} 处',
        style: TextStyle(fontSize: 11, color: context.paper.inkSoft),
      ),
    );
  }

  Widget _buildDeepRow() {
    final canRun = !_deepRunning && !_scopeEmpty;
    return Row(
      children: <Widget>[
        FilledButton.icon(
          onPressed: canRun ? _startDeep : null,
          icon: const Icon(Icons.auto_awesome, size: 16),
          label: Text(_deepRunning ? '深检中…' : 'LLM 深检'),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: _deepRunning ? null : () => _run(),
          child: const Text('重新检查'),
        ),
        const Spacer(),
        if (!_scopeEmpty && !_canReplaceInPlace && widget.controller == null)
          Text('修改请在编辑器中完成',
              style: TextStyle(fontSize: 11, color: context.paper.inkSoft)),
      ],
    );
  }

  Widget _buildTokens() {
    final parts = <String>[];
    if (_estimatedTokens != null) {
      parts.add('预估 ~${formatTokenCount(_estimatedTokens!)} token');
    }
    if (_promptTokens != null && _completionTokens != null) {
      parts.add('实测 输入 ${formatTokenCount(_promptTokens!)} + '
          '输出 ${formatTokenCount(_completionTokens!)}');
    }
    return Text(
      parts.join(' · '),
      style: TextStyle(fontSize: 11, color: context.paper.inkSoft),
    );
  }

  Widget _buildNeedsConfig() {
    return _banner(
      icon: Icons.key_outlined,
      message: '尚未配置 AI 感检查所用的模型，深检不可用。',
      actionLabel: '去设置',
      onAction: _goSettings,
    );
  }

  Widget _buildError() {
    final canGoSettings =
        _errorKind == AiErrorKind.auth || _errorKind == AiErrorKind.badRequest;
    return _banner(
      icon: Icons.error_outline,
      message: '深检失败（已保留规则结果）：$_error',
      actionLabel: canGoSettings ? '去设置' : '重试深检',
      onAction: canGoSettings ? _goSettings : _startDeep,
    );
  }

  Widget _banner({
    required IconData icon,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    const color = Color(0xFFB3261E);
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(message,
                  style: const TextStyle(fontSize: 12, color: color)),
            ),
          ),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }

  Widget _buildFallback(String text) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.paper.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('模型未返回结构化结果，原文如下：',
              style: TextStyle(fontSize: 12, color: context.paper.accent)),
          const SizedBox(height: 4),
          Text(text,
              style: TextStyle(fontSize: 12, color: context.paper.inkSoft)),
        ],
      ),
    );
  }

  Widget _buildFilterChips(List<FlavorIssue> merged) {
    final counts = <String, int>{};
    for (final issue in merged) {
      counts.update(issue.type, (v) => v + 1, ifAbsent: () => 1);
    }
    final types = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return Wrap(
      spacing: 6,
      runSpacing: -6,
      children: <Widget>[
        FilterChip(
          label: const Text('全部'),
          selected: _typeFilter.isEmpty,
          onSelected: (_) => setState(_typeFilter.clear),
        ),
        for (final type in types)
          FilterChip(
            label: Text('$type ${counts[type]}'),
            selected: _typeFilter.contains(type),
            onSelected: (selected) => setState(() {
              if (selected) {
                _typeFilter.add(type);
              } else {
                _typeFilter.remove(type);
              }
            }),
          ),
      ],
    );
  }

  Widget _buildEmptyHint() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Text('该范围没有正文，无可检查内容',
          style: TextStyle(fontSize: 13, color: context.paper.inkSoft)),
    );
  }

  Widget _buildCleanHint() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Text('未发现明显的 AI 味问题',
          style: TextStyle(fontSize: 13, color: context.paper.inkSoft)),
    );
  }

  Widget _buildIssueCard(FlavorIssue issue) {
    final canReplace = _canReplaceInPlace && issue.replacement != null;
    final canLocate = !issue.isDocumentLevel;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 4),
      decoration: BoxDecoration(
        color: context.paper.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _severityDot(issue.severity),
              const SizedBox(width: 6),
              Text(FlavorSeverity.label(issue.severity),
                  style: TextStyle(
                      fontSize: 11, color: _severityColor(issue.severity))),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${issue.type}${issue.source == FlavorSource.llm ? ' · 深检' : ''}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.paper.ink),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '更多',
                icon: const Icon(Icons.more_horiz, size: 18),
                onSelected: (value) {
                  switch (value) {
                    case 'locate':
                      _locate(issue);
                    case 'replace':
                      _replace(issue);
                    case 'ignore':
                      _ignore(issue);
                    case 'ignoreType':
                      _ignoreType(issue.type);
                  }
                },
                itemBuilder: (context) => <PopupMenuEntry<String>>[
                  if (canLocate)
                    const PopupMenuItem<String>(
                        value: 'locate', child: Text('定位到原文')),
                  if (canReplace)
                    PopupMenuItem<String>(
                      value: 'replace',
                      child: Text(issue.replacement!.isEmpty
                          ? '一键删除该词'
                          : '一键替换为「${issue.replacement}」'),
                    ),
                  const PopupMenuItem<String>(
                      value: 'ignore', child: Text('忽略这条')),
                  PopupMenuItem<String>(
                    value: 'ignoreType',
                    child: Text('忽略全部「${issue.type}」'),
                  ),
                ],
              ),
            ],
          ),
          if (issue.excerpt.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 2, right: 8),
              child: Text('原文：${issue.excerpt}',
                  style: TextStyle(fontSize: 12, color: context.paper.ink)),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 2, right: 8, top: 2),
            child: Text(issue.message,
                style: TextStyle(fontSize: 12, color: context.paper.inkSoft)),
          ),
          if (issue.suggestion != null)
            Padding(
              padding: const EdgeInsets.only(left: 2, right: 8, top: 2),
              child: Text('建议：${issue.suggestion}',
                  style: TextStyle(fontSize: 12, color: context.paper.accent)),
            ),
          Row(
            children: <Widget>[
              if (canLocate)
                TextButton(
                  onPressed: () => _locate(issue),
                  child: const Text('定位'),
                ),
              if (canReplace)
                TextButton(
                  onPressed: () => _replace(issue),
                  child: Text(issue.replacement!.isEmpty ? '删除' : '替换'),
                ),
              const Spacer(),
              TextButton(
                onPressed: () => _ignore(issue),
                child: const Text('忽略'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _severityDot(int severity) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: _severityColor(severity),
        shape: BoxShape.circle,
      ),
    );
  }

  Color _severityColor(int severity) {
    if (severity >= FlavorSeverity.high) return const Color(0xFFB3261E);
    if (severity == FlavorSeverity.medium) return context.paper.accent;
    return context.paper.inkSoft;
  }
}