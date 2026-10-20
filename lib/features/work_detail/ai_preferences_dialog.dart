import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/ai/continuity_suppression.dart';
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

  bool get _hasData =>
      _counts.isNotEmpty ||
      _paragraphCounts.isNotEmpty ||
      _samples.isNotEmpty ||
      _ignored.isNotEmpty;

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
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _counts = counts;
      _paragraphCounts = paragraphCounts;
      _samples = samples;
      _ignored = ignored;
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
