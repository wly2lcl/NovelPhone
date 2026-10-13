/// 云备份服务商（B-08）：五家均走 S3 兼容协议，差异由配置吸收
/// （见 ARCHITECTURE 9.1）。
enum CloudProvider {
  awsS3,
  aliyunOss,
  qiniuKodo,
  tencentCos,
  huaweiObs,
}

extension CloudProviderMeta on CloudProvider {
  /// 展示名。
  String get label {
    switch (this) {
      case CloudProvider.awsS3:
        return 'AWS S3';
      case CloudProvider.aliyunOss:
        return '阿里云 OSS';
      case CloudProvider.qiniuKodo:
        return '七牛云 Kodo';
      case CloudProvider.tencentCos:
        return '腾讯云 COS';
      case CloudProvider.huaweiObs:
        return '华为云 OBS';
    }
  }

  /// endpoint 模板，`{region}` 由实际 region 替换，用于切换服务商时预填。
  String endpointFor(String region) {
    final r = region.trim().isEmpty ? '<region>' : region.trim();
    switch (this) {
      case CloudProvider.awsS3:
        return 's3.$r.amazonaws.com';
      case CloudProvider.aliyunOss:
        return 'oss-$r.aliyuncs.com';
      case CloudProvider.qiniuKodo:
        return 's3-$r.qiniucs.com';
      case CloudProvider.tencentCos:
        return 'cos.$r.myqcloud.com';
      case CloudProvider.huaweiObs:
        // 不要把桶名拼进 endpoint，否则 SignatureDoesNotMatch（ARCHITECTURE 9.1）。
        return 'obs.$r.myhuaweicloud.com';
    }
  }

  /// region 填写提示。
  String get regionHint {
    switch (this) {
      case CloudProvider.awsS3:
        return '例如 us-east-1';
      case CloudProvider.aliyunOss:
        return '例如 cn-hangzhou';
      case CloudProvider.qiniuKodo:
        return '例如 cn-east-1';
      case CloudProvider.tencentCos:
        return '例如 ap-guangzhou';
      case CloudProvider.huaweiObs:
        return '例如 cn-north-4';
    }
  }

  /// endpoint 填写提示（不带桶名，示例随服务商变化）。
  String get endpointHint {
    switch (this) {
      case CloudProvider.awsS3:
        return '不带桶名，例如 s3.us-east-1.amazonaws.com';
      case CloudProvider.aliyunOss:
        return '不带桶名，例如 oss-cn-hangzhou.aliyuncs.com';
      case CloudProvider.qiniuKodo:
        return '不带桶名，例如 s3-cn-east-1.qiniucs.com';
      case CloudProvider.tencentCos:
        return '不带桶名，例如 cos.ap-guangzhou.myqcloud.com';
      case CloudProvider.huaweiObs:
        return '不带桶名，例如 obs.cn-north-4.myhuaweicloud.com';
    }
  }

  /// 阿里云 OSS 走 S3 V4 签名需附加请求头 `x-oss-s3-compat: true`。
  bool get needsOssCompatHeader => this == CloudProvider.aliyunOss;
}

/// 按落库标识解析服务商，未知值回落 AWS S3（容忍历史脏数据）。
CloudProvider cloudProviderFromId(String? id) => CloudProvider.values.firstWhere(
      (p) => p.name == id,
      orElse: () => CloudProvider.awsS3,
    );

/// 默认路径前缀。
const String kDefaultCloudBackupPrefix = 'novelphone/backups/';

/// 默认保留份数。
const int kDefaultCloudKeepCount = 10;

/// 自动备份频率（B-08 自动调度）：落库为小时数，UI 用本枚举。
enum CloudAutoInterval {
  every12h(12, '每 12 小时'),
  daily(24, '每天'),
  weekly(168, '每周');

  const CloudAutoInterval(this.hours, this.label);

  /// 间隔小时数（落库值与到期判据）。
  final int hours;

  /// 展示名。
  final String label;

  /// 按落库小时数解析，未知值回落「每天」。
  static CloudAutoInterval fromHours(int? hours) =>
      values.firstWhere((i) => i.hours == hours,
          orElse: () => CloudAutoInterval.daily);
}

/// 默认自动备份间隔（小时）。
const int kDefaultCloudAutoIntervalHours = 24;

/// 云备份配置（B-08）：非敏感项落 APP_SETTING，凭证走安全存储，不在此模型中。
class CloudBackupConfig {
  const CloudBackupConfig({
    this.enabled = false,
    this.provider = CloudProvider.awsS3,
    this.endpoint = '',
    this.region = '',
    this.bucket = '',
    this.prefix = kDefaultCloudBackupPrefix,
    this.keepCount = kDefaultCloudKeepCount,
    this.autoEnabled = false,
    this.autoIntervalHours = kDefaultCloudAutoIntervalHours,
  });

  /// 总开关：关闭时不联网、不产生任何云端请求。
  final bool enabled;
  final CloudProvider provider;
  final String endpoint;
  final String region;
  final String bucket;
  final String prefix;

  /// 远端保留份数（最小 1）。
  final int keepCount;

  /// 自动备份（B-08 自动调度）：开启后于启动 / 回到前台时按间隔触发。
  final bool autoEnabled;

  /// 自动备份间隔（小时）。
  final int autoIntervalHours;

  /// 自动备份频率枚举视图。
  CloudAutoInterval get autoInterval =>
      CloudAutoInterval.fromHours(autoIntervalHours);

  /// 配置是否完整（不含凭证），是发起云端请求的前提。
  bool get isConfigured =>
      enabled &&
      endpoint.trim().isNotEmpty &&
      region.trim().isNotEmpty &&
      bucket.trim().isNotEmpty;

  /// 归一化前缀：非空且以 `/` 结尾，保证对象 key 形如 `{prefix}{时间戳}.zip`。
  String get normalizedPrefix {
    final p = prefix.trim();
    if (p.isEmpty) return kDefaultCloudBackupPrefix;
    return p.endsWith('/') ? p : '$p/';
  }

  /// 夹紧后的保留份数。
  int get effectiveKeepCount => keepCount < 1 ? 1 : keepCount;

  CloudBackupConfig copyWith({
    bool? enabled,
    CloudProvider? provider,
    String? endpoint,
    String? region,
    String? bucket,
    String? prefix,
    int? keepCount,
    bool? autoEnabled,
    int? autoIntervalHours,
  }) {
    return CloudBackupConfig(
      enabled: enabled ?? this.enabled,
      provider: provider ?? this.provider,
      endpoint: endpoint ?? this.endpoint,
      region: region ?? this.region,
      bucket: bucket ?? this.bucket,
      prefix: prefix ?? this.prefix,
      keepCount: keepCount ?? this.keepCount,
      autoEnabled: autoEnabled ?? this.autoEnabled,
      autoIntervalHours: autoIntervalHours ?? this.autoIntervalHours,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'enabled': enabled,
        'provider': provider.name,
        'endpoint': endpoint,
        'region': region,
        'bucket': bucket,
        'prefix': prefix,
        'keepCount': keepCount,
        'autoEnabled': autoEnabled,
        'autoIntervalHours': autoIntervalHours,
      };

  /// 容忍脏数据的反序列化。
  factory CloudBackupConfig.fromJson(Map<String, dynamic> json) {
    return CloudBackupConfig(
      enabled: json['enabled'] == true,
      provider: cloudProviderFromId(json['provider'] as String?),
      endpoint: (json['endpoint'] as String?) ?? '',
      region: (json['region'] as String?) ?? '',
      bucket: (json['bucket'] as String?) ?? '',
      prefix: (json['prefix'] as String?) ?? kDefaultCloudBackupPrefix,
      keepCount: _asInt(json['keepCount']) ?? kDefaultCloudKeepCount,
      autoEnabled: json['autoEnabled'] == true,
      autoIntervalHours:
          _asInt(json['autoIntervalHours']) ?? kDefaultCloudAutoIntervalHours,
    );
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}