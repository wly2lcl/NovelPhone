import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_client.dart';
import 'ai_error.dart';
import 'sse.dart';

/// Chat Completions 适配器（OpenAI 官方与全部 OpenAI 兼容服务）。
/// 端点：`POST {baseUrl}/chat/completions`，system 作为首条 role=system 消息，
/// 解析 `choices[].delta.content`，末帧取 usage，`tools` / `tool_calls` 亦在此收敛。
class ChatCompletionsAdapter implements AiClient {
  ChatCompletionsAdapter({
    required this.baseUrl,
    required this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String apiKey;
  final http.Client _client;

  @override
  Stream<ChatChunk> streamChat(ChatRequest req) async* {
    final uri = Uri.parse('${_trimSlash(baseUrl)}/chat/completions');
    final body = <String, dynamic>{
      'model': req.model,
      'messages': <Map<String, dynamic>>[
        if ((req.system ?? '').isNotEmpty)
          <String, dynamic>{'role': 'system', 'content': req.system},
        ...req.messages.map(_messageJson),
      ],
      'stream': true,
      'temperature': req.temperature,
      'max_tokens': req.maxTokens,
      'stream_options': const <String, dynamic>{'include_usage': true},
      if (req.tools.isNotEmpty)
        'tools': req.tools
            .map((t) => <String, dynamic>{
                  'type': 'function',
                  'function': <String, dynamic>{
                    'name': t.name,
                    'description': t.description,
                    'parameters': t.inputSchema,
                  },
                })
            .toList(),
    };

    final http.StreamedResponse response;
    try {
      final request = http.Request('POST', uri)
        ..headers.addAll(<String, String>{
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
          'Authorization': 'Bearer $apiKey',
        })
        ..body = jsonEncode(body);
      response = await _client.send(request);
    } catch (e) {
      yield ChatError(kind: AiErrorKind.network, message: '网络请求失败：$e');
      return;
    }

    if (response.statusCode != 200) {
      final text = await response.stream.bytesToString();
      yield mapHttpError(response.statusCode, text);
      return;
    }

    final accumulators = <int, _ToolCallAccumulator>{};
    String? finishReason;
    try {
      await for (final event in parseSse(response.stream)) {
        final data = event.data;
        if (data.isEmpty) continue;
        if (data == '[DONE]') break;
        final decoded = _tryDecode(data);
        if (decoded == null) continue;

        final usage = decoded['usage'];
        if (usage is Map) {
          yield ChatUsage(
            promptTokens: _intOf(usage['prompt_tokens']),
            completionTokens: _intOf(usage['completion_tokens']),
          );
        }

        final choices = decoded['choices'];
        if (choices is List && choices.isNotEmpty) {
          final choice = choices.first;
          if (choice is Map) {
            final delta = choice['delta'];
            if (delta is Map) {
              final content = delta['content'];
              if (content is String && content.isNotEmpty) {
                yield ChatTextDelta(content);
              }
              final toolCalls = delta['tool_calls'];
              if (toolCalls is List) {
                for (final raw in toolCalls) {
                  if (raw is Map) _accumulate(accumulators, raw);
                }
              }
            }
            final finish = choice['finish_reason'];
            if (finish is String) finishReason = finish;
          }
        }
      }
    } catch (e) {
      // 网络中断：保留已收流，由 UI 提供重试（ARCHITECTURE 5.2）。
      yield ChatError(kind: AiErrorKind.network, message: '流式读取中断：$e');
      return;
    }

    if (accumulators.isNotEmpty) {
      yield ChatToolCalls(
        accumulators.values
            .where((a) => a.name.isNotEmpty)
            .map((a) => ToolCall(
                  id: a.id,
                  name: a.name,
                  arguments: a.arguments.toString(),
                ))
            .toList(),
      );
    }
    yield ChatDone(finishReason: finishReason);
  }

  Map<String, dynamic> _messageJson(ChatMessage message) {
    if (message.role == 'tool') {
      return <String, dynamic>{
        'role': 'tool',
        'tool_call_id': message.toolCallId ?? '',
        'content': message.content,
      };
    }
    final toolCalls = message.toolCalls;
    if (message.role == 'assistant' && toolCalls != null && toolCalls.isNotEmpty) {
      return <String, dynamic>{
        'role': 'assistant',
        'content': message.content.isEmpty ? null : message.content,
        'tool_calls': toolCalls
            .map((c) => <String, dynamic>{
                  'id': c.id,
                  'type': 'function',
                  'function': <String, dynamic>{
                    'name': c.name,
                    'arguments': c.arguments,
                  },
                })
            .toList(),
      };
    }
    return <String, dynamic>{'role': message.role, 'content': message.content};
  }

  void _accumulate(Map<int, _ToolCallAccumulator> map, Map<dynamic, dynamic> tc) {
    final index = _intOf(tc['index']);
    final accumulator = map.putIfAbsent(index, _ToolCallAccumulator.new);
    final id = tc['id'];
    if (id is String && id.isNotEmpty) accumulator.id = id;
    final function = tc['function'];
    if (function is Map) {
      final name = function['name'];
      if (name is String && name.isNotEmpty) accumulator.name = name;
      final arguments = function['arguments'];
      if (arguments is String) accumulator.arguments.write(arguments);
    }
  }
}

class _ToolCallAccumulator {
  String id = '';
  String name = '';
  final StringBuffer arguments = StringBuffer();
}

String _trimSlash(String url) => url.endsWith('/') ? url.substring(0, url.length - 1) : url;

Map<String, dynamic>? _tryDecode(String data) {
  try {
    final decoded = jsonDecode(data);
    return decoded is Map ? decoded.cast<String, dynamic>() : null;
  } catch (_) {
    return null; // 容忍坏帧，不中断整条流
  }
}

int _intOf(Object? value) => value is num ? value.toInt() : 0;