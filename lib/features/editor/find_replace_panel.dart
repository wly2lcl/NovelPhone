import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'editor_controller.dart';

/// 查找替换面板（PRD 5.3）：本章关键词查找、命中数、单个/全部替换、大小写选项。
class FindReplacePanel extends StatefulWidget {
  const FindReplacePanel({
    super.key,
    required this.controller,
    required this.onClose,
  });

  final EditorController controller;
  final VoidCallback onClose;

  @override
  State<FindReplacePanel> createState() => _FindReplacePanelState();
}

class _FindReplacePanelState extends State<FindReplacePanel> {
  final TextEditingController _keyword = TextEditingController();
  final TextEditingController _replacement = TextEditingController();
  bool _caseSensitive = false;
  int _count = 0;

  @override
  void dispose() {
    _keyword.dispose();
    _replacement.dispose();
    super.dispose();
  }

  void _refreshCount() {
    setState(() {
      _count = widget.controller.countMatches(
        _keyword.text,
        caseSensitive: _caseSensitive,
      );
    });
  }

  void _replaceNext() {
    widget.controller.replaceNext(
      _keyword.text,
      _replacement.text,
      caseSensitive: _caseSensitive,
    );
    _refreshCount();
  }

  void _replaceAll() {
    final replaced = widget.controller.replaceAll(
      _keyword.text,
      _replacement.text,
      caseSensitive: _caseSensitive,
    );
    _refreshCount();
    if (replaced > 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已替换 $replaced 处')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.paper.surface,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _keyword,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: '查找',
                    isDense: true,
                  ),
                  onChanged: (_) => _refreshCount(),
                ),
              ),
              IconButton(
                tooltip: '区分大小写',
                isSelected: _caseSensitive,
                icon: const Icon(Icons.text_fields),
                selectedIcon: Icon(
                  Icons.text_fields,
                  color: context.paper.accent,
                ),
                onPressed: () {
                  setState(() => _caseSensitive = !_caseSensitive);
                  _refreshCount();
                },
              ),
              Text('$_count 处', style: TextStyle(color: context.paper.inkSoft)),
              IconButton(
                tooltip: '关闭',
                icon: const Icon(Icons.close),
                onPressed: widget.onClose,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _replacement,
                  decoration: const InputDecoration(
                    hintText: '替换为',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: _keyword.text.isEmpty ? null : _replaceNext,
                child: const Text('替换'),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: _keyword.text.isEmpty ? null : _replaceAll,
                child: const Text('全部替换'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
