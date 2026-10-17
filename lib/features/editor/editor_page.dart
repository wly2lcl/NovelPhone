import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/reading_appearance.dart';
import '../../app/summary_editor.dart';
import '../../app/theme.dart';
import '../../core/formatting.dart';
import '../../core/word_count.dart';
import '../../data/data_providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../../l10n/error_text.dart';
import '../../l10n/l10n.dart';
import '../ai/ai_notice.dart';
import '../ai/ai_providers.dart';
import '../ai/ai_service.dart';
import '../work_detail/work_detail_providers.dart';
import 'ai_confirm_panel.dart';
import 'editor_controller.dart';
import 'find_replace_panel.dart';
import 'flavor_check_panel.dart';
import 'snapshot_panel.dart';

/// AI 章节工具菜单项（ENH-06）：面板模式 + 非面板动作（查看/编辑摘要）。
enum _ChapterTool {
  summarize,
  volumeSummary,
  outlineExpand,
  consistency,
  editSummary,
}

/// 编辑器（PRD 5.3）：正文编辑区 + 顶栏（标题 / 保存状态）+ 底部工具栏 + 状态栏。
class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({
    super.key,
    required this.workId,
    required this.chapterId,
    this.checkStart,
    this.checkEnd,
  });

  final int workId;
  final int chapterId;

  /// AI 感检查定位（M4-10）：跨章跳转时高亮的区间。
  final int? checkStart;
  final int? checkEnd;

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  late final EditorController _controller;
  bool _findVisible = false;
  AiPanelMode? _aiMode;
  bool _checkVisible = false;
  bool _snapshotsVisible = false;

  /// 专注模式（ENH-04）：隐藏工具栏与状态栏，并把光标行固定在编辑区竖直中线。
  bool _focusMode = false;

  /// 改写快照（ENH-04）：点击「AI 改写」那一刻的选区。
  /// 面板打开或弹窗都会令正文失焦、改写 selection，唯一可信来源是当场快照。
  int? _rewriteStart;
  int? _rewriteEnd;
  String _rewriteText = '';

  /// 章纲扩写种子（ENH-05）：本章一句话梗概，作为 AI 扩写分场大纲的输入。
  String? _outlineSeed;

  /// 用于从正文 TextField 取出唯一 RenderEditable，做光标居中滚动。
  final GlobalKey _textFieldKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = EditorController(
      repository: ref.read(chapterRepositoryProvider),
      workId: widget.workId,
      chapterId: widget.chapterId,
    );
    _controller.load().then((_) {
      if (!mounted) return;
      // load() 完成后正文区需重建，否则会一直停留在加载指示器上。
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final start = widget.checkStart;
        if (start != null) {
          _controller.revealRange(start, widget.checkEnd ?? start);
        } else {
          _restoreScroll();
        }
      });
    });
    // 光标居中滚动只在专注模式下生效（监听时刻可能早于 load 完成）。
    _controller.textController.addListener(_onCaretChanged);
  }

  @override
  void dispose() {
    // 离开编辑器的最后一次落库（含光标与滚动位置，供会话恢复）。
    _controller.textController.removeListener(_onCaretChanged);
    _controller.flush();
    _controller.dispose();
    super.dispose();
  }

  /// 光标（或选区）变化时，专注模式下把光标行滚到编辑区竖直中线。
  void _onCaretChanged() {
    if (!_focusMode || !_controller.loaded) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _pinCaretToCenter());
  }

  /// 让光标行底边对齐编辑区（TextField 视口）底边；章末也能居中。
  void _pinCaretToCenter() {
    if (!mounted || !_focusMode) return;
    final scrollController = _controller.scrollController;
    if (!scrollController.hasClients) return;
    final renderEditable = _findRenderEditable();
    if (renderEditable == null) return;
    final offset = _controller.textController.selection.baseOffset;
    if (offset < 0) return;
    // getLocalRectForCaret 返回的已是视口局部坐标（已扣除当前滚动量）。
    final rect = renderEditable.getLocalRectForCaret(
      TextPosition(offset: offset),
    );
    final position = scrollController.position;
    final target =
        (scrollController.offset + rect.bottom - renderEditable.size.height)
            .clamp(0.0, position.maxScrollExtent);
    if ((target - scrollController.offset).abs() <= 0.5) return;
    scrollController.jumpTo(target);
  }

  RenderEditable? _findRenderEditable() {
    final renderObject = _textFieldKey.currentContext?.findRenderObject();
    if (renderObject == null) return null;
    RenderEditable? found;
    void visit(RenderObject child) {
      if (found != null) return;
      if (child is RenderEditable) {
        found = child;
        return;
      }
      child.visitChildren(visit);
    }

    visit(renderObject);
    return found;
  }

  void _restoreScroll() {
    final scrollController = _controller.scrollController;
    if (!scrollController.hasClients) return;
    final target = _controller.initialScrollOffset.toDouble();
    if (target > 0) {
      scrollController.jumpTo(
        target.clamp(0.0, scrollController.position.maxScrollExtent).toDouble(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // B-04：写作外观（夜间纸张 / 字号 / 行距），未加载完先用默认纸质外观。
    final appearance =
        ref.watch(readingAppearanceProvider).value ?? const ReadingAppearance();
    // 全局深色时写作区自动跟随（优先级高于写作外观自身开关）。
    final globalDark = Theme.of(context).brightness == Brightness.dark;
    final palette = ReadingPalette.of(appearance, globalDark: globalDark);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        foregroundColor: palette.ink,
        titleSpacing: 0,
        title: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => InkWell(
            onTap: _renameChapter,
            child: Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    _controller.title.isEmpty
                        ? context.l10n.commonUntitledChapter
                        : _controller.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.edit_outlined, size: 15),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: context.l10n.snapshotHistoryTitle,
            icon: const Icon(Icons.history),
            onPressed: () => setState(() {
              _findVisible = false;
              _checkVisible = false;
              _aiMode = null;
              _snapshotsVisible = !_snapshotsVisible;
            }),
          ),
          IconButton(
            tooltip: context.l10n.editorChapterSummaryTooltip,
            icon: const Icon(Icons.list_alt),
            onPressed: _editChapterSummary,
          ),
          // AI 章节工具（ENH-05 / ENH-06）：逐章摘要、卷前情回顾、章纲扩写、查看/编辑摘要。
          PopupMenuButton<_ChapterTool>(
            tooltip: context.l10n.editorAiToolsTooltip,
            icon: const Icon(Icons.auto_awesome),
            onSelected: _onChapterTool,
            itemBuilder: (context) => <PopupMenuEntry<_ChapterTool>>[
              PopupMenuItem<_ChapterTool>(
                value: _ChapterTool.summarize,
                child: Text(context.l10n.editorToolSummarize),
              ),
              PopupMenuItem<_ChapterTool>(
                value: _ChapterTool.volumeSummary,
                child: Text(context.l10n.editorToolVolumeSummary),
              ),
              PopupMenuItem<_ChapterTool>(
                value: _ChapterTool.outlineExpand,
                child: Text(context.l10n.editorToolOutlineExpand),
              ),
              PopupMenuItem<_ChapterTool>(
                value: _ChapterTool.consistency,
                child: Text(context.l10n.editorToolContinuity),
              ),
              PopupMenuItem<_ChapterTool>(
                value: _ChapterTool.editSummary,
                child: Text(context.l10n.editorToolEditSummary),
              ),
            ],
          ),
          // 专注模式唯一开关（ENH-04）：专注下工具栏与状态栏隐藏，必须常驻可退出。
          IconButton(
            tooltip: _focusMode
                ? context.l10n.editorExitFocusMode
                : context.l10n.editorFocusMode,
            icon: Icon(
              _focusMode ? Icons.fullscreen_exit : Icons.center_focus_strong,
            ),
            onPressed: () => setState(() => _focusMode = !_focusMode),
          ),
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => _SaveIndicator(
              status: _controller.saveStatus,
              onRetry: _controller.retrySave,
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(child: _buildEditorBody(appearance)),
          if (_findVisible)
            FindReplacePanel(
              controller: _controller,
              onClose: () => setState(() => _findVisible = false),
            ),
          if (_aiMode != null)
            AiConfirmPanel(
              workId: widget.workId,
              chapterId: widget.chapterId,
              initialMode: _aiMode!,
              onInsert: _controller.insertAtCursor,
              rewriteText: _rewriteText,
              onReplace: _applyRewrite,
              outlineSeed: _outlineSeed,
              onSaveSummary: _saveSummary,
              onSaveOutline: _saveOutline,
              onSaveVolumeSummary: _saveVolumeSummary,
              onClose: () => setState(() {
                _aiMode = null;
                _rewriteStart = null;
                _rewriteEnd = null;
                _rewriteText = '';
                _outlineSeed = null;
              }),
            ),
          if (_checkVisible)
            FlavorCheckPanel(
              workId: widget.workId,
              initialChapterId: widget.chapterId,
              controller: _controller,
              onClose: () => setState(() => _checkVisible = false),
            ),
          if (_snapshotsVisible)
            SnapshotPanel(
              controller: _controller,
              chapterId: widget.chapterId,
              onClose: () => setState(() => _snapshotsVisible = false),
            ),
          if (!_focusMode)
            _Toolbar(
              controller: _controller,
              palette: palette,
              onFind: () => setState(() {
                _checkVisible = false;
                _snapshotsVisible = false;
                _findVisible = !_findVisible;
              }),
              onAiFeature: _openAi,
              onCheck: () => setState(() {
                _findVisible = false;
                _aiMode = null;
                _snapshotsVisible = false;
                _checkVisible = !_checkVisible;
              }),
            ),
          if (!_focusMode)
            _StatusBar(
              controller: _controller,
              workId: widget.workId,
              palette: palette,
            ),
        ],
      ),
    );
  }

  Widget _buildEditorBody(ReadingAppearance appearance) {
    if (!_controller.loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    final globalDark = Theme.of(context).brightness == Brightness.dark;
    final palette = ReadingPalette.of(appearance, globalDark: globalDark);
    return Container(
      color: palette.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 专注模式（ENH-04）：底部留白取编辑区一半高度，
          // 扩大可滚动量，使光标行（含章末）能滚到编辑区竖直中线。
          final bottomPadding = _focusMode ? constraints.maxHeight / 2 : 24.0;
          return TextField(
            key: _textFieldKey,
            controller: _controller.textController,
            scrollController: _controller.scrollController,
            focusNode: _controller.focusNode,
            maxLines: null,
            expands: true,
            autofocus: false,
            keyboardType: TextInputType.multiline,
            textAlignVertical: TextAlignVertical.top,
            style: TextStyle(
              fontFamily: kSerifFontFamily,
              fontFamilyFallback: kSerifFontFallback,
              fontSize: appearance.fontSize,
              height: appearance.lineHeight,
              color: palette.ink,
            ),
            decoration: InputDecoration(
              hintText: context.l10n.editorBodyHint,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
            ),
          );
        },
      ),
    );
  }

  Future<void> _renameChapter() async {
    // 不使用外部 TextEditingController：弹窗退场动画期间 builder 会再次执行，
    // 过早 dispose 会导致「controller used after being disposed」。
    var text = _controller.title;
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.editorChapterTitleDialog),
        content: TextFormField(
          initialValue: _controller.title,
          autofocus: true,
          maxLength: 50,
          onChanged: (value) => text = value,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(text.trim()),
            child: Text(context.l10n.commonSave),
          ),
        ],
      ),
    );
    if (title == null || title.length > 50) return;
    await _controller.renameChapter(title);
  }

  /// AI 章节工具菜单分发（ENH-06）：前三项开面板，末项直接编辑本章摘要。
  Future<void> _onChapterTool(_ChapterTool tool) async {
    switch (tool) {
      case _ChapterTool.summarize:
        await _openAi(AiPanelMode.summarize);
      case _ChapterTool.volumeSummary:
        await _openAi(AiPanelMode.volumeSummary);
      case _ChapterTool.outlineExpand:
        await _openAi(AiPanelMode.outlineExpand);
      case _ChapterTool.consistency:
        await _checkContinuity();
      case _ChapterTool.editSummary:
        await _editAiSummary();
    }
  }

  /// 打开 AI 待确认面板（PRD 5.5）：未配置可用模型组时先引导至设置页。
  Future<void> _openAi(AiPanelMode mode) async {
    // 改写需在点击那一刻同步快照选区（任何 await 之前，否则 selection 会被改写）。
    if (mode == AiPanelMode.rewrite && !_snapshotRewriteSelection()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.editorSelectRewriteText)),
      );
      return;
    }
    // 章纲扩写（ENH-05）：以本章一句话梗概为种子，未填写则先引导作者补写。
    if (mode == AiPanelMode.outlineExpand) {
      final existing = await ref
          .read(outlineRepositoryProvider)
          .findByChapter(widget.chapterId);
      if (!mounted) return;
      final seed = existing?.summary.trim() ?? '';
      if (seed.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.editorNeedOutlineSeed)),
        );
        return;
      }
      _outlineSeed = seed;
    }
    // 本卷前情回顾（ENH-06）：本卷当前章之前需有已写章节，否则无以归并。
    if (mode == AiPanelMode.volumeSummary) {
      final chapter = await ref
          .read(chapterRepositoryProvider)
          .getChapter(widget.chapterId);
      // ENH-13：只需章节元数据判断是否写有内容，避免为前置校验读整部作品正文。
      final metas = await ref
          .read(chapterRepositoryProvider)
          .watchChapterMetas(widget.workId)
          .first;
      if (!mounted) return;
      final index = metas.indexWhere((c) => c.id == widget.chapterId);
      final hasEarlier =
          index > 0 &&
          metas
              .take(index)
              .any(
                (c) =>
                    c.volumeId == chapter?.volumeId &&
                    (c.wordCount > 0 || c.summary.trim().isNotEmpty),
              );
      if (!hasEarlier) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.editorNoEarlierChapters)),
        );
        return;
      }
    }
    final task = switch (mode) {
      AiPanelMode.continueWriting => AiTask.continueWriting,
      AiPanelMode.inspireIdeas || AiPanelMode.inspireOpening => AiTask.inspire,
      AiPanelMode.rewrite => AiTask.rewrite,
      AiPanelMode.summarize => AiTask.summary,
      AiPanelMode.outlineExpand => AiTask.outlineExpand,
      AiPanelMode.volumeSummary => AiTask.volumeSummary,
    };
    final ready = await ref.read(aiServiceProvider).isReady(task);
    if (!mounted) return;
    if (!ready) {
      await _promptModelSetup();
      return;
    }
    // 首次联网前的告知（M4-16）。
    if (!await ensureAiNotice(context, ref)) return;
    if (!mounted) return;
    setState(() {
      _findVisible = false;
      _checkVisible = false;
      _snapshotsVisible = false;
      _aiMode = mode;
    });
  }

  /// 未配置可用模型组时引导至设置页（AI 面板与设定检查共用）。
  Future<void> _promptModelSetup() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.editorNoModelTitle),
        content: Text(context.l10n.editorNoModelBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.editorLater),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.editorGoSettings),
          ),
        ],
      ),
    );
    if (go == true && mounted) context.push('/settings');
  }

  /// 设定一致性检查（ENH-22）：一次性调用，结果以报告对话框展示。
  Future<void> _checkContinuity() async {
    if (_controller.textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.editorContinuityEmpty)),
      );
      return;
    }
    final service = ref.read(aiServiceProvider);
    final ready = await service.isReady(AiTask.continuity);
    if (!mounted) return;
    if (!ready) {
      await _promptModelSetup();
      return;
    }
    if (!await ensureAiNotice(context, ref)) return;
    if (!mounted) return;

    BuildContext? progressContext;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          progressContext = dialogContext;
          return AlertDialog(
            content: Row(
              children: <Widget>[
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 16),
                Expanded(child: Text(context.l10n.editorContinuityRunning)),
              ],
            ),
          );
        },
      ),
    );

    void closeProgress() {
      if (progressContext?.mounted ?? false) {
        Navigator.of(progressContext!).pop();
      }
    }

    try {
      final report = await service.checkContinuity(
        workId: widget.workId,
        chapterId: widget.chapterId,
      );
      closeProgress();
      if (!mounted) return;
      if (report.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.editorContinuityEmptyResult)),
        );
        return;
      }
      await _showContinuityReport(report);
    } on ContinuityNeedsConfig {
      closeProgress();
      if (!mounted) return;
      await _promptModelSetup();
    } on ContinuityException catch (error) {
      closeProgress();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.l10n.editorContinuityTitle),
          content: SelectableText(
            aiFailureText(
              context.l10n,
              kind: error.kind,
              message: error.message,
              statusCode: error.statusCode,
              code: error.code,
              detail: error.detail,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.l10n.commonClose),
            ),
          ],
        ),
      );
    } catch (error) {
      closeProgress();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _showContinuityReport(ContinuityReport report) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.editorContinuityTitle),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (report.truncated) ...<Widget>[
                  Text(
                    context.l10n.editorContinuityTruncated,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.paper.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SelectableText(report.text),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.commonClose),
          ),
        ],
      ),
    );
  }

  /// 同步快照当前选区（ENH-04）：返回是否选中了非空白文本。
  bool _snapshotRewriteSelection() {
    final selection = _controller.textController.selection;
    final start = selection.start;
    final end = selection.end;
    final text = _controller.textController.text;
    if (start < 0 || end <= start || end > text.length) return false;
    final selected = text.substring(start, end);
    if (selected.trim().isEmpty) return false;
    _rewriteStart = start;
    _rewriteEnd = end;
    _rewriteText = selected;
    return true;
  }

  /// 把改写结果替换回原文区间（ENH-04）：原文漂移则拒绝；仅成功才抢回焦点。
  void _applyRewrite(String text) {
    final start = _rewriteStart;
    final end = _rewriteEnd;
    if (start == null || end == null) return;
    final ok = _controller.replaceSelection(
      start: start,
      end: end,
      original: _rewriteText,
      replacement: text,
    );
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.editorOriginalChanged)),
      );
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.focusNode.requestFocus();
    });
  }

  /// 逐章摘要（ENH-05）：把 AI 摘要写回 CHAPTER.summary，供后续章节续写时注入前情。
  Future<void> _saveSummary(String text) async {
    await ref
        .read(chapterRepositoryProvider)
        .saveChapterSummary(widget.chapterId, sanitizeAiText(text).trim());
  }

  /// 本卷前情回顾（ENH-06）：把 AI 回顾写回 VOLUME.summary，供后续章节续写注入。
  /// 同时记录本次归并覆盖到的章节（ENH-07 O6 增量归并）。
  Future<void> _saveVolumeSummary(String text) async {
    final chapter = await ref
        .read(chapterRepositoryProvider)
        .getChapter(widget.chapterId);
    if (chapter == null) return;
    await ref
        .read(chapterRepositoryProvider)
        .saveVolumeSummary(
          chapter.volumeId,
          sanitizeAiText(text).trim(),
          coveredChapterId: widget.chapterId,
        );
  }

  /// 章纲扩写（ENH-05）：把 AI 分场大纲覆盖写入本章章纲。
  Future<void> _saveOutline(String text) async {
    final chapter = await ref
        .read(chapterRepositoryProvider)
        .getChapter(widget.chapterId);
    await ref
        .read(outlineRepositoryProvider)
        .saveChapterSummary(
          workId: widget.workId,
          chapterId: widget.chapterId,
          volumeId: chapter?.volumeId,
          summary: sanitizeAiText(text).trim(),
        );
  }

  /// 查看 / 编辑本章 AI 摘要（ENH-06）：弹窗读写 CHAPTER.summary。
  Future<void> _editAiSummary() async {
    final chapter = await ref
        .read(chapterRepositoryProvider)
        .getChapter(widget.chapterId);
    if (!mounted) return;
    final summary = chapter?.summary ?? '';
    // ENH-07 O4：摘要生成后正文又有改动时，提示摘要可能过期。
    final summaryUpdatedAt = chapter?.summaryUpdatedAt;
    final stale =
        summary.trim().isNotEmpty &&
        (summaryUpdatedAt == null ||
            (chapter?.updatedAt.isAfter(summaryUpdatedAt) ?? false));
    await showSummaryEditor(
      context,
      initial: summary,
      title: context.l10n.editorSummaryTitle,
      hintText: context.l10n.editorSummaryHint,
      notice: stale ? context.l10n.editorSummaryStale : null,
      onSave: (text) => ref
          .read(chapterRepositoryProvider)
          .saveChapterSummary(widget.chapterId, text),
    );
  }

  /// 编辑器侧栏入口：直接编辑本章梗概（PRD 5.4 双入口之一）。
  Future<void> _editChapterSummary() async {
    final repository = ref.read(outlineRepositoryProvider);
    final chapter = await ref
        .read(chapterRepositoryProvider)
        .getChapter(widget.chapterId);
    final existing = await repository.findByChapter(widget.chapterId);
    if (!mounted) return;
    await showSummaryEditor(
      context,
      initial: existing?.summary ?? '',
      onSave: (text) => repository.saveChapterSummary(
        workId: widget.workId,
        chapterId: widget.chapterId,
        volumeId: chapter?.volumeId,
        summary: text,
      ),
    );
  }
}

class _SaveIndicator extends StatelessWidget {
  const _SaveIndicator({required this.status, required this.onRetry});

  final SaveStatus status;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case SaveStatus.saving:
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.6),
              ),
              SizedBox(width: 8),
              Text(
                context.l10n.editorSaving,
                style: TextStyle(fontSize: 13, color: context.paper.inkSoft),
              ),
            ],
          ),
        );
      case SaveStatus.saved:
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.cloud_done_outlined,
                size: 15,
                color: context.paper.inkSoft,
              ),
              SizedBox(width: 6),
              Text(
                context.l10n.editorSaved,
                style: TextStyle(fontSize: 13, color: context.paper.inkSoft),
              ),
            ],
          ),
        );
      case SaveStatus.failed:
        return TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(
            Icons.error_outline,
            size: 16,
            color: Color(0xFFB3261E),
          ),
          label: Text(
            context.l10n.editorSaveFailed,
            style: const TextStyle(color: Color(0xFFB3261E), fontSize: 13),
          ),
        );
    }
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.controller,
    required this.palette,
    required this.onFind,
    required this.onAiFeature,
    required this.onCheck,
  });

  final EditorController controller;
  final ReadingPalette palette;
  final VoidCallback onFind;
  final void Function(AiPanelMode mode) onAiFeature;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Container(
        decoration: BoxDecoration(
          color: palette.background,
          border: Border(top: BorderSide(color: palette.divider)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: <Widget>[
              _ToolButton(
                icon: Icons.auto_awesome,
                label: context.l10n.editorAiContinue,
                palette: palette,
                onPressed: () => onAiFeature(AiPanelMode.continueWriting),
              ),
              _ToolButton(
                icon: Icons.lightbulb_outline,
                label: context.l10n.editorAiInspire,
                palette: palette,
                onPressed: () => onAiFeature(AiPanelMode.inspireIdeas),
              ),
              _ToolButton(
                icon: Icons.auto_fix_high,
                label: context.l10n.editorAiRewrite,
                palette: palette,
                onPressed: () => onAiFeature(AiPanelMode.rewrite),
              ),
              _ToolButton(
                icon: Icons.search,
                label: context.l10n.editorFind,
                palette: palette,
                onPressed: onFind,
              ),
              _ToolButton(
                icon: Icons.spellcheck,
                label: context.l10n.editorAiCheck,
                palette: palette,
                onPressed: onCheck,
              ),
              PopupMenuButton<bool>(
                tooltip: context.l10n.editorMoveParagraph,
                onSelected: (up) => controller.moveParagraph(up: up),
                itemBuilder: (context) => <PopupMenuEntry<bool>>[
                  PopupMenuItem<bool>(
                    value: true,
                    child: Text(context.l10n.editorMoveParagraphUp),
                  ),
                  PopupMenuItem<bool>(
                    value: false,
                    child: Text(context.l10n.editorMoveParagraphDown),
                  ),
                ],
                child: _ToolButtonBody(
                  icon: Icons.swap_vert,
                  label: context.l10n.editorMoveParagraph,
                  palette: palette,
                ),
              ),
              _ToolButton(
                icon: Icons.undo,
                label: context.l10n.editorUndo,
                palette: palette,
                onPressed: controller.canUndo ? controller.undo : null,
              ),
              _ToolButton(
                icon: Icons.redo,
                label: context.l10n.editorRedo,
                palette: palette,
                onPressed: controller.canRedo ? controller.redo : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.palette,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final ReadingPalette palette;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onPressed,
        child: _ToolButtonBody(
          icon: icon,
          label: label,
          palette: palette,
          enabled: onPressed != null,
        ),
      ),
    );
  }
}

class _ToolButtonBody extends StatelessWidget {
  const _ToolButtonBody({
    required this.icon,
    required this.label,
    required this.palette,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final ReadingPalette palette;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? palette.ink
        : palette.inkSoft.withValues(alpha: 0.5);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: color),
          ),
        ],
      ),
    );
  }
}

class _StatusBar extends ConsumerWidget {
  const _StatusBar({
    required this.controller,
    required this.workId,
    required this.palette,
  });

  final EditorController controller;
  final int workId;
  final ReadingPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workWords = ref.watch(workProvider(workId)).value?.wordCount ?? 0;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Container(
        color: palette.background,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
        child: Row(
          children: <Widget>[
            Text(
              context.l10n.editorChapterWords(
                formatWordCount(controller.chapterWords, context.l10n),
              ),
              style: TextStyle(
                fontSize: 12,
                color: controller.overWordLimit
                    ? const Color(0xFFB3261E)
                    : palette.inkSoft,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              context.l10n.editorWholeWorkWords(
                formatWordCount(workWords, context.l10n),
              ),
              style: TextStyle(fontSize: 12, color: palette.inkSoft),
            ),
            const Spacer(),
            Text(
              controller.lastSavedAt == null
                  ? ''
                  : context.l10n.editorLastSaved(
                      formatRelativeTime(controller.lastSavedAt!, context.l10n),
                    ),
              style: TextStyle(fontSize: 12, color: palette.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}
