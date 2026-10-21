import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/core/ai/agent_core.dart';
import 'package:novelphone/core/ai/ai_client.dart';

/// 按轮次脚本化返回的假客户端，用于验证 ReAct 循环。
class _ScriptedClient implements AiClient {
  _ScriptedClient(this.rounds);

  final List<List<ChatChunk>> rounds;
  final List<ChatRequest> requests = <ChatRequest>[];
  int _index = 0;

  @override
  Stream<ChatChunk> streamChat(ChatRequest req) async* {
    requests.add(req);
    final chunks = _index < rounds.length
        ? rounds[_index]
        : const <ChatChunk>[];
    _index++;
    yield* Stream<ChatChunk>.fromIterable(chunks);
  }
}

Tool _echoTool({
  bool fail = false,
  void Function(Map<String, dynamic>)? onCall,
}) {
  return Tool(
    name: 'get_chapter',
    description: '取章节',
    inputSchema: const <String, dynamic>{'type': 'object'},
    execute: (args) async {
      onCall?.call(args);
      if (fail) throw StateError('数据库不可用');
      return '正文内容';
    },
  );
}

void main() {
  test('多来源重名工具追加序号，且各自路由到原实现', () async {
    Tool named(String name, String result) => Tool(
      name: name,
      description: name,
      inputSchema: const <String, dynamic>{'type': 'object'},
      execute: (_) async => result,
    );

    final tools = dedupeToolNames(<Tool>[
      named('mcp_search', 'A'),
      named('mcp_search', 'B'),
      named('mcp_search', 'C'),
    ]);

    expect(tools.map((tool) => tool.name), <String>[
      'mcp_search',
      'mcp_search_2',
      'mcp_search_3',
    ]);
    expect(await tools[1].execute(<String, dynamic>{}), 'B');
    expect(await tools[2].execute(<String, dynamic>{}), 'C');
  });

  const request = ChatRequest(
    model: 'test-model',
    messages: <ChatMessage>[ChatMessage('user', '给点灵感')],
  );

  test('工具调用成功路径：执行工具、结果回传、随后输出文本', () async {
    final calls = <Map<String, dynamic>>[];
    final client = _ScriptedClient(<List<ChatChunk>>[
      <ChatChunk>[
        const ChatToolCalls(<ToolCall>[
          ToolCall(id: 'c1', name: 'get_chapter', arguments: '{"id":3}'),
        ]),
      ],
      <ChatChunk>[
        const ChatTextDelta('已根据第 3 章给出建议'),
        const ChatDone(finishReason: 'stop'),
      ],
    ]);

    final chunks = await AgentCore(client: client)
        .run(
          request: request,
          tools: <Tool>[_echoTool(onCall: calls.add)],
        )
        .toList();

    expect(calls.single, <String, dynamic>{'id': 3});
    expect(
      chunks.whereType<ChatTextDelta>().map((c) => c.text).join(),
      '已根据第 3 章给出建议',
    );

    // 第二轮请求里应带回 assistant 的工具调用与 tool 结果
    final second = client.requests[1];
    expect(second.messages, hasLength(3));
    expect(second.messages[1].role, 'assistant');
    expect(second.messages[1].toolCalls!.single.name, 'get_chapter');
    expect(second.messages[2].role, 'tool');
    expect(second.messages[2].toolCallId, 'c1');
    expect(second.messages[2].content, '正文内容');
  });

  test('工具执行失败时把错误文本回传给模型，不中断流程', () async {
    final client = _ScriptedClient(<List<ChatChunk>>[
      <ChatChunk>[
        const ChatToolCalls(<ToolCall>[
          ToolCall(id: 'c1', name: 'get_chapter', arguments: '{}'),
        ]),
      ],
      <ChatChunk>[const ChatTextDelta('工具取数失败，改为直接建议'), const ChatDone()],
    ]);

    final chunks = await AgentCore(
      client: client,
    ).run(request: request, tools: <Tool>[_echoTool(fail: true)]).toList();

    expect(client.requests[1].messages[2].content, contains('工具执行失败'));
    expect(chunks.whereType<ChatError>(), isEmpty);
    expect(chunks.whereType<ChatTextDelta>(), isNotEmpty);
  });

  test('达到最大轮次仍未收敛时输出错误并停止', () async {
    final alwaysCall = <ChatChunk>[
      const ChatToolCalls(<ToolCall>[
        ToolCall(id: 'c1', name: 'get_chapter', arguments: '{}'),
      ]),
    ];
    final client = _ScriptedClient(<List<ChatChunk>>[
      alwaysCall,
      alwaysCall,
      alwaysCall,
    ]);

    final chunks = await AgentCore(
      client: client,
      maxRounds: 2,
    ).run(request: request, tools: <Tool>[_echoTool()]).toList();

    expect(client.requests, hasLength(2));
    final error = chunks.whereType<ChatError>().single;
    expect(error.kind, AiErrorKind.unknown);
    expect(error.message, contains('轮次超限'));
  });
}
