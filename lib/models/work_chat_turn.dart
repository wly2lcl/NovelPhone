import 'dart:convert';

/// 一条持久化的作品问答消息（ENH-23），存于 APP_SETTING，不随备份导出。
class WorkChatTurn {
  const WorkChatTurn({required this.role, required this.content});

  final String role;
  final String content;

  bool get isUser => role == 'user';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'role': role,
    'content': content,
  };

  static WorkChatTurn? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final role = raw['role'];
    final content = raw['content'];
    if (role is! String || content is! String) return null;
    if (role != 'user' && role != 'assistant') return null;
    final text = content.trim();
    if (text.isEmpty) return null;
    return WorkChatTurn(role: role, content: text);
  }
}

List<WorkChatTurn> decodeChatTurns(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return const <WorkChatTurn>[];
  try {
    final decoded = jsonDecode(text);
    if (decoded is! List) return const <WorkChatTurn>[];
    return decoded
        .map(WorkChatTurn.tryParse)
        .whereType<WorkChatTurn>()
        .toList();
  } catch (_) {
    return const <WorkChatTurn>[];
  }
}

String encodeChatTurns(List<WorkChatTurn> turns) => turns.isEmpty
    ? ''
    : jsonEncode(turns.map((turn) => turn.toJson()).toList());
