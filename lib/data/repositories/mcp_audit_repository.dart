import 'dart:convert';

import '../../models/mcp_audit_entry.dart';
import 'settings_repository.dart';

/// MCP 工具调用审计（ENH-22）：最近 [maxEntries] 次远程调用的本地记录，
/// 存在 APP_SETTING 中，不联网、不含认证信息。
class McpAuditRepository {
  McpAuditRepository(this._settings);

  static const String storageKey = 'mcp_audit_log';
  static const int maxEntries = 100;

  final SettingsRepository _settings;

  Future<List<McpAuditEntry>> list() async {
    final raw = await _settings.getSetting(storageKey);
    if (raw == null || raw.trim().isEmpty) return <McpAuditEntry>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <McpAuditEntry>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(McpAuditEntry.fromJson)
          .toList(growable: false);
    } on FormatException {
      return <McpAuditEntry>[];
    }
  }

  /// 新记录置顶，超出上限时丢弃最旧的。
  Future<void> add(McpAuditEntry entry) async {
    final entries = <McpAuditEntry>[entry, ...await list()];
    final kept = entries.take(maxEntries).toList(growable: false);
    await _settings.setSetting(
      storageKey,
      jsonEncode(kept.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> clear() => _settings.setSetting(storageKey, '[]');
}
