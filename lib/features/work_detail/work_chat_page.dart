import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/ai/context_builder.dart';
import '../../data/data_providers.dart';
import '../../l10n/error_text.dart';
import '../../l10n/l10n.dart';
import '../../models/work_chat_turn.dart';
import '../ai/ai_providers.dart';
import '../ai/ai_service.dart';

/// 作品问答（ENH-23）：结合作品资料与本地检索工具的多轮对话。
class WorkChatPage extends ConsumerStatefulWidget {
  const WorkChatPage({super.key, required this.workId});

  final int workId;

  @override
  ConsumerState<WorkChatPage> createState() => _WorkChatPageState();
}

class _WorkChatPageState extends ConsumerState<WorkChatPage> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  StreamSubscription<AiEvent>? _subscription;
  final List<WorkChatTurn> _turns = <WorkChatTurn>[];
  String _streamingText = '';
  bool _streaming = false;
  bool _loading = true;
  String? _error;
  BuiltContext? _context;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final turns = await ref.read(chatRepositoryProvider).load(widget.workId);
    if (!mounted) return;
    setState(() {
      _turns
        ..clear()
        ..addAll(turns);
      _loading = false;
    });
    _scrollToBottom(animated: false);
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if (animated) {
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      } else {
        _scroll.jumpTo(target);
      }
    });
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _streaming) return;
    final l10n = context.l10n;
    final service = ref.read(aiServiceProvider);
    final ready = await service.isReady('chat');
    if (!ready) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.aiPanelNeedsConfig),
          action: SnackBarAction(
            label: l10n.editorGoSettings,
            onPressed: () => context.push('/settings'),
          ),
        ),
      );
      return;
    }
    final history = _turns
        .map((turn) => ChatContextTurn(role: turn.role, content: turn.content))
        .toList();
    setState(() {
      _turns.add(WorkChatTurn(role: 'user', content: text));
      _input.clear();
      _streaming = true;
      _streamingText = '';
      _error = null;
      _context = null;
    });
    _scrollToBottom();
    await ref.read(chatRepositoryProvider).save(widget.workId, _turns);
    _subscription = service
        .chat(workId: widget.workId, history: history, message: text)
        .listen(_onEvent, onError: _onError);
  }

  void _onEvent(AiEvent event) {
    if (!mounted) return;
    switch (event) {
      case AiContextBuilt():
        setState(() => _context = event.context);
      case AiTextChunk():
        setState(() => _streamingText += event.text);
        _scrollToBottom();
      case AiFinished():
        final reply = event.text.trim().isEmpty
            ? _streamingText.trim()
            : event.text.trim();
        _commitReply(reply);
      case AiFailed():
        setState(() {
          _streaming = false;
          _error = aiFailureText(
            context.l10n,
            kind: event.kind,
            message: event.message,
            statusCode: event.statusCode,
            code: event.code,
            detail: event.detail,
          );
        });
        _commitPartial();
      case AiNeedsConfig():
        setState(() => _streaming = false);
        _commitPartial();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.aiPanelNeedsConfig),
            action: SnackBarAction(
              label: context.l10n.editorGoSettings,
              onPressed: () => context.push('/settings'),
            ),
          ),
        );
    }
  }

  void _onError(Object error) {
    if (!mounted) return;
    setState(() {
      _streaming = false;
      _error = error.toString();
    });
    _commitPartial();
  }

  /// 流式结束：把完整回答写入历史并持久化。
  Future<void> _commitReply(String reply) async {
    if (!mounted) return;
    final text = reply.trim().isEmpty ? context.l10n.chatNoReply : reply.trim();
    setState(() {
      _streaming = false;
      _streamingText = '';
      _turns.add(WorkChatTurn(role: 'assistant', content: text));
    });
    _scrollToBottom();
    await ref.read(chatRepositoryProvider).save(widget.workId, _turns);
  }

  /// 失败 / 停止时保留已生成的部分内容，避免辛苦生成的字白丢。
  void _commitPartial() {
    final partial = _streamingText.trim();
    if (partial.isEmpty || !mounted) return;
    setState(() {
      _turns.add(WorkChatTurn(role: 'assistant', content: partial));
      _streamingText = '';
    });
    unawaited(ref.read(chatRepositoryProvider).save(widget.workId, _turns));
  }

  Future<void> _stop() async {
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    if (!mounted) return;
    setState(() => _streaming = false);
    _commitPartial();
  }

  Future<void> _clear() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.chatClearTitle),
        content: Text(l10n.chatClearBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.chatClearAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _subscription?.cancel();
    _subscription = null;
    await ref.read(chatRepositoryProvider).clear(widget.workId);
    if (!mounted) return;
    setState(() {
      _turns.clear();
      _streaming = false;
      _streamingText = '';
      _error = null;
      _context = null;
    });
  }

  void _showContext() {
    final built = _context;
    if (built == null) return;
    final l10n = context.l10n;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.chatContextTitle),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              Text(
                l10n.chatContextUsage(
                  built.estimatedTokens,
                  built.budgetTokens,
                ),
                style: TextStyle(
                  fontSize: 12,
                  color: dialogContext.paper.inkSoft,
                ),
              ),
              if (built.truncated)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l10n.aiPanelTruncated,
                    style: TextStyle(
                      fontSize: 12,
                      color: dialogContext.paper.accent,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              for (final section in built.sections)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        section.label,
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
                          color: dialogContext.paper.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.chatTitle),
        actions: <Widget>[
          if (_context != null)
            IconButton(
              tooltip: l10n.chatContextTitle,
              onPressed: _showContext,
              icon: const Icon(Icons.info_outline),
            ),
          IconButton(
            tooltip: l10n.chatClearTitle,
            onPressed: _turns.isEmpty && _streaming ? null : _clear,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _turns.isEmpty && !_streaming
                ? _EmptyChat(onSuggestion: _send)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    itemCount: _turns.length + (_streaming ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _turns.length) {
                        return _ChatBubble(
                          role: 'assistant',
                          content: _streamingText.isEmpty
                              ? l10n.chatThinking
                              : _streamingText,
                          streaming: true,
                        );
                      }
                      final turn = _turns[index];
                      return _ChatBubble(
                        role: turn.role,
                        content: turn.content,
                      );
                    },
                  ),
          ),
          if (_error != null)
            Container(
              width: double.infinity,
              color: context.paper.surface,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xFFB3261E), fontSize: 13),
              ),
            ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              decoration: BoxDecoration(
                color: context.paper.surface,
                border: Border(top: BorderSide(color: context.paper.divider)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: l10n.chatInputHint,
                        isDense: true,
                        filled: true,
                        fillColor: context.paper.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: context.paper.divider),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: _streaming ? l10n.chatStop : l10n.chatSend,
                    onPressed: _streaming ? _stop : _send,
                    icon: Icon(
                      _streaming ? Icons.stop_rounded : Icons.arrow_upward,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.onSuggestion});

  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final suggestions = <String>[
      l10n.chatSuggestionGoal,
      l10n.chatSuggestionForeshadow,
      l10n.chatSuggestionRelationship,
    ];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.forum_outlined, size: 56, color: context.paper.inkSoft),
            const SizedBox(height: 12),
            Text(
              l10n.chatEmpty,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              l10n.chatIntro,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.paper.inkSoft, height: 1.5),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: <Widget>[
                for (final suggestion in suggestions)
                  ActionChip(
                    label: Text(suggestion),
                    onPressed: () => onSuggestion(suggestion),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.role,
    required this.content,
    this.streaming = false,
  });

  final String role;
  final String content;
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    final isUser = role == 'user';
    final palette = context.paper;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? palette.accent : palette.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isUser ? 14 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 14),
          ),
          border: isUser ? null : Border.all(color: palette.divider),
        ),
        child: Text(
          streaming ? '$content▍' : content,
          style: TextStyle(
            color: isUser ? Colors.white : palette.ink,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
