import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/ai/mcp/mcp_bridge.dart';
import '../../data/data_providers.dart';

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
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除 MCP 服务'),
        content: Text('删除「${server.name}」后，其认证头也会一并从本机移除。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
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
    return Scaffold(
      appBar: AppBar(title: const Text('MCP 工具服务')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEdit(null),
        icon: const Icon(Icons.add),
        label: const Text('新增服务'),
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
                    '${server.allowedTools.isEmpty ? '全部工具可用' : '白名单：${server.allowedTools.join('、')}'}',
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
                        itemBuilder: (context) =>
                            const <PopupMenuEntry<String>>[
                              PopupMenuItem<String>(
                                value: 'edit',
                                child: Text('编辑'),
                              ),
                              PopupMenuItem<String>(
                                value: 'delete',
                                child: Text('删除'),
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
            const Text('还没有 MCP 服务'),
            const SizedBox(height: 4),
            Text(
              '添加远程 MCP server 后，其工具会在「桥段点子」生成时供 AI 调用',
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
    ).showSnackBar(const SnackBar(content: Text('已保存')));
    Navigator.of(context).pop();
  }

  /// 测试连接：连上后列出该 server 暴露的工具名。
  Future<void> _testConnection() async {
    final url = _url.text.trim();
    if (url.isEmpty) {
      setState(() {
        _testOk = false;
        _testMessage = '请先填写 MCP 端点地址';
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
          ? '连接成功，但该服务未暴露工具'
          : '连接成功，${names.length} 个工具：${names.join('、')}';
    } catch (e) {
      message = '连接失败：$e';
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
        title: Text(_isNew ? '新增 MCP 服务' : '编辑 MCP 服务'),
        actions: <Widget>[
          TextButton(
            onPressed: _loading ? null : _save,
            child: const Text('保存'),
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
                    decoration: const InputDecoration(
                      labelText: '名称',
                      hintText: '例如：我的本地 MCP 服务',
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty ? '请填写名称' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _url,
                    decoration: const InputDecoration(
                      labelText: 'MCP 端点地址',
                      helperText:
                          'Streamable HTTP 完整地址，例如 https://example.com/mcp',
                    ),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return '请填写端点地址';
                      final uri = Uri.tryParse(value);
                      if (uri == null || !uri.hasScheme) {
                        return '请填写带 http(s):// 的完整地址';
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
                      labelText: '认证请求头',
                      hintText: _hasAuth
                          ? '已保存，留空则不修改'
                          : '每行一条，例如 Authorization: Bearer xxx',
                      helperText: '仅保存在本机安全存储，不会随备份导出',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _allowedTools,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: '工具白名单',
                      helperText: '每行一个远程工具名；留空表示全部允许',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('启用'),
                    subtitle: const Text('停用后其工具不会暴露给 AI'),
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
                        label: const Text('测试连接'),
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
