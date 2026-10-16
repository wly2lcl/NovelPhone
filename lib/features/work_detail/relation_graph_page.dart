import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../data/data_providers.dart';
import '../../data/db.dart';
import '../../l10n/l10n.dart';
import 'work_detail_providers.dart';

/// 人物关系图（B-09）：环形节点 + 关系连线，下方为可编辑的关系列表。
class RelationGraphPage extends ConsumerWidget {
  const RelationGraphPage({super.key, required this.workId});

  final int workId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final characters =
        ref.watch(charactersProvider(workId)).value ?? const <Character>[];
    final relations =
        ref.watch(characterRelationsProvider(workId)).value ??
        const <CharacterRelation>[];
    final nameById = <int, String>{for (final c in characters) c.id: c.name};

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.relationGraphTitle)),
      body: Column(
        children: <Widget>[
          SizedBox(
            height: 300,
            width: double.infinity,
            child: characters.length < 2
                ? const _EmptyGraphHint()
                : CustomPaint(
                    painter: _RelationGraphPainter(
                      characters: characters,
                      relations: relations,
                      palette: context.paper,
                    ),
                  ),
          ),
          const Divider(),
          Expanded(
            child: relations.isEmpty
                ? Center(
                    child: Text(
                      context.l10n.relationGraphEmpty,
                      style: TextStyle(color: context.paper.inkSoft),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: relations.length,
                    itemBuilder: (context, index) {
                      final relation = relations[index];
                      final from =
                          nameById[relation.fromCharacterId] ??
                          context.l10n.relationGraphDeletedCharacter;
                      final to =
                          nameById[relation.toCharacterId] ??
                          context.l10n.relationGraphDeletedCharacter;
                      return ListTile(
                        title: Text('$from → $to'),
                        subtitle: relation.label.isEmpty
                            ? null
                            : Text(
                                relation.label,
                                style: TextStyle(color: context.paper.inkSoft),
                              ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            IconButton(
                              tooltip: context.l10n.commonEdit,
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: characters.length < 2
                                  ? null
                                  : () => _openEditor(
                                      context,
                                      ref,
                                      characters: characters,
                                      relation: relation,
                                    ),
                            ),
                            IconButton(
                              tooltip: context.l10n.commonDelete,
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => ref
                                  .read(characterRepositoryProvider)
                                  .deleteRelation(relation.id),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: characters.length < 2
          ? null
          : FloatingActionButton.extended(
              onPressed: () =>
                  _openEditor(context, ref, characters: characters),
              icon: const Icon(Icons.add),
              label: Text(context.l10n.relationGraphAdd),
            ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    required List<Character> characters,
    CharacterRelation? relation,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RelationFormSheet(
        workId: workId,
        characters: characters,
        relation: relation,
      ),
    );
  }
}

class _EmptyGraphHint extends StatelessWidget {
  const _EmptyGraphHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          context.l10n.relationGraphMinCharacters,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.paper.inkSoft),
        ),
      ),
    );
  }
}

/// 环形布局的关系图：节点均布在圆周上，关系以带标签的直线相连。
class _RelationGraphPainter extends CustomPainter {
  _RelationGraphPainter({
    required this.characters,
    required this.relations,
    required this.palette,
  });

  final List<Character> characters;
  final List<CharacterRelation> relations;
  final PaperPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    if (characters.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 34;
    final positions = <int, Offset>{};
    for (var i = 0; i < characters.length; i++) {
      final angle = -math.pi / 2 + 2 * math.pi * i / characters.length;
      positions[characters[i].id] =
          center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
    }

    final edgePaint = Paint()
      ..color = palette.divider
      ..strokeWidth = 1.5;
    for (final relation in relations) {
      final from = positions[relation.fromCharacterId];
      final to = positions[relation.toCharacterId];
      if (from == null || to == null) continue;
      canvas.drawLine(from, to, edgePaint);
      if (relation.label.isNotEmpty) {
        _paintText(
          canvas,
          relation.label,
          Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2),
          color: palette.inkSoft,
          fontSize: 10,
        );
      }
    }

    final fillPaint = Paint()..color = palette.surface;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = palette.accent
      ..strokeWidth = 1.5;
    for (final character in characters) {
      final p = positions[character.id]!;
      canvas.drawCircle(p, 20, fillPaint);
      canvas.drawCircle(p, 20, strokePaint);
      _paintText(canvas, character.name, p, color: palette.ink, fontSize: 11);
    }
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset center, {
    required Color color,
    required double fontSize,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 76);
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _RelationGraphPainter oldDelegate) {
    return oldDelegate.characters != characters ||
        oldDelegate.relations != relations ||
        oldDelegate.palette != palette;
  }
}

/// 关系表单（添加与编辑共用）：选择两端角色并填写关系标签。
class _RelationFormSheet extends ConsumerStatefulWidget {
  const _RelationFormSheet({
    required this.workId,
    required this.characters,
    this.relation,
  });

  final int workId;
  final List<Character> characters;
  final CharacterRelation? relation;

  @override
  ConsumerState<_RelationFormSheet> createState() => _RelationFormSheetState();
}

class _RelationFormSheetState extends ConsumerState<_RelationFormSheet> {
  late final TextEditingController _label;
  int? _fromId;
  int? _toId;
  String? _error;
  bool _saving = false;

  bool get _isEditing => widget.relation != null;

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: widget.relation?.label ?? '');
    _fromId = widget.relation?.fromCharacterId;
    _toId = widget.relation?.toCharacterId;
  }

  @override
  void dispose() {
    _label.dispose();
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
                    ? context.l10n.relationGraphEdit
                    : context.l10n.relationGraphAdd,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _fromId,
                decoration: InputDecoration(
                  labelText: context.l10n.relationGraphCharacterA,
                ),
                items: <DropdownMenuItem<int>>[
                  for (final c in widget.characters)
                    DropdownMenuItem<int>(value: c.id, child: Text(c.name)),
                ],
                onChanged: (value) => setState(() {
                  _fromId = value;
                  _error = null;
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _toId,
                decoration: InputDecoration(
                  labelText: context.l10n.relationGraphCharacterB,
                  errorText: _error,
                ),
                items: <DropdownMenuItem<int>>[
                  for (final c in widget.characters)
                    DropdownMenuItem<int>(value: c.id, child: Text(c.name)),
                ],
                onChanged: (value) => setState(() {
                  _toId = value;
                  _error = null;
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _label,
                decoration: InputDecoration(
                  labelText: context.l10n.relationGraphLabelField,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
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
    final from = _fromId;
    final to = _toId;
    if (from == null || to == null || from == to) {
      setState(() => _error = context.l10n.relationGraphSelectTwo);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final repository = ref.read(characterRepositoryProvider);
    final label = _label.text.trim();
    try {
      if (_isEditing) {
        await repository.updateRelation(
          id: widget.relation!.id,
          fromCharacterId: from,
          toCharacterId: to,
          label: label,
        );
      } else {
        await repository.createRelation(
          workId: widget.workId,
          fromCharacterId: from,
          toCharacterId: to,
          label: label,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
