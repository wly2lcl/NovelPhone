import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/cloud/cloud_backup_service.dart';
import '../../core/cloud/cloud_storage_client.dart';
import '../../core/exporter/backup_archive.dart';
import '../../data/data_providers.dart';
import '../../l10n/error_text.dart';
import '../../l10n/l10n.dart';
import '../../models/cloud_backup_config.dart';
import 'backup_actions.dart';

/// 云备份设置（B-08 / PRD 5.10）：用户自带的 S3 兼容对象存储作为备份目的地。
/// 默认关闭；关闭时不联网。凭证只写本机安全存储，不落库、不随备份导出。
class CloudBackupPage extends ConsumerStatefulWidget {
  const CloudBackupPage({super.key});

  @override
  ConsumerState<CloudBackupPage> createState() => _CloudBackupPageState();
}

class _CloudBackupPageState extends ConsumerState<CloudBackupPage> {
  final _formKey = GlobalKey<FormState>();
  final _endpoint = TextEditingController();
  final _region = TextEditingController();
  final _bucket = TextEditingController();
  final _prefix = TextEditingController(text: kDefaultCloudBackupPrefix);
  final _keepCount = TextEditingController(text: '$kDefaultCloudKeepCount');
  final _accessKey = TextEditingController();
  final _secretKey = TextEditingController();

  bool _loading = true;
  bool _enabled = false;
  bool _autoEnabled = false;
  CloudAutoInterval _autoInterval = CloudAutoInterval.daily;
  CloudProvider _provider = CloudProvider.awsS3;
  bool _hasSecret = false;
  bool _busy = false;
  String? _message;
  bool _messageOk = false;
  List<CloudObject>? _backups;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _endpoint.dispose();
    _region.dispose();
    _bucket.dispose();
    _prefix.dispose();
    _keepCount.dispose();
    _accessKey.dispose();
    _secretKey.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(settingsRepositoryProvider);
    final config = await repo.cloudBackupConfig();
    final accessKey = await repo.readCloudAccessKey();
    final secret = await repo.readCloudSecretKey();
    if (!mounted) return;
    setState(() {
      _enabled = config.enabled;
      _autoEnabled = config.autoEnabled;
      _autoInterval = config.autoInterval;
      _provider = config.provider;
      _endpoint.text = config.endpoint;
      _region.text = config.region;
      _bucket.text = config.bucket;
      _prefix.text = config.prefix;
      _keepCount.text = '${config.keepCount}';
      _accessKey.text = accessKey ?? '';
      _hasSecret = secret != null && secret.isNotEmpty;
      _loading = false;
    });
  }

  CloudBackupConfig _currentConfig() => CloudBackupConfig(
    enabled: _enabled,
    provider: _provider,
    endpoint: _endpoint.text.trim(),
    region: _region.text.trim(),
    bucket: _bucket.text.trim(),
    prefix: _prefix.text.trim(),
    keepCount: int.tryParse(_keepCount.text.trim()) ?? kDefaultCloudKeepCount,
    autoEnabled: _autoEnabled,
    autoIntervalHours: _autoInterval.hours,
  );

  void _showMessage(String message, {required bool ok}) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _messageOk = ok;
    });
  }

  Future<void> _save({bool announce = true}) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.saveCloudBackupConfig(_currentConfig());
    await repo.saveCloudCredentials(
      accessKey: _accessKey.text.trim(),
      secretKey: _secretKey.text.trim(),
    );
    if (_secretKey.text.trim().isNotEmpty) {
      _secretKey.clear();
      _hasSecret = true;
    }
    if (!mounted) return;
    setState(() {});
    if (announce) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.cloudSaved)));
    }
  }

  /// 按当前表单（未保存的输入优先）构造编排服务；缺少必填项时返回 null。
  Future<CloudBackupService?> _buildService() async {
    final l10n = context.l10n;
    final config = _currentConfig();
    if (!config.isConfigured) {
      _showMessage(l10n.cloudNeedEndpointRegionBucket, ok: false);
      return null;
    }
    final repo = ref.read(settingsRepositoryProvider);
    final accessKey = _accessKey.text.trim().isNotEmpty
        ? _accessKey.text.trim()
        : await repo.readCloudAccessKey();
    final secretKey = _secretKey.text.trim().isNotEmpty
        ? _secretKey.text.trim()
        : await repo.readCloudSecretKey();
    if (accessKey == null ||
        accessKey.isEmpty ||
        secretKey == null ||
        secretKey.isEmpty) {
      _showMessage(l10n.cloudNeedCredentials, ok: false);
      return null;
    }
    return CloudBackupService(
      backupRepository: ref.read(backupRepositoryProvider),
      config: config,
      accessKeyId: accessKey,
      secretAccessKey: secretKey,
    );
  }

  Future<void> _testConnection() async {
    final l10n = context.l10n;
    final service = await _buildService();
    if (service == null) return;
    setState(() => _busy = true);
    try {
      await service.testConnection();
      _showMessage(l10n.cloudTestOk, ok: true);
    } catch (e) {
      _showMessage(cloudErrorText(l10n, e), ok: false);
    } finally {
      service.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _backupNow() async {
    final l10n = context.l10n;
    final service = await _buildService();
    if (service == null) return;
    setState(() => _busy = true);
    try {
      final result = await service.backupNow();
      // 记录成功时间，避免刚手动备份又被自动调度重复触发。
      await ref
          .read(settingsRepositoryProvider)
          .setCloudLastBackupAt(DateTime.now());
      _showMessage(
        l10n.cloudBackupOk(result.key, _formatSize(result.bytes)) +
            (result.pruned > 0 ? l10n.cloudBackupOkPruned(result.pruned) : ''),
        ok: true,
      );
      await _loadBackups();
    } catch (e) {
      _showMessage(cloudErrorText(l10n, e), ok: false);
    } finally {
      service.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadBackups() async {
    final l10n = context.l10n;
    final service = await _buildService();
    if (service == null) return;
    setState(() => _busy = true);
    try {
      final backups = await service.listBackups();
      if (mounted) setState(() => _backups = backups);
      _showMessage(
        backups.isEmpty
            ? l10n.cloudRemoteEmpty
            : l10n.cloudRemoteCount(backups.length),
        ok: true,
      );
    } catch (e) {
      _showMessage(cloudErrorText(l10n, e), ok: false);
    } finally {
      service.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore(CloudObject object) async {
    final l10n = context.l10n;
    final service = await _buildService();
    if (service == null) return;
    setState(() => _busy = true);
    ParsedBackup? parsed;
    try {
      // ENH-15：解压 + jsonDecode 放到 isolate，避免恢复大备份时卡住 UI。
      // ENH-22：同时校验 SHA-256 并获取预览信息。
      parsed = await inspectBackupZipAsync(await service.download(object.key));
    } on FormatException catch (e) {
      _showMessage(cloudErrorText(l10n, e), ok: false);
    } catch (e) {
      _showMessage(cloudErrorText(l10n, e), ok: false);
    } finally {
      service.dispose();
      if (mounted) setState(() => _busy = false);
    }
    if (parsed == null || !mounted) return;

    if (!await showBackupPreviewDialog(context, parsed.preview)) return;
    if (!mounted) return;
    final overwrite = await pickRestoreMode(context);
    if (overwrite == null) return;
    try {
      final report = await ref
          .read(backupRepositoryProvider)
          .restore(parsed.data, overwrite: overwrite);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.backupRestoreDone(
              report.works,
              report.chapters,
              report.characters,
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(cloudErrorText(context.l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.cloudTitle),
        actions: <Widget>[
          TextButton(
            onPressed: _loading ? null : () => _save(),
            child: Text(context.l10n.commonSave),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: <Widget>[
                  const _PrivacyHint(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.l10n.cloudEnable),
                    subtitle: Text(context.l10n.cloudEnableSubtitle),
                    value: _enabled,
                    activeTrackColor: context.paper.accent,
                    onChanged: (value) async {
                      setState(() => _enabled = value);
                      await _save(announce: false);
                    },
                  ),
                  if (_enabled) ...<Widget>[
                    const Divider(height: 24),
                    DropdownButtonFormField<CloudProvider>(
                      initialValue: _provider,
                      decoration: InputDecoration(
                        labelText: context.l10n.cloudProviderLabel,
                      ),
                      items: <DropdownMenuItem<CloudProvider>>[
                        for (final provider in CloudProvider.values)
                          DropdownMenuItem<CloudProvider>(
                            value: provider,
                            child: Text(_providerLabel(context.l10n, provider)),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _provider = value;
                          _endpoint.text = value.endpointFor(_region.text);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _region,
                      decoration: InputDecoration(
                        labelText: 'Region',
                        hintText: _regionHint(context.l10n, _provider),
                      ),
                      validator: _required(context.l10n.cloudRegionRequired),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _endpoint,
                      decoration: InputDecoration(
                        labelText: 'Endpoint',
                        helperText: _endpointHint(context.l10n, _provider),
                      ),
                      validator: _required(context.l10n.cloudEndpointRequired),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _bucket,
                      decoration: InputDecoration(
                        labelText: context.l10n.cloudBucketLabel,
                      ),
                      validator: _required(context.l10n.cloudBucketRequired),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _prefix,
                      decoration: InputDecoration(
                        labelText: context.l10n.cloudPrefixLabel,
                        helperText: context.l10n.cloudPrefixHelper(
                          kDefaultCloudBackupPrefix,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _keepCount,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: context.l10n.cloudKeepCountLabel,
                        helperText: context.l10n.cloudKeepCountHelper,
                      ),
                      validator: (v) {
                        final n = int.tryParse((v ?? '').trim());
                        if (n == null || n < 1) {
                          return context.l10n.cloudKeepCountInvalid;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _accessKey,
                      decoration: InputDecoration(
                        labelText: 'AccessKey ID',
                        helperText: context.l10n.cloudCredentialsHelper,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _secretKey,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Secret Access Key',
                        hintText: _hasSecret
                            ? context.l10n.cloudSecretHintSaved
                            : '',
                        helperText: context.l10n.cloudCredentialsHelper,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: <Widget>[
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _testConnection,
                          icon: const Icon(Icons.wifi_tethering, size: 18),
                          label: Text(context.l10n.cloudTestConnection),
                        ),
                        FilledButton.icon(
                          onPressed: _busy ? null : _backupNow,
                          icon: const Icon(
                            Icons.cloud_upload_outlined,
                            size: 18,
                          ),
                          label: Text(context.l10n.cloudBackupNow),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _loadBackups,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: Text(context.l10n.cloudRefreshRemote),
                        ),
                      ],
                    ),
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    if (_message != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          _message!,
                          style: TextStyle(
                            fontSize: 12,
                            color: _messageOk
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFFB3261E),
                          ),
                        ),
                      ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.l10n.cloudAutoTitle),
                      subtitle: Text(context.l10n.cloudAutoSubtitle),
                      value: _autoEnabled,
                      activeTrackColor: context.paper.accent,
                      onChanged: (value) async {
                        setState(() => _autoEnabled = value);
                        await _save(announce: false);
                      },
                    ),
                    if (_autoEnabled) ...<Widget>[
                      DropdownButtonFormField<CloudAutoInterval>(
                        initialValue: _autoInterval,
                        decoration: InputDecoration(
                          labelText: context.l10n.cloudIntervalLabel,
                        ),
                        items: <DropdownMenuItem<CloudAutoInterval>>[
                          for (final interval in CloudAutoInterval.values)
                            DropdownMenuItem<CloudAutoInterval>(
                              value: interval,
                              child: Text(
                                _intervalLabel(context.l10n, interval),
                              ),
                            ),
                        ],
                        onChanged: (value) async {
                          if (value == null) return;
                          setState(() => _autoInterval = value);
                          await _save(announce: false);
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                    const Divider(height: 24),
                    Text(
                      context.l10n.cloudRemoteSection,
                      style: TextStyle(color: context.paper.inkSoft),
                    ),
                    const SizedBox(height: 4),
                    _BackupList(
                      backups: _backups,
                      busy: _busy,
                      onRestore: _restore,
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  FormFieldValidator<String> _required(String message) =>
      (value) => (value ?? '').trim().isEmpty ? message : null;
}

/// 人类可读的文件大小。
String _formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// 服务商展示名（模型枚举仅用于落库标识，展示处按语言映射）。
String _providerLabel(AppLocalizations l10n, CloudProvider provider) {
  switch (provider) {
    case CloudProvider.awsS3:
      return l10n.cloudProviderAwsS3;
    case CloudProvider.aliyunOss:
      return l10n.cloudProviderAliyunOss;
    case CloudProvider.qiniuKodo:
      return l10n.cloudProviderQiniuKodo;
    case CloudProvider.tencentCos:
      return l10n.cloudProviderTencentCos;
    case CloudProvider.huaweiObs:
      return l10n.cloudProviderHuaweiObs;
  }
}

/// region 填写提示。
String _regionHint(AppLocalizations l10n, CloudProvider provider) {
  switch (provider) {
    case CloudProvider.awsS3:
      return l10n.cloudRegionHintAwsS3;
    case CloudProvider.aliyunOss:
      return l10n.cloudRegionHintAliyunOss;
    case CloudProvider.qiniuKodo:
      return l10n.cloudRegionHintQiniuKodo;
    case CloudProvider.tencentCos:
      return l10n.cloudRegionHintTencentCos;
    case CloudProvider.huaweiObs:
      return l10n.cloudRegionHintHuaweiObs;
  }
}

/// endpoint 填写提示。
String _endpointHint(AppLocalizations l10n, CloudProvider provider) {
  switch (provider) {
    case CloudProvider.awsS3:
      return l10n.cloudEndpointHintAwsS3;
    case CloudProvider.aliyunOss:
      return l10n.cloudEndpointHintAliyunOss;
    case CloudProvider.qiniuKodo:
      return l10n.cloudEndpointHintQiniuKodo;
    case CloudProvider.tencentCos:
      return l10n.cloudEndpointHintTencentCos;
    case CloudProvider.huaweiObs:
      return l10n.cloudEndpointHintHuaweiObs;
  }
}

/// 自动备份频率展示名。
String _intervalLabel(AppLocalizations l10n, CloudAutoInterval interval) {
  switch (interval) {
    case CloudAutoInterval.every12h:
      return l10n.cloudIntervalEvery12h;
    case CloudAutoInterval.daily:
      return l10n.cloudIntervalDaily;
    case CloudAutoInterval.weekly:
      return l10n.cloudIntervalWeekly;
  }
}

class _PrivacyHint extends StatelessWidget {
  const _PrivacyHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
              context.l10n.cloudPrivacyHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _BackupList extends StatelessWidget {
  const _BackupList({
    required this.backups,
    required this.busy,
    required this.onRestore,
  });

  final List<CloudObject>? backups;
  final bool busy;
  final void Function(CloudObject object) onRestore;

  @override
  Widget build(BuildContext context) {
    final list = backups;
    if (list == null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          context.l10n.cloudRemoteTapRefresh,
          style: TextStyle(fontSize: 12, color: context.paper.inkSoft),
        ),
      );
    }
    if (list.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          context.l10n.cloudRemoteEmpty,
          style: TextStyle(fontSize: 12, color: context.paper.inkSoft),
        ),
      );
    }
    return Column(
      children: <Widget>[
        for (final object in list)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.archive_outlined, color: context.paper.accent),
            title: Text(_displayName(object.key)),
            subtitle: Text(
              '${_formatSize(object.size)}'
              '${object.lastModified == null ? '' : ' · ${object.lastModified}'}',
              style: TextStyle(fontSize: 12, color: context.paper.inkSoft),
            ),
            trailing: Icon(
              Icons.download_outlined,
              color: context.paper.inkSoft,
            ),
            enabled: !busy,
            onTap: () => onRestore(object),
          ),
      ],
    );
  }

  /// 只展示前缀之后的文件名。
  static String _displayName(String key) {
    final index = key.lastIndexOf('/');
    return index < 0 ? key : key.substring(index + 1);
  }
}
