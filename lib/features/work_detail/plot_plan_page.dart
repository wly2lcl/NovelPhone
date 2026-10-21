import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/ai/structured_response.dart';
import '../../data/data_providers.dart';
import '../../data/db.dart';
import '../../l10n/l10n.dart';
import '../ai/ai_notice.dart';
import '../ai/ai_providers.dart';
import '../ai/ai_service.dart';

/// AI 剧情推演（ENH-23）：给出后续走向与分章建议，可逐条存入灵感箱。
class PlotPlanPage extends ConsumerStatefulWidget {
  const PlotPlanPage({super.key, required this.workId});

  final int workId;

  @override
  ConsumerState<PlotPlanPage> createState() => _PlotPlanPageState();
}

class _PlotPlanPageState extends ConsumerState<PlotPlanPage> {
  final TextEditingController _direction = TextEditingController();
  bool _running = false;
  String? _error;
  PlotPlan? _plan;

  @override
  void dispose() {
    _direction.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final l10n = context.l10n;
    final ready = await ref.read(aiServiceProvider).isReady('plan');
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
    if (!mounted) return;
    if (!await ensureAiNotice(context, ref)) return;
    if (!mounted) return;
    setState(() {
      _running = true;
      _error = null;
      _plan = null;
    });
    try {
      final result = await ref
          .read(aiServiceProvider)
          .planPlot(
            workId: widget.workId,
            direction: _direction.text.trim().isEmpty
                ? null
                : _direction.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _running = false;
        _plan = result.plan;
      });
    } on AiServiceNeedsConfig {
      if (!mounted) return;
      setState(() => _running = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.aiPanelNeedsConfig),
          action: SnackBarAction(
            label: l10n.editorGoSettings,
            onPressed: () => context.push('/settings'),
          ),
        ),
      );
    } on AiServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _error = l10n.plotPlanFailed(e.message);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _error = l10n.plotPlanFailed('$e');
      });
    }
  }

  Future<void> _save(String content) async {
    await ref
        .read(inspirationRepositoryProvider)
        .createInspiration(widget.workId, content);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.plotPlanSaved)));
  }

  String _directionText(PlotDirection direction) => <String>[
    direction.title,
    direction.summary,
    if (direction.beats.isNotEmpty) direction.beats,
    if (direction.hook.isNotEmpty)
      '${context.l10n.plotPlanHook}：${direction.hook}',
  ].join('\n');

  String _chapterText(PlotChapter chapter) =>
      '${chapter.title}\n${chapter.summary}';

  /// 章节名与现有章节完全一致时更新该章梗概，否则记为未关联章纲。
  Future<void> _saveToOutline(PlotChapter chapter) async {
    final title = chapter.title.trim();
    final chapters = await ref
        .read(chapterRepositoryProvider)
        .listChapters(widget.workId);
    Chapter? matched;
    if (title.isNotEmpty) {
      for (final existing in chapters) {
        if (existing.title.trim() == title) {
          matched = existing;
          break;
        }
      }
    }
    final outlineRepo = ref.read(outlineRepositoryProvider);
    if (matched != null) {
      await outlineRepo.saveChapterSummary(
        workId: widget.workId,
        volumeId: matched.volumeId,
        chapterId: matched.id,
        summary: chapter.summary,
      );
    } else {
      await outlineRepo.createEntry(
        workId: widget.workId,
        summary: _chapterText(chapter),
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.plotPlanOutlineSaved)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final plan = _plan;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.plotPlanTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
        children: <Widget>[
          Text(
            l10n.plotPlanIntro,
            style: TextStyle(color: context.paper.inkSoft, height: 1.5),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _direction,
            minLines: 2,
            maxLines: 4,
            enabled: !_running,
            decoration: InputDecoration(
              labelText: l10n.plotPlanDirection,
              hintText: l10n.plotPlanDirectionHint,
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _running ? null : _run,
            icon: _running
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 1.8),
                  )
                : const Icon(Icons.route_outlined, size: 18),
            label: Text(
              _running
                  ? l10n.plotPlanRunning
                  : plan == null
                  ? l10n.plotPlanStart
                  : l10n.plotPlanRegenerate,
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xFFB3261E)),
              ),
            ),
          if (plan != null && plan.parseFailed)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.paper.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.plotPlanParseFailed,
                  style: TextStyle(color: context.paper.inkSoft),
                ),
              ),
            ),
          if (plan != null && plan.directions.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              l10n.plotPlanDirections,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final direction in plan.directions)
              _DirectionCard(
                direction: direction,
                onSave: () => _save(_directionText(direction)),
              ),
          ],
          if (plan != null && plan.chapters.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              l10n.plotPlanChapters,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final chapter in plan.chapters)
              _ChapterCard(
                chapter: chapter,
                onSave: () => _save(_chapterText(chapter)),
                onOutline: () => _saveToOutline(chapter),
              ),
          ],
        ],
      ),
    );
  }
}

class _DirectionCard extends StatelessWidget {
  const _DirectionCard({required this.direction, required this.onSave});

  final PlotDirection direction;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              direction.title,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (direction.summary.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(direction.summary, style: const TextStyle(height: 1.45)),
            ],
            if (direction.beats.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                direction.beats,
                style: TextStyle(color: context.paper.inkSoft, height: 1.5),
              ),
            ],
            if (direction.hook.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '${l10n.plotPlanHook}：${direction.hook}',
                style: TextStyle(color: context.paper.accent, height: 1.4),
              ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.lightbulb_outline, size: 18),
                label: Text(l10n.plotPlanSaveInspiration),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  const _ChapterCard({
    required this.chapter,
    required this.onSave,
    required this.onOutline,
  });

  final PlotChapter chapter;
  final VoidCallback onSave;
  final VoidCallback onOutline;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(chapter.title, style: Theme.of(context).textTheme.titleSmall),
            if (chapter.summary.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(chapter.summary, style: const TextStyle(height: 1.45)),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton.icon(
                  onPressed: onOutline,
                  icon: const Icon(Icons.list_alt_outlined, size: 18),
                  label: Text(context.l10n.plotPlanToOutline),
                ),
                TextButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.lightbulb_outline, size: 18),
                  label: Text(context.l10n.plotPlanSaveInspiration),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
