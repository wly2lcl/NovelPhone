import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../data/data_providers.dart';
import '../../data/db.dart';
import '../../l10n/l10n.dart';
import '../../models/character_tags.dart';
import 'work_detail_providers.dart';

/// 角色卡 Tab（PRD 5.4）：网格列表 + 新建/编辑/删除。
class CharactersTab extends ConsumerWidget {
  const CharactersTab({super.key, required this.workId});

  final int workId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charactersAsync = ref.watch(charactersProvider(workId));
    final characters = charactersAsync.value ?? const <Character>[];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: characters.isEmpty
          ? const _EmptyCharactersHint()
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.92,
              ),
              itemCount: characters.length,
              itemBuilder: (context, index) =>
                  _CharacterCard(workId: workId, character: characters[index]),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref),
        icon: const Icon(Icons.person_add_alt),
        label: Text(context.l10n.charactersNewCard),
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    Character? character,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CharacterFormSheet(workId: workId, character: character),
    );
  }
}

class _EmptyCharactersHint extends StatelessWidget {
  const _EmptyCharactersHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.groups_outlined, size: 64, color: context.paper.inkSoft),
            const SizedBox(height: 12),
            Text(
              context.l10n.charactersEmptyTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.charactersEmptyHint,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.paper.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({required this.workId, required this.character});

  final int workId;
  final Character character;

  @override
  Widget build(BuildContext context) {
    final tags = decodeTags(character.personalityTags);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) =>
              _CharacterFormSheet(workId: workId, character: character),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: context.paper.accent.withValues(
                      alpha: 0.14,
                    ),
                    child: Text(
                      character.name.characters.first,
                      style: TextStyle(
                        color: context.paper.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      character.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                character.identity.isEmpty
                    ? context.l10n.charactersIdentityEmpty
                    : character.identity,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.paper.inkSoft, fontSize: 13),
              ),
              const Spacer(),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final tag in tags.take(3)) _TagChip(text: tag),
                  if (tags.length > 3) _TagChip(text: '+${tags.length - 3}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: context.paper.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(color: context.paper.accent, fontSize: 12),
      ),
    );
  }
}

/// 角色卡表单（新建与编辑共用），字段见 PRD 5.4。
class _CharacterFormSheet extends ConsumerStatefulWidget {
  const _CharacterFormSheet({required this.workId, this.character});

  final int workId;
  final Character? character;

  @override
  ConsumerState<_CharacterFormSheet> createState() =>
      _CharacterFormSheetState();
}

class _CharacterFormSheetState extends ConsumerState<_CharacterFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _identity;
  late final TextEditingController _aliases;
  late final TextEditingController _tags;
  late final TextEditingController _appearance;
  late final TextEditingController _relations;
  late final TextEditingController _arc;
  String? _nameError;
  String? _tagError;
  bool _saving = false;

  bool get _isEditing => widget.character != null;

  @override
  void initState() {
    super.initState();
    final c = widget.character;
    _name = TextEditingController(text: c?.name ?? '');
    _identity = TextEditingController(text: c?.identity ?? '');
    _aliases = TextEditingController(
      text: c == null ? '' : decodeTags(c.aliases).join(' '),
    );
    _tags = TextEditingController(
      text: c == null ? '' : decodeTags(c.personalityTags).join(' '),
    );
    _appearance = TextEditingController(text: c?.appearance ?? '');
    _relations = TextEditingController(text: c?.relations ?? '');
    _arc = TextEditingController(text: c?.arc ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _identity.dispose();
    _aliases.dispose();
    _tags.dispose();
    _appearance.dispose();
    _relations.dispose();
    _arc.dispose();
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
                    ? context.l10n.charactersEditCard
                    : context.l10n.charactersNewCard,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                maxLength: 20,
                decoration: InputDecoration(
                  labelText: context.l10n.charactersNameLabel,
                  errorText: _nameError,
                ),
              ),
              TextField(
                controller: _identity,
                decoration: InputDecoration(
                  labelText: context.l10n.charactersIdentityLabel,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _aliases,
                decoration: InputDecoration(
                  labelText: context.l10n.charactersAliasesLabel,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tags,
                decoration: InputDecoration(
                  labelText: context.l10n.charactersTagsLabel,
                  errorText: _tagError,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _appearance,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: context.l10n.charactersAppearanceLabel,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _relations,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: context.l10n.charactersRelationsLabel,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _arc,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: context.l10n.charactersArcLabel,
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
    final tags = parseTagInput(_tags.text, max: 11);
    setState(() {
      _nameError = name.isEmpty || name.length > 20
          ? context.l10n.charactersNameError
          : null;
      _tagError = tags.length > 10 ? context.l10n.charactersTagsError : null;
    });
    if (_nameError != null || _tagError != null) return;

    setState(() => _saving = true);
    final repository = ref.read(characterRepositoryProvider);
    final encodedTags = encodeTags(tags);
    final encodedAliases = encodeTags(parseTagInput(_aliases.text, max: 8));
    final identity = _identity.text.trim();
    final appearance = _appearance.text.trim();
    final relations = _relations.text.trim();
    final arc = _arc.text.trim();
    try {
      if (_isEditing) {
        await repository.updateCharacter(
          id: widget.character!.id,
          name: name,
          identity: identity,
          personalityTags: encodedTags,
          aliases: encodedAliases,
          appearance: appearance,
          relations: relations,
          arc: arc,
        );
      } else {
        await repository.createCharacter(
          workId: widget.workId,
          name: name,
          identity: identity,
          personalityTags: encodedTags,
          aliases: encodedAliases,
          appearance: appearance,
          relations: relations,
          arc: arc,
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
          dialogContext.l10n.charactersDeleteConfirm(widget.character!.name),
        ),
        content: Text(dialogContext.l10n.charactersDeleteBody),
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
    await ref
        .read(characterRepositoryProvider)
        .deleteCharacter(widget.character!.id);
    if (mounted) Navigator.of(context).pop();
  }
}
