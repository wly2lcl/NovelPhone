import 'dart:convert';

import 'package:crypto/crypto.dart';

/// AWS SigV4 签名的纯函数实现（B-08，ARCHITECTURE 9.1）：
/// canonical request → string to sign → signing key → `Authorization` 头。
/// 无副作用、可单测。
class S3Signer {
  const S3Signer({
    required this.accessKeyId,
    required this.secretAccessKey,
    required this.region,
    this.service = 's3',
    this.clock,
  });

  final String accessKeyId;
  final String secretAccessKey;
  final String region;
  final String service;

  /// 可注入的当前时间（便于单测）；为 null 时取当前 UTC 时间。
  final DateTime Function()? clock;

  /// 为一次请求生成需附加的请求头：`host` / `x-amz-date` /
  /// `x-amz-content-sha256` / `Authorization`，以及 [extraHeaders]（一并参与签名）。
  Map<String, String> sign({
    required String method,
    required Uri uri,
    Map<String, String> extraHeaders = const <String, String>{},
    List<int> payload = const <int>[],
  }) {
    final payloadHash = _hex(sha256.convert(payload).bytes);
    final time = (clock?.call() ?? DateTime.now()).toUtc();
    final amzDate = _amzDate(time);
    final dateStamp = _dateStamp(time);

    // 参与签名的头：统一小写名、去首尾空白。
    final signed = <String, String>{
      'host': _hostHeader(uri),
      'x-amz-content-sha256': payloadHash,
      'x-amz-date': amzDate,
      for (final entry in extraHeaders.entries)
        entry.key.toLowerCase().trim(): entry.value.trim(),
    };
    final names = signed.keys.toList()..sort();

    final canonicalHeaders =
        StringBuffer()..writeAll(names.map((n) => '$n:${signed[n]}\n'));
    final signedHeaders = names.join(';');

    final canonicalRequest = <String>[
      method.toUpperCase(),
      _canonicalUri(uri),
      _canonicalQuery(uri),
      canonicalHeaders.toString(),
      signedHeaders,
      payloadHash,
    ].join('\n');

    final scope = '$dateStamp/$region/$service/aws4_request';
    final stringToSign = <String>[
      'AWS4-HMAC-SHA256',
      amzDate,
      scope,
      _hex(sha256.convert(utf8.encode(canonicalRequest)).bytes),
    ].join('\n');

    final signature = _hex(
      Hmac(sha256, _signingKey(dateStamp))
          .convert(utf8.encode(stringToSign))
          .bytes,
    );

    final authorization = 'AWS4-HMAC-SHA256 '
        'Credential=$accessKeyId/$scope, '
        'SignedHeaders=$signedHeaders, '
        'Signature=$signature';

    return <String, String>{
      'host': signed['host']!,
      'x-amz-content-sha256': payloadHash,
      'x-amz-date': amzDate,
      for (final entry in extraHeaders.entries) entry.key: entry.value,
      'Authorization': authorization,
    };
  }

  List<int> _signingKey(String dateStamp) {
    final kDate = Hmac(sha256, utf8.encode('AWS4$secretAccessKey'))
        .convert(utf8.encode(dateStamp))
        .bytes;
    final kRegion = Hmac(sha256, kDate).convert(utf8.encode(region)).bytes;
    final kService = Hmac(sha256, kRegion).convert(utf8.encode(service)).bytes;
    return Hmac(sha256, kService).convert(utf8.encode('aws4_request')).bytes;
  }

  /// canonical URI：按段做 AWS 编码（未保留字符集 `A-Za-z0-9-_.~`），
  /// 由 [Uri.pathSegments]（已解码）重编码，避免与 Uri 自身编码规则产生歧义。
  static String _canonicalUri(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.isEmpty) return '/';
    return '/${segments.map(awsUriEncode).join('/')}';
  }

  /// canonical query：按参数名排序后逐项 AWS 编码，用 `&` 连接。
  static String _canonicalQuery(Uri uri) {
    if (uri.queryParameters.isEmpty) return '';
    final names = uri.queryParameters.keys.toList()..sort();
    return names
        .map((n) =>
            '${awsUriEncode(n)}=${awsUriEncode(uri.queryParameters[n] ?? '')}')
        .join('&');
  }

  static String _hostHeader(Uri uri) {
    final defaultPort = uri.scheme == 'http' ? 80 : 443;
    if (uri.hasPort && uri.port != defaultPort) return '${uri.host}:${uri.port}';
    return uri.host;
  }

  static String _amzDate(DateTime utc) =>
      '${_dateStamp(utc)}T${_two(utc.hour)}${_two(utc.minute)}${_two(utc.second)}Z';

  static String _dateStamp(DateTime utc) =>
      '${utc.year.toString().padLeft(4, '0')}${_two(utc.month)}${_two(utc.day)}';

  static String _two(int value) => value.toString().padLeft(2, '0');

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// AWS 保留字符集：`A-Z a-z 0-9 - _ . ~`，其余全部百分号编码（UTF-8）。
  /// 供客户端按同一规则预编码 path/query，保证签名与实发请求路径一致。
  static String awsUriEncode(String input) {
    const unreserved =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~';
    final buffer = StringBuffer();
    for (final byte in utf8.encode(input)) {
      if (byte < 128 && unreserved.contains(String.fromCharCode(byte))) {
        buffer.writeCharCode(byte);
      } else {
        buffer.write('%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}');
      }
    }
    return buffer.toString();
  }
}