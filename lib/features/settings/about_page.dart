import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../l10n/l10n.dart';

/// 上架用隐私政策外链（与 docs/PRIVACY.md 同步维护）。
const String privacyPolicyUrl =
    'https://github.com/wly2lcl/NovelPhone/blob/main/docs/PRIVACY.md';

/// 关于页（ENH-19）：版本信息、隐私说明与开源许可入口，对应上架合规的前置要求。
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String? _version;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _version = '${info.version} (${info.buildNumber})');
    } on Exception {
      // 平台通道不可用（如部分测试环境）时保持占位符，不影响页面其余内容。
    }
  }

  Future<void> _openPrivacyPolicy() async {
    final opened = await launchUrl(
      Uri.parse(privacyPolicyUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.aboutPrivacyLinkFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsAbout)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 32),
        children: <Widget>[
          Text(
            'NovelPhone',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.aboutTagline,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.paper.inkSoft,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.aboutVersion(_version ?? '—'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.paper.inkSoft,
            ),
          ),
          const SizedBox(height: 24),
          _Card(
            title: l10n.aboutPrivacyTitle,
            children: <Widget>[
              _bullet(context, l10n.aboutPrivacyNoAccount),
              _bullet(context, l10n.aboutPrivacyLocal),
              _bullet(context, l10n.aboutPrivacyKey),
              _bullet(context, l10n.aboutPrivacyNetwork),
              _bullet(context, l10n.aboutPrivacyOffline),
              _bullet(context, l10n.aboutPrivacyErase, last: true),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _openPrivacyPolicy,
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text(l10n.aboutPrivacyPolicyLink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Card(
            title: l10n.aboutLicenses,
            children: <Widget>[
              Text(
                l10n.aboutLicensesSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.paper.inkSoft,
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => showLicensePage(
                    context: context,
                    applicationName: 'NovelPhone',
                    applicationVersion: _version ?? '',
                    applicationLegalese: 'Apache License 2.0',
                  ),
                  child: Text(l10n.aboutLicensesAction),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            '© 2026 NovelPhone · Apache License 2.0',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.paper.inkSoft,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bullet(BuildContext context, String text, {bool last = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: context.paper.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.paper.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.paper.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
