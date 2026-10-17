import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/ai/mcp/mcp_bridge.dart';
import '../../core/ai/mcp/mcp_oauth.dart';
import '../../data/data_providers.dart';
import '../../l10n/l10n.dart';
import '../ai/mcp_credentials.dart';

/// MCP 工具服务管理（B-02）：维护远程 Streamable HTTP server 与认证头。
/// 认证头只写安全存储（与 API key 同策略），配置 JSON 仅存 URL / 白名单。
class McpServersPage extends ConsumerStatefulWidget {
  const McpServersPage({super.key});

  @override
  ConsumerState<McpServersPage> createState() => _McpServersPageState();
}

class _McpServersPageState extends ConsumerState<McpServersPage> {
  List<McpServerConfig>? _servers;
  Set<int> _withAuth = <int>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(settingsRepositoryProvider);
    final list = await repo.listMcpServers();
    final withAuth = <int>{};
    for (final server in list) {
      if (await repo.hasMcpAuthHeaders(server.id) ||
          await repo.hasMcpOAuthTokens(server.id)) {
        withAuth.add(server.id);
      }
    }
    if (mounted) {
      setState(() {
        _servers = list;
        _withAuth = withAuth;
      });
    }
  }

  Future<void> _openEdit(int? id) async {
    await context.push('/settings/mcp-servers/${id ?? 'new'}');
    await _load();
  }

  Future<void> _toggle(McpServerConfig server, bool enabled) async {
    await ref
        .read(settingsRepositoryProvider)
        .updateMcpServer(server.copyWith(enabled: enabled));
    await _load();
  }

  Future<void> _confirmDelete(McpServerConfig server) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.mcpDeleteTitle),
        content: Text(l10n.mcpDeleteBody(server.name)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(settingsRepositoryProvider).deleteMcpServer(server.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final servers = _servers;
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mcpTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEdit(null),
        icon: const Icon(Icons.add),
        label: Text(l10n.mcpAdd),
      ),
      body: servers == null
          ? const Center(child: CircularProgressIndicator())
          : servers.isEmpty
          ? const _EmptyHint()
          : ListView.separated(
              itemCount: servers.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final server = servers[index];
                return ListTile(
                  leading: Icon(
                    _withAuth.contains(server.id)
                        ? Icons.vpn_key
                        : Icons.vpn_key_off_outlined,
                    color: _withAuth.contains(server.id)
                        ? context.paper.accent
                        : context.paper.inkSoft,
                  ),
                  title: Text(server.name),
                  subtitle: Text(
                    '${server.url}\n'
                    '${server.allowedTools.isEmpty ? l10n.mcpAllTools : l10n.mcpWhitelist(server.allowedTools.join(l10n.mcpListSeparator))}',
                    maxLines: 3,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.paper.inkSoft,
                    ),
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Semantics(
                        label: l10n.mcpEnableSwitch(server.name),
                        child: Switch(
                          value: server.enabled,
                          activeTrackColor: context.paper.accent,
                          onChanged: (value) => _toggle(server, value),
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: l10n.commonMoreActions,
                        onSelected: (value) async {
                          switch (value) {
                            case 'edit':
                              await _openEdit(server.id);
                            case 'delete':
                              await _confirmDelete(server);
                          }
                        },
                        itemBuilder: (context) => <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                            value: 'edit',
                            child: Text(context.l10n.commonEdit),
                          ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Text(context.l10n.commonDelete),
                          ),
                        ],
                      ),
                    ],
                  ),
                  onTap: () => _openEdit(server.id),
                );
              },
            ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.hub_outlined, size: 40, color: context.paper.inkSoft),
            const SizedBox(height: 12),
            Text(context.l10n.mcpEmptyTitle),
            const SizedBox(height: 4),
            Text(
              context.l10n.mcpEmptyHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// MCP server 编辑（B-02）：URL + 自定义请求头（Token 认证）+ 工具白名单。
class McpServerEditPage extends ConsumerStatefulWidget {
  const McpServerEditPage({super.key, this.serverId});

  /// null 表示新增。
  final int? serverId;

  @override
  ConsumerState<McpServerEditPage> createState() => _McpServerEditPageState();
}

class _McpServerEditPageState extends ConsumerState<McpServerEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _url = TextEditingController();
  final _auth = TextEditingController();
  final _oauthClientId = TextEditingController();
  final _oauthScopes = TextEditingController();
  final _allowedTools = TextEditingController();

  bool _enabled = true;
  bool _hasAuth = false;
  bool _hasOAuthTokens = false;
  bool _loading = true;
  bool _testing = false;
  bool _authorizing = false;
  String? _testMessage;
  bool _testOk = false;
  McpAuthMode _authMode = McpAuthMode.headers;

  /// 新增页保存后回填的 id（授权与测试需要真实 id 挂载令牌）。
  int? _savedId;

  bool get _isNew => widget.serverId == null && _savedId == null;

  int? get _serverId => _savedId ?? widget.serverId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _auth.dispose();
    _oauthClientId.dispose();
    _oauthScopes.dispose();
    _allowedTools.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = _serverId;
    if (id == null) {
      setState(() => _loading = false);
      return;
    }
    final repo = ref.read(settingsRepositoryProvider);
    final servers = await repo.listMcpServers();
    McpServerConfig? server;
    for (final candidate in servers) {
      if (candidate.id == id) {
        server = candidate;
        break;
      }
    }
    if (server == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final found = server;
    final hasAuth = await repo.hasMcpAuthHeaders(found.id);
    final hasTokens = await repo.hasMcpOAuthTokens(found.id);
    if (!mounted) return;
    setState(() {
      _name.text = found.name;
      _url.text = found.url;
      _allowedTools.text = found.allowedTools.join('\n');
      _oauthClientId.text = found.oauthClientId;
      _oauthScopes.text = found.oauthScopes.join(' ');
      _enabled = found.enabled;
      _authMode = found.authMode;
      _hasAuth = hasAuth;
      _hasOAuthTokens = hasTokens;
      _loading = false;
    });
  }

  List<String> get _toolList => _allowedTools.text
      .split('\n')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  /// scope 列表：空格或逗号分隔。
  List<String> get _scopeList => _oauthScopes.text
      .split(RegExp(r'[\s,]+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  /// 当前表单对应的配置（新增页 id 为 0，仅用于授权前预览）。
  McpServerConfig _currentConfig() => McpServerConfig(
    id: _serverId ?? 0,
    name: _name.text.trim(),
    url: _url.text.trim(),
    enabled: _enabled,
    allowedTools: _toolList,
    authMode: _authMode,
    oauthClientId: _oauthClientId.text.trim(),
    oauthScopes: _scopeList,
  );

  /// 当前生效的认证头文本：输入框优先，其次已存值（编辑时留空表示不修改）。
  Future<String> _effectiveAuth() async {
    final typed = _auth.text.trim();
    if (typed.isNotEmpty) return typed;
    final id = _serverId;
    if (id == null) return '';
    return await ref.read(settingsRepositoryProvider).readMcpAuthHeaders(id) ??
        '';
  }

  /// 校验并落库；新增时建档并回填 id（授权流程需要）。失败返回 null。
  Future<McpServerConfig?> _persistConfig() async {
    if (!(_formKey.currentState?.validate() ?? false)) return null;
    final repo = ref.read(settingsRepositoryProvider);
    final name = _name.text.trim();
    final url = _url.text.trim();
    final tools = _toolList;
    final auth = _auth.text.trim();
    final scopes = _scopeList;
    final id = _serverId;
    if (id == null) {
      final createdId = await repo.createMcpServer(
        name: name,
        url: url,
        enabled: _enabled,
        allowedTools: tools,
        authHeaders: auth.isEmpty ? null : auth,
        authMode: _authMode,
        oauthClientId: _oauthClientId.text.trim(),
        oauthScopes: scopes,
      );
      _savedId = createdId;
    } else {
      final servers = await repo.listMcpServers();
      final server = servers.where((s) => s.id == id).first;
      final typedClientId = _oauthClientId.text.trim();
      await repo.updateMcpServer(
        server.copyWith(
          name: name,
          url: url,
          enabled: _enabled,
          allowedTools: tools,
          authMode: _authMode,
          // 表单留空时保留已存值（动态注册回写的 client_id 不能被清掉）。
          oauthClientId: typedClientId.isEmpty
              ? server.oauthClientId
              : typedClientId,
          oauthScopes: scopes,
        ),
        authHeaders: auth.isEmpty ? null : auth,
      );
    }
    return _currentConfig();
  }

  Future<void> _save() async {
    final config = await _persistConfig();
    if (config == null) return;
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.mcpSaved)));
    Navigator.of(context).pop();
  }

  /// 用系统浏览器打开授权页；打不开视为授权失败。
  Future<void> _openBrowser(Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw McpOAuthException('无法打开系统浏览器，请手动完成授权');
    }
  }

  /// 开始 OAuth 授权：先落库（授权需要真实 id 挂载令牌），再拉起浏览器等待回调。
  Future<void> _authorize() async {
    final l10n = context.l10n;
    final config = await _persistConfig();
    if (config == null) return;
    if (!mounted) return;
    setState(() => _authorizing = true);
    Object? failure;
    try {
      await runMcpAuthorizationFlow(
        ref.read(settingsRepositoryProvider),
        config,
        openBrowser: _openBrowser,
      );
    } catch (e) {
      failure = e;
    }
    var clientId = '';
    try {
      final servers = await ref
          .read(settingsRepositoryProvider)
          .listMcpServers();
      for (final server in servers) {
        if (server.id == config.id) {
          clientId = server.oauthClientId;
          break;
        }
      }
    } catch (_) {
      // 读取回显失败不影响授权结果。
    }
    if (!mounted) return;
    setState(() {
      _authorizing = false;
      if (failure == null) {
        _hasOAuthTokens = true;
        if (clientId.isNotEmpty) _oauthClientId.text = clientId;
      }
    });
    final messenger = ScaffoldMessenger.of(context);
    if (failure == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.mcpOAuthSuccess)));
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.mcpOAuthFailed('$failure'))),
      );
    }
  }

  /// 清除本服务器已保存的 OAuth 令牌（登出）。
  Future<void> _clearAuthorization() async {
    final l10n = context.l10n;
    final id = _serverId;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.mcpOAuthClearTitle),
        content: Text(l10n.mcpOAuthClearBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(settingsRepositoryProvider).clearMcpOAuthTokens(id);
    if (!mounted) return;
    setState(() => _hasOAuthTokens = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.mcpOAuthCleared)));
  }

  /// 测试连接：连上后列出该 server 暴露的工具名。
  Future<void> _testConnection() async {
    final l10n = context.l10n;
    final url = _url.text.trim();
    if (url.isEmpty) {
      setState(() {
        _testOk = false;
        _testMessage = l10n.mcpEndpointMissing;
      });
      return;
    }
    if (_authMode == McpAuthMode.oauth && _serverId == null) {
      setState(() {
        _testOk = false;
        _testMessage = l10n.mcpOAuthSaveFirst;
      });
      return;
    }
    setState(() {
      _testing = true;
      _testMessage = null;
    });
    final repo = ref.read(settingsRepositoryProvider);
    final config = _currentConfig();
    String message;
    var ok = false;
    try {
      final credentials = _authMode == McpAuthMode.oauth
          ? await resolveMcpCredentials(repo, config)
          : McpCredentials(headers: parseAuthHeaders(await _effectiveAuth()));
      final names = await listMcpToolNames(
        config: config,
        credentials: credentials,
      );
      ok = true;
      message = names.isEmpty
          ? l10n.mcpTestOkNoTools
          : l10n.mcpTestOkTools(
              names.length,
              names.join(l10n.mcpListSeparator),
            );
    } catch (e) {
      message = l10n.mcpTestFailed('$e');
    }
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testOk = ok;
      _testMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isNew ? context.l10n.mcpNewTitle : context.l10n.mcpEditTitle,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: _loading ? null : _save,
            child: Text(context.l10n.commonSave),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: <Widget>[
                  TextFormField(
                    controller: _name,
                    maxLength: 30,
                    decoration: InputDecoration(
                      labelText: context.l10n.mcpNameLabel,
                      hintText: context.l10n.mcpNameHint,
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? context.l10n.mcpNameRequired
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _url,
                    decoration: InputDecoration(
                      labelText: context.l10n.mcpEndpointLabel,
                      helperText: context.l10n.mcpEndpointHelper,
                    ),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) {
                        return context.l10n.mcpEndpointRequired;
                      }
                      final uri = Uri.tryParse(value);
                      if (uri == null || !uri.hasScheme) {
                        return context.l10n.mcpEndpointInvalid;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.mcpAuthModeLabel,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<McpAuthMode>(
                    segments: <ButtonSegment<McpAuthMode>>[
                      ButtonSegment<McpAuthMode>(
                        value: McpAuthMode.headers,
                        label: Text(context.l10n.mcpAuthModeHeaders),
                      ),
                      ButtonSegment<McpAuthMode>(
                        value: McpAuthMode.oauth,
                        label: Text(context.l10n.mcpAuthModeOAuth),
                      ),
                    ],
                    selected: <McpAuthMode>{_authMode},
                    onSelectionChanged: _authorizing
                        ? null
                        : (selection) =>
                              setState(() => _authMode = selection.first),
                  ),
                  const SizedBox(height: 16),
                  if (_authMode == McpAuthMode.headers)
                    TextFormField(
                      controller: _auth,
                      minLines: 1,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: context.l10n.mcpAuthLabel,
                        hintText: _hasAuth
                            ? context.l10n.mcpAuthHintSaved
                            : context.l10n.mcpAuthHint,
                        helperText: context.l10n.mcpAuthHelper,
                      ),
                    )
                  else ...<Widget>[
                    TextFormField(
                      controller: _oauthClientId,
                      decoration: InputDecoration(
                        labelText: context.l10n.mcpOAuthClientIdLabel,
                        hintText: context.l10n.mcpOAuthClientIdHint,
                        helperText: context.l10n.mcpOAuthClientIdHelper,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _oauthScopes,
                      decoration: InputDecoration(
                        labelText: context.l10n.mcpOAuthScopesLabel,
                        helperText: context.l10n.mcpOAuthScopesHelper,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Icon(
                                  _hasOAuthTokens
                                      ? Icons.verified_user
                                      : Icons.gpp_maybe_outlined,
                                  size: 18,
                                  color: _hasOAuthTokens
                                      ? context.paper.accent
                                      : context.paper.inkSoft,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _hasOAuthTokens
                                        ? context.l10n.mcpOAuthStatusAuthorized
                                        : context
                                              .l10n
                                              .mcpOAuthStatusNotAuthorized,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.l10n.mcpOAuthSecureHint,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.paper.inkSoft,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: <Widget>[
                                FilledButton.tonalIcon(
                                  onPressed: _authorizing ? null : _authorize,
                                  icon: _authorizing
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 1.6,
                                          ),
                                        )
                                      : const Icon(Icons.login, size: 18),
                                  label: Text(
                                    _hasOAuthTokens
                                        ? context.l10n.mcpOAuthReauthorize
                                        : context.l10n.mcpOAuthAuthorize,
                                  ),
                                ),
                                if (_hasOAuthTokens) ...<Widget>[
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: _authorizing
                                        ? null
                                        : _clearAuthorization,
                                    icon: const Icon(Icons.link_off, size: 18),
                                    label: Text(context.l10n.mcpOAuthClear),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _allowedTools,
                    minLines: 2,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: context.l10n.mcpToolsLabel,
                      helperText: context.l10n.mcpToolsHelper,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.l10n.mcpEnable),
                    subtitle: Text(context.l10n.mcpEnableSubtitle),
                    value: _enabled,
                    activeTrackColor: context.paper.accent,
                    onChanged: (v) => setState(() => _enabled = v),
                  ),
                  const Divider(height: 24),
                  Row(
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: _testing ? null : _testConnection,
                        icon: _testing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.6,
                                ),
                              )
                            : const Icon(Icons.wifi_tethering, size: 18),
                        label: Text(context.l10n.mcpTestConnection),
                      ),
                    ],
                  ),
                  if (_testMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _testMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          color: _testOk
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFB3261E),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
