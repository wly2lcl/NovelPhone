import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/ai/mcp/mcp_bridge.dart';
import '../../data/data_providers.dart';
import '../../l10n/l10n.dart';

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
      if (await repo.hasMcpAuthHeaders(server.id)) withAuth.add(server.id);
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
                      Switch(
                        value: server.enabled,
                        activeTrackColor: context.paper.accent,
                        onChanged: (value) => _toggle(server, value),
                      ),
                      PopupMenuButton<String>(
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
  final _allowedTools = TextEditingController();

  bool _enabled = true;
  bool _hasAuth = false;
  bool _loading = true;
  bool _testing = false;
  String? _testMessage;
  bool _testOk = false;

  bool get _isNew => widget.serverId == null;

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
    _allowedTools.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_isNew) {
      setState(() => _loading = false);
      return;
    }
    final repo = ref.read(settingsRepositoryProvider);
    final servers = await repo.listMcpServers();
    McpServerConfig? server;
    for (final candidate in servers) {
      if (candidate.id == widget.serverId) {
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
    if (!mounted) return;
    setState(() {
      _name.text = found.name;
      _url.text = found.url;
      _allowedTools.text = found.allowedTools.join('\n');
      _enabled = found.enabled;
      _hasAuth = hasAuth;
      _loading = false;
    });
  }

  List<String> get _toolList => _allowedTools.text
      .split('\n')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  /// 当前生效的认证头文本：输入框优先，其次已存值（编辑时留空表示不修改）。
  Future<String> _effectiveAuth() async {
    final typed = _auth.text.trim();
    if (typed.isNotEmpty) return typed;
    if (_isNew) return '';
    return await ref
            .read(settingsRepositoryProvider)
            .readMcpAuthHeaders(widget.serverId!) ??
        '';
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final repo = ref.read(settingsRepositoryProvider);
    final name = _name.text.trim();
    final url = _url.text.trim();
    final tools = _toolList;
    final auth = _auth.text.trim();

    if (_isNew) {
      await repo.createMcpServer(
        name: name,
        url: url,
        allowedTools: tools,
        authHeaders: auth.isEmpty ? null : auth,
      );
    } else {
      final servers = await repo.listMcpServers();
      final server = servers.where((s) => s.id == widget.serverId).first;
      await repo.updateMcpServer(
        server.copyWith(
          name: name,
          url: url,
          enabled: _enabled,
          allowedTools: tools,
        ),
        authHeaders: auth.isEmpty ? null : auth,
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.mcpSaved)));
    Navigator.of(context).pop();
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
    setState(() {
      _testing = true;
      _testMessage = null;
    });
    final config = McpServerConfig(
      id: widget.serverId ?? 0,
      name: _name.text.trim(),
      url: url,
      enabled: _enabled,
      allowedTools: _toolList,
    );
    String message;
    var ok = false;
    try {
      final names = await listMcpToolNames(
        config: config,
        headers: parseAuthHeaders(await _effectiveAuth()),
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
                  ),
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
