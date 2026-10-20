import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/ai/structured_response.dart';
import '../../data/data_providers.dart';
import '../../data/db.dart';
import '../../l10n/l10n.dart';
import '../../models/story_state_kind.dart';
import '../ai/ai_providers.dart';
import '../ai/ai_service.dart';

/// AI 本章状态变化提取（ENH-35）：抽取结果与现有卡片对照，勾选后落库。
/// 返回是否写入了状态卡。
Future<bool> showStoryStateExtractionDialog(
  BuildContext context, {
  required int workId,
  required int chapterId,
}) async {
  final applied = await showDialog<bool>(
    context: context,
    builder: (_) =>
        StoryStateExtractionDialog(workId: workId, chapterId: chapterId),
  );
  return applied ?? false;
}

enum _ApplyMode { create, update, unchanged }

/// 状态提取结果预览对话框。
class StoryStateExtractionDialog extends ConsumerStatefulWidget {
  const StoryStateExtractionDialog({
    super.key,
    required this.workId,
    required this.chapterId,
  });

  final int workId;
  final int chapterId;

  @override
  ConsumerState<StoryStateExtractionDialog> createState() =>
      _StoryStateExtractionDialogState();
}

class _StoryStateExtractionDialogState
    extends ConsumerState<StoryStateExtractionDialog> {
  bool _loading = true;
  bool _applying = false;
  String? _error;
  List<StoryStateSuggestion> _suggestions = const <StoryStateSuggestion>[];
  Map<String, StoryState> _existingByKey = const <String, StoryState>{};
  final Set<int> _selected = <int>{};

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _error = null;
      _suggestions = const <StoryStateSuggestion>[];
      _selected.clear();
    });
    try {
      final existing = await ref
          .read(storyStateRepositoryProvider)
          .listEntries(widget.workId);
      final result = await ref
          .read(aiServiceProvider)
          .extractStoryStates(
            workId: widget.workId,
            chapterId: widget.chapterId,
          );
      if (!mounted) return;
      final byKey = <String, StoryState>{
        for (final entry in existing)
          '${entry.kind}|${entry.title.trim().toLowerCase()}': entry,
      };
      final suggestions = result.extraction.suggestions;
      setState(() {
        _existingByKey = byKey;
        _suggestions = suggestions;
        _loading = false;
        for (var i = 0; i < suggestions.length; i++) {
          if (_modeOf(suggestions[i]) != _ApplyMode.unchanged) {
            _selected.add(i);
          }
        }
      });
    } on AiServiceNeedsConfig {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = context.l10n.aiPanelNeedsConfig;
      });
    } on AiServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = context.l10n.storyStateExtractFailed(e.message);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = context.l10n.storyStateExtractFailed('$e');
      });
    }
  }

  _ApplyMode _modeOf(StoryStateSuggestion suggestion) {
    final existing = _existingByKey[suggestion.key];
    if (existing == null) return _ApplyMode.create;
    final detail = suggestion.detail.trim();
    final detailChanged = detail.isNotEmpty && detail != existing.detail.trim();
    final statusChanged = suggestion.closes && existing.status != 'closed';
    return detailChanged || statusChanged
        ? _ApplyMode.update
        : _ApplyMode.unchanged;
  }

  Future<void> _apply() async {
    if (_selected.isEmpty) return;
    setState(() => _applying = true);
    final repository = ref.read(storyStateRepositoryProvider);
    var created = 0;
    var updated = 0;
    for (final index in _selected.toList()..sort()) {
      if (index >= _suggestions.length) continue;
      final suggestion = _suggestions[index];
      final existing = _existingByKey[suggestion.key];
      if (existing == null) {
        await repository.createEntry(
          workId: widget.workId,
          kind: suggestion.kind,
          title: suggestion.title,
          detail: suggestion.detail,
          status: suggestion.status,
          chapterId: widget.chapterId,
          sortOrder: _existingByKey.length + created,
        );
        created++;
        continue;
      }
      final detail = suggestion.detail.trim().isEmpty
          ? existing.detail
          : suggestion.detail.trim();
      final status = suggestion.closes ? 'closed' : existing.status;
      if (detail == existing.detail && status == existing.status) continue;
      await repository.updateEntry(
        id: existing.id,
        kind: StoryStateKind.fromValue(existing.kind),
        title: existing.title,
        detail: detail,
        status: status,
        chapterId: existing.chapterId ?? widget.chapterId,
        sortOrder: existing.sortOrder,
      );
      updated++;
    }
    if (!mounted) return;
    setState(() => _applying = false);
    final messenger = ScaffoldMessenger.of(context);
    final message = context.l10n.storyStateExtractApplied(created, updated);
    Navigator.of(context).pop(true);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.storyStateExtractTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: _loading
            ? Row(
                children: <Widget>[
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(l10n.storyStateExtractRunning)),
                ],
              )
            : _error != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFB3261E)),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _run,
                    child: Text(l10n.commonRetry),
                  ),
                ],
              )
            : _suggestions.isEmpty
            ? Text(
                l10n.storyStateExtractEmpty,
                style: TextStyle(color: context.paper.inkSoft),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.storyStateExtractIntro,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.paper.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < _suggestions.length; i++)
                      _SuggestionTile(
                        suggestion: _suggestions[i],
                        mode: _modeOf(_suggestions[i]),
                        selected: _selected.contains(i),
                        onChanged: (value) {
                          setState(() {
                            if (value) {
                              _selected.add(i);
                            } else {
                              _selected.remove(i);
                            }
                          });
                        },
                      ),
                  ],
                ),
              ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _applying ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.commonClose),
        ),
        if (!_loading && _error == null && _suggestions.isNotEmpty)
          FilledButton(
            onPressed: _selected.isEmpty || _applying ? null : _apply,
            child: Text(l10n.storyStateExtractApply(_selected.length)),
          ),
      ],
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.suggestion,
    required this.mode,
    required this.selected,
    required this.onChanged,
  });

  final StoryStateSuggestion suggestion;
  final _ApplyMode mode;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final unchanged = mode == _ApplyMode.unchanged;
    final subtitle = <String>[
      if (suggestion.detail.trim().isNotEmpty) suggestion.detail.trim(),
      if (suggestion.closes) l10n.storyStateClosed,
    ].join(' · ');
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      value: selected,
      onChanged: unchanged ? null : (value) => onChanged(value ?? false),
      title: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              '[${_kindLabel(context, suggestion.kind)}] ${suggestion.title}',
            ),
          ),
          const SizedBox(width: 8),
          Text(
            switch (mode) {
              _ApplyMode.create => l10n.storyStateExtractNew,
              _ApplyMode.update => l10n.storyStateExtractUpdate,
              _ApplyMode.unchanged => l10n.storyStateExtractUnchanged,
            },
            style: TextStyle(
              fontSize: 12,
              color: unchanged
                  ? context.paper.inkSoft
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
    );
  }

  String _kindLabel(BuildContext context, StoryStateKind kind) {
    final l10n = context.l10n;
    return switch (kind) {
      StoryStateKind.character => l10n.storyStateTabCharacter,
      StoryStateKind.foreshadow => l10n.storyStateTabForeshadow,
      StoryStateKind.timeline => l10n.storyStateTabTimeline,
    };
  }
}
