import 'package:mcp_dart/mcp_dart.dart' as mcp;

import '../agent_core.dart';
import 'mcp_oauth.dart';

/// MCP 远程工具在本地工具集中的命名前缀，避免与内置工具（get_chapter 等）重名。
const String mcpToolPrefix = 'mcp_';

/// 认证方式（ENH-21）。
enum McpAuthMode {
  /// 自定义请求头（可空；密钥只存安全存储，不随配置 JSON 落库）。
  headers,

  /// OAuth 2.1 PKCE（令牌只存安全存储；流程见 mcp_oauth.dart）。
  oauth,
}

/// 一个远程 MCP server 的配置（不含密钥；认证材料单独存安全存储）。
class McpServerConfig {
  const McpServerConfig({
    required this.id,
    required this.name,
    required this.url,
    this.enabled = true,
    this.allowedTools = const <String>[],
    this.authMode = McpAuthMode.headers,
    this.oauthClientId = '',
    this.oauthScopes = const <String>[],
  });

  final int id;
  final String name;

  /// Streamable HTTP 端点完整地址，如 https://example.com/mcp。
  final String url;
  final bool enabled;

  /// 允许暴露给模型的工具名白名单；为空表示全部允许（用于控制计费与信任面）。
  final List<String> allowedTools;

  /// 认证方式；历史配置缺省为 [McpAuthMode.headers]（行为不变）。
  final McpAuthMode authMode;

  /// OAuth 预注册 client_id；空串表示走动态注册，
  /// 动态注册结果会在首次授权后回写到这里。
  final String oauthClientId;

  /// OAuth 请求的 scope 列表（可为空，由授权服务器决定默认值）。
  final List<String> oauthScopes;

  bool allowsTool(String name) =>
      allowedTools.isEmpty || allowedTools.contains(name);

  McpServerConfig copyWith({
    String? name,
    String? url,
    bool? enabled,
    List<String>? allowedTools,
    McpAuthMode? authMode,
    String? oauthClientId,
    List<String>? oauthScopes,
  }) {
    return McpServerConfig(
      id: id,
      name: name ?? this.name,
      url: url ?? this.url,
      enabled: enabled ?? this.enabled,
      allowedTools: allowedTools ?? this.allowedTools,
      authMode: authMode ?? this.authMode,
      oauthClientId: oauthClientId ?? this.oauthClientId,
      oauthScopes: oauthScopes ?? this.oauthScopes,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'url': url,
    'enabled': enabled,
    'allowedTools': allowedTools,
    'authMode': authMode.name,
    'oauthClientId': oauthClientId,
    'oauthScopes': oauthScopes,
  };

  factory McpServerConfig.fromJson(Map<String, dynamic> json) {
    return McpServerConfig(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      url: json['url'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      allowedTools:
          (json['allowedTools'] as List?)?.whereType<String>().toList() ??
          const <String>[],
      authMode: json['authMode'] == McpAuthMode.oauth.name
          ? McpAuthMode.oauth
          : McpAuthMode.headers,
      oauthClientId: json['oauthClientId'] as String? ?? '',
      oauthScopes:
          (json['oauthScopes'] as List?)?.whereType<String>().toList() ??
          const <String>[],
    );
  }
}

/// 连接一个 server 所需的凭据（ENH-21）：
/// 自定义请求头（可空）+ OAuth 访问令牌（authMode=oauth 时必填）。
class McpCredentials {
  const McpCredentials({
    this.headers = const <String, String>{},
    this.oauthTokens,
  });

  final Map<String, String> headers;
  final McpOAuthTokens? oauthTokens;
}

/// OAuth 模式下缺少可用令牌（未授权或已失效）：UI 应引导到设置页重新授权。
class McpAuthRequiredException implements Exception {
  const McpAuthRequiredException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 解析用户填写的认证头文本：每行一条 `Key: Value`（也容忍 `Key=Value`）。
/// 密钥本体只存安全存储，不随配置 JSON 落库（与 API key 同策略）。
Map<String, String> parseAuthHeaders(String raw) {
  final headers = <String, String>{};
  for (final line in raw.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    final separator = trimmed.contains(':')
        ? trimmed.indexOf(':')
        : trimmed.indexOf('=');
    if (separator <= 0) continue;
    final key = trimmed.substring(0, separator).trim();
    final value = trimmed.substring(separator + 1).trim();
    if (key.isEmpty || value.isEmpty) continue;
    headers[key] = value;
  }
  return headers;
}

/// 已连接的 MCP 会话：持有连接与包装后的工具，用完须 [close]。
/// 抽成接口便于单测注入假实现（不发起真实网络连接）。
abstract interface class McpToolSession {
  String get serverName;

  List<Tool> get tools;

  Future<void> close();
}

/// 连接一个远程 server 后返回的工具会话。
class _RemoteMcpSession implements McpToolSession {
  _RemoteMcpSession(this._client, this.serverName, this.tools);

  final mcp.McpClient _client;

  @override
  final String serverName;

  @override
  final List<Tool> tools;

  bool _closed = false;

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _safeClose(_client);
  }
}

/// 打开 MCP 工具会话的函数签名（便于单测注入假实现，替代 [openMcpTools]）。
typedef McpToolOpener =
    Future<McpToolSession> Function(
      McpServerConfig config,
      McpCredentials credentials,
    );

mcp.McpClient _newClient() => mcp.McpClient(
  const mcp.Implementation(name: 'novelphone', version: '1.0.0'),
);

/// 只读令牌来源：把仓库层已存的 OAuth 令牌交给 transport，
/// 由其自动附加 `Authorization: Bearer`。交互式授权由 App 侧流程
/// （mcp_oauth.dart）负责，不交给 transport 内部状态机。
class _StoredTokensProvider implements mcp.OAuthClientProvider {
  _StoredTokensProvider(this._tokens);

  final McpOAuthTokens _tokens;

  @override
  Future<mcp.OAuthTokens?> tokens() async => mcp.OAuthTokens(
    accessToken: _tokens.accessToken,
    refreshToken: _tokens.refreshToken,
  );

  @override
  Future<void> redirectToAuthorization() async {
    throw const McpAuthRequiredException('OAuth 令牌已失效，请在设置中对该服务器重新授权');
  }
}

mcp.StreamableHttpClientTransport _transport(
  McpServerConfig config,
  McpCredentials credentials,
) {
  final headers = credentials.headers;
  final tokens = credentials.oauthTokens;
  return mcp.StreamableHttpClientTransport(
    Uri.parse(config.url),
    opts: mcp.StreamableHttpClientTransportOptions(
      requestInit: headers.isEmpty
          ? null
          : <String, dynamic>{'headers': headers},
      authProvider: tokens == null ? null : _StoredTokensProvider(tokens),
    ),
  );
}

void _requireCredentials(McpServerConfig config, McpCredentials credentials) {
  if (config.authMode == McpAuthMode.oauth && credentials.oauthTokens == null) {
    throw const McpAuthRequiredException('该服务器使用 OAuth 2.1 认证，请先在设置中完成授权');
  }
}

/// 连接期错误的用户化映射：HTTP 401/403 视为认证问题（未授权或令牌失效），
/// 其余原样抛出（McpError 自带可读信息，交给「测试连接」直接展示）。
Object _mappedMcpError(mcp.McpError error) {
  final message = error.message;
  if (message.contains('HTTP 401') || message.contains('HTTP 403')) {
    return const McpAuthRequiredException(
      '服务器拒绝了访问（HTTP 401/403），未授权或令牌已失效，请检查认证配置或重新授权',
    );
  }
  return error;
}

/// 连接一个 MCP server 并返回其工具名列表（设置页「测试连接」用）。
Future<List<String>> listMcpToolNames({
  required McpServerConfig config,
  McpCredentials credentials = const McpCredentials(),
}) async {
  _requireCredentials(config, credentials);
  final client = _newClient();
  try {
    await client.connect(_transport(config, credentials));
    final result = await client.listTools();
    return result.tools.map((t) => t.name).toList();
  } on mcp.UnauthorizedError {
    throw const McpAuthRequiredException('服务器拒绝了访问（未授权或令牌已失效），请重新授权');
  } on mcp.McpError catch (error) {
    throw _mappedMcpError(error);
  } finally {
    await _safeClose(client);
  }
}

/// 连接一个 MCP server，把 `tools/list` 结果包装为同构 [Tool]（ARCHITECTURE 5.4）。
/// 工具名统一加 [mcpToolPrefix] 前缀；不在白名单内的工具不暴露。
Future<McpToolSession> openMcpTools({
  required McpServerConfig config,
  McpCredentials credentials = const McpCredentials(),
}) async {
  _requireCredentials(config, credentials);
  final client = _newClient();
  try {
    await client.connect(_transport(config, credentials));
    final result = await client.listTools();
    final tools = <Tool>[];
    for (final remote in result.tools) {
      if (!config.allowsTool(remote.name)) continue;
      tools.add(
        Tool(
          name: '$mcpToolPrefix${remote.name}',
          description: remote.description ?? '远程 MCP 工具 ${remote.name}',
          inputSchema: remote.inputSchema.toJson(),
          execute: (args) => _callTool(client, remote.name, args),
        ),
      );
    }
    return _RemoteMcpSession(client, config.name, tools);
  } on mcp.UnauthorizedError {
    await _safeClose(client);
    throw const McpAuthRequiredException('服务器拒绝了访问（未授权或令牌已失效），请重新授权');
  } on mcp.McpError catch (error) {
    await _safeClose(client);
    throw _mappedMcpError(error);
  } catch (e) {
    await _safeClose(client);
    rethrow;
  }
}

Future<String> _callTool(
  mcp.McpClient client,
  String name,
  Map<String, dynamic> args,
) async {
  final result = await client.callTool(
    mcp.CallToolRequest(name: name, arguments: args),
  );
  final text = _contentText(result.content);
  if (result.isError) return '远程工具返回错误：$text';
  return text.isEmpty ? '（远程工具无文本输出）' : text;
}

String _contentText(List<mcp.Content> content) {
  final buffer = StringBuffer();
  for (final item in content) {
    if (item is mcp.TextContent) {
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.write(item.text);
    }
  }
  return buffer.toString();
}

Future<void> _safeClose(mcp.McpClient client) async {
  try {
    await client.close();
  } catch (_) {
    // 忽略：连接未建立或已失效。
  }
}
