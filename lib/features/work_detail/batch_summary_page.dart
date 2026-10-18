import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/ai/sanitize_ai_text.dart';
import '../../data/data_providers.dart';
import '../../data/db.dart';
import '../../data/repositories/settings_repository.dart';
import '../../l10n/error_text.dart';
import '../../l10n/l10n.dart';
import '../ai/ai_providers.dart';
import '../ai/ai_service.dart';

class _SummaryResult {
  const _SummaryResult({required this.chapter, this.summary, this.error});

  final Chapter chapter;
  final String? summary;
  final String? error;

  bool get failed => error != null;
}

/// 批量生成前情摘要（ENH-24）：顺序执行，避免并发触发服务商限流。
class BatchSummaryPage extends ConsumerStatefulWidget {
  const BatchSummaryPage({super.key, required this.workId});

  final int workId;

  @override
  ConsumerState<BatchSummaryPage> createState() => _BatchSummaryPageState();
}

class _BatchSummaryPageState extends ConsumerState<BatchSummaryPage> {
  List<Chapter> _chapters = const <Chapter>[];
  final List<_SummaryResult> _results = <_SummaryResult>[];
  bool _loading = true;
  bool _running = false;
  bool _cancelRequested = false;
  int _current = 0;
  int _total = 0;

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
      _chapters = chapters
          .where((chapter) => chapter.content.trim().isNotEmpty)
          .toList();
      _loading = false;
    });
  }

  bool _needsSummary(Chapter chapter) {
    if (chapter.summary.trim().isEmpty) return true;
    final updatedAt = chapter.summaryUpdatedAt;
    return updatedAt == null || chapter.updatedAt.isAfter(updatedAt);
  }

  int get _missingCount => _chapters.where(_needsSummary).length;

  Future<void> _run({required bool all}) async {
    final l10n = context.l10n;
    final targets = _chapters
        .where((chapter) => all || _needsSummary(chapter))
        .toList();
    if (targets.isEmpty) return;
    final service = ref.read(aiServiceProvider);
    final ready = await service.isReady(AiTask.summary);
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
    final chapterRepo = ref.read(chapterRepositoryProvider);
    setState(() {
      _running = true;
      _cancelRequested = false;
      _current = 0;
      _total = targets.length;
      _results.clear();
    });
    var saved = 0;
    for (var i = 0; i < targets.length; i++) {
      if (_cancelRequested || !mounted) break;
      setState(() => _current = i + 1);
      final chapter = targets[i];
      final buffer = StringBuffer();
      String? error;
      var needsConfig = false;
      try {
        await for (final event in service.summarizeChapter(
          workId: widget.workId,
          chapterId: chapter.id,
        )) {
          if (event is AiTextChunk) {
            buffer.write(event.text);
          } else if (event is AiFailed) {
            error = aiFailureText(
              l10n,
              kind: event.kind,
              message: event.message,
              statusCode: event.statusCode,
              code: event.code,
              detail: event.detail,
            );
          } else if (event is AiNeedsConfig) {
            needsConfig = true;
          }
        }
        if (needsConfig) {
          if (!mounted) return;
          setState(() => _running = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.aiPanelNeedsConfig)));
          return;
        }
        if (error == null) {
          final summary = sanitizeAiText(buffer.toString()).trim();
          if (summary.isEmpty) {
            error = l10n.batchSummaryFailed(l10n.batchSummaryEmptyResult);
          } else {
            await chapterRepo.saveChapterSummary(chapter.id, summary);
            saved++;
          }
        }
      } catch (e) {
        error = l10n.batchSummaryFailed('$e');
      }
      if (!mounted) return;
      setState(() {
        _results.add(
          _SummaryResult(
            chapter: chapter,
            summary: error == null
                ? sanitizeAiText(buffer.toString()).trim()
                : null,
            error: error,
          ),
        );
      });
    }
    if (!mounted) return;
    setState(() => _running = false);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.batchSummaryDone(saved))));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.batchSummaryTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
              children: <Widget>[
                Text(
                  l10n.batchSummaryIntro,
                  style: TextStyle(color: context.paper.inkSoft, height: 1.5),
                ),
                const SizedBox(height: 16),
                if (_chapters.isEmpty)
                  Text(
                    l10n.batchSummaryEmpty,
                    style: TextStyle(color: context.paper.inkSoft),
                  )
                else ...<Widget>[
                  if (_running) ...<Widget>[
                    LinearProgressIndicator(
                      value: _total == 0 ? 0 : _current / _total,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _cancelRequested
                          ? l10n.batchSummaryStopping
                          : l10n.batchSummaryRunning(_current, _total),
                      style: TextStyle(color: context.paper.inkSoft),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _cancelRequested
                          ? null
                          : () => setState(() => _cancelRequested = true),
                      icon: const Icon(Icons.stop_circle_outlined, size: 18),
                      label: Text(l10n.batchSummaryCancel),
                    ),
                  ] else ...<Widget>[
                    FilledButton.icon(
                      onPressed: _missingCount == 0
                          ? null
                          : () => _run(all: false),
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: Text(l10n.batchSummaryStart(_missingCount)),
                    ),
                    if (_missingCount < _chapters.length)
                      TextButton(
                        onPressed: () => _run(all: true),
                        child: Text(l10n.batchSummaryAll),
                      ),
                  ],
                  const SizedBox(height: 16),
                  for (final chapter in _chapters)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        _needsSummary(chapter)
                            ? Icons.pending_outlined
                            : Icons.check_circle_outline,
                        color: _needsSummary(chapter)
                            ? context.paper.accent
                            : context.paper.inkSoft,
                      ),
                      title: Text(
                        chapter.title.isEmpty
                            ? l10n.commonUntitledChapter
                            : chapter.title,
                      ),
                      subtitle: Text(
                        chapter.summary.trim().isEmpty
                            ? l10n.batchSummaryMissing
                            : _needsSummary(chapter)
                            ? l10n.batchSummaryStale
                            : l10n.batchSummaryCurrent,
                      ),
                    ),
                  if (_results.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 20),
                    Text(
                      l10n.batchSummaryResult,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    for (final result in _results)
                      _ResultCard(
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

class _ResultCard extends StatelessWidget {
  const _ResultCard({super.key, required this.result});

  final _SummaryResult result;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(result.chapter.title),
        subtitle: Text(
          result.failed ? result.error! : result.summary ?? '',
          maxLines: result.failed ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: result.failed
                ? const Color(0xFFB3261E)
                : context.paper.inkSoft,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SelectableText(result.failed ? result.error! : result.summary ?? ''),
        ],
      ),
    );
  }
}
