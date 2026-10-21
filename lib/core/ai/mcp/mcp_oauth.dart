/// MCP OAuth 2.1 PKCE 客户端流程（ENH-21）。
///
/// 按 MCP 授权规范（2025-06-18 版）与相关 RFC 实现移动端公开客户端流程：
/// · RFC 9728：受保护资源元数据发现（优先 401 `WWW-Authenticate` 质询，
///   兜底 `/.well-known/oauth-protected-resource`）；
/// · RFC 8414：授权服务器元数据（`/.well-known/oauth-authorization-server`，
///   兜底 OpenID Connect `/.well-known/openid-configuration`）；
/// · RFC 7591：动态客户端注册（未预填 client_id 时自动注册）；
/// · RFC 7636：PKCE（S256）；
/// · RFC 8252：loopback 回调（`http://127.0.0.1:<随机端口>/callback`）；
/// · RFC 8707：resource 参数绑定 MCP 服务器地址。
///
/// 本类不触碰存储与平台能力（打开浏览器由 UI 层做、令牌存取由仓库层做），
/// 便于单测注入 [http.Client] 走真实网络回环或假实现。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// 流程错误：消息面向用户（与 settings 页「测试连接」同策略直接展示）。
class McpOAuthException implements Exception {
  const McpOAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 持久化的 OAuth 令牌（access + 可选 refresh + 过期时间）。
class McpOAuthTokens {
  const McpOAuthTokens({
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
  });

  final String accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;

  /// 留 30 秒余量，避免边界时刻发出即将过期的请求。
  bool get isExpired =>
      expiresAt != null &&
      DateTime.now().isAfter(expiresAt!.subtract(const Duration(seconds: 30)));

  Map<String, dynamic> toJson() => <String, dynamic>{
    'access': accessToken,
    'refresh': refreshToken,
    'expiresAt': expiresAt?.toIso8601String(),
  };

  static McpOAuthTokens? fromJson(Map<String, dynamic> json) {
    final access = json['access'] as String? ?? '';
    if (access.isEmpty) return null;
    return McpOAuthTokens(
      accessToken: access,
      refreshToken: (json['refresh'] as String?)?.trim().isEmpty ?? true
          ? null
          : json['refresh'] as String,
      expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? ''),
    );
  }
}

/// 一次待完成的授权：UI 打开 [authorizationUri]（系统浏览器），
/// 等待 [tokens] 完成（用户在浏览器完成授权、loopback 收到回调并换到令牌）。
class McpAuthorizationSession {
  McpAuthorizationSession({
    required this.authorizationUri,
    required this.tokens,
    required this.registeredClientId,
    required this.cancel,
  });

  /// 用户在浏览器中访问的授权地址（PKCE S256 已内嵌）。
  final Uri authorizationUri;

  /// 授权完成的令牌；失败时为 [McpOAuthException]。
  final Future<McpOAuthTokens> tokens;

  /// 动态注册得到的 client_id（预填 client_id 时为 null）；调用方应持久化。
  final String? registeredClientId;

  /// 放弃授权（关闭本地回调服务器）。
  final Future<void> Function() cancel;
}

/// 授权服务器元数据（发现的子集）。
class _AuthServerMetadata {
  _AuthServerMetadata({
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    this.registrationEndpoint,
  });

  final Uri authorizationEndpoint;
  final Uri tokenEndpoint;
  final Uri? registrationEndpoint;
}

/// 一个 MCP server 的 OAuth 流程执行器（无状态于存储之外）。
class McpOAuthClient {
  McpOAuthClient({
    required this.resourceUri,
    this.clientId = '',
    this.scopes = const <String>[],
    this.clientName = 'NovelPhone',
    http.Client? httpClient,
    this.callbackTimeout = const Duration(minutes: 5),
    this.requestTimeout = const Duration(seconds: 15),
  }) : _http = httpClient ?? http.Client();

  /// MCP 服务器地址（resource 参数与发现基址）。
  final Uri resourceUri;

  /// 预注册的 client_id；空串表示走动态注册。
  final String clientId;
  final List<String> scopes;
  final String clientName;
  final Duration callbackTimeout;
  final Duration requestTimeout;
  final http.Client _http;

  /// 发起一轮授权：发现 → 注册（如需）→ PKCE → 本地回调。
  /// 返回后由调用方打开 [McpAuthorizationSession.authorizationUri]。
  Future<McpAuthorizationSession> startAuthorization() async {
    _requireSecure(resourceUri, 'MCP 服务器地址');
    final authServer = await _discoverAuthorizationServer();
    final metadata = await _fetchAuthServerMetadata(authServer);

    // 先绑定 loopback 拿到 redirect_uri，再做动态注册（注册需要回调地址）。
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirectUri = Uri.parse('http://127.0.0.1:${server.port}/callback');

    String? registeredClientId;
    var effectiveClientId = clientId.trim();
    if (effectiveClientId.isEmpty) {
      registeredClientId = await _registerClient(
        metadata,
        redirectUri: redirectUri,
      );
      effectiveClientId = registeredClientId;
    }

    final verifier = generateCodeVerifier();
    final challenge = codeChallengeS256(verifier);
    final state = _randomToken(16);

    final authorizationUri = metadata.authorizationEndpoint.replace(
      queryParameters: <String, String>{
        'response_type': 'code',
        'client_id': effectiveClientId,
        'redirect_uri': redirectUri.toString(),
        'state': state,
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
        'resource': resourceUri.toString(),
        if (scopes.isNotEmpty) 'scope': scopes.join(' '),
      },
    );

    final tokens = _awaitLoopbackCallback(
      server: server,
      expectedState: state,
      redirectUri: redirectUri,
      codeVerifier: verifier,
      tokenEndpoint: metadata.tokenEndpoint,
      clientId: effectiveClientId,
    );
    return McpAuthorizationSession(
      authorizationUri: authorizationUri,
      tokens: tokens,
      registeredClientId: registeredClientId,
      cancel: () async {
        try {
          await server.close(force: true);
        } catch (_) {
          // 已关闭。
        }
      },
    );
  }

  /// 用 refresh_token 换新令牌（发现 → 刷新）。refresh 失败抛
  /// [McpOAuthException]，调用方引导用户重新授权。
  Future<McpOAuthTokens> refreshToken(McpOAuthTokens current) async {
    final refresh = current.refreshToken;
    if (refresh == null || refresh.isEmpty) {
      throw const McpOAuthException('没有可用的刷新令牌，需要重新授权');
    }
    final authServer = await _discoverAuthorizationServer();
    final metadata = await _fetchAuthServerMetadata(authServer);
    final response = await _postForm(metadata.tokenEndpoint, <String, String>{
      'grant_type': 'refresh_token',
      'refresh_token': refresh,
      'client_id': clientId,
      'resource': resourceUri.toString(),
    });
    // 非轮换刷新会省略 refresh_token：沿用旧值，避免下次刷新被强制重新授权。
    return _tokensFromResponse(response, fallbackRefreshToken: refresh);
  }

  // ---------- 发现 ----------

  Future<Uri> _discoverAuthorizationServer() async {
    // 1) 质询式：向 MCP 端点发未认证请求，读 401 的 WWW-Authenticate。
    final metadataUrl =
        await _resourceMetadataFromChallenge() ??
        await _resourceMetadataFromWellKnown();
    if (metadataUrl == null) {
      throw const McpOAuthException('未能发现受保护资源元数据，请确认服务器支持 OAuth 授权');
    }
    final document = await _getJson(metadataUrl);
    final servers = document['authorization_servers'];
    if (servers is! List || servers.isEmpty) {
      throw const McpOAuthException('受保护资源元数据缺少 authorization_servers');
    }
    String? first;
    for (final candidate in servers) {
      if (candidate is String && candidate.isNotEmpty) {
        first = candidate;
        break;
      }
    }
    if (first == null) {
      throw const McpOAuthException('authorization_servers 为空');
    }
    final uri = Uri.tryParse(first);
    if (uri == null || !uri.hasScheme) {
      throw McpOAuthException('authorization_servers 中的地址无效：$first');
    }
    _requireSecure(uri, '授权服务器地址');
    return uri;
  }

  Future<Uri?> _resourceMetadataFromChallenge() async {
    try {
      final request = http.Request('GET', resourceUri)
        ..headers['accept'] = 'text/event-stream, application/json';
      final streamed = await _http.send(request).timeout(requestTimeout);
      await streamed.stream.drain<void>();
      final header = streamed.headers['www-authenticate'];
      if (header == null) return null;
      final match = RegExp(
        'resource_metadata="([^"]+)"',
        caseSensitive: false,
      ).firstMatch(header);
      final raw = match?.group(1);
      if (raw == null) return null;
      return Uri.tryParse(raw);
    } catch (_) {
      // 探测失败交由 well-known 兜底。
      return null;
    }
  }

  Future<Uri?> _resourceMetadataFromWellKnown() async {
    final origin = resourceUri.replace(
      path: '/.well-known/oauth-protected-resource',
      query: null,
      fragment: null,
    );
    final withPath = resourceUri.path.isEmpty || resourceUri.path == '/'
        ? origin
        : origin.replace(
            path: '/.well-known/oauth-protected-resource${resourceUri.path}',
          );
    for (final candidate in <Uri>[withPath, origin]) {
      try {
        final document = await _getJson(candidate);
        if (document.containsKey('authorization_servers')) return candidate;
      } catch (_) {
        // 继续尝试下一个候选。
      }
    }
    return null;
  }

  Future<_AuthServerMetadata> _fetchAuthServerMetadata(Uri authServer) async {
    final candidates = <Uri>[
      authServer.replace(
        path:
            '/.well-known/oauth-authorization-server${authServer.path == '/' ? '' : authServer.path}',
      ),
      authServer.replace(
        path:
            '/.well-known/openid-configuration${authServer.path == '/' ? '' : authServer.path}',
      ),
    ];
    for (final candidate in candidates) {
      Map<String, dynamic> document;
      try {
        document = await _getJson(candidate);
      } catch (_) {
        continue;
      }
      final authorizationEndpoint = Uri.tryParse(
        document['authorization_endpoint'] as String? ?? '',
      );
      final tokenEndpoint = Uri.tryParse(
        document['token_endpoint'] as String? ?? '',
      );
      if (authorizationEndpoint == null ||
          !authorizationEndpoint.hasScheme ||
          tokenEndpoint == null ||
          !tokenEndpoint.hasScheme) {
        continue;
      }
      _requireSecure(authorizationEndpoint, '授权端点');
      _requireSecure(tokenEndpoint, '令牌端点');
      final registrationEndpoint = Uri.tryParse(
        document['registration_endpoint'] as String? ?? '',
      );
      final methods = document['code_challenge_methods_supported'];
      if (methods is List &&
          methods.whereType<String>().isNotEmpty &&
          !methods.contains('S256')) {
        throw const McpOAuthException('授权服务器不支持 PKCE S256，出于安全考虑已中止');
      }
      return _AuthServerMetadata(
        authorizationEndpoint: authorizationEndpoint,
        tokenEndpoint: tokenEndpoint,
        registrationEndpoint:
            registrationEndpoint != null && registrationEndpoint.hasScheme
            ? registrationEndpoint
            : null,
      );
    }
    throw const McpOAuthException('未能获取授权服务器元数据');
  }

  // ---------- 动态注册 ----------

  Future<String> _registerClient(
    _AuthServerMetadata metadata, {
    required Uri redirectUri,
  }) async {
    final endpoint = metadata.registrationEndpoint;
    if (endpoint == null) {
      throw const McpOAuthException('授权服务器不支持动态注册，请在设置中预填 client_id');
    }
    final response = await _postJson(endpoint, <String, dynamic>{
      'client_name': clientName,
      'redirect_uris': <String>[redirectUri.toString()],
      'grant_types': <String>['authorization_code', 'refresh_token'],
      'response_types': <String>['code'],
      'token_endpoint_auth_method': 'none',
      if (scopes.isNotEmpty) 'scope': scopes.join(' '),
    });
    final id = response['client_id'] as String? ?? '';
    if (id.isEmpty) {
      throw const McpOAuthException('动态注册未返回 client_id');
    }
    return id;
  }

  // ---------- loopback 回调 ----------

  Future<McpOAuthTokens> _awaitLoopbackCallback({
    required HttpServer server,
    required String expectedState,
    required Uri redirectUri,
    required String codeVerifier,
    required Uri tokenEndpoint,
    required String clientId,
  }) async {
    final completer = Completer<McpOAuthTokens>();
    final subscription = server.listen((request) async {
      if (request.uri.path != '/callback') {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }
      if (completer.isCompleted) {
        await _respondHtml(request, HttpStatus.ok, '授权已完成，请返回 NovelPhone。');
        return;
      }
      final params = request.uri.queryParameters;
      final error = params['error'];
      final code = params['code'] ?? '';
      final state = params['state'] ?? '';

      Future<void> respond(String html, {bool ok = true}) => _respondHtml(
        request,
        ok ? HttpStatus.ok : HttpStatus.badRequest,
        html,
      );

      if (error != null) {
        await respond(
          '授权被拒绝：$error ${params['error_description'] ?? ''}',
          ok: false,
        );
        completer.completeError(
          McpOAuthException(
            '授权被拒绝（$error）${params['error_description'] ?? ''}',
          ),
        );
        return;
      }
      if (state != expectedState) {
        await respond('state 校验失败，出于安全考虑已中止。', ok: false);
        completer.completeError(
          const McpOAuthException('回调 state 与请求不一致，已中止授权（可能是跨站伪造请求）'),
        );
        return;
      }
      if (code.isEmpty) {
        await respond('回调缺少 authorization code。', ok: false);
        completer.completeError(
          const McpOAuthException('回调缺少 authorization code'),
        );
        return;
      }
      try {
        final tokens = await _exchangeAuthorizationCode(
          tokenEndpoint: tokenEndpoint,
          code: code,
          codeVerifier: codeVerifier,
          redirectUri: redirectUri,
          clientId: clientId,
        );
        await respond('授权成功，请返回 NovelPhone 继续使用。');
        completer.complete(tokens);
      } catch (e) {
        await respond('换取令牌失败：$e', ok: false);
        completer.completeError(e);
      }
    });

    try {
      return await completer.future.timeout(callbackTimeout);
    } on TimeoutException {
      throw const McpOAuthException('授权等待超时（5 分钟），请重试');
    } finally {
      await subscription.cancel();
      try {
        await server.close(force: true);
      } catch (_) {
        // 已关闭。
      }
    }
  }

  Future<void> _respondHtml(
    HttpRequest request,
    int status,
    String message,
  ) async {
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.html
      ..write(
        '<!doctype html><html><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width,initial-scale=1">'
        '<title>NovelPhone 授权</title></head>'
        '<body style="font-family:sans-serif;padding:32px;line-height:1.6">'
        '<p>$message</p></body></html>',
      );
    await request.response.close();
  }

  // ---------- 令牌端点 ----------

  Future<McpOAuthTokens> _exchangeAuthorizationCode({
    required Uri tokenEndpoint,
    required String code,
    required String codeVerifier,
    required Uri redirectUri,
    required String clientId,
  }) async {
    final response = await _postForm(tokenEndpoint, <String, String>{
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': redirectUri.toString(),
      'client_id': clientId,
      'code_verifier': codeVerifier,
      'resource': resourceUri.toString(),
    });
    return _tokensFromResponse(response);
  }

  McpOAuthTokens _tokensFromResponse(
    Map<String, dynamic> json, {
    String? fallbackRefreshToken,
  }) {
    final access = json['access_token'] as String? ?? '';
    if (access.isEmpty) {
      throw const McpOAuthException('令牌响应缺少 access_token');
    }
    final rawRefresh = json['refresh_token'];
    final refresh = rawRefresh is String ? rawRefresh.trim() : '';
    final expiresIn = (json['expires_in'] as num?)?.toInt();
    return McpOAuthTokens(
      accessToken: access,
      refreshToken: refresh.isEmpty ? fallbackRefreshToken : refresh,
      expiresAt: expiresIn == null
          ? null
          : DateTime.now().add(Duration(seconds: expiresIn)),
    );
  }

  // ---------- HTTP 小工具 ----------

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await _http.get(uri).timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw McpOAuthException('请求 $uri 失败（HTTP ${response.statusCode}）');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) {
      throw McpOAuthException('$uri 返回的不是 JSON 对象');
    }
    return decoded.cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> _postJson(
    Uri uri,
    Map<String, dynamic> body,
  ) async {
    final response = await _http
        .post(
          uri,
          headers: <String, String>{'content-type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw McpOAuthException('请求 $uri 失败（HTTP ${response.statusCode}）');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) {
      throw McpOAuthException('$uri 返回的不是 JSON 对象');
    }
    return decoded.cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> _postForm(
    Uri uri,
    Map<String, String> form,
  ) async {
    final response = await _http
        .post(
          uri,
          headers: <String, String>{
            'content-type': 'application/x-www-form-urlencoded',
            'accept': 'application/json',
          },
          body: form,
        )
        .timeout(requestTimeout);
    Map<String, dynamic> decoded;
    try {
      final value = jsonDecode(utf8.decode(response.bodyBytes));
      decoded = value is Map
          ? value.cast<String, dynamic>()
          : <String, dynamic>{};
    } catch (_) {
      decoded = <String, dynamic>{};
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error =
          decoded['error'] as String? ?? 'HTTP ${response.statusCode}';
      final description = decoded['error_description'] as String? ?? '';
      throw McpOAuthException('令牌端点返回错误：$error $description'.trim());
    }
    return decoded;
  }

  static void _requireSecure(Uri uri, String what) {
    final isLoopback = _isLoopback(uri.host);
    if (uri.scheme == 'https' || (uri.scheme == 'http' && isLoopback)) {
      return;
    }
    throw McpOAuthException('$what 必须使用 HTTPS（本地回环除外）：$uri');
  }

  static bool _isLoopback(String host) =>
      host == '127.0.0.1' || host == '::1' || host == 'localhost';
}

// ---------- PKCE（RFC 7636，独立函数便于单测对照官方测试向量）----------

final Random _random = Random.secure();

List<int> _randomBytes(int length) =>
    List<int>.generate(length, (_) => _random.nextInt(256));

String _randomToken(int bytes) =>
    base64Url.encode(_randomBytes(bytes)).replaceAll('=', '');

/// 生成 code_verifier：43~128 位 URL-safe 字符（32 随机字节的 Base64URL）。
String generateCodeVerifier() => _randomToken(32);

/// S256：`BASE64URL(SHA256(ASCII(code_verifier)))`，去填充。
String codeChallengeS256(String verifier) => base64Url
    .encode(sha256.convert(utf8.encode(verifier)).bytes)
    .replaceAll('=', '');
