import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/locale.dart';
import '../../app/theme.dart';
import '../../data/data_providers.dart';
import '../../l10n/l10n.dart';
import 'backup_actions.dart';

/// 设置页（M1 为占位，M2 补备份引导，M3 落地模型组 / key / 统计）。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.commonSettings)),
      body: ListView(
        children: <Widget>[
          _SectionTitle(l10n.settingsSectionAiModels),
          ListTile(
            leading: const Icon(Icons.key_outlined),
            title: Text(l10n.settingsModelGroups),
            subtitle: Text(l10n.settingsModelGroupsSubtitle),
            trailing: Icon(Icons.chevron_right, color: context.paper.inkSoft),
            onTap: () => context.push('/settings/model-groups'),
          ),
          ListTile(
            leading: const Icon(Icons.alt_route),
            title: Text(l10n.settingsTaskMapping),
            subtitle: Text(l10n.settingsTaskMappingSubtitle),
            trailing: Icon(Icons.chevron_right, color: context.paper.inkSoft),
            onTap: () => context.push('/settings/task-mapping'),
          ),
          ListTile(
            leading: const Icon(Icons.insights_outlined),
            title: Text(l10n.settingsTokenStats),
            trailing: Icon(Icons.chevron_right, color: context.paper.inkSoft),
            onTap: () => context.push('/settings/token-stats'),
          ),
          ListTile(
            leading: const Icon(Icons.hub_outlined),
            title: Text(l10n.settingsMcpServers),
            subtitle: Text(l10n.settingsMcpServersSubtitle),
            trailing: Icon(Icons.chevron_right, color: context.paper.inkSoft),
            onTap: () => context.push('/settings/mcp-servers'),
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: Text(l10n.settingsSkills),
            subtitle: Text(l10n.settingsSkillsSubtitle),
            trailing: Icon(Icons.chevron_right, color: context.paper.inkSoft),
            onTap: () => context.push('/settings/skills'),
          ),
          const Divider(),
          _SectionTitle(l10n.settingsSectionWriting),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: Text(l10n.settingsAppearance),
            subtitle: Text(l10n.settingsAppearanceSubtitle),
            trailing: Icon(Icons.chevron_right, color: context.paper.inkSoft),
            onTap: () => context.push('/settings/appearance'),
          ),
          const _ThemeModeTile(),
          const _LocaleTile(),
          ListTile(
            leading: const Icon(Icons.local_fire_department_outlined),
            title: Text(l10n.settingsWritingStats),
            subtitle: Text(l10n.settingsWritingStatsSubtitle),
            trailing: Icon(Icons.chevron_right, color: context.paper.inkSoft),
            onTap: () => context.push('/settings/writing-stats'),
          ),
          const Divider(),
          _SectionTitle(l10n.settingsSectionData),
          const _BackupHint(),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: Text(l10n.settingsBackupToFile),
            subtitle: Text(l10n.settingsBackupToFileSubtitle),
            trailing: Icon(Icons.chevron_right, color: context.paper.inkSoft),
            onTap: () => exportBackup(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: Text(l10n.settingsRestoreFromBackup),
            subtitle: Text(l10n.settingsRestoreFromBackupSubtitle),
            trailing: Icon(Icons.chevron_right, color: context.paper.inkSoft),
            onTap: () => restoreBackup(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: Text(l10n.settingsCloudBackup),
            subtitle: Text(l10n.settingsCloudBackupSubtitle),
            trailing: Icon(Icons.chevron_right, color: context.paper.inkSoft),
            onTap: () => context.push('/settings/cloud-backup'),
          ),
          const Divider(),
          _SectionTitle(l10n.settingsSectionAbout),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.settingsAbout),
            subtitle: Text(l10n.settingsAboutSubtitle),
            trailing: Icon(Icons.chevron_right, color: context.paper.inkSoft),
            onTap: () => context.push('/settings/about'),
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
              context.l10n.settingsBackupHint,
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
    final mode = ref.watch(appThemeModeProvider).value ?? AppThemeMode.system;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.brightness_6_outlined, color: context.paper.ink),
              const SizedBox(width: 12),
              Text(l10n.settingsThemeMode),
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
                    label: Text(_themeModeLabel(l10n, m)),
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

String _themeModeLabel(AppLocalizations l10n, AppThemeMode mode) =>
    switch (mode) {
      AppThemeMode.system => l10n.themeModeSystem,
      AppThemeMode.light => l10n.themeModeLight,
      AppThemeMode.dark => l10n.themeModeDark,
    };

/// 界面语言：跟随系统 / 简体中文 / English，写入后全应用立即生效。
class _LocaleTile extends ConsumerWidget {
  const _LocaleTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(appLocaleProvider).value ?? AppLocale.system;
    final l10n = context.l10n;
    return ListTile(
      leading: const Icon(Icons.translate),
      title: Text(l10n.settingsLanguage),
      subtitle: Text(_localeLabel(l10n, locale)),
      trailing: Icon(Icons.chevron_right, color: context.paper.inkSoft),
      onTap: () async {
        final selected = await showModalBottomSheet<AppLocale>(
          context: context,
          builder: (sheetContext) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final value in AppLocale.values)
                  ListTile(
                    title: Text(_localeLabel(l10n, value)),
                    trailing: value == locale
                        ? Icon(Icons.check, color: sheetContext.paper.accent)
                        : null,
                    onTap: () => Navigator.of(sheetContext).pop(value),
                  ),
              ],
            ),
          ),
        );
        if (selected == null) return;
        await ref
            .read(settingsRepositoryProvider)
            .setSetting(AppLocale.settingKey, selected.value);
        ref.invalidate(appLocaleProvider);
      },
    );
  }
}

String _localeLabel(AppLocalizations l10n, AppLocale locale) =>
    switch (locale) {
      AppLocale.system => l10n.localeSystem,
      AppLocale.zh => l10n.localeZh,
      AppLocale.en => l10n.localeEn,
    };
