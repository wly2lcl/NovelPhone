// 假 OAuth MCP 服务器（ENH-21）：本机回环上模拟 MCP 授权规范
// （2025-06-18）全链路，用于真机验证「设置 → MCP 工具服务 → OAuth 2.1」
// 的授权与调用流程，无需真实授权服务器与真实 MCP 服务。
//
// 用法：
//   dart run tool/fake_mcp_oauth_server.dart [port]   # 默认 8899
//   adb reverse tcp:8899 tcp:8899
//   应用内新增 MCP 服务：地址填 http://127.0.0.1:8899/mcp，认证方式选
//   「OAuth 2.1（PKCE）」，「开始授权」后浏览器会自动回跳应用完成授权。
//
// 流程（全部在同一端口模拟，逐步打印日志）：
//   1. GET  /mcp 未带令牌 → 401 + WWW-Authenticate 质询（resource_metadata）
//   2. GET  /.well-known/oauth-protected-resource → authorization_servers
//   3. GET  /.well-known/oauth-authorization-server → 授权端点元数据
//   4. POST /register → 动态注册，返回 client_id
//   5. GET  /authorize → 302 回应用 loopback 回调（携带 code/state）
//   6. POST /token → 对照 S256(code_verifier) 与 code_challenge 完成 PKCE 校验
//   7. POST /mcp 带 Bearer → SSE 返回 initialize / tools/list / tools/call
//
// 观测：GET /stats 返回各步骤计数（JSON），GET /stats/reset 清零计数与其
// 已发放的授权码。
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;

Future<void> main(List<String> args) async {
  final port = args.isNotEmpty ? int.parse(args.first) : 8899;
  final server = FakeOAuthMcpServer();
  await server.start(port);
}

class FakeOAuthMcpServer {
  int _port = 0;

  /// authorization code → code_challenge（PKCE S256）。
  final Map<String, String> _codes = <String, String>{};

  /// 各步骤计数（/stats 与 /stats/reset 不计入）。
  final Map<String, int> _counts = <String, int>{};

  String _accessToken = 'access-token-1';
  final String _refreshToken = 'refresh-token-1';

  Uri get _base => Uri.parse('http://127.0.0.1:$_port');

  Future<void> start(int port) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _port = server.port;
    stdout.writeln('fake-oauth-mcp 已启动：$_base');
    stdout.writeln('  MCP 端点（应用内填写）：$_base/mcp');
    stdout.writeln('  观测：GET /stats、GET /stats/reset');
    stdout.writeln('  提示：先执行 adb reverse tcp:$_port tcp:$_port');
    await for (final request in server) {
      unawaited(_handle(request));
    }
  }

  void _bump(String key) => _counts[key] = (_counts[key] ?? 0) + 1;

  void _log(String message) {
    final now = DateTime.now().toIso8601String().substring(11, 19);
    stdout.writeln('[$now] $message');
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      final path = request.uri.path;
      if (request.method == 'GET' && path == '/stats') {
        await _json(request, 200, <String, dynamic>{
          'counts': _counts,
          'total': _counts.values.fold(0, (sum, n) => sum + n),
        });
        return;
      }
      if (request.method == 'GET' && path == '/stats/reset') {
        final cleared = <String, int>{..._counts};
        _counts.clear();
        _codes.clear();
        _accessToken = 'access-token-1';
        await _json(request, 200, <String, dynamic>{'cleared': cleared});
        return;
      }
      switch (path) {
        case '/mcp':
          await _handleMcp(request);
        case '/.well-known/oauth-protected-resource':
          _bump('protectedResourceMetadata');
          _log('受保护资源元数据请求');
          await _json(request, 200, <String, dynamic>{
            'resource': '$_base/mcp',
            'authorization_servers': <String>['$_base'],
          });
        case '/.well-known/oauth-authorization-server':
          _bump('authServerMetadata');
          _log('授权服务器元数据请求');
          await _json(request, 200, <String, dynamic>{
            'issuer': '$_base',
            'authorization_endpoint': '$_base/authorize',
            'token_endpoint': '$_base/token',
            'registration_endpoint': '$_base/register',
            'code_challenge_methods_supported': <String>['S256'],
          });
        case '/register':
          _bump('register');
          final clientName = await _readJsonField(request, 'client_name');
          _log('动态注册客户端：${clientName ?? '(未命名)'} → dyn-client-1');
          await _json(request, 200, <String, dynamic>{
            'client_id': 'dyn-client-1',
            'client_name': clientName ?? 'NovelPhone',
          });
        case '/authorize':
          await _handleAuthorize(request);
        case '/token':
          await _handleToken(request);
        default:
          await _json(request, 404, <String, dynamic>{'error': 'not_found'});
      }
    } catch (e) {
      _log('请求处理异常：$e');
      try {
        await request.response.close();
      } catch (_) {}
    }
  }

  // ---------- MCP 资源端点 ----------

  Future<void> _handleMcp(HttpRequest request) async {
    final auth = request.headers.value('authorization') ?? '';
    if (auth != 'Bearer $_accessToken') {
      _bump('challenge401');
      _log('MCP 未授权访问（${auth.isEmpty ? '无 Authorization 头' : auth}）→ 401 质询');
      request.response
        ..statusCode = 401
        ..headers.set(
          'www-authenticate',
          'Bearer resource_metadata='
              '"$_base/.well-known/oauth-protected-resource"',
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
    _bump('mcpCalls');
    final body = await utf8.decodeStream(request);
    final message = jsonDecode(body) as Map<String, dynamic>;
    final id = message['id'];
    final method = message['method'] as String? ?? '';
    if (id == null) {
      // 通知（如 notifications/initialized）：202 无正文。
      request.response.statusCode = 202;
      await request.response.close();
      return;
    }
    if (method == 'server/discover') {
      // 按“旧协议服务器”行事：对现代发现请求回 400，
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
    _log('MCP 调用：$method (id=$id)');
    final result = _jsonRpcResult(message);
    await _sse(request, <String, dynamic>{
      'jsonrpc': '2.0',
      'id': id,
      'result': result,
    });
  }

  Map<String, dynamic> _jsonRpcResult(Map<String, dynamic> message) {
    switch (message['method']) {
      case 'initialize':
        final params =
            message['params'] as Map<String, dynamic>? ?? <String, dynamic>{};
        return <String, dynamic>{
          'protocolVersion': params['protocolVersion'] ?? '2025-06-18',
          'capabilities': <String, dynamic>{
            'tools': <String, dynamic>{},
          },
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
              'description': '回显输入文本（fake-oauth-mcp）',
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
            <String, dynamic>{
              'type': 'text',
              'text': 'echo:${args['text']}（fake-oauth-mcp）',
            },
          ],
        };
      default:
        return <String, dynamic>{};
    }
  }

  // ---------- 授权端点 ----------

  Future<void> _handleAuthorize(HttpRequest request) async {
    final query = request.uri.queryParameters;
    final redirectUri = query['redirect_uri'] ?? '';
    final state = query['state'] ?? '';
    final challenge = query['code_challenge'] ?? '';
    if (redirectUri.isEmpty || challenge.isEmpty) {
      await _json(request, 400, <String, dynamic>{'error': 'invalid_request'});
      return;
    }
    _bump('authorize');
    final code = 'code-${_codes.length + 1}';
    _codes[code] = challenge;
    _log('授权请求：client_id=${query['client_id']}，已签发 $code（302 回跳应用）');
    final redirect = Uri.parse(redirectUri).replace(
      queryParameters: <String, String>{'code': code, 'state': state},
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
        final code = form['code'] ?? '';
        final challenge = _codes[code];
        _bump('token');
        if (challenge == null) {
          _log('令牌请求失败：授权码不存在或已使用（$code）');
          await _json(request, 400, <String, dynamic>{'error': 'invalid_grant'});
          return;
        }
        _codes.remove(code);
        final verifier = form['code_verifier'] ?? '';
        // PKCE 服务器端校验：S256(code_verifier) 必须等于 code_challenge。
        final actual = _s256(verifier);
        if (verifier.isEmpty || actual != challenge) {
          _bump('pkceFailed');
          _log('PKCE 校验失败：code_verifier 与 code_challenge 不匹配');
          await _json(request, 400, <String, dynamic>{
            'error': 'invalid_grant',
            'error_description': 'PKCE verification failed',
          });
          return;
        }
        _log('PKCE 校验通过，签发访问令牌($_accessToken)与刷新令牌');
        await _json(request, 200, <String, dynamic>{
          'access_token': _accessToken,
          'refresh_token': _refreshToken,
          'token_type': 'Bearer',
          'expires_in': 3600,
        });
      case 'refresh_token':
        _bump('refresh');
        if (form['refresh_token'] != _refreshToken) {
          await _json(request, 400, <String, dynamic>{'error': 'invalid_grant'});
          return;
        }
        _accessToken = 'access-token-${DateTime.now().millisecondsSinceEpoch}';
        _log('刷新令牌：签发新访问令牌($_accessToken)');
        await _json(request, 200, <String, dynamic>{
          'access_token': _accessToken,
          'refresh_token': _refreshToken,
          'token_type': 'Bearer',
          'expires_in': 3600,
        });
      default:
        await _json(request, 400, <String, dynamic>{
          'error': 'unsupported_grant_type',
        });
    }
  }

  // ---------- 小工具 ----------

  String _s256(String verifier) => base64Url
      .encode(crypto.sha256.convert(utf8.encode(verifier)).bytes)
      .replaceAll('=', '');

  Future<String?> _readJsonField(HttpRequest request, String field) async {
    try {
      final body = await utf8.decodeStream(request);
      final decoded = jsonDecode(body);
      if (decoded is Map) return decoded[field] as String?;
    } catch (_) {
      // 容忍空体/非法 JSON。
    }
    return null;
  }

  Future<void> _sse(HttpRequest request, Map<String, dynamic> message) async {
    request.response
      ..statusCode = 200
      ..headers.contentType = ContentType(
        'text',
        'event-stream',
        charset: 'utf-8',
      )
      ..write('event: message\ndata: ${jsonEncode(message)}\n\n');
    await request.response.close();
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
