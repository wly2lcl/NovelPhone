import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_client.dart';
import 'ai_error.dart';
import 'sse.dart';

/// Messages 适配器（Anthropic Claude）。
/// 端点：`POST {baseUrl}/v1/messages`，system 提为顶层字段，
/// 解析 `content_block_delta` 事件序列，合并 `message_start`（input usage）
/// 与 `message_delta`（output usage）双段 usage，`tool_use` / `tool_result` 亦在此收敛。
class MessagesAdapter implements AiClient {
  MessagesAdapter({
    required this.baseUrl,
    required this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const String _apiVersion = '2023-06-01';

  final String baseUrl;
  final String apiKey;
  final http.Client _client;

  Uri get _uri {
    final trimmed = _trimSlash(baseUrl);
    // 兼容用户把 baseUrl 直接填成 .../v1 的情况，避免出现 /v1/v1/messages。
    final path = trimmed.endsWith('/v1')
        ? '$trimmed/messages'
        : '$trimmed/v1/messages';
    return Uri.parse(path);
  }

  @override
  Stream<ChatChunk> streamChat(ChatRequest req) async* {
    final body = <String, dynamic>{
      'model': req.model,
      'max_tokens': req.maxTokens,
      'temperature': req.temperature,
      'stream': true,
      if ((req.system ?? '').isNotEmpty) 'system': req.system,
      'messages': req.messages.map(_messageJson).toList(),
      if (req.tools.isNotEmpty)
        'tools': req.tools
            .map(
              (t) => <String, dynamic>{
                'name': t.name,
                'description': t.description,
                'input_schema': t.inputSchema,
              },
            )
            .toList(),
    };

    final http.StreamedResponse response;
    try {
      final request = http.Request('POST', _uri)
        ..headers.addAll(<String, String>{
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
          'x-api-key': apiKey,
          'anthropic-version': _apiVersion,
        })
        ..body = jsonEncode(body);
      response = await _client.send(request);
    } catch (e) {
      yield ChatError(
        kind: AiErrorKind.network,
        message: '网络请求失败：$e',
        detail: '$e',
      );
      return;
    }

    if (response.statusCode != 200) {
      final text = await response.stream.bytesToString();
      yield mapHttpError(response.statusCode, text);
      return;
    }

    var inputTokens = 0;
    var outputTokens = 0;
    var usageSeen = false;
    String? stopReason;
    final toolBlocks = <int, _ToolBlock>{};

    try {
      await for (final event in parseSse(response.stream)) {
        final data = event.data;
        if (data.isEmpty) continue;
        final decoded = _tryDecode(data);
        if (decoded == null) continue;
        final type = decoded['type'];

        if (type == 'message_start') {
          final message = decoded['message'];
          if (message is Map) {
            final usage = message['usage'];
            if (usage is Map) {
              inputTokens = _intOf(usage['input_tokens']);
              usageSeen = true;
            }
          }
        } else if (type == 'content_block_start') {
          final index = _intOf(decoded['index']);
          final block = decoded['content_block'];
          if (block is Map && block['type'] == 'tool_use') {
            toolBlocks[index] = _ToolBlock(
              id: block['id'] is String ? block['id'] as String : '',
              name: block['name'] is String ? block['name'] as String : '',
            );
          }
        } else if (type == 'content_block_delta') {
          final index = _intOf(decoded['index']);
          final delta = decoded['delta'];
          if (delta is Map) {
            if (delta['type'] == 'text_delta') {
              final text = delta['text'];
              if (text is String && text.isNotEmpty) yield ChatTextDelta(text);
            } else if (delta['type'] == 'input_json_delta') {
              final partial = delta['partial_json'];
              if (partial is String) {
                toolBlocks[index]?.arguments.write(partial);
              }
            }
          }
        } else if (type == 'message_delta') {
          final usage = decoded['usage'];
          if (usage is Map) {
            outputTokens = _intOf(usage['output_tokens']);
            usageSeen = true;
          }
          final delta = decoded['delta'];
          if (delta is Map && delta['stop_reason'] is String) {
            stopReason = delta['stop_reason'] as String;
          }
        } else if (type == 'error') {
          final error = decoded['error'];
          final message = error is Map && error['message'] is String
              ? error['message'] as String
              : '未知错误';
          yield ChatError(
            kind: AiErrorKind.badRequest,
            message: '模型服务返回错误：$message',
            code: ChatErrorCode.providerError,
            detail: message,
          );
          return;
        }
      }
    } catch (e) {
      yield ChatError(
        kind: AiErrorKind.network,
        message: '流式读取中断：$e',
        detail: '$e',
      );
      return;
    }

    if (usageSeen) {
      yield ChatUsage(
        promptTokens: inputTokens,
        completionTokens: outputTokens,
      );
    }
    if (toolBlocks.isNotEmpty) {
      yield ChatToolCalls(
        toolBlocks.values
            .where((b) => b.name.isNotEmpty)
            .map(
              (b) => ToolCall(
                id: b.id,
                name: b.name,
                arguments: b.arguments.isEmpty ? '{}' : b.arguments.toString(),
              ),
            )
            .toList(),
      );
    }
    yield ChatDone(finishReason: stopReason);
  }

  Map<String, dynamic> _messageJson(ChatMessage message) {
    if (message.role == 'tool') {
      return <String, dynamic>{
        'role': 'user',
        'content': <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'tool_result',
            'tool_use_id': message.toolCallId ?? '',
            'content': message.content,
          },
        ],
      };
    }
    final toolCalls = message.toolCalls;
    if (message.role == 'assistant' &&
        toolCalls != null &&
        toolCalls.isNotEmpty) {
      return <String, dynamic>{
        'role': 'assistant',
        'content': <Map<String, dynamic>>[
          if (message.content.isNotEmpty)
            <String, dynamic>{'type': 'text', 'text': message.content},
          ...toolCalls.map(
            (c) => <String, dynamic>{
              'type': 'tool_use',
              'id': c.id,
              'name': c.name,
              'input': _decodeArguments(c.arguments),
            },
          ),
        ],
      };
    }
    return <String, dynamic>{'role': message.role, 'content': message.content};
  }

  Map<String, dynamic> _decodeArguments(String arguments) {
    if (arguments.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(arguments);
      return decoded is Map
          ? decoded.cast<String, dynamic>()
          : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}

class _ToolBlock {
  _ToolBlock({required this.id, required this.name});

  final String id;
  final String name;
  final StringBuffer arguments = StringBuffer();
}

String _trimSlash(String url) =>
    url.endsWith('/') ? url.substring(0, url.length - 1) : url;

Map<String, dynamic>? _tryDecode(String data) {
  try {
    final decoded = jsonDecode(data);
    return decoded is Map ? decoded.cast<String, dynamic>() : null;
  } catch (_) {
    return null;
  }
}

int _intOf(Object? value) => value is num ? value.toInt() : 0;
