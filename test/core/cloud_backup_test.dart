import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:novelphone/core/cloud/cloud_backup_service.dart';
import 'package:novelphone/core/cloud/cloud_storage_client.dart';
import 'package:novelphone/core/cloud/s3_signer.dart';
import 'package:novelphone/core/exporter/backup_crypto.dart';
import 'package:novelphone/data/db.dart';
import 'package:novelphone/data/repositories/backup_repository.dart';
import 'package:novelphone/data/repositories/settings_repository.dart';
import 'package:novelphone/data/repositories/work_repository.dart';
import 'package:novelphone/data/secure_key_store.dart';
import 'package:novelphone/features/settings/cloud_backup_auto.dart';
import 'package:novelphone/models/cloud_backup_config.dart';

/// B-08：云备份（SigV4 签名 / S3 兼容客户端 / 编排 / 配置持久化）。
void main() {
  group('S3Signer（AWS 官方测试向量）', () {
    test('GET Object 示例签名一致', () {
      final signer = S3Signer(
        accessKeyId: 'AKIAIOSFODNN7EXAMPLE',
        secretAccessKey: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
        region: 'us-east-1',
        clock: () => DateTime.utc(2013, 5, 24, 0, 0, 0),
      );
      final headers = signer.sign(
        method: 'GET',
        uri: Uri.parse('https://examplebucket.s3.amazonaws.com/test.txt'),
        extraHeaders: const <String, String>{'range': 'bytes=0-9'},
      );

      expect(headers['x-amz-date'], '20130524T000000Z');
      expect(
        headers['x-amz-content-sha256'],
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
      expect(
        headers['Authorization'],
        'AWS4-HMAC-SHA256 '
        'Credential=AKIAIOSFODNN7EXAMPLE/20130524/us-east-1/s3/aws4_request, '
        'SignedHeaders=host;range;x-amz-content-sha256;x-amz-date, '
        'Signature=f0e8bdb87c964420e857bd35b5d6ed310bd44f0170aba48dd91039c6036bdb41',
      );
    });

    test('awsUriEncode 按 AWS 规则编码保留字符（GET 向量未覆盖的点）', () {
      expect(S3Signer.awsUriEncode('a b\$c/中'), 'a%20b%24c%2F%E4%B8%AD');
      expect(S3Signer.awsUriEncode('a-b_c.d~e'), 'a-b_c.d~e');
      expect(S3Signer.awsUriEncode('a&b=c'), 'a%26b%3Dc');
    });
  });

  group('CloudBackupConfig', () {
    test('脏数据回落默认值，前缀与保留份数归一化', () {
      final config = CloudBackupConfig.fromJson(<String, dynamic>{
        'provider': 'unknown',
        'keepCount': '0',
        'prefix': 'abc',
      });
      expect(config.provider, CloudProvider.awsS3);
      expect(config.enabled, isFalse);
      expect(config.effectiveKeepCount, 1);
      expect(config.normalizedPrefix, 'abc/');
      expect(CloudBackupConfig.fromJson(config.toJson()).bucket, isEmpty);
    });

    test('服务商 endpoint 模板与 OSS 兼容头', () {
      expect(
        CloudProvider.huaweiObs.endpointFor('cn-north-4'),
        'obs.cn-north-4.myhuaweicloud.com',
      );
      expect(CloudProvider.aliyunOss.needsOssCompatHeader, isTrue);
      expect(CloudProvider.awsS3.needsOssCompatHeader, isFalse);
    });

    test('isConfigured 要求开关开启且必填项完整', () {
      const config = CloudBackupConfig(
        enabled: true,
        endpoint: 's3.example.com',
        region: 'us-east-1',
        bucket: 'bk',
      );
      expect(config.isConfigured, isTrue);
      expect(config.copyWith(enabled: false).isConfigured, isFalse);
      expect(config.copyWith(bucket: '').isConfigured, isFalse);
    });

    test('自动备份频率归一化与配置往返', () {
      expect(CloudAutoInterval.fromHours(12), CloudAutoInterval.every12h);
      expect(CloudAutoInterval.fromHours(168), CloudAutoInterval.weekly);
      expect(CloudAutoInterval.fromHours(999), CloudAutoInterval.daily);

      const config = CloudBackupConfig(
        autoEnabled: true,
        autoIntervalHours: 168,
      );
      expect(config.autoInterval, CloudAutoInterval.weekly);
      expect(
        CloudBackupConfig.fromJson(config.toJson()).autoIntervalHours,
        168,
      );
      expect(
        CloudBackupConfig.fromJson(<String, dynamic>{}).autoInterval,
        CloudAutoInterval.daily,
      );
    });

    test('endpointHint 示例随服务商变化', () {
      expect(
        CloudProvider.awsS3.endpointHint,
        contains('s3.us-east-1.amazonaws.com'),
      );
      expect(CloudProvider.aliyunOss.endpointHint, contains('aliyuncs.com'));
      expect(CloudProvider.qiniuKodo.endpointHint, contains('qiniucs.com'));
      expect(CloudProvider.tencentCos.endpointHint, contains('myqcloud.com'));
      expect(
        CloudProvider.huaweiObs.endpointHint,
        contains('myhuaweicloud.com'),
      );
    });
  });

  group('S3CompatibleClient', () {
    CloudBackupConfig config({CloudProvider provider = CloudProvider.awsS3}) =>
        CloudBackupConfig(
          enabled: true,
          provider: provider,
          endpoint: 's3.example.com',
          region: 'us-east-1',
          bucket: 'my-bucket',
          prefix: 'novelphone/backups/',
        );

    S3CompatibleClient clientWith(
      Future<http.Response> Function(http.Request) handler, {
      CloudProvider provider = CloudProvider.awsS3,
    }) => S3CompatibleClient(
      config: config(provider: provider),
      accessKeyId: 'ak',
      secretAccessKey: 'sk',
      httpClient: MockClient(handler),
      clock: () => DateTime.utc(2026, 10, 8, 7, 30, 0),
    );

    test('putObject 使用 path-style 寻址并附签名与 OSS 兼容头', () async {
      late http.Request captured;
      final client = clientWith((request) async {
        captured = request;
        return http.Response('', 200);
      }, provider: CloudProvider.aliyunOss);
      await client.putObject(
        'novelphone/backups/20261008T153000.zip',
        Uint8List.fromList(utf8.encode('zip')),
      );

      expect(captured.method, 'PUT');
      expect(
        captured.url.toString(),
        'https://s3.example.com/my-bucket/novelphone/backups/20261008T153000.zip',
      );
      expect(headerOf(captured, 'x-oss-s3-compat'), 'true');
      expect(headerOf(captured, 'x-amz-date'), '20261008T073000Z');
      expect(
        headerOf(captured, 'Authorization'),
        startsWith('AWS4-HMAC-SHA256 '),
      );
      // host 交由 HTTP 层补，避免与受限头处理冲突。
      expect(headerOf(captured, 'host'), isNull);
    });

    test('key 中的保留字符按 AWS 规则编码进请求路径', () async {
      late http.Request captured;
      final client = clientWith((request) async {
        captured = request;
        return http.Response('', 200);
      });
      await client.putObject('p/a b\$c/中.zip', Uint8List.fromList(<int>[1]));

      expect(
        captured.url.toString(),
        'https://s3.example.com/my-bucket/p/a%20b%24c/%E4%B8%AD.zip',
      );
      expect(
        headerOf(captured, 'Authorization'),
        startsWith('AWS4-HMAC-SHA256 '),
      );
    });

    test('listObjects 解析 XML 并按续页拉取', () async {
      final requests = <http.Request>[];
      final client = clientWith((request) async {
        requests.add(request);
        if (requests.length == 1) {
          return http.Response(
            '<ListBucketResult><IsTruncated>true</IsTruncated>'
            '<Contents><Key>p/a.zip</Key><Size>10</Size>'
            '<LastModified>2026-10-08T07:30:00.000Z</LastModified></Contents>'
            '<NextContinuationToken>tok</NextContinuationToken></ListBucketResult>',
            200,
          );
        }
        return http.Response(
          '<ListBucketResult><IsTruncated>false</IsTruncated>'
          '<Contents><Key>p/b.zip</Key><Size>20</Size></Contents></ListBucketResult>',
          200,
        );
      });

      final objects = await client.listObjects('p/');

      expect(objects.map((o) => o.key), <String>['p/a.zip', 'p/b.zip']);
      expect(objects.first.size, 10);
      expect(objects.first.lastModified, DateTime.utc(2026, 10, 8, 7, 30));
      expect(requests, hasLength(2));
      expect(requests.first.url.queryParameters['prefix'], 'p/');
      expect(requests.last.url.queryParameters['continuation-token'], 'tok');
    });

    test('403 / SignatureDoesNotMatch / 404 给出明确提示', () async {
      final client = clientWith((request) async {
        if (request.method == 'GET') {
          return http.Response(
            '<Error><Code>SignatureDoesNotMatch</Code></Error>',
            403,
          );
        }
        return http.Response('<Error><Code>NoSuchBucket</Code></Error>', 404);
      });

      expect(
        () => client.getObject('k'),
        throwsA(
          isA<CloudStorageException>().having(
            (e) => e.message,
            'message',
            contains('签名校验失败'),
          ),
        ),
      );
      expect(
        () => client.deleteObject('k'),
        throwsA(
          isA<CloudStorageException>().having(
            (e) => e.message,
            'message',
            contains('404'),
          ),
        ),
      );
    });

    test('checkConnection 发最小请求（max-keys=1）', () async {
      late http.Request captured;
      final client = clientWith((request) async {
        captured = request;
        return http.Response('<ListBucketResult/>', 200);
      });
      await client.checkConnection();
      expect(captured.url.queryParameters['max-keys'], '1');
    });
  });

  group('CloudBackupService', () {
    late AppDatabase db;
    late _FakeStorageModel storage;

    setUp(() async {
      db = AppDatabase.memory();
      await WorkRepository(db).createWork(title: '长夜行');
      storage = _FakeStorageModel();
    });

    tearDown(() async => db.close());

    CloudBackupService serviceWith(
      List<DateTime> times, {
      int keepCount = 2,
      String? passphrase,
    }) {
      var index = 0;
      return CloudBackupService(
        backupRepository: BackupRepository(db),
        config: CloudBackupConfig(
          enabled: true,
          endpoint: 's3.example.com',
          region: 'us-east-1',
          bucket: 'bk',
          keepCount: keepCount,
        ),
        accessKeyId: 'ak',
        secretAccessKey: 'sk',
        passphrase: passphrase,
        client: storage,
        clock: () => times[index++],
      );
    }

    test('backupNow 上传带时间戳对象并清理超出保留份数的旧备份', () async {
      final service = serviceWith(<DateTime>[
        DateTime(2026, 10, 8, 10, 0, 0),
        DateTime(2026, 10, 8, 11, 0, 0),
        DateTime(2026, 10, 8, 12, 0, 0),
      ]);

      final first = await service.backupNow();
      expect(first.key, 'novelphone/backups/20261008T100000.zip');
      expect(first.bytes, greaterThan(0));
      await service.backupNow();
      final third = await service.backupNow();

      expect(third.pruned, 1);
      expect(storage.objects, hasLength(2));
      final remaining = await service.listBackups();
      expect(remaining.map((o) => o.key), <String>[
        'novelphone/backups/20261008T120000.zip',
        'novelphone/backups/20261008T110000.zip',
      ]);
    });

    test('listBackups 只返回前缀内的 zip，下载与测试连接可用', () async {
      final service = serviceWith(<DateTime>[DateTime(2026, 10, 8, 10, 0, 0)]);
      await service.backupNow();
      storage.objects['novelphone/backups/note.txt'] = Uint8List.fromList(<int>[
        1,
      ]);
      storage.objects['other/keep.zip'] = Uint8List.fromList(<int>[2]);

      final backups = await service.listBackups();
      expect(backups.map((o) => o.key), <String>[
        'novelphone/backups/20261008T100000.zip',
      ]);

      final bytes = await service.download(
        'novelphone/backups/20261008T100000.zip',
      );
      expect(bytes, isNotEmpty);

      await service.testConnection();
      expect(storage.connectionChecked, isTrue);
    });

    test('保留份数最小为 1', () async {
      final service = serviceWith(<DateTime>[
        DateTime(2026, 10, 8, 10, 0, 0),
        DateTime(2026, 10, 8, 11, 0, 0),
      ], keepCount: 0);
      await service.backupNow();
      final second = await service.backupNow();
      expect(second.pruned, 1);
      expect(storage.objects, hasLength(1));
    });

    test('配置密码后上传 .npbak，且可用同一密码解出原备份', () async {
      final service = serviceWith(<DateTime>[
        DateTime(2026, 10, 8, 10, 0, 0),
      ], passphrase: 'cloud-pass-123');

      final result = await service.backupNow();
      expect(result.key, endsWith('.npbak'));

      final bytes = storage.objects[result.key]!;
      expect(isEncryptedBackup(bytes), isTrue);
      final zip = await decryptBackupBytes(bytes, 'cloud-pass-123');
      expect(zip.length, greaterThan(0));
      expect(String.fromCharCodes(zip.take(2)), 'PK');

      final backups = await service.listBackups();
      expect(backups.map((o) => o.key), <String>[result.key]);
    }, timeout: const Timeout(Duration(seconds: 90)));
  });

  group('云备份自动调度', () {
    late AppDatabase db;
    late SettingsRepository settings;
    late _FakeStorageModel storage;

    setUp(() async {
      db = AppDatabase.memory();
      await WorkRepository(db).createWork(title: '长夜行');
      settings = SettingsRepository(db, InMemoryKeyStore());
    });

    tearDown(() async => db.close());

    CloudBackupScheduler scheduler(
      DateTime now, {
      CloudStorageClient Function(CloudBackupConfig, String, String)? factory,
    }) => CloudBackupScheduler(
      settings: settings,
      backups: BackupRepository(db),
      clientFactory: factory ?? (c, ak, sk) => storage,
      clock: () => now,
    );

    Future<void> enableAuto({int intervalHours = 24}) async {
      await settings.saveCloudBackupConfig(
        CloudBackupConfig(
          enabled: true,
          endpoint: 's3.example.com',
          region: 'us-east-1',
          bucket: 'bk',
          autoEnabled: true,
          autoIntervalHours: intervalHours,
        ),
      );
      await settings.saveCloudCredentials(accessKey: 'ak', secretKey: 'sk');
    }

    test('isCloudBackupDue：无记录到期，满足间隔才到期', () {
      final now = DateTime(2026, 10, 8, 10);
      expect(
        isCloudBackupDue(lastAt: null, intervalHours: 24, now: now),
        isTrue,
      );
      expect(
        isCloudBackupDue(
          lastAt: DateTime(2026, 10, 8, 9),
          intervalHours: 24,
          now: now,
        ),
        isFalse,
      );
      expect(
        isCloudBackupDue(
          lastAt: DateTime(2026, 10, 7, 10),
          intervalHours: 24,
          now: now,
        ),
        isTrue,
      );
      // 间隔夹紧为最小 1 小时。
      expect(
        isCloudBackupDue(
          lastAt: DateTime(2026, 10, 8, 9),
          intervalHours: 0,
          now: now,
        ),
        isTrue,
      );
    });

    test('开关未开启 / 未配置 / 缺凭证时不联网', () async {
      storage = _FakeStorageModel();
      // 默认关闭
      await scheduler(DateTime(2026, 10, 8, 10)).checkAndRun();
      expect(storage.objects, isEmpty);

      // 只开总开关、未开自动
      await settings.saveCloudBackupConfig(
        const CloudBackupConfig(
          enabled: true,
          endpoint: 's3.example.com',
          region: 'us-east-1',
          bucket: 'bk',
        ),
      );
      await settings.saveCloudCredentials(accessKey: 'ak', secretKey: 'sk');
      await scheduler(DateTime(2026, 10, 8, 10)).checkAndRun();
      expect(storage.objects, isEmpty);

      // 开自动但缺凭证
      await settings.saveCloudBackupConfig(
        CloudBackupConfig(
          enabled: true,
          endpoint: 's3.example.com',
          region: 'us-east-1',
          bucket: 'bk',
          autoEnabled: true,
        ),
      );
      await settings.clearCloudCredentials();
      await scheduler(DateTime(2026, 10, 8, 10)).checkAndRun();
      expect(storage.objects, isEmpty);
    });

    test('到期即备份并记录时间，未到期不重复，满间隔再备份', () async {
      storage = _FakeStorageModel();
      await enableAuto();

      await scheduler(DateTime(2026, 10, 8, 10, 0, 0)).checkAndRun();
      expect(storage.objects, hasLength(1));
      expect(await settings.cloudLastBackupAt(), DateTime(2026, 10, 8, 10));

      // 11 小时后仍未到期。
      await scheduler(DateTime(2026, 10, 8, 21, 0, 0)).checkAndRun();
      expect(storage.objects, hasLength(1));

      // 满 24 小时后再备份。
      await scheduler(DateTime(2026, 10, 9, 10, 0, 0)).checkAndRun();
      expect(storage.objects, hasLength(2));
    });

    test('远端失败静默：不抛出且不记录时间', () async {
      await enableAuto();
      await scheduler(
        DateTime(2026, 10, 8, 10),
        factory: (c, ak, sk) => _FailingStorage(),
      ).checkAndRun();
      expect(await settings.cloudLastBackupAt(), isNull);
    });

    test('开启加密但缺密码时不上传；补密码后自动上传 .npbak', () async {
      storage = _FakeStorageModel();
      await enableAuto();
      await settings.setBackupEncryptionEnabled(true);

      await scheduler(DateTime(2026, 10, 8, 10)).checkAndRun();
      expect(storage.objects, isEmpty);
      expect(await settings.cloudLastBackupAt(), isNull);

      await settings.saveBackupPassphrase('auto-pass-123');
      await scheduler(DateTime(2026, 10, 8, 10)).checkAndRun();
      expect(storage.objects, hasLength(1));
      expect(storage.objects.keys.single, endsWith('.npbak'));
      expect(await settings.cloudLastBackupAt(), DateTime(2026, 10, 8, 10));
    }, timeout: const Timeout(Duration(seconds: 90)));
  });

  group('SettingsRepository 云备份持久化', () {
    test('配置落库、凭证只进安全存储', () async {
      final db = AppDatabase.memory();
      final settings = SettingsRepository(db, InMemoryKeyStore());

      expect((await settings.cloudBackupConfig()).enabled, isFalse);

      await settings.saveCloudBackupConfig(
        const CloudBackupConfig(
          enabled: true,
          provider: CloudProvider.tencentCos,
          endpoint: 'cos.ap-guangzhou.myqcloud.com',
          region: 'ap-guangzhou',
          bucket: 'bk',
          keepCount: 3,
        ),
      );
      await settings.saveCloudCredentials(
        accessKey: 'AKID',
        secretKey: 'SECRET',
      );

      final restored = await settings.cloudBackupConfig();
      expect(restored.provider, CloudProvider.tencentCos);
      expect(restored.bucket, 'bk');
      expect(restored.keepCount, 3);
      expect(await settings.readCloudAccessKey(), 'AKID');
      expect(await settings.readCloudSecretKey(), 'SECRET');

      final raw = await settings.getSetting(
        SettingsRepository.cloudBackupConfigKey,
      );
      expect(raw, isNot(contains('AKID')));
      expect(raw, isNot(contains('SECRET')));

      await settings.clearCloudCredentials();
      expect(await settings.readCloudAccessKey(), isNull);
      expect(await settings.readCloudSecretKey(), isNull);

      await db.close();
    });

    test('截屏保护 / 备份加密开关落库，密码只进安全存储', () async {
      final db = AppDatabase.memory();
      final keyStore = InMemoryKeyStore();
      final settings = SettingsRepository(db, keyStore);

      expect(await settings.screenProtectionEnabled(), isFalse);
      await settings.setScreenProtectionEnabled(true);
      expect(await settings.screenProtectionEnabled(), isTrue);
      expect(
        await settings.getSetting(
          SettingsRepository.screenProtectionEnabledKey,
        ),
        '1',
      );

      expect(await settings.backupEncryptionEnabled(), isFalse);
      await settings.setBackupEncryptionEnabled(true);
      await settings.saveBackupPassphrase('pass-123456');
      expect(await settings.backupEncryptionEnabled(), isTrue);
      expect(await settings.readBackupPassphrase(), 'pass-123456');

      final raw = await settings.getSetting(
        SettingsRepository.backupEncryptionEnabledKey,
      );
      expect(raw, '1');
      expect(raw, isNot(contains('pass-123456')));

      await settings.clearBackupPassphrase();
      expect(await settings.readBackupPassphrase(), isNull);

      await db.close();
    });
  });
}

/// 大小写无关地读取请求头。
String? headerOf(http.Request request, String name) {
  final lower = name.toLowerCase();
  for (final entry in request.headers.entries) {
    if (entry.key.toLowerCase() == lower) return entry.value;
  }
  return null;
}

/// 内存假对象存储，用于编排层测试。
class _FakeStorageModel implements CloudStorageClient {
  final Map<String, Uint8List> objects = <String, Uint8List>{};
  bool connectionChecked = false;

  @override
  Future<void> putObject(
    String key,
    Uint8List bytes, {
    String contentType = 'application/zip',
  }) async => objects[key] = bytes;

  @override
  Future<Uint8List> getObject(String key) async =>
      objects[key] ?? (throw const CloudStorageException('对象不存在'));

  @override
  Future<void> deleteObject(String key) async => objects.remove(key);

  @override
  Future<List<CloudObject>> listObjects(String prefix) async => objects.entries
      .where((e) => e.key.startsWith(prefix))
      .map((e) => CloudObject(key: e.key, size: e.value.length))
      .toList();

  @override
  Future<void> checkConnection() async => connectionChecked = true;

  @override
  void close() {}
}

/// 上传即失败的对象存储，用于验证自动备份静默失败。
class _FailingStorage implements CloudStorageClient {
  @override
  Future<void> putObject(
    String key,
    Uint8List bytes, {
    String contentType = 'application/zip',
  }) async => throw const CloudStorageException('模拟上传失败');

  @override
  Future<Uint8List> getObject(String key) async =>
      throw const CloudStorageException('模拟下载失败');

  @override
  Future<void> deleteObject(String key) async {}

  @override
  Future<List<CloudObject>> listObjects(String prefix) async => <CloudObject>[];

  @override
  Future<void> checkConnection() async {}

  @override
  void close() {}
}
