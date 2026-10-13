import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/reading_appearance.dart';
import '../../app/theme.dart';
import '../../core/formatting.dart';
import '../../core/word_count.dart';
import '../../data/data_providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../ai/ai_notice.dart';
import '../ai/ai_providers.dart';
import '../work_detail/outline_tab.dart';
import '../work_detail/work_detail_providers.dart';
import 'ai_confirm_panel.dart';
import 'editor_controller.dart';
import 'find_replace_panel.dart';
import 'flavor_check_panel.dart';
import 'snapshot_panel.dart';

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
  }

  @override
  void dispose() {
    // 离开编辑器的最后一次落库（含光标与滚动位置，供会话恢复）。
    _controller.flush();
    _controller.dispose();
    super.dispose();
  }

  void _restoreScroll() {
    final scrollController = _controller.scrollController;
    if (!scrollController.hasClients) return;
    final target = _controller.initialScrollOffset.toDouble();
    if (target > 0) {
      scrollController.jumpTo(
          target.clamp(0.0, scrollController.position.maxScrollExtent).toDouble());
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
                    _controller.title.isEmpty ? '未命名章节' : _controller.title,
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
            tooltip: '版本历史',
            icon: const Icon(Icons.history),
            onPressed: () => setState(() {
              _findVisible = false;
              _checkVisible = false;
              _aiMode = null;
              _snapshotsVisible = !_snapshotsVisible;
            }),
          ),
          IconButton(
            tooltip: '本章梗概',
            icon: const Icon(Icons.list_alt),
            onPressed: _editChapterSummary,
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
              onClose: () => setState(() => _aiMode = null),
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
      child: TextField(
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
        decoration: const InputDecoration(
          hintText: '在这里写下正文…',
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.fromLTRB(16, 16, 16, 24),
        ),
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
        title: const Text('章节标题'),
        content: TextFormField(
          initialValue: _controller.title,
          autofocus: true,
          maxLength: 50,
          onChanged: (value) => text = value,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (title == null || title.length > 50) return;
    await _controller.renameChapter(title);
  }

  /// 打开 AI 待确认面板（PRD 5.5）：未配置可用模型组时先引导至设置页。
  Future<void> _openAi(AiPanelMode mode) async {
    final task = mode == AiPanelMode.continueWriting
        ? AiTask.continueWriting
        : AiTask.inspire;
    final ready = await ref.read(aiServiceProvider).isReady(task);
    if (!mounted) return;
    if (!ready) {
      final go = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('尚未配置模型'),
          content: const Text('请先在设置中添加模型组并填写 API Key，再使用 AI 功能。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('稍后'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('去设置'),
            ),
          ],
        ),
      );
      if (go == true && mounted) context.push('/settings');
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

  /// 编辑器侧栏入口：直接编辑本章梗概（PRD 5.4 双入口之一）。
  Future<void> _editChapterSummary() async {
    final repository = ref.read(outlineRepositoryProvider);
    final chapter =
        await ref.read(chapterRepositoryProvider).getChapter(widget.chapterId);
    final existing = await repository.findByChapter(widget.chapterId);
    if (!mounted) return;
    await showSummaryEditor(
      context,
      ref,
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
              Text('保存中', style: TextStyle(fontSize: 13, color: context.paper.inkSoft)),
            ],
          ),
        );
      case SaveStatus.saved:
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: <Widget>[
              Icon(Icons.cloud_done_outlined, size: 15, color: context.paper.inkSoft),
              SizedBox(width: 6),
              Text('已保存', style: TextStyle(fontSize: 13, color: context.paper.inkSoft)),
            ],
          ),
        );
      case SaveStatus.failed:
        return TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.error_outline, size: 16, color: Color(0xFFB3261E)),
          label: const Text('保存失败，点击重试',
              style: TextStyle(color: Color(0xFFB3261E), fontSize: 13)),
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
                label: 'AI 续写',
                palette: palette,
                onPressed: () => onAiFeature(AiPanelMode.continueWriting),
              ),
              _ToolButton(
                icon: Icons.lightbulb_outline,
                label: 'AI 灵感',
                palette: palette,
                onPressed: () => onAiFeature(AiPanelMode.inspireIdeas),
              ),
              _ToolButton(
                icon: Icons.search,
                label: '查找替换',
                palette: palette,
                onPressed: onFind,
              ),
              _ToolButton(
                icon: Icons.spellcheck,
                label: 'AI 感检查',
                palette: palette,
                onPressed: onCheck,
              ),
              PopupMenuButton<bool>(
                tooltip: '段落移动',
                onSelected: (up) => controller.moveParagraph(up: up),
                itemBuilder: (context) => const <PopupMenuEntry<bool>>[
                  PopupMenuItem<bool>(value: true, child: Text('本段上移')),
                  PopupMenuItem<bool>(value: false, child: Text('本段下移')),
                ],
                child: _ToolButtonBody(
                  icon: Icons.swap_vert,
                  label: '段落移动',
                  palette: palette,
                ),
              ),
              _ToolButton(
                icon: Icons.undo,
                label: '撤销',
                palette: palette,
                onPressed: controller.canUndo ? controller.undo : null,
              ),
              _ToolButton(
                icon: Icons.redo,
                label: '重做',
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
    final color =
        enabled ? palette.ink : palette.inkSoft.withValues(alpha: 0.5);
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
              '本章 ${formatWordCount(controller.chapterWords)}',
              style: TextStyle(
                fontSize: 12,
                color: controller.overWordLimit
                    ? const Color(0xFFB3261E)
                    : palette.inkSoft,
              ),
            ),
            const SizedBox(width: 12),
            Text('全书 ${formatWordCount(workWords)}',
                style: TextStyle(fontSize: 12, color: palette.inkSoft)),
            const Spacer(),
            Text(
              controller.lastSavedAt == null
                  ? ''
                  : '最后保存 ${formatRelativeTime(controller.lastSavedAt!)}',
              style: TextStyle(fontSize: 12, color: palette.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}