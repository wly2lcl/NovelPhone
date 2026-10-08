import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_client.dart';
import 'ai_error.dart';
import 'sse.dart';

/// Responses 适配器（OpenAI Responses 端点，架构 9 章 B-01）。
/// 端点：`POST {baseUrl}/responses`，system 提为顶层 `instructions`，
/// 解析 `response.output_text.delta` 文本增量与 `response.completed` 的 usage，
/// `function_call` 系列事件的工具调用亦在此收敛。
class ResponsesAdapter implements AiClient {
  ResponsesAdapter({
    required this.baseUrl,
    required this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String apiKey;
  final http.Client _client;

  Uri get _uri {
    final trimmed = _trimSlash(baseUrl);
    // 兼容用户把 baseUrl 直接填成 .../v1 的情况，避免出现 /v1/v1/responses。
    final path = trimmed.endsWith('/v1') ? '$trimmed/responses' : '$trimmed/v1/responses';
    return Uri.parse(path);
  }

  @override
  Stream<ChatChunk> streamChat(ChatRequest req) async* {
    final body = <String, dynamic>{
      'model': req.model,
      if ((req.system ?? '').isNotEmpty) 'instructions': req.system,
      'input': <Map<String, dynamic>>[
        for (final message in req.messages) ..._inputItems(message),
      ],
      'stream': true,
      'temperature': req.temperature,
      'max_output_tokens': req.maxTokens,
      if (req.tools.isNotEmpty)
        'tools': req.tools
            .map((t) => <String, dynamic>{
                  'type': 'function',
                  'name': t.name,
                  'description': t.description,
                  'parameters': t.inputSchema,
                })
            .toList(),
    };

    final http.StreamedResponse response;
    try {
      final request = http.Request('POST', _uri)
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

    final calls = <String, _FunctionCall>{};
    var inputTokens = 0;
    var outputTokens = 0;
    var usageSeen = false;
    String? finishReason;

    try {
      await for (final event in parseSse(response.stream)) {
        final data = event.data;
        if (data.isEmpty) continue;
        if (data == '[DONE]') break;
        final decoded = _tryDecode(data);
        if (decoded == null) continue;
        final type = decoded['type'];

        if (type == 'response.output_text.delta') {
          final delta = decoded['delta'];
          if (delta is String && delta.isNotEmpty) yield ChatTextDelta(delta);
        } else if (type == 'response.output_item.added') {
          final item = decoded['item'];
          if (item is Map && item['type'] == 'function_call') {
            _upsert(calls, item, overrideArguments: false);
          }
        } else if (type == 'response.function_call_arguments.delta') {
          final key = _itemKey(decoded);
          final delta = decoded['delta'];
          if (key != null && delta is String) calls[key]?.arguments.write(delta);
        } else if (type == 'response.output_item.done') {
          final item = decoded['item'];
          if (item is Map && item['type'] == 'function_call') {
            // 完成帧携带完整 arguments，以其为准（覆盖增量累积结果）。
            _upsert(calls, item, overrideArguments: true);
          }
        } else if (type == 'response.completed' || type == 'response.incomplete') {
          final payload = decoded['response'];
          if (payload is Map) {
            final usage = payload['usage'];
            if (usage is Map) {
              inputTokens = _intOf(usage['input_tokens']);
              outputTokens = _intOf(usage['output_tokens']);
              usageSeen = true;
            }
            final status = payload['status'];
            if (status is String) finishReason = status;
          }
          if (type == 'response.incomplete') {
            yield const ChatError(
              kind: AiErrorKind.badRequest,
              message: '模型输出被截断（incomplete），请缩短上下文或提高输出上限',
            );
            return;
          }
        } else if (type == 'response.failed') {
          yield ChatError(
            kind: AiErrorKind.server,
            message: '模型服务返回失败：${_errorText(decoded)}',
          );
          return;
        } else if (type == 'error') {
          yield ChatError(
            kind: AiErrorKind.badRequest,
            message: '模型服务返回错误：${_errorText(decoded)}',
          );
          return;
        }
      }
    } catch (e) {
      // 网络中断：保留已收流，由 UI 提供重试（ARCHITECTURE 5.2）。
      yield ChatError(kind: AiErrorKind.network, message: '流式读取中断：$e');
      return;
    }

    if (usageSeen) {
      yield ChatUsage(promptTokens: inputTokens, completionTokens: outputTokens);
    }
    final resolved = calls.values
        .where((c) => c.name.isNotEmpty)
        .map((c) => ToolCall(
              id: c.callId.isEmpty ? c.itemId : c.callId,
              name: c.name,
              arguments: c.arguments.toString(),
            ))
        .toList();
    if (resolved.isNotEmpty) yield ChatToolCalls(resolved);
    yield ChatDone(finishReason: finishReason);
  }

  /// 一条内部消息展开为 Responses 的 input 条目（可多条：assistant 文本 + 工具调用）。
  List<Map<String, dynamic>> _inputItems(ChatMessage message) {
    if (message.role == 'tool') {
      return <Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'function_call_output',
          'call_id': message.toolCallId ?? '',
          'output': message.content,
        },
      ];
    }
    final toolCalls = message.toolCalls;
    if (message.role == 'assistant' && toolCalls != null && toolCalls.isNotEmpty) {
      return <Map<String, dynamic>>[
        if (message.content.isNotEmpty)
          <String, dynamic>{'role': 'assistant', 'content': message.content},
        ...toolCalls.map((c) => <String, dynamic>{
              'type': 'function_call',
              'call_id': c.id,
              'name': c.name,
              'arguments': c.arguments,
            }),
      ];
    }
    return <Map<String, dynamic>>[
      <String, dynamic>{'role': message.role, 'content': message.content},
    ];
  }

  String? _itemKey(Map<String, dynamic> decoded) {
    final itemId = decoded['item_id'];
    if (itemId is String && itemId.isNotEmpty) return itemId;
    final item = decoded['item'];
    if (item is Map) {
      final id = item['id'];
      if (id is String && id.isNotEmpty) return id;
    }
    return null;
  }

  void _upsert(
    Map<String, _FunctionCall> map,
    Map item, {
    required bool overrideArguments,
  }) {
    final itemId = item['id'] is String ? item['id'] as String : '';
    final key = itemId.isEmpty ? 'index:${_intOf(item['index'])}' : itemId;
    final call = map.putIfAbsent(key, () => _FunctionCall(itemId));
    final callId = item['call_id'];
    if (callId is String && callId.isNotEmpty) call.callId = callId;
    final name = item['name'];
    if (name is String && name.isNotEmpty) call.name = name;
    final arguments = item['arguments'];
    if (arguments is String && arguments.isNotEmpty && overrideArguments) {
      call.arguments
        ..clear()
        ..write(arguments);
    }
  }
}

class _FunctionCall {
  _FunctionCall(this.itemId);

  final String itemId;
  String callId = '';
  String name = '';
  final StringBuffer arguments = StringBuffer();
}

String _errorText(Map<String, dynamic> decoded) {
  final message = decoded['message'];
  if (message is String && message.isNotEmpty) return message;
  final error = decoded['error'];
  if (error is Map && error['message'] is String) return error['message'] as String;
  final payload = decoded['response'];
  if (payload is Map) {
    final error = payload['error'];
    if (error is Map && error['message'] is String) return error['message'] as String;
  }
  return '未知错误';
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