import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../data/data_providers.dart';
import '../../data/db.dart';
import '../../l10n/l10n.dart';
import '../../models/setting_type.dart';
import 'work_detail_providers.dart';

/// 设定类型展示文案：SettingType.label 保持不动（存储/提示词兼容），
/// UI 展示统一走共享 l10n 键。
String _settingTypeLabel(AppLocalizations l10n, SettingType type) {
  return switch (type) {
    SettingType.worldview => l10n.settingTypeWorldview,
    SettingType.location => l10n.settingTypeLocation,
    SettingType.item => l10n.settingTypeItem,
  };
}

/// 设定集 Tab（B-09）：世界观 / 地点 / 道具三类条目的展示与编辑。
class WorldbuildingTab extends ConsumerStatefulWidget {
  const WorldbuildingTab({super.key, required this.workId});

  final int workId;

  @override
  ConsumerState<WorldbuildingTab> createState() => _WorldbuildingTabState();
}

class _WorldbuildingTabState extends ConsumerState<WorldbuildingTab> {
  SettingType _filter = SettingType.worldview;

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(settingEntriesProvider(widget.workId));
    final entries = (entriesAsync.value ?? const <SettingEntry>[])
        .where((e) => e.type == _filter.value)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: <Widget>[
                for (final type in SettingType.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_settingTypeLabel(context.l10n, type)),
                      selected: _filter == type,
                      onSelected: (_) => setState(() => _filter = type),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? _EmptySettingsHint(type: _filter)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: entries.length,
                    itemBuilder: (context, index) => _SettingCard(
                      entry: entries[index],
                      onTap: () => _openEditor(context, entry: entries[index]),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, initialType: _filter),
        icon: const Icon(Icons.add),
        label: Text(context.l10n.worldbuildingNewEntry),
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context, {
    SettingEntry? entry,
    SettingType? initialType,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SettingFormSheet(
        workId: widget.workId,
        entry: entry,
        initialType: initialType ?? SettingType.worldview,
      ),
    );
  }
}

class _EmptySettingsHint extends StatelessWidget {
  const _EmptySettingsHint({required this.type});

  final SettingType type;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.auto_stories_outlined,
              size: 64,
              color: context.paper.inkSoft,
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.worldbuildingEmptyTitle(
                _settingTypeLabel(context.l10n, type),
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.worldbuildingEmptyHint(
                _settingTypeLabel(context.l10n, type),
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.paper.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({required this.entry, required this.onTap});

  final SettingEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    _settingTypeLabel(
                      context.l10n,
                      SettingType.fromValue(entry.type),
                    ),
                    style: TextStyle(color: context.paper.accent, fontSize: 12),
                  ),
                ],
              ),
              if (entry.content.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  entry.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.paper.inkSoft, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 设定条目表单（新建与编辑共用）。
class _SettingFormSheet extends ConsumerStatefulWidget {
  const _SettingFormSheet({
    required this.workId,
    required this.initialType,
    this.entry,
  });

  final int workId;
  final SettingType initialType;
  final SettingEntry? entry;

  @override
  ConsumerState<_SettingFormSheet> createState() => _SettingFormSheetState();
}

class _SettingFormSheetState extends ConsumerState<_SettingFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _content;
  late SettingType _type;
  String? _nameError;
  bool _saving = false;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _name = TextEditingController(text: e?.name ?? '');
    _content = TextEditingController(text: e?.content ?? '');
    _type = e == null ? widget.initialType : SettingType.fromValue(e.type);
  }

  @override
  void dispose() {
    _name.dispose();
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _isEditing
                    ? context.l10n.worldbuildingEditEntry
                    : context.l10n.worldbuildingNewEntry,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  for (final type in SettingType.values)
                    ChoiceChip(
                      label: Text(_settingTypeLabel(context.l10n, type)),
                      selected: _type == type,
                      onSelected: (_) => setState(() => _type = type),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                maxLength: 50,
                decoration: InputDecoration(
                  labelText: context.l10n.worldbuildingNameLabel,
                  errorText: _nameError,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _content,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: context.l10n.worldbuildingContentLabel,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  if (_isEditing)
                    TextButton.icon(
                      onPressed: _saving ? null : _confirmDelete,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Color(0xFFB3261E),
                      ),
                      label: Text(
                        context.l10n.commonDelete,
                        style: const TextStyle(color: Color(0xFFB3261E)),
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(context.l10n.commonCancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(context.l10n.commonSave),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    setState(() {
      _nameError = name.isEmpty || name.length > 50
          ? context.l10n.worldbuildingNameError
          : null;
    });
    if (_nameError != null) return;

    setState(() => _saving = true);
    final repository = ref.read(settingRepositoryProvider);
    final content = _content.text.trim();
    try {
      if (_isEditing) {
        await repository.updateEntry(
          id: widget.entry!.id,
          type: _type,
          name: name,
          content: content,
        );
      } else {
        await repository.createEntry(
          workId: widget.workId,
          type: _type,
          name: name,
          content: content,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          dialogContext.l10n.worldbuildingDeleteConfirm(widget.entry!.name),
        ),
        content: Text(dialogContext.l10n.worldbuildingDeleteBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(settingRepositoryProvider).deleteEntry(widget.entry!.id);
    if (mounted) Navigator.of(context).pop();
  }
}
