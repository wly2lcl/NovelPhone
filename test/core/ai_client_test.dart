import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:novelphone/core/ai/ai_client.dart';
import 'package:novelphone/core/ai/chat_completions_adapter.dart';
import 'package:novelphone/core/ai/messages_adapter.dart';
import 'package:novelphone/core/ai/responses_adapter.dart';
import 'package:novelphone/core/ai/retrying_ai_client.dart';

/// M3-05：用录制的 SSE 响应分别驱动两个适配器（流式文本 / usage / 错误路径）。
void main() {
  ChatRequest request() => const ChatRequest(
    model: 'test-model',
    system: '你是助手',
    messages: <ChatMessage>[ChatMessage('user', '继续')],
  );

  Future<List<ChatChunk>> run(AiClient client, ChatRequest req) =>
      client.streamChat(req).toList();

  group('ChatCompletionsAdapter', () {
    test('解析流式文本、usage 与结束帧', () async {
      final body = <String>[
        'data: {"choices":[{"delta":{"content":"雨"}}]}',
        '',
        'data: {"choices":[{"delta":{"content":"下了一夜"}}]}',
        '',
        'data: {"choices":[{"delta":{},"finish_reason":"stop"}],'
            '"usage":{"prompt_tokens":12,"completion_tokens":5}}',
        '',
        'data: [DONE]',
        '',
      ].join('\n');

      late http.Request captured;
      final client = ChatCompletionsAdapter(
        baseUrl: 'https://api.example.com/v1',
        apiKey: 'sk-test',
        client: MockClient((req) async {
          captured = req;
          return http.Response.bytes(
            utf8.encode(body),
            200,
            headers: <String, String>{'content-type': 'text/event-stream'},
          );
        }),
      );

      final chunks = await run(client, request());
      final text = chunks.whereType<ChatTextDelta>().map((c) => c.text).join();
      expect(text, '雨下了一夜');

      final usage = chunks.whereType<ChatUsage>().single;
      expect(usage.promptTokens, 12);
      expect(usage.completionTokens, 5);

      expect(chunks.whereType<ChatDone>().single.finishReason, 'stop');
      expect(captured.url.path, '/v1/chat/completions');
      expect(captured.headers['Authorization'], 'Bearer sk-test');
    });

    test('累积 tool_calls 并一次性发出', () async {
      final body = <String>[
        'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_1",'
            '"function":{"name":"get_chapter","arguments":"{\\"id\\":"}}]}}]}',
        '',
        'data: {"choices":[{"delta":{"tool_calls":[{"index":0,'
            '"function":{"arguments":"3}"}}]}}]}',
        '',
        'data: [DONE]',
        '',
      ].join('\n');

      final client = ChatCompletionsAdapter(
        baseUrl: 'https://api.example.com/v1',
        apiKey: 'sk-test',
        client: MockClient((_) async => http.Response(body, 200)),
      );

      final chunks = await run(client, request());
      final calls = chunks.whereType<ChatToolCalls>().single.calls;
      expect(calls, hasLength(1));
      expect(calls.single.id, 'call_1');
      expect(calls.single.name, 'get_chapter');
      expect(jsonDecode(calls.single.arguments), <String, dynamic>{'id': 3});
    });

    test('限流响应映射为 rateLimit 错误', () async {
      final client = ChatCompletionsAdapter(
        baseUrl: 'https://api.example.com/v1',
        apiKey: 'sk-test',
        client: MockClient(
          (_) async => http.Response('{"error":"slow down"}', 429),
        ),
      );

      final chunks = await run(client, request());
      final error = chunks.whereType<ChatError>().single;
      expect(error.kind, AiErrorKind.rateLimit);
    });
  });

  group('MessagesAdapter', () {
    test('合并双段 usage 并解析 content_block_delta', () async {
      final body = <String>[
        'event: message_start',
        'data: {"type":"message_start","message":{"usage":{"input_tokens":9}}}',
        '',
        'event: content_block_start',
        'data: {"type":"content_block_start","index":0,"content_block":{"type":"text"}}',
        '',
        'event: content_block_delta',
        'data: {"type":"content_block_delta","index":0,'
            '"delta":{"type":"text_delta","text":"月色"}}',
        '',
        'event: content_block_delta',
        'data: {"type":"content_block_delta","index":0,'
            '"delta":{"type":"text_delta","text":"很好"}}',
        '',
        'event: message_delta',
        'data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},'
            '"usage":{"output_tokens":6}}',
        '',
        'event: message_stop',
        'data: {"type":"message_stop"}',
        '',
      ].join('\n');

      late http.Request captured;
      final client = MessagesAdapter(
        baseUrl: 'https://api.anthropic.com/v1',
        apiKey: 'ak-test',
        client: MockClient((req) async {
          captured = req;
          return http.Response.bytes(utf8.encode(body), 200);
        }),
      );

      final chunks = await run(client, request());
      expect(
        chunks.whereType<ChatTextDelta>().map((c) => c.text).join(),
        '月色很好',
      );
      final usage = chunks.whereType<ChatUsage>().single;
      expect(usage.promptTokens, 9);
      expect(usage.completionTokens, 6);
      expect(chunks.whereType<ChatDone>().single.finishReason, 'end_turn');

      // baseUrl 已含 /v1 时不重复追加
      expect(captured.url.path, '/v1/messages');
      expect(captured.headers['x-api-key'], 'ak-test');
      expect(captured.headers['anthropic-version'], '2023-06-01');
      // system 作为顶层字段而非消息
      final sent = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(sent['system'], '你是助手');
      expect((sent['messages'] as List).length, 1);
    });

    test('解析 tool_use 块与 input_json_delta', () async {
      final body = <String>[
        'event: content_block_start',
        'data: {"type":"content_block_start","index":1,'
            '"content_block":{"type":"tool_use","id":"toolu_1","name":"get_outline"}}',
        '',
        'event: content_block_delta',
        'data: {"type":"content_block_delta","index":1,'
            '"delta":{"type":"input_json_delta","partial_json":"{\\"workId\\":7}"}}',
        '',
        'event: message_stop',
        'data: {"type":"message_stop"}',
        '',
      ].join('\n');

      final client = MessagesAdapter(
        baseUrl: 'https://api.anthropic.com',
        apiKey: 'ak-test',
        client: MockClient((_) async => http.Response(body, 200)),
      );

      final chunks = await run(client, request());
      final call = chunks.whereType<ChatToolCalls>().single.calls.single;
      expect(call.id, 'toolu_1');
      expect(call.name, 'get_outline');
      expect(jsonDecode(call.arguments), <String, dynamic>{'workId': 7});
    });

    test('error 事件映射为 badRequest', () async {
      final body = <String>[
        'event: error',
        'data: {"type":"error","error":{"type":"invalid_request_error",'
            '"message":"max_tokens 超限"}}',
        '',
      ].join('\n');

      final client = MessagesAdapter(
        baseUrl: 'https://api.anthropic.com',
        apiKey: 'ak-test',
        client: MockClient(
          (_) async => http.Response.bytes(utf8.encode(body), 200),
        ),
      );

      final chunks = await run(client, request());
      final error = chunks.whereType<ChatError>().single;
      expect(error.kind, AiErrorKind.badRequest);
      expect(error.message, contains('max_tokens 超限'));
    });
  });

  group('ResponsesAdapter（B-01）', () {
    test('解析 output_text.delta、usage 与结束帧', () async {
      final body = <String>[
        'event: response.created',
        'data: {"type":"response.created","response":{"id":"resp_1"}}',
        '',
        'event: response.output_text.delta',
        'data: {"type":"response.output_text.delta","delta":"雨"}',
        '',
        'event: response.output_text.delta',
        'data: {"type":"response.output_text.delta","delta":"下了一夜"}',
        '',
        'event: response.completed',
        'data: {"type":"response.completed","response":{"status":"completed",'
            '"usage":{"input_tokens":12,"output_tokens":5}}}',
        '',
      ].join('\n');

      late http.Request captured;
      final client = ResponsesAdapter(
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'sk-test',
        client: MockClient((req) async {
          captured = req;
          return http.Response.bytes(utf8.encode(body), 200);
        }),
      );

      final chunks = await run(client, request());
      expect(
        chunks.whereType<ChatTextDelta>().map((c) => c.text).join(),
        '雨下了一夜',
      );
      final usage = chunks.whereType<ChatUsage>().single;
      expect(usage.promptTokens, 12);
      expect(usage.completionTokens, 5);
      expect(chunks.whereType<ChatDone>().single.finishReason, 'completed');

      // baseUrl 已含 /v1 时不重复追加；system 提为 instructions 而非消息
      expect(captured.url.path, '/v1/responses');
      expect(captured.headers['Authorization'], 'Bearer sk-test');
      final sent = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(sent['instructions'], '你是助手');
      expect(sent['max_output_tokens'], 1024);
      final input = sent['input'] as List;
      expect(input, hasLength(1));
      expect((input.single as Map)['role'], 'user');
    });

    test('累积 function_call 并一次性发出', () async {
      final body = <String>[
        'event: response.output_item.added',
        'data: {"type":"response.output_item.added","output_index":0,"item":'
            '{"type":"function_call","id":"fc_1","call_id":"call_1",'
            '"name":"get_chapter","arguments":""}}',
        '',
        'event: response.function_call_arguments.delta',
        'data: {"type":"response.function_call_arguments.delta","item_id":"fc_1",'
            '"delta":"{\\"id\\":"}',
        '',
        'event: response.output_item.done',
        'data: {"type":"response.output_item.done","output_index":0,"item":'
            '{"type":"function_call","id":"fc_1","call_id":"call_1",'
            '"name":"get_chapter","arguments":"{\\"id\\":3}"}}',
        '',
        'event: response.completed',
        'data: {"type":"response.completed","response":{"status":"completed"}}',
        '',
      ].join('\n');

      final client = ResponsesAdapter(
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'sk-test',
        client: MockClient(
          (_) async => http.Response.bytes(utf8.encode(body), 200),
        ),
      );

      final chunks = await run(client, request());
      final call = chunks.whereType<ChatToolCalls>().single.calls.single;
      expect(call.id, 'call_1');
      expect(call.name, 'get_chapter');
      expect(jsonDecode(call.arguments), <String, dynamic>{'id': 3});
    });

    test('error 事件与 401 响应分别映射为 badRequest / auth', () async {
      final errorBody = <String>[
        'event: error',
        'data: {"type":"error","message":"不支持的模型"}',
        '',
      ].join('\n');
      final client = ResponsesAdapter(
        baseUrl: 'https://api.openai.com',
        apiKey: 'sk-test',
        client: MockClient(
          (_) async => http.Response.bytes(utf8.encode(errorBody), 200),
        ),
      );
      final chunks = await run(client, request());
      final error = chunks.whereType<ChatError>().single;
      expect(error.kind, AiErrorKind.badRequest);
      expect(error.message, contains('不支持的模型'));

      final unauthorized = ResponsesAdapter(
        baseUrl: 'https://api.openai.com',
        apiKey: 'sk-bad',
        client: MockClient(
          (_) async => http.Response('{"error":"bad key"}', 401),
        ),
      );
      final authChunks = await run(unauthorized, request());
      expect(authChunks.whereType<ChatError>().single.kind, AiErrorKind.auth);
    });

    test('工具结果回传映射为 function_call_output', () async {
      late http.Request captured;
      final client = ResponsesAdapter(
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'sk-test',
        client: MockClient((req) async {
          captured = req;
          return http.Response(
            'data: {"type":"response.completed","response":{"status":"completed"}}\n\n',
            200,
          );
        }),
      );

      await run(
        client,
        const ChatRequest(
          model: 'test-model',
          messages: <ChatMessage>[
            ChatMessage('user', '继续'),
            ChatMessage(
              'assistant',
              '',
              toolCalls: <ToolCall>[
                ToolCall(
                  id: 'call_1',
                  name: 'get_chapter',
                  arguments: '{"id":3}',
                ),
              ],
            ),
            ChatMessage('tool', '章节正文', toolCallId: 'call_1'),
          ],
        ),
      );

      final input =
          (jsonDecode(captured.body) as Map<String, dynamic>)['input'] as List;
      expect(input, hasLength(3));
      expect((input[1] as Map)['type'], 'function_call');
      expect((input[2] as Map)['type'], 'function_call_output');
      expect((input[2] as Map)['call_id'], 'call_1');
    });
  });

  group('RetryingAiClient（429 / 5xx 自动退避重试，ARCHITECTURE 5.2）', () {
    test('首个响应 429 时自动重试并最终成功，usage 正常透出', () async {
      var calls = 0;
      final adapter = ChatCompletionsAdapter(
        baseUrl: 'https://api.example.com/v1',
        apiKey: 'sk-test',
        client: MockClient((_) async {
          calls++;
          if (calls == 1) return http.Response('{"error":"slow down"}', 429);
          return http.Response.bytes(
            utf8.encode(
              'data: {"choices":[{"delta":{"content":"好"}}]}\n\n'
              'data: {"choices":[{"delta":{},"finish_reason":"stop"}],'
              '"usage":{"prompt_tokens":3,"completion_tokens":1}}\n\n'
              'data: [DONE]\n\n',
            ),
            200,
          );
        }),
      );
      final client = RetryingAiClient(adapter, baseDelay: Duration.zero);

      final chunks = await run(client, request());
      expect(calls, 2);
      expect(chunks.whereType<ChatError>(), isEmpty);
      expect(chunks.whereType<ChatTextDelta>().map((c) => c.text).join(), '好');
      expect(chunks.whereType<ChatUsage>().single.completionTokens, 1);
    });

    test('5xx 同样自动重试（最多 maxRetries 次后透出错误）', () async {
      final adapter = ChatCompletionsAdapter(
        baseUrl: 'https://api.example.com/v1',
        apiKey: 'sk-test',
        client: MockClient((_) async => http.Response('boom', 503)),
      );
      final client = RetryingAiClient(adapter, baseDelay: Duration.zero);

      final chunks = await run(client, request());
      // 1 次原始请求 + 1 次重试，仍失败则透出 server 错误
      expect(chunks.whereType<ChatError>().single.kind, AiErrorKind.server);
    });

    test('已产出文本增量后的错误不再重试（避免重复内容）', () async {
      final fake = _ScriptedClient(<List<ChatChunk>>[
        <ChatChunk>[
          const ChatTextDelta('雨'),
          const ChatError(kind: AiErrorKind.rateLimit, message: '429'),
        ],
      ]);
      final client = RetryingAiClient(fake, baseDelay: Duration.zero);

      final chunks = await run(client, request());
      expect(fake.calls, 1);
      expect(chunks.whereType<ChatTextDelta>().map((c) => c.text).join(), '雨');
      expect(chunks.whereType<ChatError>().single.kind, AiErrorKind.rateLimit);
    });

    test('非可重试错误（401）直接透出，不重试', () async {
      var calls = 0;
      final adapter = ChatCompletionsAdapter(
        baseUrl: 'https://api.example.com/v1',
        apiKey: 'sk-bad',
        client: MockClient((_) async {
          calls++;
          return http.Response('{"error":"bad key"}', 401);
        }),
      );
      final client = RetryingAiClient(adapter, baseDelay: Duration.zero);

      final chunks = await run(client, request());
      expect(calls, 1);
      expect(chunks.whereType<ChatError>().single.kind, AiErrorKind.auth);
    });
  });

  group('超时保护（ENH-23）', () {
    const timeout = Duration(milliseconds: 50);

    final builders =
        <String, ({AiClient Function(http.Client) build, String firstEvent})>{
          'ChatCompletions': (
            build: (client) => ChatCompletionsAdapter(
              baseUrl: 'https://api.example.com/v1',
              apiKey: 'sk-test',
              client: client,
              connectTimeout: timeout,
              idleTimeout: timeout,
            ),
            firstEvent: 'data: {"choices":[{"delta":{"content":"雨"}}]}\n\n',
          ),
          'Messages': (
            build: (client) => MessagesAdapter(
              baseUrl: 'https://api.example.com',
              apiKey: 'sk-test',
              client: client,
              connectTimeout: timeout,
              idleTimeout: timeout,
            ),
            firstEvent:
                'data: {"type":"content_block_delta","index":0,'
                '"delta":{"type":"text_delta","text":"雨"}}\n\n',
          ),
          'Responses': (
            build: (client) => ResponsesAdapter(
              baseUrl: 'https://api.example.com/v1',
              apiKey: 'sk-test',
              client: client,
              connectTimeout: timeout,
              idleTimeout: timeout,
            ),
            firstEvent:
                'data: {"type":"response.output_text.delta","delta":"雨"}\n\n',
          ),
        };

    for (final entry in builders.entries) {
      test('${entry.key}：连接超时给出 network 错误', () async {
        final client = entry.value.build(
          MockClient((_) => Completer<http.Response>().future),
        );

        final chunks = await run(client, request());

        final error = chunks.whereType<ChatError>().single;
        expect(error.kind, AiErrorKind.network);
        expect(error.message, contains('连接超时'));
        expect(error.detail, 'TimeoutException');
      });

      test('${entry.key}：流式空闲超时保留已收文本并提示超时', () async {
        final controller = StreamController<List<int>>();
        final client = entry.value.build(
          MockClient.streaming(
            (_, _) async => http.StreamedResponse(controller.stream, 200),
          ),
        );
        controller.add(utf8.encode(entry.value.firstEvent));

        final chunks = await run(client, request());
        await controller.close();

        expect(
          chunks.whereType<ChatTextDelta>().map((c) => c.text).join(),
          contains('雨'),
        );
        final error = chunks.whereType<ChatError>().single;
        expect(error.kind, AiErrorKind.network);
        expect(error.message, contains('响应超时'));
      });
    }
  });
}

/// 按脚本回放 chunk 的假客户端（用于精确控制文本增量与错误的先后）。
class _ScriptedClient implements AiClient {
  _ScriptedClient(this._scripts);

  final List<List<ChatChunk>> _scripts;
  int calls = 0;

  @override
  Stream<ChatChunk> streamChat(ChatRequest req) async* {
    final script =
        _scripts[calls < _scripts.length ? calls : _scripts.length - 1];
    calls++;
    for (final chunk in script) {
      yield chunk;
    }
  }
}
