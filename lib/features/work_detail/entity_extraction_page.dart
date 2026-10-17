import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/ai/structured_response.dart';
import '../../data/data_providers.dart';
import '../../l10n/l10n.dart';
import '../../models/character_tags.dart';
import '../../models/setting_type.dart';
import '../ai/ai_providers.dart';
import '../ai/ai_service.dart';

/// AI 设定补全（ENH-23）：从正文抽取角色 / 设定，预览去重后一键建档。
class EntityExtractionPage extends ConsumerStatefulWidget {
  const EntityExtractionPage({super.key, required this.workId});

  final int workId;

  @override
  ConsumerState<EntityExtractionPage> createState() =>
      _EntityExtractionPageState();
}

class _EntityExtractionPageState extends ConsumerState<EntityExtractionPage> {
  bool _running = false;
  bool _applying = false;
  String? _error;
  EntityExtraction? _result;
  final Set<int> _selectedCharacters = <int>{};
  final Set<int> _selectedSettings = <int>{};
  final Set<String> _existingCharacters = <String>{};
  final Set<String> _existingSettings = <String>{};
  int _appliedCharacters = 0;
  int _appliedSettings = 0;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final characters = await ref
        .read(characterRepositoryProvider)
        .listCharacters(widget.workId);
    final settings = await ref
        .read(settingRepositoryProvider)
        .listEntries(widget.workId);
    if (!mounted) return;
    setState(() {
      _existingCharacters
        ..clear()
        ..addAll(characters.map((c) => c.name.trim().toLowerCase()));
      _existingSettings
        ..clear()
        ..addAll(
          settings.map((s) => '${s.type}|${s.name.trim().toLowerCase()}'),
        );
    });
  }

  bool _characterExists(ExtractedCharacter character) =>
      _existingCharacters.contains(character.name.trim().toLowerCase());

  bool _settingExists(ExtractedSetting setting) => _existingSettings.contains(
    '${setting.type.value}|${setting.name.trim().toLowerCase()}',
  );

  Future<void> _extract() async {
    final l10n = context.l10n;
    final ready = await ref.read(aiServiceProvider).isReady('extract');
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
    setState(() {
      _running = true;
      _error = null;
      _result = null;
      _selectedCharacters.clear();
      _selectedSettings.clear();
      _appliedCharacters = 0;
      _appliedSettings = 0;
    });
    try {
      await _loadExisting();
      final result = await ref
          .read(aiServiceProvider)
          .extractEntities(workId: widget.workId);
      if (!mounted) return;
      if (result.extraction.parseFailed) {
        setState(() {
          _error = l10n.entityExtractParseFailed;
          _running = false;
        });
        return;
      }
      final extraction = result.extraction;
      setState(() {
        _result = extraction;
        _running = false;
        for (var i = 0; i < extraction.characters.length; i++) {
          if (!_characterExists(extraction.characters[i])) {
            _selectedCharacters.add(i);
          }
        }
        for (var i = 0; i < extraction.settings.length; i++) {
          if (!_settingExists(extraction.settings[i])) {
            _selectedSettings.add(i);
          }
        }
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
        _error = l10n.entityExtractFailed(e.message);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _error = l10n.entityExtractFailed('$e');
      });
    }
  }

  Future<void> _apply() async {
    final extraction = _result;
    if (extraction == null) return;
    setState(() => _applying = true);
    final characterRepo = ref.read(characterRepositoryProvider);
    final settingRepo = ref.read(settingRepositoryProvider);
    var characters = 0;
    var settings = 0;
    for (final index in _selectedCharacters.toList()..sort()) {
      final item = extraction.characters[index];
      if (index >= extraction.characters.length || _characterExists(item)) {
        continue;
      }
      await characterRepo.createCharacter(
        workId: widget.workId,
        name: item.name,
        identity: item.identity,
        personalityTags: encodeTags(
          parseTagInput(item.personality.replaceAll(RegExp(r'[;；]'), ' ')),
        ),
        appearance: item.appearance,
        relations: item.relations,
        arc: item.arc,
      );
      characters++;
    }
    for (final index in _selectedSettings.toList()..sort()) {
      final item = extraction.settings[index];
      if (index >= extraction.settings.length || _settingExists(item)) continue;
      await settingRepo.createEntry(
        workId: widget.workId,
        type: item.type,
        name: item.name,
        content: item.content,
      );
      settings++;
    }
    if (!mounted) return;
    setState(() {
      _applying = false;
      _appliedCharacters = characters;
      _appliedSettings = settings;
      _selectedCharacters.clear();
      _selectedSettings.clear();
    });
    await _loadExisting();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.entityExtractApplied(characters, settings)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final extraction = _result;
    final selectedCount = _selectedCharacters.length + _selectedSettings.length;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.entityExtractTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: <Widget>[
          Text(
            l10n.entityExtractIntro,
            style: TextStyle(color: context.paper.inkSoft, height: 1.5),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _running || _applying ? null : _extract,
            icon: _running
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 1.8),
                  )
                : const Icon(Icons.auto_awesome, size: 18),
            label: Text(
              _running ? l10n.entityExtractRunning : l10n.entityExtractStart,
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
          if (extraction != null && extraction.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                l10n.entityExtractEmpty,
                style: TextStyle(color: context.paper.inkSoft),
              ),
            ),
          if (extraction != null && extraction.characters.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              l10n.entityExtractCharacters,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (var i = 0; i < extraction.characters.length; i++)
              _CharacterTile(
                character: extraction.characters[i],
                existing: _characterExists(extraction.characters[i]),
                selected: _selectedCharacters.contains(i),
                onChanged: (value) {
                  setState(() {
                    if (value) {
                      _selectedCharacters.add(i);
                    } else {
                      _selectedCharacters.remove(i);
                    }
                  });
                },
              ),
          ],
          if (extraction != null && extraction.settings.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              l10n.entityExtractSettings,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (var i = 0; i < extraction.settings.length; i++)
              _SettingTile(
                setting: extraction.settings[i],
                existing: _settingExists(extraction.settings[i]),
                selected: _selectedSettings.contains(i),
                onChanged: (value) {
                  setState(() {
                    if (value) {
                      _selectedSettings.add(i);
                    } else {
                      _selectedSettings.remove(i);
                    }
                  });
                },
              ),
          ],
          if (_appliedCharacters + _appliedSettings > 0)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                l10n.entityExtractApplied(_appliedCharacters, _appliedSettings),
                style: TextStyle(color: context.paper.inkSoft),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: selectedCount == 0 || _applying ? null : _apply,
            child: Text(l10n.entityExtractApply(selectedCount)),
          ),
        ),
      ),
    );
  }
}

class _CharacterTile extends StatelessWidget {
  const _CharacterTile({
    required this.character,
    required this.existing,
    required this.selected,
    required this.onChanged,
  });

  final ExtractedCharacter character;
  final bool existing;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final subtitle = <String>[
      if (character.identity.isNotEmpty) character.identity,
      if (character.personality.isNotEmpty) character.personality,
      if (character.appearance.isNotEmpty) character.appearance,
    ].join(' · ');
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      value: selected,
      onChanged: existing ? null : (v) => onChanged(v ?? false),
      title: Row(
        children: <Widget>[
          Expanded(child: Text(character.name)),
          if (existing)
            Text(
              l10n.entityExtractExisting,
              style: TextStyle(fontSize: 12, color: context.paper.inkSoft),
            ),
        ],
      ),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.setting,
    required this.existing,
    required this.selected,
    required this.onChanged,
  });

  final ExtractedSetting setting;
  final bool existing;
  final bool selected;
  final ValueChanged<bool> onChanged;

  String _typeLabel(BuildContext context) {
    final l10n = context.l10n;
    switch (setting.type) {
      case SettingType.location:
        return l10n.settingTypeLocation;
      case SettingType.item:
        return l10n.settingTypeItem;
      case SettingType.worldview:
        return l10n.settingTypeWorldview;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      value: selected,
      onChanged: existing ? null : (v) => onChanged(v ?? false),
      title: Row(
        children: <Widget>[
          Expanded(child: Text('[${_typeLabel(context)}] ${setting.name}')),
          if (existing)
            Text(
              l10n.entityExtractExisting,
              style: TextStyle(fontSize: 12, color: context.paper.inkSoft),
            ),
        ],
      ),
      subtitle: setting.content.isEmpty ? null : Text(setting.content),
    );
  }
}
