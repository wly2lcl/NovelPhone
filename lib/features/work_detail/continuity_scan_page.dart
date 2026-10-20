import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/ai/structured_response.dart';
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
    this.result = const ContinuityCheckResult(parseFailed: true),
    this.truncated = false,
    this.error,
  });

  final Chapter chapter;

  /// 模型原始输出（结构化结果不可用时回退展示）。
  final String text;
  final ContinuityCheckResult result;
  final bool truncated;
  final String? error;

  bool get failed => error != null;
}

/// 全书一致性体检（ENH-23 / ENH-38）：逐章顺序检查，避免并发触发服务商限流；
/// 结果按结构化冲突展示，可直接跳到对应章节。
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
              result: report.result,
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
      if (result.failed) {
        buffer.writeln(l10n.continuityScanFailedLine(result.error!));
      } else {
        final check = result.result;
        if (check.summary.isNotEmpty) buffer.writeln(check.summary);
        if (check.parseFailed) buffer.writeln(result.text);
        for (var i = 0; i < check.issues.length; i++) {
          final issue = check.issues[i];
          buffer.writeln(
            '${i + 1}. [${_severityText(l10n, issue.severity)}] ${issue.quote}',
          );
          if (issue.detail.isNotEmpty) {
            buffer.writeln('   ${l10n.continuityIssueDetail(issue.detail)}');
          }
          if (issue.source.isNotEmpty) {
            buffer.writeln('   ${l10n.continuityIssueSource(issue.source)}');
          }
          if (issue.suggestion.isNotEmpty) {
            buffer.writeln(
              '   ${l10n.continuityIssueSuggestion(issue.suggestion)}',
            );
          }
        }
      }
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
                        workId: widget.workId,
                        result: result,
                      ),
                  ],
                ],
              ],
            ),
    );
  }
}

String _severityText(AppLocalizations l10n, String severity) {
  return switch (severity) {
    'high' => l10n.continuitySeverityHigh,
    'low' => l10n.continuitySeverityLow,
    _ => l10n.continuitySeverityMedium,
  };
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({super.key, required this.workId, required this.result});

  final int workId;
  final _ScanResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final check = result.result;
    final String subtitle;
    final Color subtitleColor;
    if (result.failed) {
      subtitle = l10n.continuityScanChapterFailed;
      subtitleColor = const Color(0xFFB3261E);
    } else if (check.parseFailed) {
      subtitle = l10n.continuityScanParseFailed;
      subtitleColor = const Color(0xFFA15C00);
    } else if (check.issues.isEmpty) {
      subtitle = l10n.continuityScanNoIssues;
      subtitleColor = context.paper.inkSoft;
    } else {
      subtitle = l10n.continuityIssueCount(check.issues.length);
      subtitleColor = context.paper.accent;
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(result.chapter.title),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: subtitleColor),
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
          if (result.failed)
            SelectableText(result.error!)
          else ...<Widget>[
            if (check.summary.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  check.summary,
                  style: TextStyle(color: context.paper.ink, height: 1.4),
                ),
              ),
            if (check.parseFailed) ...<Widget>[
              Text(
                l10n.continuityIssueParseFallback,
                style: TextStyle(fontSize: 12, color: context.paper.inkSoft),
              ),
              const SizedBox(height: 8),
              SelectableText(result.text),
            ] else
              for (var i = 0; i < check.issues.length; i++)
                _ScanIssue(index: i + 1, issue: check.issues[i]),
            if (!check.parseFailed) ...<Widget>[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => context.push(
                    '/work/$workId/chapter/${result.chapter.id}',
                  ),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text(l10n.continuityScanOpenChapter),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ScanIssue extends StatelessWidget {
  const _ScanIssue({required this.index, required this.issue});

  final int index;
  final ContinuityIssue issue;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final severityColor = switch (issue.severity) {
      'high' => const Color(0xFFB3261E),
      'low' => context.paper.inkSoft,
      _ => const Color(0xFFA15C00),
    };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.paper.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.paper.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '#$index · ${_severityText(l10n, issue.severity)}',
            style: TextStyle(
              fontSize: 11,
              color: severityColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (issue.quote.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            SelectableText(
              '「${issue.quote}」',
              style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4),
            ),
          ],
          if (issue.detail.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              l10n.continuityIssueDetail(issue.detail),
              style: TextStyle(fontSize: 12, color: context.paper.inkSoft),
            ),
          ],
          if (issue.source.isNotEmpty) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              l10n.continuityIssueSource(issue.source),
              style: TextStyle(fontSize: 12, color: context.paper.inkSoft),
            ),
          ],
          if (issue.suggestion.isNotEmpty) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              l10n.continuityIssueSuggestion(issue.suggestion),
              style: TextStyle(fontSize: 12, color: context.paper.ink),
            ),
          ],
        ],
      ),
    );
  }
}
