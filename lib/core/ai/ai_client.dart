import 'dart:async';

/// AI 统一模型的内部表示（ARCHITECTURE 5.1）：与端点协议无关，
/// 端点差异全部收敛在各自的 Adapter 内。

/// 工具定义，结构对齐 MCP（name / description / inputSchema）。
class ToolSpec {
  const ToolSpec({
    required this.name,
    required this.description,
    required this.inputSchema,
  });

  final String name;
  final String description;

  /// JSON Schema（MCP 用 inputSchema，OpenAI 用 parameters）。
  final Map<String, dynamic> inputSchema;
}

/// 模型请求的一次工具调用。
class ToolCall {
  const ToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  final String id;
  final String name;

  /// 模型给出的参数 JSON 字符串（可能为空或非法，由执行侧容错）。
  final String arguments;
}

/// 一轮消息。role 取值：user / assistant / tool。
/// assistant 可携带工具调用；role=tool 时 [toolCallId] 对应被回填的调用。
class ChatMessage {
  const ChatMessage(this.role, this.content, {this.toolCalls, this.toolCallId});

  final String role;
  final String content;
  final List<ToolCall>? toolCalls;
  final String? toolCallId;

  factory ChatMessage.user(String content) => ChatMessage('user', content);

  factory ChatMessage.assistant(String content, {List<ToolCall>? toolCalls}) =>
      ChatMessage('assistant', content, toolCalls: toolCalls);

  factory ChatMessage.toolResult(String toolCallId, String content) =>
      ChatMessage('tool', content, toolCallId: toolCallId);
}

/// 统一请求（ARCHITECTURE 5.1）。model / 温度 / 输出上限由调用方按模型组填入。
class ChatRequest {
  const ChatRequest({
    required this.model,
    this.system,
    required this.messages,
    this.temperature = 0.8,
    this.maxTokens = 1024,
    this.tools = const <ToolSpec>[],
  });

  final String model;
  final String? system;
  final List<ChatMessage> messages;
  final double temperature;
  final int maxTokens;
  final List<ToolSpec> tools;
}

/// 错误分类（ARCHITECTURE 5.2）：UI 层按此单点处置。
enum AiErrorKind {
  /// 网络错误 / 超时：保留已收流，提供重试。
  network,

  /// 401 / 403：key 无效，引导设置页。
  auth,

  /// 429：限流。
  rateLimit,

  /// 服务商内容过滤拒绝。
  contentFilter,

  /// 参数错误（400 等）。
  badRequest,

  /// 5xx：服务端故障。
  server,

  unknown,
}

/// 流式增量（ARCHITECTURE 5.1）。工具调用在流末尾一次性给出，供 Agent Core 使用。
sealed class ChatChunk {
  const ChatChunk();
}

class ChatTextDelta extends ChatChunk {
  const ChatTextDelta(this.text);

  final String text;
}

/// 本轮模型请求的全部工具调用（适配器内累积后一次性发出）。
class ChatToolCalls extends ChatChunk {
  const ChatToolCalls(this.calls);

  final List<ToolCall> calls;
}

class ChatUsage extends ChatChunk {
  const ChatUsage({required this.promptTokens, required this.completionTokens});

  final int promptTokens;
  final int completionTokens;
}

class ChatDone extends ChatChunk {
  const ChatDone({this.finishReason});

  final String? finishReason;
}

class ChatError extends ChatChunk {
  const ChatError({required this.kind, required this.message, this.statusCode});

  final AiErrorKind kind;
  final String message;
  final int? statusCode;
}

/// 模型调用统一接口。一个模型组构造一个实例，key 在构造时注入。
abstract interface class AiClient {
  Stream<ChatChunk> streamChat(ChatRequest req);
}
