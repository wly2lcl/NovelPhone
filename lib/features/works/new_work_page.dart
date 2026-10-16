import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/data_providers.dart';
import '../../data/repositories/work_repository.dart';
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
      setState(() => _error = '请填写作品标题');
      return;
    }
    if (title.characters.length > 50) {
      setState(() => _error = '标题最多 50 字');
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
          _error = '作品数量已达上限 ${WorkRepository.maxWorks} 部';
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
        _error = '创建失败：$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新建作品')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text('作品标题', style: TextStyle(color: context.paper.inkSoft)),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            autofocus: true,
            maxLength: 50,
            decoration: InputDecoration(hintText: '例如：长夜行', errorText: _error),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          Text('封面色块', style: TextStyle(color: context.paper.inkSoft)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: WorkCoverColors.palette.map((color) {
              final selected = color.toARGB32() == _coverColor;
              return GestureDetector(
                onTap: () => setState(() => _coverColor = color.toARGB32()),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? context.paper.ink : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(_submitting ? '创建中…' : '创建作品'),
          ),
        ],
      ),
    );
  }
}
