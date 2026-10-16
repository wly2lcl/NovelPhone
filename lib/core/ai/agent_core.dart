import 'dart:convert';

import 'ai_client.dart';

/// 工具抽象：结构对齐 MCP（name / description / inputSchema），
/// 执行签名与 MCP callTool 一致，便于将来把远程工具包装成同构 Tool（ARCHITECTURE 5.4）。
class Tool {
  const Tool({
    required this.name,
    required this.description,
    required this.inputSchema,
    required this.execute,
  });

  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;
  final Future<String> Function(Map<String, dynamic> args) execute;

  ToolSpec get spec =>
      ToolSpec(name: name, description: description, inputSchema: inputSchema);
}

/// 轻量 ReAct 循环：调用模型 → 有 tool_calls 则执行工具、结果回传 → 直到无 tool_calls。
/// 只消费统一的 ChatChunk，不感知具体端点（ARCHITECTURE 5.4）。
class AgentCore {
  const AgentCore({required this.client, this.maxRounds = 4});

  final AiClient client;

  /// 工具调用最大轮次，防止模型反复取数不收敛。
  final int maxRounds;

  /// [request] 的 tools 会被 [tools] 覆盖。
  Stream<ChatChunk> run({
    required ChatRequest request,
    required List<Tool> tools,
  }) async* {
    final messages = List<ChatMessage>.of(request.messages);
    final specs = tools.map((t) => t.spec).toList();

    for (var round = 0; round < maxRounds; round++) {
      final roundRequest = ChatRequest(
        model: request.model,
        system: request.system,
        messages: List<ChatMessage>.of(messages),
        temperature: request.temperature,
        maxTokens: request.maxTokens,
        tools: specs,
      );

      final pendingCalls = <ToolCall>[];
      String? finishReason;
      var failed = false;

      await for (final chunk in client.streamChat(roundRequest)) {
        switch (chunk) {
          case ChatTextDelta():
            yield chunk;
          case ChatUsage():
            yield chunk;
          case ChatToolCalls():
            pendingCalls.addAll(chunk.calls);
          case ChatDone():
            finishReason = chunk.finishReason;
          case ChatError():
            yield chunk;
            failed = true;
        }
      }

      if (failed) return; // 错误已透出，交由 UI 处置
      if (pendingCalls.isEmpty) {
        yield ChatDone(finishReason: finishReason);
        return;
      }

      messages.add(ChatMessage.assistant('', toolCalls: pendingCalls));
      for (final call in pendingCalls) {
        messages.add(
          ChatMessage.toolResult(call.id, await _execute(tools, call)),
        );
      }
    }

    yield const ChatError(
      kind: AiErrorKind.unknown,
      message: 'AI 工具调用轮次超限，已停止',
      code: ChatErrorCode.toolLoop,
    );
  }

  Future<String> _execute(List<Tool> tools, ToolCall call) async {
    Tool? tool;
    for (final candidate in tools) {
      if (candidate.name == call.name) {
        tool = candidate;
        break;
      }
    }
    if (tool == null) return '错误：未知工具 ${call.name}';
    try {
      final args = call.arguments.isEmpty
          ? <String, dynamic>{}
          : _decode(call.arguments);
      return await tool.execute(args);
    } catch (e) {
      return '工具执行失败：$e';
    }
  }

  Map<String, dynamic> _decode(String arguments) {
    final decoded = jsonDecode(arguments);
    return decoded is Map
        ? decoded.cast<String, dynamic>()
        : <String, dynamic>{};
  }
}
