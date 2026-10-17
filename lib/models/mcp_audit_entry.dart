/// 一次远程 MCP 工具调用的审计记录（ENH-22）。
/// 只记录摘要文本，不落任何认证信息；全部保存在本机设置表中。
class McpAuditEntry {
  const McpAuditEntry({
    required this.serverName,
    required this.toolName,
    required this.argumentsSummary,
    required this.resultSummary,
    required this.success,
    required this.durationMs,
    required this.createdAt,
  });

  final String serverName;
  final String toolName;
  final String argumentsSummary;
  final String resultSummary;
  final bool success;
  final int durationMs;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'server': serverName,
    'tool': toolName,
    'args': argumentsSummary,
    'result': resultSummary,
    'success': success,
    'durationMs': durationMs,
    'createdAt': createdAt.toIso8601String(),
  };

  factory McpAuditEntry.fromJson(Map<String, dynamic> json) {
    return McpAuditEntry(
      serverName: json['server'] as String? ?? '',
      toolName: json['tool'] as String? ?? '',
      argumentsSummary: json['args'] as String? ?? '',
      resultSummary: json['result'] as String? ?? '',
      success: json['success'] as bool? ?? false,
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
