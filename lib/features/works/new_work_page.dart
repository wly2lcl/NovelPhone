import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/data_providers.dart';
import '../../data/repositories/work_repository.dart';
import '../../l10n/l10n.dart';
import '../../models/work_cover_colors.dart';

/// 新建作品表单（PRD 5.1）：标题必填 1-50 字，封面色块从 8 色预设中选择。
class NewWorkPage extends ConsumerStatefulWidget {
  const NewWorkPage({super.key});

  @override
  ConsumerState<NewWorkPage> createState() => _NewWorkPageState();
}

class _NewWorkPageState extends ConsumerState<NewWorkPage> {
  final TextEditingController _titleController = TextEditingController();
  late int _coverColor = WorkCoverColors.random();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = context.l10n.newWorkTitleRequired);
      return;
    }
    if (title.characters.length > 50) {
      setState(() => _error = context.l10n.newWorkTitleMax(50));
      return;
    }

    setState(() {
      _error = null;
      _submitting = true;
    });

    final repository = ref.read(workRepositoryProvider);
    try {
      if (await repository.countWorks() >= WorkRepository.maxWorks) {
        setState(() {
          _submitting = false;
          _error = context.l10n.worksLimitReached(WorkRepository.maxWorks);
        });
        return;
      }
      final workId = await repository.createWork(
        title: title,
        coverColor: _coverColor,
      );
      if (!mounted) return;
      context.pushReplacement('/work/$workId');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = context.l10n.commonCreateFailed('$error');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.worksNew)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(
            context.l10n.newWorkTitleLabel,
            style: TextStyle(color: context.paper.inkSoft),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            autofocus: true,
            maxLength: 50,
            decoration: InputDecoration(
              hintText: context.l10n.newWorkTitleHint,
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.newWorkCoverLabel,
            style: TextStyle(color: context.paper.inkSoft),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: WorkCoverColors.palette.indexed.map((entry) {
              final (index, color) = entry;
              final selected = color.toARGB32() == _coverColor;
              return Semantics(
                button: true,
                selected: selected,
                label: context.l10n.newWorkCoverOptionLabel(index + 1),
                onTap: () => setState(() => _coverColor = color.toARGB32()),
                child: GestureDetector(
                  excludeFromSemantics: true,
                  onTap: () => setState(() => _coverColor = color.toARGB32()),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? context.paper.ink
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(
              _submitting
                  ? context.l10n.newWorkCreating
                  : context.l10n.newWorkCreate,
            ),
          ),
        ],
      ),
    );
  }
}
