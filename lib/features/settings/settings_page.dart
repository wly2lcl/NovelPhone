import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/data_providers.dart';
import 'backup_actions.dart';

/// 设置页（M1 为占位，M2 补备份引导，M3 落地模型组 / key / 统计）。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: <Widget>[
          const _SectionTitle('AI 与模型'),
          ListTile(
            leading: const Icon(Icons.key_outlined),
            title: const Text('模型组与 API Key'),
            subtitle: const Text('按服务商管理 key、baseUrl、模型列表与生成参数'),
            trailing: Icon(Icons.chevron_right, color: context.paper.inkSoft),
            onTap: () => context.push('/settings/model-groups'),
          ),
          ListTile(
            leading: const Icon(Icons.alt_route),
            title: const Text('任务与模型映射'),
            subtitle: const Text('为续写、灵感、AI 感检查分别指定模型组'),
            trailing: Icon(Icons.chevron_right, color: context.paper.inkSoft),
            onTap: () => context.push('/settings/task-mapping'),
          ),
          ListTile(
            leading: const Icon(Icons.insights_outlined),
            title: const Text('Token 与采纳统计'),
            trailing: Icon(Icons.chevron_right, color: context.paper.inkSoft),
            onTap: () => context.push('/settings/token-stats'),
          ),
          ListTile(
            leading: const Icon(Icons.hub_outlined),
            title: const Text('MCP 工具服务'),
            subtitle: const Text('接入远程 MCP server，把其工具提供给 AI 调用'),
            trailing: Icon(Icons.chevron_right, color: context.paper.inkSoft),
            onTap: () => context.push('/settings/mcp-servers'),
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: const Text('自定义技能'),
            subtitle: const Text('附加指令与工具白名单，注入续写与灵感生成'),
            trailing: Icon(Icons.chevron_right, color: context.paper.inkSoft),
            onTap: () => context.push('/settings/skills'),
          ),
          const Divider(),
          const _SectionTitle('写作'),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text('写作外观'),
            subtitle: const Text('夜间纸张、正文字号与行距'),
            trailing: Icon(Icons.chevron_right, color: context.paper.inkSoft),
            onTap: () => context.push('/settings/appearance'),
          ),
          const _ThemeModeTile(),
          ListTile(
            leading: const Icon(Icons.local_fire_department_outlined),
            title: const Text('写作统计'),
            subtitle: const Text('每日字数目标、连续写作天数与番茄钟'),
            trailing: Icon(Icons.chevron_right, color: context.paper.inkSoft),
            onTap: () => context.push('/settings/writing-stats'),
          ),
          const Divider(),
          const _SectionTitle('数据'),
          const _BackupHint(),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('备份到文件'),
            subtitle: const Text('导出全部作品与正文，用于换机或防丢失'),
            trailing: Icon(Icons.chevron_right, color: context.paper.inkSoft),
            onTap: () => exportBackup(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('从备份恢复'),
            subtitle: const Text('选择备份文件，可合并为新作品或覆盖本机数据'),
            trailing: Icon(Icons.chevron_right, color: context.paper.inkSoft),
            onTap: () => restoreBackup(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('云备份'),
            subtitle: const Text('备份到你自己的对象存储（S3 / OSS / COS 等），默认关闭'),
            trailing: Icon(Icons.chevron_right, color: context.paper.inkSoft),
            onTap: () => context.push('/settings/cloud-backup'),
          ),
        ],
      ),
    );
  }
}

/// 备份引导（M2-18）：作品数据全在本机，换机前务必先备份。
class _BackupHint extends StatelessWidget {
  const _BackupHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.paper.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline, size: 18, color: context.paper.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '作品数据全部保存在本机。卸载应用或换机前，请先「备份到文件」，'
              '否则数据将无法找回。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(text, style: TextStyle(color: context.paper.inkSoft)),
    );
  }
}

/// 全局深浅模式：跟随系统 / 浅色 / 深色，写入后全应用立即生效。
class _ThemeModeTile extends ConsumerWidget {
  const _ThemeModeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode =
        ref.watch(appThemeModeProvider).value ?? AppThemeMode.system;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.brightness_6_outlined, color: context.paper.ink),
              const SizedBox(width: 12),
              const Text('深浅模式'),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<AppThemeMode>(
              showSelectedIcon: false,
              segments: <ButtonSegment<AppThemeMode>>[
                for (final m in AppThemeMode.values)
                  ButtonSegment<AppThemeMode>(
                    value: m,
                    label: Text(m.label),
                  ),
              ],
              selected: <AppThemeMode>{mode},
              onSelectionChanged: (selection) async {
                await ref
                    .read(settingsRepositoryProvider)
                    .setSetting(AppThemeMode.settingKey, selection.first.value);
                ref.invalidate(appThemeModeProvider);
              },
            ),
          ),
        ],
      ),
    );
  }
}