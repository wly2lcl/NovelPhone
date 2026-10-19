import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
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
  List<AdoptedSample> _samples = const <AdoptedSample>[];

  bool get _hasData => _counts.isNotEmpty || _samples.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(settingsRepositoryProvider);
    final enabled = await repo.readAiPreferencesEnabled(widget.workId);
    final counts = await repo.readAiFeedback(widget.workId);
    final samples = await repo.readAdoptedSamples(widget.workId);
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _counts = counts;
      _samples = samples;
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
    if (!mounted) return;
    setState(() {
      _counts = const <String, int>{};
      _samples = const <AdoptedSample>[];
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.aiPreferencesCleared)));
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
                            child: Text(
                              '${i + 1}. ${_samples[i].text}',
                              style: const TextStyle(fontSize: 13, height: 1.5),
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
