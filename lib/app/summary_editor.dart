import 'package:flutter/material.dart';

import 'theme.dart';

/// 摘要类文本编辑弹窗（本章梗概 / 本章 AI 摘要 / 本卷前情回顾共用）。
///
/// 弹窗退场动画期间 showDialog 的 builder 会再次执行；若在 showDialog 返回后立刻
/// dispose 外部持有的 TextEditingController，会命中「A TextEditingController was
/// used after being disposed」并连带整页崩溃。因此这里改用由文本框自身管理生命
/// 周期的 initialValue，不持有外部 controller，onChanged 只写入局部变量。
/// 新增任何弹窗输入框都必须沿用该写法。
Future<void> showSummaryEditor(
  BuildContext context, {
  required String initial,
  required Future<void> Function(String summary) onSave,
  String title = '编辑本章梗概',
  String hintText = '说明本章要发生什么（0-1000 字）；AI 章纲扩写也以此为一句话梗概',
  int maxLines = 8,
  String? notice,
}) async {
  var text = initial;
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (notice != null && notice.isNotEmpty) ...<Widget>[
            Text(
              notice,
              style: TextStyle(fontSize: 12, color: dialogContext.paper.accent),
            ),
            const SizedBox(height: 8),
          ],
          TextFormField(
            initialValue: initial,
            autofocus: true,
            maxLines: maxLines,
            maxLength: 1000,
            onChanged: (value) => text = value,
            decoration: InputDecoration(hintText: hintText),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(text.trim()),
          child: const Text('保存'),
        ),
      ],
    ),
  );
  if (result == null || result.length > 1000) return;
  await onSave(result);
}
