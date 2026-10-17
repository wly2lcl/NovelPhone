import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/ai/context_builder.dart';
import '../../l10n/l10n.dart';
import '../ai/ai_service.dart';

/// 流式一致性检查结果（ENH-23）。
class ContinuityStreamResult {
  const ContinuityStreamResult({
    this.text = '',
    this.truncated = false,
    this.stopped = false,
    this.failure,
    this.rawError,
    this.needsConfig = false,
  });

  final String text;
  final bool truncated;
  final bool stopped;
  final AiFailed? failure;
  final String? rawError;
  final bool needsConfig;
}

/// 一致性检查进度对话框（ENH-23）：实时显示已生成内容，可随时停止并保留部分结果。
class ContinuityStreamDialog extends ConsumerStatefulWidget {
  const ContinuityStreamDialog({super.key, required this.stream});

  final Stream<AiEvent> stream;

  @override
  ConsumerState<ContinuityStreamDialog> createState() =>
      _ContinuityStreamDialogState();
}

class _ContinuityStreamDialogState
    extends ConsumerState<ContinuityStreamDialog> {
  final StringBuffer _buffer = StringBuffer();
  StreamSubscription<AiEvent>? _subscription;
  BuiltContext? _context;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _subscription = widget.stream.listen(
      _onEvent,
      onError: (Object error) =>
          _close(ContinuityStreamResult(rawError: '$error')),
      onDone: () => _close(
        ContinuityStreamResult(
          text: _buffer.toString(),
          truncated: _context?.truncated ?? false,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _onEvent(AiEvent event) {
    if (!mounted || _closed) return;
    switch (event) {
      case AiContextBuilt():
        _context = event.context;
      case AiTextChunk():
        setState(() => _buffer.write(event.text));
      case AiFinished():
        _close(
          ContinuityStreamResult(
            text: event.text.trim().isEmpty
                ? _buffer.toString()
                : event.text.trim(),
            truncated: _context?.truncated ?? false,
          ),
        );
      case AiFailed():
        _close(ContinuityStreamResult(failure: event));
      case AiNeedsConfig():
        _close(const ContinuityStreamResult(needsConfig: true));
    }
  }

  void _close(ContinuityStreamResult result) {
    if (!mounted || _closed) return;
    _closed = true;
    Navigator.of(context).pop(result);
  }

  Future<void> _stop() async {
    await _subscription?.cancel();
    _close(
      ContinuityStreamResult(
        text: _buffer.toString(),
        truncated: _context?.truncated ?? false,
        stopped: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = _buffer.toString();
    return AlertDialog(
      title: Text(l10n.editorContinuityTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.45,
          ),
          child: SingleChildScrollView(
            child: text.isEmpty
                ? Row(
                    children: <Widget>[
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Text(l10n.editorContinuityRunning)),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (_context?.truncated ?? false) ...<Widget>[
                        Text(
                          l10n.editorContinuityTruncated,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.paper.inkSoft,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      SelectableText('$text▍'),
                    ],
                  ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: _stop, child: Text(l10n.editorContinuityStop)),
      ],
    );
  }
}
