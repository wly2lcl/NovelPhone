import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/data_providers.dart';

/// AI 功能首次联网前的告知（M4-16，COMPLIANCE §3）。
///
/// 返回 true 表示已确认（或此前已确认过），调用方可以继续发起联网请求；
/// 返回 false 表示用户取消，调用方应中止本次 AI 操作。
const String aiNoticeTitle = '使用 AI 前请知悉';

const String aiNoticeBody = '你的作品正文与设定默认只保存在本机。'
    '当你使用 AI 功能时，应用会把你自行配置的模型服务商所需的最小上下文'
    '（当前章节内容、章纲、相关角色卡等）通过网络直接发送给你配置的服务商，'
    '不会经过 NovelPhone 的服务器。\n\n'
    '你的 API Key 保存在设备安全区，不会上传。\n\n'
    '点击"我已了解"表示你已知悉并同意上述传输行为。';

Future<bool> ensureAiNotice(BuildContext context, WidgetRef ref) async {
  final settings = ref.read(settingsRepositoryProvider);
  if (await settings.hasConfirmedAiNotice()) return true;
  if (!context.mounted) return false;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text(aiNoticeTitle),
      content: const Text(aiNoticeBody),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('我已了解'),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  await settings.confirmAiNotice();
  return true;
}