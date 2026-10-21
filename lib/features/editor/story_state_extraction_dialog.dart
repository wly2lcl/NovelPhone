import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/ai/structured_response.dart';
import '../../data/data_providers.dart';
import '../../data/db.dart';
import '../../l10n/l10n.dart';
import '../../models/character_tags.dart';
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

/// 关系变化的应用判定（ENH-56）。
enum _RelationMode { create, update, remove, unchanged, unresolvable }

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
  List<RelationChangeSuggestion> _relationChanges =
      const <RelationChangeSuggestion>[];
  final Set<int> _selectedRelations = <int>{};
  List<CharacterRelation> _existingRelations = const <CharacterRelation>[];
  Map<String, Character> _resolvedNames = const <String, Character>{};

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
      _relationChanges = const <RelationChangeSuggestion>[];
      _selectedRelations.clear();
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
      final changes = result.extraction.relationChanges;
      final relations = changes.isEmpty
          ? const <CharacterRelation>[]
          : await ref
                .read(characterRepositoryProvider)
                .listRelations(widget.workId);
      final resolvedNames = await _resolveNames(changes);
      if (!mounted) return;
      setState(() {
        _existingByKey = byKey;
        _suggestions = suggestions;
        _relationChanges = changes;
        _existingRelations = relations;
        _resolvedNames = resolvedNames;
        _loading = false;
        for (var i = 0; i < suggestions.length; i++) {
          if (_modeOf(suggestions[i]) != _ApplyMode.unchanged) {
            _selected.add(i);
          }
        }
        for (var i = 0; i < changes.length; i++) {
          final mode = _relationModeOf(changes[i]);
          if (mode != _RelationMode.unchanged &&
              mode != _RelationMode.unresolvable) {
            _selectedRelations.add(i);
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

  /// 把模型给的 from / to 名字解析成角色（名称或别名，忽略大小写）。
  Future<Map<String, Character>> _resolveNames(
    Iterable<RelationChangeSuggestion> changes,
  ) async {
    final repository = ref.read(characterRepositoryProvider);
    final characters = await repository.listCharacters(widget.workId);
    final byName = <String, Character>{
      for (final character in characters)
        character.name.trim().toLowerCase(): character,
      for (final character in characters)
        for (final alias in decodeTags(character.aliases))
          if (alias.trim().isNotEmpty) alias.trim().toLowerCase(): character,
    };
    final resolved = <String, Character>{};
    for (final change in changes) {
      for (final name in <String>[change.from, change.to]) {
        final key = name.trim().toLowerCase();
        final match = byName[key];
        if (match != null) resolved[key] = match;
      }
    }
    return resolved;
  }

  Character? _resolve(String name) => _resolvedNames[name.trim().toLowerCase()];

  /// 判定一条关系变化落到关系图上的动作。
  _RelationMode _relationModeOf(RelationChangeSuggestion change) {
    final from = _resolve(change.from);
    final to = _resolve(change.to);
    if (from == null || to == null || from.id == to.id) {
      return _RelationMode.unresolvable;
    }
    final edge = _findEdge(from.id, to.id);
    return switch (change.action) {
      'remove' => edge == null ? _RelationMode.unchanged : _RelationMode.remove,
      'update' =>
        edge == null
            ? _RelationMode.create
            : (edge.label.trim() == change.label.trim()
                  ? _RelationMode.unchanged
                  : _RelationMode.update),
      _ =>
        edge == null
            ? _RelationMode.create
            : (edge.label.trim() == change.label.trim()
                  ? _RelationMode.unchanged
                  : _RelationMode.update),
    };
  }

  /// 找已有有向边：关系图是有向的，反向边不能当作同一条。
  CharacterRelation? _findEdge(int from, int to) {
    for (final relation in _existingRelations) {
      if (relation.fromCharacterId == from && relation.toCharacterId == to) {
        return relation;
      }
    }
    return null;
  }

  /// 应用关系变化，返回实际新增 / 更新 / 删除的条数。
  /// 名称与别名解析后可能落到同一对角色，按有向 pair 去重，避免重复写库。
  Future<(int, int, int)> _applyRelations() async {
    final repository = ref.read(characterRepositoryProvider);
    final applied = <String>{};
    var added = 0;
    var updated = 0;
    var removed = 0;
    for (final index in _selectedRelations.toList()..sort()) {
      if (index >= _relationChanges.length) continue;
      final change = _relationChanges[index];
      final from = _resolve(change.from);
      final to = _resolve(change.to);
      if (from == null || to == null) continue;
      final pair = '${from.id}>${to.id}';
      if (!applied.add(pair)) continue;
      final edge = _findEdge(from.id, to.id);
      switch (_relationModeOf(change)) {
        case _RelationMode.create:
          await repository.createRelation(
            workId: widget.workId,
            fromCharacterId: from.id,
            toCharacterId: to.id,
            label: change.label.trim(),
          );
          added++;
        case _RelationMode.update:
          if (edge == null) break;
          // 保持原方向，仅更新称谓。
          await repository.updateRelation(
            id: edge.id,
            fromCharacterId: edge.fromCharacterId,
            toCharacterId: edge.toCharacterId,
            label: change.label.trim(),
          );
          updated++;
        case _RelationMode.remove:
          if (edge == null) break;
          await repository.deleteRelation(edge.id);
          removed++;
        case _RelationMode.unchanged || _RelationMode.unresolvable:
          break;
      }
    }
    return (added, updated, removed);
  }

  Future<void> _apply() async {
    if (_selected.isEmpty && _selectedRelations.isEmpty) return;
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
    // ENH-56：勾选的关系变化一并应用。
    var relationsAdded = 0;
    var relationsUpdated = 0;
    var relationsRemoved = 0;
    if (_selectedRelations.isNotEmpty) {
      final counts = await _applyRelations();
      relationsAdded = counts.$1;
      relationsUpdated = counts.$2;
      relationsRemoved = counts.$3;
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    var message = context.l10n.storyStateExtractApplied(created, updated);
    if (relationsAdded + relationsUpdated + relationsRemoved > 0) {
      message =
          '$message\n${context.l10n.storyStateExtractRelationsApplied(relationsAdded, relationsUpdated, relationsRemoved)}';
    }
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
            : _suggestions.isEmpty && _relationChanges.isEmpty
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
                    if (_relationChanges.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        l10n.storyStateExtractRelationSection,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.paper.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 4),
                      for (var i = 0; i < _relationChanges.length; i++)
                        _RelationTile(
                          change: _relationChanges[i],
                          mode: _relationModeOf(_relationChanges[i]),
                          selected: _selectedRelations.contains(i),
                          onChanged: (value) {
                            setState(() {
                              if (value) {
                                _selectedRelations.add(i);
                              } else {
                                _selectedRelations.remove(i);
                              }
                            });
                          },
                        ),
                    ],
                  ],
                ),
              ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _applying ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.commonClose),
        ),
        if (!_loading &&
            _error == null &&
            (_suggestions.isNotEmpty || _relationChanges.isNotEmpty))
          FilledButton(
            onPressed:
                (_selected.isEmpty && _selectedRelations.isEmpty) || _applying
                ? null
                : _apply,
            child: Text(
              l10n.storyStateExtractApply(
                _selected.length + _selectedRelations.length,
              ),
            ),
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

/// 人物关系变化勾选项（ENH-56）。
class _RelationTile extends StatelessWidget {
  const _RelationTile({
    required this.change,
    required this.mode,
    required this.selected,
    required this.onChanged,
  });

  final RelationChangeSuggestion change;
  final _RelationMode mode;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final disabled =
        mode == _RelationMode.unchanged || mode == _RelationMode.unresolvable;
    final modeText = switch (mode) {
      _RelationMode.create => l10n.storyStateExtractNew,
      _RelationMode.update => l10n.storyStateExtractUpdate,
      _RelationMode.remove => l10n.storyStateExtractRelationRemove,
      _RelationMode.unchanged => l10n.storyStateExtractUnchanged,
      _RelationMode.unresolvable => l10n.storyStateExtractRelationUnresolvable,
    };
    final label = change.label.trim();
    final subtitle = label.isEmpty
        ? null
        : Text('${change.from.trim()} → ${change.to.trim()}：$label');
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      value: selected,
      onChanged: disabled ? null : (value) => onChanged(value ?? false),
      title: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              '[${l10n.storyStateExtractRelationSection}] '
              '${change.from.trim()} → ${change.to.trim()}',
            ),
          ),
          const SizedBox(width: 8),
          Text(
            modeText,
            style: TextStyle(
              fontSize: 12,
              color: disabled
                  ? context.paper.inkSoft
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
      subtitle: subtitle,
    );
  }
}
