import 'dart:typed_data';

import '../../data/repositories/backup_repository.dart';
import '../../models/cloud_backup_config.dart';
import '../exporter/backup_archive.dart';
import '../exporter/backup_crypto.dart';
import 'cloud_storage_client.dart';

/// 一次云备份的结果。
class CloudBackupResult {
  const CloudBackupResult({
    required this.key,
    required this.bytes,
    required this.pruned,
  });

  /// 上传后的远端对象 key。
  final String key;

  /// 备份文件字节数。
  final int bytes;

  /// 本次按保留份数清理掉的旧备份数量。
  final int pruned;
}

/// 云备份编排（B-08，ARCHITECTURE 9.1）：
/// 复用 `core/exporter` 生成备份 zip → 上传带时间戳对象 →
/// 列举同前缀 → 按保留份数 N 删除最旧。
class CloudBackupService {
  CloudBackupService({
    required BackupRepository backupRepository,
    required CloudBackupConfig config,
    required String accessKeyId,
    required String secretAccessKey,
    this.passphrase,
    CloudStorageClient? client,
    DateTime Function()? clock,
  }) : _repository = backupRepository,
       _config = config,
       _clock = clock ?? DateTime.now,
       _client =
           client ??
           S3CompatibleClient(
             config: config,
             accessKeyId: accessKeyId,
             secretAccessKey: secretAccessKey,
             clock: clock,
           ),
       _ownsClient = client == null;

  final BackupRepository _repository;
  final CloudBackupConfig _config;

  /// 非空表示上传前用该密码加密（ENH-26）。
  final String? passphrase;
  final DateTime Function() _clock;
  final CloudStorageClient _client;
  final bool _ownsClient;

  /// 立即备份：上传当前整库备份，并按保留份数清理最旧文件。
  Future<CloudBackupResult> backupNow() async {
    var bytes = await exportBackupZipBytes(_repository);
    final passphrase = this.passphrase;
    final encrypted = passphrase != null && passphrase.isNotEmpty;
    if (encrypted) {
      bytes = await encryptBackupBytesAsync(bytes, passphrase);
    }
    final extension = encrypted ? kEncryptedBackupExtension : 'zip';
    final key =
        '${_config.normalizedPrefix}${objectStamp(_clock())}.$extension';
    await _client.putObject(
      key,
      bytes,
      contentType: encrypted ? 'application/octet-stream' : 'application/zip',
    );
    final pruned = await pruneOldBackups();
    return CloudBackupResult(key: key, bytes: bytes.length, pruned: pruned);
  }

  /// 远端备份列表（同前缀，按时间戳倒序）。
  Future<List<CloudObject>> listBackups() async {
    final prefix = _config.normalizedPrefix;
    final objects = await _client.listObjects(prefix);
    final backups =
        objects
            .where(
              (o) =>
                  o.key.startsWith(prefix) &&
                  (o.key.endsWith('.zip') ||
                      o.key.endsWith('.$kEncryptedBackupExtension')),
            )
            .toList()
          ..sort((a, b) => b.key.compareTo(a.key));
    return backups;
  }

  /// 下载指定备份。
  Future<Uint8List> download(String key) => _client.getObject(key);

  /// 测试连接：发一次最小请求验证 Endpoint / Region / 桶 / 凭证。
  Future<void> testConnection() => _client.checkConnection();

  /// 清理超出保留份数的最旧备份，返回删除数量。
  Future<int> pruneOldBackups() async {
    final backups = await listBackups();
    final keep = _config.effectiveKeepCount;
    var pruned = 0;
    for (final object in backups.skip(keep)) {
      await _client.deleteObject(object.key);
      pruned++;
    }
    return pruned;
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}

/// 对象 key 的时间戳（本地时区，`yyyyMMddTHHmmss`，定长零填充便于按 key 排序）。
String objectStamp(DateTime time) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${time.year.toString().padLeft(4, '0')}${two(time.month)}${two(time.day)}'
      'T${two(time.hour)}${two(time.minute)}${two(time.second)}';
}
