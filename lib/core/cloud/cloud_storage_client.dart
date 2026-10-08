import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../../models/cloud_backup_config.dart';
import 's3_signer.dart';

/// 远端对象元信息。
class CloudObject {
  const CloudObject({required this.key, required this.size, this.lastModified});

  final String key;
  final int size;
  final DateTime? lastModified;
}

/// 云备份存储错误：携带可读原因，供 UI 明确提示（ARCHITECTURE 9.1 错误处理）。
class CloudStorageException implements Exception {
  const CloudStorageException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// 对象存储读写抽象（B-08），仅依赖 http。
abstract interface class CloudStorageClient {
  /// 上传对象。
  Future<void> putObject(String key, Uint8List bytes,
      {String contentType = 'application/zip'});

  /// 下载对象。
  Future<Uint8List> getObject(String key);

  /// 删除对象。
  Future<void> deleteObject(String key);

  /// 列举指定前缀下的对象（自动翻页）。
  Future<List<CloudObject>> listObjects(String prefix);

  /// 测试连接：发一次最小请求（列举桶内 1 个对象）验证 endpoint / region / 桶 / 凭证。
  Future<void> checkConnection();

  /// 释放底层连接。
  void close();
}

/// S3 兼容实现：path-style 寻址 + SigV4 签名，覆盖
/// AWS S3 / 阿里云 OSS / 七牛云 Kodo / 腾讯云 COS / 华为云 OBS（ARCHITECTURE 9.1）。
class S3CompatibleClient implements CloudStorageClient {
  S3CompatibleClient({
    required CloudBackupConfig config,
    required String accessKeyId,
    required String secretAccessKey,
    http.Client? httpClient,
    DateTime Function()? clock,
  })  : _config = config,
        _signer = S3Signer(
          accessKeyId: accessKeyId,
          secretAccessKey: secretAccessKey,
          region: config.region.trim(),
          clock: clock,
        ),
        _http = httpClient ?? http.Client(),
        _ownsHttp = httpClient == null;

  final CloudBackupConfig _config;
  final S3Signer _signer;
  final http.Client _http;
  final bool _ownsHttp;

  /// OSS 兼容头（阿里云 OSS 走 S3 V4 签名时必须附加）。
  Map<String, String> get _compatHeaders => _config.provider.needsOssCompatHeader
      ? const <String, String>{'x-oss-s3-compat': 'true'}
      : const <String, String>{};

  @override
  Future<void> putObject(String key, Uint8List bytes,
      {String contentType = 'application/zip'}) async {
    final uri = _objectUri(key);
    final headers = _sign(
      'PUT',
      uri,
      extraHeaders: <String, String>{'content-type': contentType, ..._compatHeaders},
      payload: bytes,
    );
    final response = await _send(
      () => _http.put(uri, headers: _requestHeaders(headers), body: bytes),
    );
    _ensureSuccess(response);
  }

  @override
  Future<Uint8List> getObject(String key) async {
    final uri = _objectUri(key);
    final headers = _sign('GET', uri, extraHeaders: _compatHeaders);
    final response = await _send(
      () => _http.get(uri, headers: _requestHeaders(headers)),
    );
    _ensureSuccess(response);
    return response.bodyBytes;
  }

  @override
  Future<void> deleteObject(String key) async {
    final uri = _objectUri(key);
    final headers = _sign('DELETE', uri, extraHeaders: _compatHeaders);
    final response = await _send(
      () => _http.delete(uri, headers: _requestHeaders(headers)),
    );
    _ensureSuccess(response);
  }

  @override
  Future<List<CloudObject>> listObjects(String prefix) async {
    final objects = <CloudObject>[];
    String? token;
    do {
      final uri = _bucketUri(<String, String>{
        'list-type': '2',
        if (prefix.isNotEmpty) 'prefix': prefix,
        'continuation-token': ?token,
      });
      final headers = _sign('GET', uri, extraHeaders: _compatHeaders);
      final response = await _send(
        () => _http.get(uri, headers: _requestHeaders(headers)),
      );
      _ensureSuccess(response);
      final parsed = _parseListResponse(response.body);
      objects.addAll(parsed.objects);
      token = parsed.nextToken;
    } while (token != null);
    return objects;
  }

  @override
  Future<void> checkConnection() async {
    final uri = _bucketUri(const <String, String>{'list-type': '2', 'max-keys': '1'});
    final headers = _sign('GET', uri, extraHeaders: _compatHeaders);
    final response = await _send(
      () => _http.get(uri, headers: _requestHeaders(headers)),
    );
    _ensureSuccess(response);
  }

  @override
  void close() {
    if (_ownsHttp) _http.close();
  }

  Map<String, String> _sign(
    String method,
    Uri uri, {
    Map<String, String> extraHeaders = const <String, String>{},
    List<int> payload = const <int>[],
  }) =>
      _signer.sign(
        method: method,
        uri: uri,
        extraHeaders: extraHeaders,
        payload: payload,
      );

  /// 发送时去掉 `host`：签名已含 host，实际由 HTTP 层按同一值自动补上，
  /// 避免与底层对受限头的处理冲突。
  Map<String, String> _requestHeaders(Map<String, String> signed) {
    final headers = Map<String, String>.of(signed)..remove('host');
    return headers;
  }

  Uri _objectUri(String key) => _uri(path: '/${_config.bucket.trim()}/$key');

  Uri _bucketUri(Map<String, String> query) =>
      _uri(path: '/${_config.bucket.trim()}', query: query);

  Uri _uri({required String path, Map<String, String>? query}) {
    var base = _config.endpoint.trim();
    if (base.isEmpty) {
      throw const CloudStorageException('请先填写 Endpoint');
    }
    if (!base.contains('://')) base = 'https://$base';
    final parsed = Uri.parse(base);
    final authority =
        parsed.hasPort ? '${parsed.host}:${parsed.port}' : parsed.host;
    // 按 AWS 规则预编码 path/query 后再交给 Uri.parse：
    // 使实际请求路径与 S3Signer 的 canonical URI 完全一致
    // （Dart 的 Uri 对 `$`、`&` 等子分隔符不会编码，会导致签名不匹配）。
    final buffer = StringBuffer('${parsed.scheme}://$authority')
      ..write(_encodePath(path));
    if (query != null && query.isNotEmpty) {
      buffer.write('?${_encodeQuery(query)}');
    }
    return Uri.parse(buffer.toString());
  }

  /// 路径按段做 AWS 编码，保留 `/` 作为分隔符。
  static String _encodePath(String path) {
    final segments = path.split('/').where((s) => s.isNotEmpty);
    if (segments.isEmpty) return '/';
    return '/${segments.map(S3Signer.awsUriEncode).join('/')}';
  }

  /// 查询串按参数名排序后逐项 AWS 编码，用 `&` 连接。
  static String _encodeQuery(Map<String, String> query) {
    final names = query.keys.toList()..sort();
    return names
        .map((n) =>
            '${S3Signer.awsUriEncode(n)}=${S3Signer.awsUriEncode(query[n] ?? '')}')
        .join('&');
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request();
    } catch (e) {
      throw CloudStorageException('网络请求失败：$e');
    }
  }

  void _ensureSuccess(http.Response response) {
    final code = response.statusCode;
    if (code >= 200 && code < 300) return;
    throw _errorFor(response);
  }

  CloudStorageException _errorFor(http.Response response) {
    final code = response.statusCode;
    final body = _snippet(response.body);
    if (body.contains('SignatureDoesNotMatch')) {
      return CloudStorageException(
        '签名校验失败（SignatureDoesNotMatch）：请检查 AccessKey / SecretKey、'
        'Endpoint 与 Region 是否匹配',
        statusCode: code,
      );
    }
    if (code == 403) {
      return CloudStorageException(
        '访问被拒绝（403）：请检查 AccessKey / SecretKey 与桶权限',
        statusCode: code,
      );
    }
    if (code == 404) {
      return CloudStorageException(
        '资源不存在（404）：请检查 Endpoint、桶名与路径前缀',
        statusCode: code,
      );
    }
    if (body.contains('RequestTimeTooSkewed')) {
      return CloudStorageException(
        '设备时钟与服务器偏差过大（RequestTimeTooSkewed）：请校准系统时间',
        statusCode: code,
      );
    }
    return CloudStorageException('云端返回 HTTP $code：$body', statusCode: code);
  }

  static String _snippet(String body) {
    final flat = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    return flat.length <= 200 ? flat : '${flat.substring(0, 200)}…';
  }

  static ({List<CloudObject> objects, String? nextToken}) _parseListResponse(
    String body,
  ) {
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(body);
    } on XmlException {
      return (objects: const <CloudObject>[], nextToken: null);
    }
    final objects = <CloudObject>[];
    for (final element in doc.findAllElements('Contents')) {
      final key = _childText(element, 'Key');
      if (key == null) continue;
      objects.add(CloudObject(
        key: key,
        size: int.tryParse(_childText(element, 'Size') ?? '') ?? 0,
        lastModified: DateTime.tryParse(_childText(element, 'LastModified') ?? ''),
      ));
    }
    final truncated = _docText(doc, 'IsTruncated') == 'true';
    final next = truncated ? _docText(doc, 'NextContinuationToken') : null;
    return (objects: objects, nextToken: next);
  }

  static String? _childText(XmlElement parent, String name) {
    for (final child in parent.findElements(name)) {
      return child.innerText;
    }
    return null;
  }

  static String? _docText(XmlDocument doc, String name) {
    for (final element in doc.findAllElements(name)) {
      return element.innerText;
    }
    return null;
  }
}