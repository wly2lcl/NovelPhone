import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:novelphone/core/ai/mcp/mcp_bridge.dart';
import 'package:novelphone/core/ai/mcp/mcp_oauth.dart';
import 'package:novelphone/data/db.dart';
import 'package:novelphone/data/repositories/settings_repository.dart';
import 'package:novelphone/data/secure_key_store.dart';
import 'package:novelphone/features/ai/mcp_credentials.dart';

/// 内嵌的假 OAuth 授权服务器 + MCP 资源服务器（真实 HTTP 回环）。
/// 覆盖 ENH-21 全链路：质询发现 → AS 元数据 → 动态注册 → /authorize 302 →
/// loopback 回调 → /token 校验 PKCE → Bearer 访问 /mcp。
class _FakeOAuthMcpServer {
  _FakeOAuthMcpServer._(this._server);

  final HttpServer _server;

  int get port => _server.port;

  Uri get mcpUri => Uri.parse('http://127.0.0.1:$port/mcp');

  final Map<String, _PendingGrant> _codes = <String, _PendingGrant>{};

  /// 授权回调是否篡改 state（用于负例）。
  bool tamperState = false;

  int refreshCount = 0;
  String accessToken = 'access-1';
  final String refreshTokenValue = 'refresh-1';

  /// 令牌端点最近一次收到的 code_verifier（供断言服务器端 PKCE 校验）。
  String? lastCodeVerifier;

  /// 触发过 401 质询的请求次数（含发现阶段的 GET）。
  int challenge401Count = 0;

  static Future<_FakeOAuthMcpServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = _FakeOAuthMcpServer._(server);
    unawaited(fake._serve());
    return fake;
  }

  Future<void> close() => _server.close(force: true);

  Future<void> _serve() async {
    await for (final request in _server) {
      unawaited(_handle(request));
    }
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      switch (request.uri.path) {
        case '/mcp':
          await _handleMcp(request);
        case '/.well-known/oauth-protected-resource':
          await _json(request, 200, <String, dynamic>{
            'resource': mcpUri.toString(),
            'authorization_servers': <String>['http://127.0.0.1:$port'],
          });
        case '/.well-known/oauth-authorization-server':
          await _json(request, 200, <String, dynamic>{
            'issuer': 'http://127.0.0.1:$port',
            'authorization_endpoint': 'http://127.0.0.1:$port/authorize',
            'token_endpoint': 'http://127.0.0.1:$port/token',
            'registration_endpoint': 'http://127.0.0.1:$port/register',
            'code_challenge_methods_supported': <String>['S256'],
          });
        case '/register':
          await _json(request, 200, <String, dynamic>{
            'client_id': 'dyn-client-1',
          });
        case '/authorize':
          await _handleAuthorize(request);
        case '/token':
          await _handleToken(request);
        default:
          await _json(request, 404, <String, dynamic>{'error': 'not_found'});
      }
    } catch (_) {
      // 单个请求异常不影响后续（测试里以断言为准）。
      try {
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _handleMcp(HttpRequest request) async {
    final auth = request.headers.value('authorization') ?? '';
    if (auth != 'Bearer $accessToken') {
      challenge401Count++;
      request.response
        ..statusCode = 401
        ..headers.set(
          'www-authenticate',
          'Bearer resource_metadata='
              '"http://127.0.0.1:$port/.well-known/oauth-protected-resource"',
        );
      await request.response.close();
      return;
    }
    if (request.method != 'POST') {
      // 已认证但非 POST：按 Streamable HTTP 规范返回 405（无独立 SSE 流）。
      request.response.statusCode = 405;
      await request.response.close();
      return;
    }
    final body = await utf8.decodeStream(request);
    final message = jsonDecode(body) as Map<String, dynamic>;
    final id = message['id'];
    if (id == null) {
      // 通知（如 notifications/initialized）：202 无正文。
      request.response.statusCode = 202;
      await request.response.close();
      return;
    }
    if (message['method'] == 'server/discover') {
      // 假服务器按“旧协议服务器”行事：对现代发现请求回 400，
      // 触发 mcp_dart 客户端回退到 initialize 握手。
      await _json(request, 400, <String, dynamic>{
        'jsonrpc': '2.0',
        'id': id,
        'error': <String, dynamic>{
          'code': -32601,
          'message': 'Method not found',
        },
      });
      return;
    }
    final result = _jsonRpcResult(message);
    final payload = jsonEncode(<String, dynamic>{
      'jsonrpc': '2.0',
      'id': id,
      'result': result,
    });
    request.response
      ..statusCode = 200
      ..headers.contentType = ContentType(
        'text',
        'event-stream',
        charset: 'utf-8',
      )
      ..write('event: message\ndata: $payload\n\n');
    await request.response.close();
  }

  Map<String, dynamic> _jsonRpcResult(Map<String, dynamic> message) {
    switch (message['method']) {
      case 'initialize':
        final params =
            message['params'] as Map<String, dynamic>? ?? <String, dynamic>{};
        return <String, dynamic>{
          'protocolVersion': params['protocolVersion'] ?? '2025-06-18',
          'capabilities': <String, dynamic>{'tools': <String, dynamic>{}},
          'serverInfo': <String, dynamic>{
            'name': 'fake-oauth-mcp',
            'version': '1.0.0',
          },
        };
      case 'tools/list':
        return <String, dynamic>{
          'tools': <dynamic>[
            <String, dynamic>{
              'name': 'echo',
              'description': '回显输入',
              'inputSchema': <String, dynamic>{
                'type': 'object',
                'properties': <String, dynamic>{
                  'text': <String, dynamic>{'type': 'string'},
                },
              },
            },
          ],
        };
      case 'tools/call':
        final params =
            message['params'] as Map<String, dynamic>? ?? <String, dynamic>{};
        final args =
            params['arguments'] as Map<String, dynamic>? ?? <String, dynamic>{};
        return <String, dynamic>{
          'content': <dynamic>[
            <String, dynamic>{'type': 'text', 'text': 'echo:${args['text']}'},
          ],
        };
      default:
        return <String, dynamic>{};
    }
  }

  Future<void> _handleAuthorize(HttpRequest request) async {
    final query = request.uri.queryParameters;
    final redirectUri = query['redirect_uri'] ?? '';
    if (redirectUri.isEmpty) {
      await _json(request, 400, <String, dynamic>{'error': 'invalid_request'});
      return;
    }
    final code = 'code-${_codes.length + 1}';
    _codes[code] = _PendingGrant(
      challenge: query['code_challenge'] ?? '',
      redirectUri: redirectUri,
    );
    final redirect = Uri.parse(redirectUri).replace(
      queryParameters: <String, String>{
        'code': code,
        'state': tamperState ? 'tampered-state' : query['state'] ?? '',
      },
    );
    request.response
      ..statusCode = 302
      ..headers.set('location', redirect.toString());
    await request.response.close();
  }

  Future<void> _handleToken(HttpRequest request) async {
    final body = await utf8.decodeStream(request);
    final form = Uri.splitQueryString(body);
    switch (form['grant_type']) {
      case 'authorization_code':
        final pending = _codes[form['code']];
        if (pending == null) {
          await _json(request, 400, <String, dynamic>{
            'error': 'invalid_grant',
          });
          return;
        }
        final verifier = form['code_verifier'] ?? '';
        lastCodeVerifier = verifier;
        final expected = base64Url
            .encode(sha256.convert(utf8.encode(verifier)).bytes)
            .replaceAll('=', '');
        if (verifier.isEmpty || expected != pending.challenge) {
          await _json(request, 400, <String, dynamic>{
            'error': 'invalid_grant',
            'error_description': 'PKCE 校验失败',
          });
          return;
        }
        await _json(request, 200, <String, dynamic>{
          'access_token': accessToken,
          'refresh_token': refreshTokenValue,
          'token_type': 'Bearer',
          'expires_in': 3600,
        });
      case 'refresh_token':
        refreshCount++;
        if (form['refresh_token'] != refreshTokenValue) {
          await _json(request, 400, <String, dynamic>{
            'error': 'invalid_grant',
          });
          return;
        }
        accessToken = 'access-refreshed';
        await _json(request, 200, <String, dynamic>{
          'access_token': accessToken,
          'refresh_token': refreshTokenValue,
          'token_type': 'Bearer',
          'expires_in': 3600,
        });
      default:
        await _json(request, 400, <String, dynamic>{
          'error': 'unsupported_grant_type',
        });
    }
  }

  Future<void> _json(
    HttpRequest request,
    int status,
    Map<String, dynamic> body,
  ) async {
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await request.response.close();
  }
}

class _PendingGrant {
  _PendingGrant({required this.challenge, required this.redirectUri});

  final String challenge;
  final String redirectUri;
}

/// 模拟系统浏览器：先看 302（不跟随），再“导航”到 Location。
Future<http.Response> fakeBrowserNavigate(
  Uri authorizationUri, {
  int firstStatus = 302,
}) async {
  final browser = http.Client();
  try {
    final probe = http.Request('GET', authorizationUri)
      ..followRedirects = false;
    final first = await browser.send(probe);
    await first.stream.drain<void>();
    expect(first.statusCode, firstStatus);
    final location = first.headers['location'];
    expect(location, isNotNull, reason: '授权端点应返回 302 Location');
    return await browser.get(Uri.parse(location!));
  } finally {
    browser.close();
  }
}

void main() {
  group('PKCE（RFC 7636）', () {
    test('S256 对照 RFC 官方测试向量', () {
      expect(
        codeChallengeS256('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
        'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
      );
    });

    test('verifier 为 43 位 URL-safe 字符', () {
      final verifier = generateCodeVerifier();
      expect(verifier.length, inInclusiveRange(43, 128));
      expect(RegExp(r'^[A-Za-z0-9\-._~]+$').hasMatch(verifier), isTrue);
      expect(verifier, isNot(generateCodeVerifier()));
    });
  });

  group('McpOAuthClient 全流程（真实 HTTP 回环）', () {
    late _FakeOAuthMcpServer fake;
    late AppDatabase db;
    late SettingsRepository repo;

    setUp(() async {
      fake = await _FakeOAuthMcpServer.start();
      db = AppDatabase.memory();
      repo = SettingsRepository(db, InMemoryKeyStore());
    });

    tearDown(() async {
      await fake.close();
      await db.close();
    });

    test('动态注册 → PKCE → loopback 回调 → 令牌落库 → Bearer 连接', () async {
      final id = await repo.createMcpServer(
        name: 'OAuth 服务',
        url: fake.mcpUri.toString(),
        authMode: McpAuthMode.oauth,
        oauthScopes: <String>['tools.read'],
      );
      final config = (await repo.listMcpServers()).single;

      Uri? opened;
      final tokens = await runMcpAuthorizationFlow(
        repo,
        config,
        openBrowser: (uri) async {
          opened = uri;
          final callback = await fakeBrowserNavigate(uri);
          expect(callback.statusCode, 200);
        },
      );

      // 授权地址携带 PKCE / state / resource / scope。
      expect(opened, isNotNull);
      expect(opened!.queryParameters['response_type'], 'code');
      expect(opened!.queryParameters['code_challenge_method'], 'S256');
      expect(opened!.queryParameters['code_challenge'], isNotEmpty);
      expect(opened!.queryParameters['resource'], fake.mcpUri.toString());
      expect(opened!.queryParameters['scope'], 'tools.read');

      expect(tokens.accessToken, 'access-1');
      expect(tokens.refreshToken, 'refresh-1');
      expect(tokens.expiresAt, isNotNull);

      // 动态注册的 client_id 已回写配置，令牌已入安全存储。
      final saved = (await repo.listMcpServers()).single;
      expect(saved.oauthClientId, 'dyn-client-1');
      expect(await repo.hasMcpOAuthTokens(id), isTrue);
      final stored = await repo.readMcpOAuthTokens(id);
      expect(stored!.accessToken, 'access-1');

      // 服务器端 PKCE 校验（不匹配会 400 并让整个流程失败）。
      expect(fake.lastCodeVerifier, isNotEmpty);
      // 发现阶段走过 401 + WWW-Authenticate 质询（RFC 9728）。
      expect(fake.challenge401Count, greaterThan(0));

      // 授权后的令牌即刻可用：连接 MCP、列工具、调工具。
      final names = await listMcpToolNames(
        config: saved,
        credentials: McpCredentials(oauthTokens: stored),
      );
      expect(names, <String>['echo']);
      final session = await openMcpTools(
        config: saved,
        credentials: McpCredentials(oauthTokens: stored),
      );
      try {
        expect(session.tools.single.name, '${mcpToolPrefix}echo');
        final text = await session.tools.single.execute(<String, dynamic>{
          'text': '你好',
        });
        expect(text, 'echo:你好');
      } finally {
        await session.close();
      }
    });

    test('回调 state 被篡改时中止授权且不落令牌', () async {
      final id = await repo.createMcpServer(
        name: 'OAuth 服务',
        url: fake.mcpUri.toString(),
        authMode: McpAuthMode.oauth,
      );
      fake.tamperState = true;
      final config = (await repo.listMcpServers()).single;

      await expectLater(
        runMcpAuthorizationFlow(
          repo,
          config,
          openBrowser: (uri) async {
            final callback = await fakeBrowserNavigate(uri);
            expect(callback.statusCode, 400);
          },
        ),
        throwsA(isA<McpOAuthException>()),
      );
      expect(await repo.hasMcpOAuthTokens(id), isFalse);
    });

    test('令牌过期时自动 refresh 并回写', () async {
      final id = await repo.createMcpServer(
        name: 'OAuth 服务',
        url: fake.mcpUri.toString(),
        authMode: McpAuthMode.oauth,
        oauthClientId: 'dyn-client-1',
      );
      await repo.saveMcpOAuthTokens(
        id,
        McpOAuthTokens(
          accessToken: 'stale',
          refreshToken: fake.refreshTokenValue,
          expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      );
      final config = (await repo.listMcpServers()).single;

      final credentials = await resolveMcpCredentials(repo, config);

      expect(credentials.oauthTokens!.accessToken, 'access-refreshed');
      expect(fake.refreshCount, 1);
      final stored = await repo.readMcpOAuthTokens(id);
      expect(stored!.accessToken, 'access-refreshed');
    });

    test('刷新失败时清除令牌并提示重新授权', () async {
      final id = await repo.createMcpServer(
        name: 'OAuth 服务',
        url: fake.mcpUri.toString(),
        authMode: McpAuthMode.oauth,
      );
      await repo.saveMcpOAuthTokens(
        id,
        McpOAuthTokens(
          accessToken: 'stale',
          refreshToken: 'wrong-refresh',
          expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      );
      final config = (await repo.listMcpServers()).single;

      await expectLater(
        resolveMcpCredentials(repo, config),
        throwsA(isA<McpAuthRequiredException>()),
      );
      expect(await repo.hasMcpOAuthTokens(id), isFalse);
    });
  });

  group('连接凭据与错误映射', () {
    late _FakeOAuthMcpServer fake;

    setUp(() async {
      fake = await _FakeOAuthMcpServer.start();
    });

    tearDown(() => fake.close());

    test('OAuth 模式缺令牌：本地拦截，不发请求', () async {
      final config = McpServerConfig(
        id: 1,
        name: 'x',
        url: fake.mcpUri.toString(),
        authMode: McpAuthMode.oauth,
      );
      await expectLater(
        listMcpToolNames(config: config),
        throwsA(isA<McpAuthRequiredException>()),
      );
    });

    test('无令牌直连（headers 模式）遇 401：映射为重新授权提示', () async {
      final config = McpServerConfig(
        id: 1,
        name: 'x',
        url: fake.mcpUri.toString(),
      );
      await expectLater(
        listMcpToolNames(config: config),
        throwsA(
          isA<McpAuthRequiredException>().having(
            (e) => e.message,
            'message',
            contains('重新授权'),
          ),
        ),
      );
    });

    test('服务器不支持 OAuth（无发现信息）时给出可读错误', () async {
      final bare = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => bare.close(force: true));
      bare.listen((request) async {
        request.response.statusCode = 404;
        await request.response.close();
      });
      final client = McpOAuthClient(
        resourceUri: Uri.parse('http://127.0.0.1:${bare.port}/mcp'),
      );
      await expectLater(
        client.startAuthorization(),
        throwsA(
          isA<McpOAuthException>().having(
            (e) => e.message,
            'message',
            contains('受保护资源元数据'),
          ),
        ),
      );
    });

    test('非回环 http 地址被拒绝', () async {
      final client = McpOAuthClient(
        resourceUri: Uri.parse('http://example.com/mcp'),
      );
      await expectLater(
        client.startAuthorization(),
        throwsA(
          isA<McpOAuthException>().having(
            (e) => e.message,
            'message',
            contains('HTTPS'),
          ),
        ),
      );
    });
  });
}
