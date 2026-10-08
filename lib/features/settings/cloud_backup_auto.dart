import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cloud/cloud_backup_service.dart';
import '../../core/cloud/cloud_storage_client.dart';
import '../../data/data_providers.dart';
import '../../data/repositories/backup_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../models/cloud_backup_config.dart';

/// 自动备份是否到期（纯函数，便于单测）：无记录视为到期，
/// 否则「距上次备份的小时数」达到间隔即到期。
bool isCloudBackupDue({
  required DateTime? lastAt,
  required int intervalHours,
  required DateTime now,
}) {
  if (lastAt == null) return true;
  final hours = intervalHours < 1 ? 1 : intervalHours;
  return now.difference(lastAt).inMinutes >= hours * 60;
}

/// 云备份自动调度（B-08）：在启动 / 回到前台时检查是否到期，到期则备份。
/// 仅在「总开关 + 自动开关」均开启且配置、凭证齐全时才会联网；
/// 失败静默（不打断用户），下次检查自动重试。
class CloudBackupScheduler {
  CloudBackupScheduler({
    required this.settings,
    required this.backups,
    this.clientFactory,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final SettingsRepository settings;
  final BackupRepository backups;
  final CloudStorageClient Function(CloudBackupConfig, String, String)?
      clientFactory;
  final DateTime Function() _clock;

  /// 防重入：一次检查未结束时忽略新的触发。
  bool _running = false;

  Future<void> checkAndRun() async {
    if (_running) return;
    _running = true;
    try {
      final config = await settings.cloudBackupConfig();
      if (!config.enabled || !config.autoEnabled || !config.isConfigured) {
        return;
      }
      final accessKey = await settings.readCloudAccessKey();
      final secretKey = await settings.readCloudSecretKey();
      if (accessKey == null ||
          accessKey.isEmpty ||
          secretKey == null ||
          secretKey.isEmpty) {
        return;
      }
      final lastAt = await settings.cloudLastBackupAt();
      final now = _clock();
      if (!isCloudBackupDue(
        lastAt: lastAt,
        intervalHours: config.autoIntervalHours,
        now: now,
      )) {
        return;
      }

      final service = CloudBackupService(
        backupRepository: backups,
        config: config,
        accessKeyId: accessKey,
        secretAccessKey: secretKey,
        client: clientFactory?.call(config, accessKey, secretKey),
        clock: _clock,
      );
      try {
        await service.backupNow();
        await settings.setCloudLastBackupAt(now);
      } finally {
        service.dispose();
      }
    } catch (_) {
      // 静默失败：自动备份不打断用户；下次检查会重试。
    } finally {
      _running = false;
    }
  }
}

final cloudBackupSchedulerProvider = Provider<CloudBackupScheduler>(
  (ref) => CloudBackupScheduler(
    settings: ref.watch(settingsRepositoryProvider),
    backups: ref.watch(backupRepositoryProvider),
  ),
);

/// 宿主组件：冷启动与每次回到前台时触发一次到期检查（无常驻定时器）。
class CloudBackupAutoRunner extends ConsumerStatefulWidget {
  const CloudBackupAutoRunner({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CloudBackupAutoRunner> createState() =>
      _CloudBackupAutoRunnerState();
}

class _CloudBackupAutoRunnerState extends ConsumerState<CloudBackupAutoRunner>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  /// 不 await：自动备份在后台静默进行，不阻塞界面。
  void _check() => ref.read(cloudBackupSchedulerProvider).checkAndRun();

  @override
  Widget build(BuildContext context) => widget.child;
}