import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/formatting.dart';
import '../../data/data_providers.dart';
import '../../l10n/l10n.dart';
import '../../models/mcp_audit_entry.dart';

/// MCP 工具调用审计（ENH-22）：查看最近 100 次远程调用，可清空。
/// 记录只存本机，不含认证信息。
class McpAuditPage extends ConsumerStatefulWidget {
  const McpAuditPage({super.key});

  @override
  ConsumerState<McpAuditPage> createState() => _McpAuditPageState();
}

class _McpAuditPageState extends ConsumerState<McpAuditPage> {
  List<McpAuditEntry>? _entries;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await ref.read(mcpAuditRepositoryProvider).list();
    if (!mounted) return;
    setState(() => _entries = entries);
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.mcpAuditClearConfirmTitle),
        content: Text(context.l10n.mcpAuditClearConfirmBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.mcpAuditClear),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(mcpAuditRepositoryProvider).clear();
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.mcpAuditCleared)));
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mcpAuditTitle),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.mcpAuditClear,
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: entries == null || entries.isEmpty ? null : _clear,
          ),
        ],
      ),
      body: entries == null
          ? const Center(child: CircularProgressIndicator())
          : entries.isEmpty
          ? const _EmptyHint()
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  _AuditTile(entry: entries[index]),
            ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  const _AuditTile({required this.entry});

  final McpAuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = entry.success ? l10n.mcpAuditSuccess : l10n.mcpAuditFailure;
    final color = entry.success
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;
    final bodyStyle = TextStyle(
      fontSize: 12,
      color: context.paper.inkSoft,
      fontFamily: 'monospace',
    );
    return ExpansionTile(
      leading: Icon(
        entry.success ? Icons.check_circle_outline : Icons.error_outline,
        color: color,
      ),
      title: Text(entry.toolName),
      subtitle: Text(
        '$status · ${entry.serverName} · ${entry.durationMs} ms\n'
        '${formatRelativeTime(entry.createdAt, l10n)}',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionLabel(l10n.mcpAuditArguments),
        SelectableText(
          entry.argumentsSummary.isEmpty ? '—' : entry.argumentsSummary,
          style: bodyStyle,
        ),
        const SizedBox(height: 8),
        _SectionLabel(l10n.mcpAuditResult),
        SelectableText(
          entry.resultSummary.isEmpty ? '—' : entry.resultSummary,
          style: bodyStyle,
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: context.paper.inkSoft),
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
            Icon(
              Icons.fact_check_outlined,
              size: 40,
              color: context.paper.inkSoft,
            ),
            const SizedBox(height: 12),
            Text(context.l10n.mcpAuditEmpty),
            const SizedBox(height: 4),
            Text(
              context.l10n.mcpAuditEmptyHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
