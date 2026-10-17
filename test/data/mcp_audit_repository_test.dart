import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/data/db.dart';
import 'package:novelphone/data/repositories/mcp_audit_repository.dart';
import 'package:novelphone/data/repositories/settings_repository.dart';
import 'package:novelphone/data/secure_key_store.dart';
import 'package:novelphone/models/mcp_audit_entry.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository settings;
  late McpAuditRepository audit;

  setUp(() {
    db = AppDatabase.memory();
    settings = SettingsRepository(db, InMemoryKeyStore());
    audit = McpAuditRepository(settings);
  });

  tearDown(() async {
    await db.close();
  });

  McpAuditEntry entry(int i, {bool success = true}) => McpAuditEntry(
    serverName: '测试 MCP',
    toolName: 'mcp_tool_$i',
    argumentsSummary: '{"q":"$i"}',
    resultSummary: '结果 $i',
    success: success,
    durationMs: i,
    createdAt: DateTime(2026, 10, 17, 12, i % 60),
  );

  test('新记录置顶并完整持久化', () async {
    await audit.add(entry(1));
    await audit.add(entry(2, success: false));

    final entries = await audit.list();
    expect(entries.map((e) => e.toolName), <String>[
      'mcp_tool_2',
      'mcp_tool_1',
    ]);

    final reopened = McpAuditRepository(
      SettingsRepository(db, InMemoryKeyStore()),
    );
    final restored = (await reopened.list()).first;
    expect(restored.serverName, '测试 MCP');
    expect(restored.argumentsSummary, '{"q":"2"}');
    expect(restored.resultSummary, '结果 2');
    expect(restored.success, isFalse);
    expect(restored.durationMs, 2);
    expect(restored.createdAt, DateTime(2026, 10, 17, 12, 2));
  });

  test('只保留最近 100 条', () async {
    for (var i = 0; i < 105; i++) {
      await audit.add(entry(i));
    }

    final entries = await audit.list();
    expect(entries, hasLength(McpAuditRepository.maxEntries));
    expect(entries.first.toolName, 'mcp_tool_104');
    expect(entries.last.toolName, 'mcp_tool_5');
  });

  test('清空后没有记录', () async {
    await audit.add(entry(1));
    await audit.clear();

    expect(await audit.list(), isEmpty);
  });

  test('存储内容损坏时按空列表处理', () async {
    await settings.setSetting(McpAuditRepository.storageKey, 'not-json');

    expect(await audit.list(), isEmpty);
  });
}
