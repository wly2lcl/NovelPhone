import 'package:http/http.dart' as http;

import '../../core/ai/mcp/mcp_bridge.dart';
import '../../core/ai/mcp/mcp_oauth.dart';
import '../../data/repositories/settings_repository.dart';

/// MCP 连接凭据解析与 OAuth 授权执行（ENH-21）。
///
/// 放在 features 层，因为需要同时触达仓库层（安全存储）与 core 流程库；
/// ai_service 与设置页共用这里的逻辑，避免两处漂移。

/// 解析一个 server 的连接凭据：
/// · headers 模式：直读认证头；
/// · oauth 模式：读令牌，过期时自动用 refresh_token 续期并回写；
///   无令牌 / 刷新失败抛 [McpAuthRequiredException]，UI 引导重新授权。
Future<McpCredentials> resolveMcpCredentials(
  SettingsRepository repository,
  McpServerConfig config, {
  http.Client? httpClient,
}) async {
  final headers = await repository.resolveMcpHeaders(config.id);
  if (config.authMode != McpAuthMode.oauth) {
    return McpCredentials(headers: headers);
  }
  var tokens = await repository.readMcpOAuthTokens(config.id);
  if (tokens == null) {
    throw const McpAuthRequiredException('该服务器使用 OAuth 2.1 认证，请先在设置中完成授权');
  }
  if (tokens.isExpired) {
    try {
      final client = McpOAuthClient(
        resourceUri: Uri.parse(config.url),
        clientId: config.oauthClientId,
        scopes: config.oauthScopes,
        httpClient: httpClient,
      );
      tokens = await client.refreshToken(tokens);
      await repository.saveMcpOAuthTokens(config.id, tokens);
    } catch (_) {
      await repository.clearMcpOAuthTokens(config.id);
      throw const McpAuthRequiredException('OAuth 令牌已过期且刷新失败，请重新授权');
    }
  }
  return McpCredentials(headers: headers, oauthTokens: tokens);
}

/// 发起一轮 OAuth 授权并等待完成：
/// 动态注册的 client_id 先落库（避免重复注册），成功后令牌入安全存储。
/// [openBrowser] 由 UI 层注入（url_launcher 打开系统浏览器）。
Future<McpOAuthTokens> runMcpAuthorizationFlow(
  SettingsRepository repository,
  McpServerConfig config, {
  required Future<void> Function(Uri authorizationUri) openBrowser,
  http.Client? httpClient,
}) async {
  final client = McpOAuthClient(
    resourceUri: Uri.parse(config.url),
    clientId: config.oauthClientId,
    scopes: config.oauthScopes,
    httpClient: httpClient,
  );
  final session = await client.startAuthorization();
  final registered = session.registeredClientId;
  if (registered != null && registered != config.oauthClientId) {
    await repository.updateMcpServer(
      config.copyWith(oauthClientId: registered),
    );
  }
  await openBrowser(session.authorizationUri);
  final tokens = await session.tokens;
  await repository.saveMcpOAuthTokens(config.id, tokens);
  return tokens;
}
