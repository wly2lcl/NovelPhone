import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/data_providers.dart';
import '../../data/db.dart';
import '../../data/repositories/settings_repository.dart';
import '../../l10n/error_text.dart';
import '../../l10n/l10n.dart';
import '../ai/ai_notice.dart';
import '../ai/ai_providers.dart';
import '../ai/ai_service.dart';

class _ScanResult {
  const _ScanResult({
    required this.chapter,
    this.text = '',
    this.truncated = false,
    this.error,
  });

  final Chapter chapter;
  final String text;
  final bool truncated;
  final String? error;

  bool get failed => error != null;

  bool get clean => !failed && !text.contains('冲突');
}

/// 全书一致性体检（ENH-23）：逐章顺序检查，避免并发触发服务商限流。
class ContinuityScanPage extends ConsumerStatefulWidget {
  const ContinuityScanPage({super.key, required this.workId});

  final int workId;

  @override
  ConsumerState<ContinuityScanPage> createState() => _ContinuityScanPageState();
}

class _ContinuityScanPageState extends ConsumerState<ContinuityScanPage> {
  List<Chapter> _targets = const <Chapter>[];
  final List<_ScanResult> _results = <_ScanResult>[];
  bool _loading = true;
  bool _running = false;
  bool _cancelRequested = false;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final chapters = await ref
        .read(chapterRepositoryProvider)
        .listChapters(widget.workId);
    if (!mounted) return;
    setState(() {
      _targets = chapters
          .where((chapter) => chapter.content.trim().isNotEmpty)
          .toList();
      _loading = false;
    });
  }

  Future<void> _run() async {
    final l10n = context.l10n;
    final service = ref.read(aiServiceProvider);
    final ready = await service.isReady(AiTask.continuity);
    if (!mounted) return;
    if (!ready) {
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
    if (!await ensureAiNotice(context, ref)) return;
    if (!mounted) return;
    setState(() {
      _running = true;
      _cancelRequested = false;
      _current = 0;
      _results.clear();
    });
    for (var i = 0; i < _targets.length; i++) {
      if (_cancelRequested || !mounted) break;
      setState(() => _current = i + 1);
      final chapter = _targets[i];
      try {
        final report = await service.checkContinuity(
          workId: widget.workId,
          chapterId: chapter.id,
        );
        if (!mounted) return;
        setState(() {
          _results.add(
            _ScanResult(
              chapter: chapter,
              text: report.text.trim(),
              truncated: report.truncated,
            ),
          );
        });
      } on ContinuityNeedsConfig {
        if (!mounted) return;
        setState(() => _running = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.aiPanelNeedsConfig)));
        return;
      } on ContinuityException catch (error) {
        if (!mounted) return;
        setState(() {
          _results.add(
            _ScanResult(
              chapter: chapter,
              error: aiFailureText(
                l10n,
                kind: error.kind,
                message: error.message,
                statusCode: error.statusCode,
                code: error.code,
                detail: error.detail,
              ),
            ),
          );
        });
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _results.add(_ScanResult(chapter: chapter, error: '$error'));
        });
      }
    }
    if (!mounted) return;
    setState(() => _running = false);
  }

  Future<void> _copyAll() async {
    final l10n = context.l10n;
    final buffer = StringBuffer();
    for (final result in _results) {
      buffer.writeln('【${result.chapter.title}】');
      buffer.writeln(
        result.failed
            ? l10n.continuityScanFailedLine(result.error!)
            : result.text,
      );
      buffer.writeln();
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.continuityScanCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.continuityScanTitle),
        actions: <Widget>[
          if (_results.isNotEmpty)
            IconButton(
              tooltip: l10n.continuityScanCopyAll,
              onPressed: _copyAll,
              icon: const Icon(Icons.copy_all_outlined),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
              children: <Widget>[
                Text(
                  l10n.continuityScanIntro,
                  style: TextStyle(color: context.paper.inkSoft, height: 1.5),
                ),
                const SizedBox(height: 16),
                if (_targets.isEmpty)
                  Text(
                    l10n.continuityScanEmpty,
                    style: TextStyle(color: context.paper.inkSoft),
                  )
                else ...<Widget>[
                  if (_running) ...<Widget>[
                    LinearProgressIndicator(
                      value: _targets.isEmpty ? 0 : _current / _targets.length,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _cancelRequested
                          ? l10n.continuityScanStopping
                          : l10n.continuityScanRunning(
                              _current,
                              _targets.length,
                            ),
                      style: TextStyle(color: context.paper.inkSoft),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (_running)
                    OutlinedButton.icon(
                      onPressed: _cancelRequested
                          ? null
                          : () => setState(() => _cancelRequested = true),
                      icon: const Icon(Icons.stop_circle_outlined, size: 18),
                      label: Text(l10n.continuityScanCancel),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _run,
                      icon: const Icon(Icons.fact_check_outlined, size: 18),
                      label: Text(
                        _results.isEmpty
                            ? l10n.continuityScanStart
                            : l10n.continuityScanRerun,
                      ),
                    ),
                  if (_results.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 20),
                    Text(
                      l10n.continuityScanResult,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.continuityScanProgress(
                        _results.length,
                        _targets.length,
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.paper.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final result in _results)
                      _ResultTile(
                        key: ValueKey(result.chapter.id),
                        result: result,
                      ),
                  ],
                ],
              ],
            ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({super.key, required this.result});

  final _ScanResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final subtitle = result.failed
        ? l10n.continuityScanChapterFailed
        : result.clean
        ? l10n.continuityScanNoIssues
        : l10n.continuityScanHasIssues;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(result.chapter.title),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: result.failed
                ? const Color(0xFFB3261E)
                : result.clean
                ? context.paper.inkSoft
                : context.paper.accent,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (result.truncated)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.editorContinuityTruncated,
                style: TextStyle(fontSize: 12, color: context.paper.inkSoft),
              ),
            ),
          SelectableText(result.failed ? result.error! : result.text),
        ],
      ),
    );
  }
}
