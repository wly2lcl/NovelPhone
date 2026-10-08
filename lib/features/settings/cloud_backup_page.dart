import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/cloud/cloud_backup_service.dart';
import '../../core/cloud/cloud_storage_client.dart';
import '../../core/exporter/backup_archive.dart';
import '../../data/data_providers.dart';
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
  final _keepCount =
      TextEditingController(text: '$kDefaultCloudKeepCount');
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
        keepCount: int.tryParse(_keepCount.text.trim()) ??
            kDefaultCloudKeepCount,
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已保存')));
    }
  }

  /// 按当前表单（未保存的输入优先）构造编排服务；缺少必填项时返回 null。
  Future<CloudBackupService?> _buildService() async {
    final config = _currentConfig();
    if (!config.isConfigured) {
      _showMessage('请先完整填写 Endpoint、Region 与桶名', ok: false);
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
      _showMessage('请先填写 AccessKey 与 SecretKey', ok: false);
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
    final service = await _buildService();
    if (service == null) return;
    setState(() => _busy = true);
    try {
      await service.testConnection();
      _showMessage('连接成功：桶与凭证可用', ok: true);
    } catch (e) {
      _showMessage('连接失败：$e', ok: false);
    } finally {
      service.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _backupNow() async {
    final service = await _buildService();
    if (service == null) return;
    setState(() => _busy = true);
    try {
      final result = await service.backupNow();
      // 记录成功时间，避免刚手动备份又被自动调度重复触发。
      await ref.read(settingsRepositoryProvider).setCloudLastBackupAt(DateTime.now());
      _showMessage(
        '备份成功：${result.key}（${_formatSize(result.bytes)}）'
        '${result.pruned > 0 ? '，已清理 ${result.pruned} 份旧备份' : ''}',
        ok: true,
      );
      await _loadBackups();
    } catch (e) {
      _showMessage('备份失败：$e', ok: false);
    } finally {
      service.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadBackups() async {
    final service = await _buildService();
    if (service == null) return;
    setState(() => _busy = true);
    try {
      final backups = await service.listBackups();
      if (mounted) setState(() => _backups = backups);
      _showMessage(
        backups.isEmpty ? '远端暂无备份' : '远端共 ${backups.length} 份备份',
        ok: true,
      );
    } catch (e) {
      _showMessage('读取远端备份失败：$e', ok: false);
    } finally {
      service.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore(CloudObject object) async {
    final service = await _buildService();
    if (service == null) return;
    setState(() => _busy = true);
    Map<String, dynamic>? data;
    try {
      data = parseBackupZip(await service.download(object.key));
    } on FormatException catch (e) {
      _showMessage('恢复失败：${e.message}', ok: false);
    } catch (e) {
      _showMessage('恢复失败：$e', ok: false);
    } finally {
      service.dispose();
      if (mounted) setState(() => _busy = false);
    }
    if (data == null || !mounted) return;

    final overwrite = await pickRestoreMode(context);
    if (overwrite == null) return;
    try {
      final report = await ref
          .read(backupRepositoryProvider)
          .restore(data, overwrite: overwrite);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          '恢复完成：${report.works} 部作品、${report.chapters} 章、${report.characters} 个角色卡',
        ),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('恢复失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('云备份'),
        actions: <Widget>[
          TextButton(
            onPressed: _loading ? null : () => _save(),
            child: const Text('保存'),
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
                    title: const Text('启用云备份'),
                    subtitle: const Text('关闭时不联网、不产生任何云端请求'),
                    value: _enabled,
                    activeTrackColor: PaperColors.accent,
                    onChanged: (value) async {
                      setState(() => _enabled = value);
                      await _save(announce: false);
                    },
                  ),
                  if (_enabled) ...<Widget>[
                    const Divider(height: 24),
                    DropdownButtonFormField<CloudProvider>(
                      initialValue: _provider,
                      decoration: const InputDecoration(labelText: '服务商'),
                      items: <DropdownMenuItem<CloudProvider>>[
                        for (final provider in CloudProvider.values)
                          DropdownMenuItem<CloudProvider>(
                            value: provider,
                            child: Text(provider.label),
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
                        hintText: _provider.regionHint,
                      ),
                      validator: _required('Region'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _endpoint,
                      decoration: const InputDecoration(
                        labelText: 'Endpoint',
                        helperText: '不带桶名，例如 obs.cn-north-4.myhuaweicloud.com',
                      ),
                      validator: _required('Endpoint'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _bucket,
                      decoration: const InputDecoration(labelText: '存储桶 Bucket'),
                      validator: _required('桶名'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _prefix,
                      decoration: const InputDecoration(
                        labelText: '路径前缀',
                        helperText: '默认 novelphone/backups/',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _keepCount,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '保留份数',
                        helperText: '超出后自动删除最旧的备份，最小 1',
                      ),
                      validator: (v) {
                        final n = int.tryParse((v ?? '').trim());
                        if (n == null || n < 1) return '请填写不小于 1 的整数';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _accessKey,
                      decoration: const InputDecoration(
                        labelText: 'AccessKey ID',
                        helperText: '仅保存在本机安全存储，不会随备份导出',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _secretKey,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Secret Access Key',
                        hintText: _hasSecret ? '已保存，留空则不修改' : '',
                        helperText: '仅保存在本机安全存储，不会随备份导出',
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
                          label: const Text('测试连接'),
                        ),
                        FilledButton.icon(
                          onPressed: _busy ? null : _backupNow,
                          icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                          label: const Text('立即备份'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _loadBackups,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('刷新远端备份'),
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
                      title: const Text('自动备份'),
                      subtitle: const Text('开启后于启动 / 回到前台时，距上次备份满所选间隔则自动备份'),
                      value: _autoEnabled,
                      activeTrackColor: PaperColors.accent,
                      onChanged: (value) async {
                        setState(() => _autoEnabled = value);
                        await _save(announce: false);
                      },
                    ),
                    if (_autoEnabled) ...<Widget>[
                      DropdownButtonFormField<CloudAutoInterval>(
                        initialValue: _autoInterval,
                        decoration: const InputDecoration(labelText: '备份频率'),
                        items: <DropdownMenuItem<CloudAutoInterval>>[
                          for (final interval in CloudAutoInterval.values)
                            DropdownMenuItem<CloudAutoInterval>(
                              value: interval,
                              child: Text(interval.label),
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
                    const Text('远端备份', style: TextStyle(color: PaperColors.inkSoft)),
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

  FormFieldValidator<String> _required(String label) => (value) =>
      (value ?? '').trim().isEmpty ? '请填写$label' : null;
}

/// 人类可读的文件大小。
String _formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class _PrivacyHint extends StatelessWidget {
  const _PrivacyHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PaperColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.info_outline, size: 18, color: PaperColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '云备份默认关闭，仅在你开启并触发时联网（含开启自动备份后按频率触发）。'
              '备份内容与本地 zip 一致（含正文，不含任何 API Key）；'
              'AccessKey / SecretKey 只保存在本机安全存储。',
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
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          '点击「刷新远端备份」查看已有备份',
          style: TextStyle(fontSize: 12, color: PaperColors.inkSoft),
        ),
      );
    }
    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          '远端暂无备份',
          style: TextStyle(fontSize: 12, color: PaperColors.inkSoft),
        ),
      );
    }
    return Column(
      children: <Widget>[
        for (final object in list)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.archive_outlined, color: PaperColors.accent),
            title: Text(_displayName(object.key)),
            subtitle: Text(
              '${_formatSize(object.size)}'
              '${object.lastModified == null ? '' : ' · ${object.lastModified}'}',
              style: const TextStyle(fontSize: 12, color: PaperColors.inkSoft),
            ),
            trailing: const Icon(Icons.download_outlined, color: PaperColors.inkSoft),
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