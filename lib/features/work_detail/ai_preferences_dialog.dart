import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/ai/collaboration_rules.dart';
import '../../core/ai/context_builder.dart' show estimateTokens;
import '../../core/ai/continuity_suppression.dart';
import '../../core/ai/preference_distillation.dart';
import '../../core/ai/writing_preferences.dart';
import '../../data/data_providers.dart';
import '../../l10n/l10n.dart';

/// 作者协作偏好（ENH-27.2）：查看 / 开关 / 清空作品级本地偏好。
Future<void> showAiPreferencesDialog(BuildContext context, int workId) {
  return showDialog<void>(
    context: context,
    builder: (_) => _AiPreferencesDialog(workId: workId),
  );
}

class _AiPreferencesDialog extends ConsumerStatefulWidget {
  const _AiPreferencesDialog({required this.workId});

  final int workId;

  @override
  ConsumerState<_AiPreferencesDialog> createState() =>
      _AiPreferencesDialogState();
}

class _AiPreferencesDialogState extends ConsumerState<_AiPreferencesDialog> {
  bool _loading = true;
  bool _enabled = true;
  Map<String, int> _counts = const <String, int>{};
  Map<String, int> _paragraphCounts = const <String, int>{};
  List<AdoptedSample> _samples = const <AdoptedSample>[];
  List<ContinuitySuppression> _ignored = const <ContinuitySuppression>[];
  List<String> _rules = const <String>[];
  Map<String, List<String>> _scopes = const <String, List<String>>{};
  List<String> _banned = const <String>[];
  List<String> _rejected = const <String>[];
  List<AdoptedSample> _analysisSamples = const <AdoptedSample>[];
  String _previewTask = CollabRuleTask.all;
  bool _distillShown = false;

  bool get _hasData =>
      _counts.isNotEmpty ||
      _paragraphCounts.isNotEmpty ||
      _samples.isNotEmpty ||
      _ignored.isNotEmpty ||
      _rules.isNotEmpty ||
      _banned.isNotEmpty ||
      _rejected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(settingsRepositoryProvider);
    final enabled = await repo.readAiPreferencesEnabled(widget.workId);
    final counts = await repo.readAiFeedback(widget.workId);
    final paragraphCounts = await repo.readAiParagraphFeedback(widget.workId);
    final samples = await repo.readAdoptedSamples(widget.workId);
    final ignored = await repo.readContinuitySuppressions(widget.workId);
    final collaboration = await repo.readCollaborationRules(widget.workId);
    final rejected = await repo.readRejectedAiTexts(widget.workId);
    final analysisSamples = await repo.readAnalysisSamples(widget.workId);
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _counts = counts;
      _paragraphCounts = paragraphCounts;
      _samples = samples;
      _ignored = ignored;
      _rules = collaboration.rules;
      _scopes = collaboration.scopes;
      _banned = collaboration.banned;
      _rejected = rejected;
      _analysisSamples = analysisSamples;
      _loading = false;
    });
  }

  Future<void> _toggle(bool value) async {
    setState(() => _enabled = value);
    await ref
        .read(settingsRepositoryProvider)
        .setAiPreferencesEnabled(widget.workId, value);
  }

  Future<void> _clear() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.aiPreferencesClearTitle),
        content: Text(l10n.aiPreferencesClearBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.aiPreferencesClear),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(settingsRepositoryProvider)
        .clearAiPreferences(widget.workId);
    await ref
        .read(settingsRepositoryProvider)
        .clearContinuitySuppressions(widget.workId);
    if (!mounted) return;
    setState(() {
      _counts = const <String, int>{};
      _paragraphCounts = const <String, int>{};
      _samples = const <AdoptedSample>[];
      _ignored = const <ContinuitySuppression>[];
      _rules = const <String>[];
      _scopes = const <String, List<String>>{};
      _banned = const <String>[];
      _rejected = const <String>[];
      _analysisSamples = const <AdoptedSample>[];
      _distillShown = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.aiPreferencesCleared)));
  }

  Future<void> _restore(ContinuitySuppression entry) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.restoreContinuitySuppression(widget.workId, entry.fingerprint);
    final ignored = await repo.readContinuitySuppressions(widget.workId);
    if (!mounted) return;
    setState(() => _ignored = ignored);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.aiPreferencesConflictRestored)),
    );
  }

  Future<String?> _promptForText({
    required String title,
    required String hint,
    required int maxLength,
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    controller.selection = TextSelection.collapsed(offset: initialValue.length);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: maxLength,
          maxLines: 2,
          minLines: 1,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(context.l10n.commonAdd),
          ),
        ],
      ),
    );
    controller.dispose();
    final text = result?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  Future<void> _addRule([String? preset]) async {
    final l10n = context.l10n;
    final text =
        preset ??
        await _promptForText(
          title: l10n.aiPreferencesAddRuleTitle,
          hint: l10n.aiPreferencesRuleHint,
          maxLength: CollaborationRules.maxRuleChars,
        );
    if (text == null || text.trim().isEmpty) return;
    final repo = ref.read(settingsRepositoryProvider);
    await repo.addCollaborationRule(widget.workId, text);
    final collaboration = await repo.readCollaborationRules(widget.workId);
    if (!mounted) return;
    setState(() {
      _rules = collaboration.rules;
      _scopes = collaboration.scopes;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.aiPreferencesRuleAdded)));
  }

  Future<void> _removeRule(String rule) async {
    final repo = ref.read(settingsRepositoryProvider);
    final nextScopes = Map<String, List<String>>.of(_scopes)..remove(rule);
    await repo.saveCollaborationRules(
      widget.workId,
      CollaborationRules(
        rules: _rules.where((e) => e != rule).toList(growable: false),
        banned: _banned,
        scopes: nextScopes,
      ),
    );
    final collaboration = await repo.readCollaborationRules(widget.workId);
    if (!mounted) return;
    setState(() {
      _rules = collaboration.rules;
      _scopes = collaboration.scopes;
    });
  }

  Future<void> _saveRules(
    List<String> rules,
    Map<String, List<String>> scopes,
  ) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.saveCollaborationRules(
      widget.workId,
      CollaborationRules(rules: rules, banned: _banned, scopes: scopes),
    );
    final collaboration = await repo.readCollaborationRules(widget.workId);
    if (!mounted) return;
    setState(() {
      _rules = collaboration.rules;
      _scopes = collaboration.scopes;
    });
  }

  Future<void> _editRule(int index) async {
    final l10n = context.l10n;
    final updated = await _promptForText(
      title: l10n.aiPreferencesRuleEditTitle,
      hint: l10n.aiPreferencesRuleHint,
      maxLength: CollaborationRules.maxRuleChars,
      initialValue: _rules[index],
    );
    if (updated == null || updated == _rules[index]) return;
    final rules = List<String>.of(_rules);
    final old = rules[index];
    rules[index] = updated;
    final scopes = Map<String, List<String>>.of(_scopes);
    final scope = scopes.remove(old);
    if (scope != null) scopes[updated] = scope;
    await _saveRules(rules, scopes);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.aiPreferencesRuleUpdated)));
  }

  Future<void> _moveRule(int index, int delta) async {
    final target = index + delta;
    if (target < 0 || target >= _rules.length) return;
    final rules = List<String>.of(_rules);
    final item = rules.removeAt(index);
    rules.insert(target, item);
    await _saveRules(rules, _scopes);
  }

  Future<void> _changeScopes(String rule) async {
    final l10n = context.l10n;
    var selected = List<String>.of(
      CollaborationRules.sanitizeScopeList(_scopes[rule] ?? const <String>[]),
    );
    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(l10n.aiPreferencesRuleScopeTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.aiPreferencesRuleScopeHint,
                style: TextStyle(fontSize: 12, color: context.paper.inkSoft),
              ),
              for (final task in CollabRuleTask.selectable)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(_taskLabel(l10n, task)),
                  value: selected.contains(task),
                  onChanged: (value) => setDialogState(() {
                    if (value == true) {
                      selected.add(task);
                    } else {
                      selected.remove(task);
                    }
                  }),
                ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => setDialogState(() => selected.clear()),
              child: Text(l10n.aiPreferencesRuleAllTasks),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(CollaborationRules.sanitizeScopeList(selected)),
              child: Text(l10n.commonSave),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    final scopes = Map<String, List<String>>.of(_scopes);
    if (result.isEmpty) {
      scopes.remove(rule);
    } else {
      scopes[rule] = result;
    }
    await _saveRules(_rules, scopes);
  }

  String _taskLabel(AppLocalizations l10n, String task) {
    switch (task) {
      case CollabRuleTask.continueWriting:
        return l10n.aiTaskContinue;
      case CollabRuleTask.rewrite:
        return l10n.aiTaskRewrite;
      case CollabRuleTask.inspire:
        return l10n.aiTaskInspire;
      case CollabRuleTask.outline:
        return l10n.aiTaskOutlineExpand;
      case CollabRuleTask.plot:
        return l10n.aiTaskPlan;
    }
    return task;
  }

  String _scopeSummary(AppLocalizations l10n, String rule) {
    final list = CollaborationRules.sanitizeScopeList(
      _scopes[rule] ?? const <String>[],
    );
    if (list.isEmpty) return l10n.aiPreferencesRuleAllTasks;
    return list.map((task) => _taskLabel(l10n, task)).join(' · ');
  }

  Future<void> _addBanned([String? preset]) async {
    final l10n = context.l10n;
    final text =
        preset ??
        await _promptForText(
          title: l10n.aiPreferencesAddBannedTitle,
          hint: l10n.aiPreferencesBannedHintInput,
          maxLength: CollaborationRules.maxBannedChars,
        );
    if (text == null || text.trim().isEmpty) return;
    final repo = ref.read(settingsRepositoryProvider);
    await repo.addBannedPhrase(widget.workId, text);
    final collaboration = await repo.readCollaborationRules(widget.workId);
    if (!mounted) return;
    setState(() => _banned = collaboration.banned);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.aiPreferencesBannedAdded)));
  }

  Future<void> _removeBanned(String phrase) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.removeBannedPhrase(widget.workId, phrase);
    final collaboration = await repo.readCollaborationRules(widget.workId);
    if (!mounted) return;
    setState(() => _banned = collaboration.banned);
  }

  Future<void> _addHints(List<DistilledHint> hints) async {
    if (hints.isEmpty) return;
    final repo = ref.read(settingsRepositoryProvider);
    for (final hint in hints) {
      await repo.addCollaborationRule(widget.workId, hint.text);
    }
    final collaboration = await repo.readCollaborationRules(widget.workId);
    if (!mounted) return;
    setState(() => _rules = collaboration.rules);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.aiPreferencesRuleAdded)),
    );
  }

  /// ENH-46：实际会附加到 prompt 的偏好文本（与 AiService 的合并顺序一致）。
  String _previewText() {
    final counts = <String, int>{..._counts};
    for (final entry in _paragraphCounts.entries) {
      counts[entry.key] = (counts[entry.key] ?? 0) + entry.value;
    }
    final task = _previewTask == CollabRuleTask.all ? '' : _previewTask;
    return <String>[
      WritingPreferences.promptBlock(
        reasonCounts: counts,
        samples: _samples,
        preferredTask: task,
      ),
      CollaborationRules.promptBlock(
        rules: _rules,
        banned: _banned,
        task: task,
        scopes: _scopes,
      ),
    ].where((block) => block.isNotEmpty).join('\n\n');
  }

  Widget _buildRuleTile(AppLocalizations l10n, int index) {
    final rule = _rules[index];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(10, 2, 2, 4),
      decoration: BoxDecoration(
        color: context.paper.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '• $rule',
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
              IconButton(
                tooltip: l10n.aiPreferencesRuleEdit,
                onPressed: () => _editRule(index),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit_outlined, size: 16),
              ),
              IconButton(
                tooltip: l10n.commonDelete,
                onPressed: () => _removeRule(rule),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 16),
              ),
            ],
          ),
          Row(
            children: <Widget>[
              ActionChip(
                avatar: const Icon(Icons.filter_alt_outlined, size: 14),
                label: Text(_scopeSummary(l10n, rule)),
                onPressed: () => _changeScopes(rule),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                labelStyle: const TextStyle(fontSize: 11),
              ),
              const Spacer(),
              IconButton(
                tooltip: l10n.aiPreferencesRuleMoveUp,
                onPressed: index == 0 ? null : () => _moveRule(index, -1),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.arrow_upward, size: 15),
              ),
              IconButton(
                tooltip: l10n.aiPreferencesRuleMoveDown,
                onPressed: index == _rules.length - 1
                    ? null
                    : () => _moveRule(index, 1),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.arrow_downward, size: 15),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _reasonLabel(AppLocalizations l10n, String reason) {
    switch (reason) {
      case AiFeedbackReason.offCharacter:
        return l10n.aiFeedbackOffCharacter;
      case AiFeedbackReason.slowPace:
        return l10n.aiFeedbackSlowPace;
      case AiFeedbackReason.offSetting:
        return l10n.aiFeedbackOffSetting;
      case AiFeedbackReason.other:
        return l10n.aiFeedbackOther;
      case AiFeedbackReason.tooAi:
      default:
        return l10n.aiFeedbackTooAi;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final suggestions = AiCliche.suggest(
      rejectedTexts: _rejected,
      banned: _banned,
    );
    final hints = PreferenceDistillation.distill(
      _samples,
      analysisSamples: _analysisSamples,
    );
    final hasPairs =
        _samples.any((sample) => sample.hasSource) ||
        _analysisSamples.any((sample) => sample.hasSource);
    final conflicts = CollaborationRules.conflicts(_rules, scopes: _scopes);
    final preview = _previewText();
    return AlertDialog(
      title: Text(l10n.aiPreferencesTitle),
      content: SizedBox(
        width: 520,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.aiPreferencesDescription,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.paper.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        l10n.aiPreferencesEnabled,
                        style: const TextStyle(fontSize: 14),
                      ),
                      value: _enabled,
                      onChanged: _toggle,
                    ),
                    const Divider(),
                    _sectionTitle(l10n.aiPreferencesRules),
                    Text(
                      l10n.aiPreferencesRulesHint,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.paper.inkSoft,
                      ),
                    ),
                    if (_rules.isEmpty)
                      Text(
                        l10n.aiPreferencesNoRules,
                        style: TextStyle(color: context.paper.inkSoft),
                      )
                    else
                      for (var i = 0; i < _rules.length; i++)
                        _buildRuleTile(l10n, i),
                    if (conflicts.isNotEmpty)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFB3261E,
                          ).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            for (final conflict in conflicts)
                              Text(
                                l10n.aiPreferencesRuleConflict(
                                  conflict.first,
                                  conflict.second,
                                ),
                                style: const TextStyle(
                                  fontSize: 11,
                                  height: 1.4,
                                  color: Color(0xFFB3261E),
                                ),
                              ),
                          ],
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _addRule,
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(l10n.aiPreferencesAddRule),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: Size.zero,
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _sectionTitle(l10n.aiPreferencesBanned),
                    Text(
                      l10n.aiPreferencesBannedHint,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.paper.inkSoft,
                      ),
                    ),
                    if (_banned.isEmpty)
                      Text(
                        l10n.aiPreferencesNoBanned,
                        style: TextStyle(color: context.paper.inkSoft),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: <Widget>[
                            for (final phrase in _banned)
                              InputChip(
                                label: Text('「$phrase」'),
                                onDeleted: () => _removeBanned(phrase),
                                deleteButtonTooltipMessage: l10n.commonDelete,
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                labelStyle: const TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _addBanned,
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(l10n.aiPreferencesAddBanned),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: Size.zero,
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    if (_rejected.isNotEmpty)
                      Text(
                        l10n.aiPreferencesRejectedHint(_rejected.length),
                        style: TextStyle(
                          fontSize: 11,
                          color: context.paper.inkSoft,
                        ),
                      ),
                    if (suggestions.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        l10n.aiPreferencesSuggestions,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        l10n.aiPreferencesSuggestionHint,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.paper.inkSoft,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: <Widget>[
                            for (final phrase in suggestions)
                              ActionChip(
                                avatar: const Icon(Icons.add, size: 14),
                                label: Text(phrase),
                                onPressed: () => _addBanned(phrase),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                labelStyle: const TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    _sectionTitle(l10n.aiPreferencesDistill),
                    Text(
                      l10n.aiPreferencesDistillHint,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.paper.inkSoft,
                      ),
                    ),
                    if (!hasPairs)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          l10n.aiPreferencesDistillEmpty,
                          style: TextStyle(
                            fontSize: 11,
                            color: context.paper.inkSoft,
                          ),
                        ),
                      )
                    else ...<Widget>[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => setState(() => _distillShown = true),
                          icon: const Icon(Icons.auto_awesome, size: 16),
                          label: Text(l10n.aiPreferencesDistillAction),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            minimumSize: Size.zero,
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      if (_distillShown)
                        if (hints.isEmpty)
                          Text(
                            l10n.aiPreferencesDistillEmpty,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.paper.inkSoft,
                            ),
                          )
                        else ...<Widget>[
                          for (final hint in hints)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(top: 6),
                              padding: const EdgeInsets.fromLTRB(10, 8, 4, 4),
                              decoration: BoxDecoration(
                                color: context.paper.background,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    hint.text,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      height: 1.45,
                                    ),
                                  ),
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Text(
                                          <String>[
                                            l10n.aiPreferencesDistillEvidence(
                                              hint.evidence,
                                            ),
                                            if (hint.analysisEvidence > 0)
                                              l10n.aiPreferencesDistillAnalysis(
                                                hint.analysisEvidence,
                                              ),
                                          ].join(' · '),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: context.paper.inkSoft,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            _addHints(<DistilledHint>[hint]),
                                        child: Text(
                                          l10n.aiPreferencesAddToRules,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          if (hints.length > 1)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: () => _addHints(hints),
                                child: Text(l10n.aiPreferencesAddAllRules),
                              ),
                            ),
                        ],
                    ],
                    const SizedBox(height: 12),
                    if (!_hasData)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          l10n.aiPreferencesEmpty,
                          style: TextStyle(color: context.paper.inkSoft),
                        ),
                      )
                    else ...<Widget>[
                      if (_counts.isNotEmpty) ...<Widget>[
                        _sectionTitle(l10n.aiPreferencesReasons),
                        for (final reason in AiFeedbackReason.all)
                          if ((_counts[reason] ?? 0) > 0)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(_reasonLabel(l10n, reason)),
                                  ),
                                  Text(
                                    l10n.aiPreferencesCount(_counts[reason]!),
                                    style: TextStyle(
                                      color: context.paper.inkSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        const SizedBox(height: 12),
                      ],
                      if (_paragraphCounts.isNotEmpty) ...<Widget>[
                        _sectionTitle(l10n.aiPreferencesParagraphReasons),
                        for (final reason in AiFeedbackReason.all)
                          if ((_paragraphCounts[reason] ?? 0) > 0)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(_reasonLabel(l10n, reason)),
                                  ),
                                  Text(
                                    l10n.aiPreferencesCount(
                                      _paragraphCounts[reason]!,
                                    ),
                                    style: TextStyle(
                                      color: context.paper.inkSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        const SizedBox(height: 12),
                      ],
                      _sectionTitle(l10n.aiPreferencesSamples),
                      if (_samples.isEmpty)
                        Text(
                          l10n.aiPreferencesNoSamples,
                          style: TextStyle(color: context.paper.inkSoft),
                        )
                      else
                        for (var i = 0; i < _samples.length; i++)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: context.paper.background,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  '${i + 1}. ${_samples[i].text}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                ),
                                if (_samples[i].hasSource)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      l10n.aiPreferencesPairSource(
                                        _samples[i].source,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        height: 1.4,
                                        color: context.paper.inkSoft,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      const SizedBox(height: 12),
                      _sectionTitle(l10n.aiPreferencesIgnoredConflicts),
                      if (_ignored.isEmpty)
                        Text(
                          l10n.aiPreferencesNoIgnored,
                          style: TextStyle(color: context.paper.inkSoft),
                        )
                      else
                        for (final entry in _ignored)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
                            decoration: BoxDecoration(
                              color: context.paper.background,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        '「${entry.quote}」',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          height: 1.4,
                                        ),
                                      ),
                                      if (entry.source.isNotEmpty ||
                                          entry.reason.isNotEmpty)
                                        Text(
                                          <String>[
                                            if (entry.source.isNotEmpty)
                                              entry.source,
                                            if (entry.reason.isNotEmpty)
                                              entry.reason,
                                          ].join(' · '),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: context.paper.inkSoft,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _restore(entry),
                                  child: Text(
                                    l10n.aiPreferencesRestoreConflict,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      const SizedBox(height: 12),
                      _sectionTitle(l10n.aiPreferencesPreview),
                      Text(
                        l10n.aiPreferencesPreviewHint,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.paper.inkSoft,
                        ),
                      ),
                      Row(
                        children: <Widget>[
                          Text(
                            l10n.aiPreferencesPreviewTask,
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: _previewTask,
                            underline: const SizedBox.shrink(),
                            style: TextStyle(
                              fontSize: 12,
                              color: context.paper.ink,
                            ),
                            items: <DropdownMenuItem<String>>[
                              DropdownMenuItem<String>(
                                value: CollabRuleTask.all,
                                child: Text(l10n.aiPreferencesRuleAllTasks),
                              ),
                              for (final task in CollabRuleTask.selectable)
                                DropdownMenuItem<String>(
                                  value: task,
                                  child: Text(_taskLabel(l10n, task)),
                                ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _previewTask = value);
                            },
                          ),
                          const Spacer(),
                          Text(
                            l10n.aiPreferencesPreviewTokens(
                              estimateTokens(preview),
                            ),
                            style: TextStyle(
                              fontSize: 11,
                              color: context.paper.inkSoft,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: context.paper.background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          preview.isEmpty
                              ? l10n.aiPreferencesPreviewEmpty
                              : preview,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: preview.isEmpty
                                ? context.paper.inkSoft
                                : context.paper.ink,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
      actions: <Widget>[
        if (_hasData && !_loading)
          TextButton(onPressed: _clear, child: Text(l10n.aiPreferencesClear)),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
