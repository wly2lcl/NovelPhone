// 假 LLM 服务器（ENH-16）：本机回环上模拟 Chat Completions / Messages
// 三个端点协议的关键行为，用于真机验证 429/5xx 自动重试、内容过滤提示
// 与 Anthropic 流式解析，无需真实供应商 Key。
//
// 用法：
//   dart run tool/fake_llm_server.dart [port] [chunkDelayMs]   # 默认 8899 / 80ms
//   adb reverse tcp:8899 tcp:8899
//   模型组 Base URL 填 http://127.0.0.1:8899/<场景>
//
// 场景（路径首段即场景名，其余路径忽略）：
//   /openai              Chat Completions 正常流（delta 分片 + usage + [DONE]）
//   /openai-style        返回文风档案 JSON（验证 ENH-23 文风提取）
//   /openai-extract      返回角色 / 设定抽取 JSON（验证 ENH-23 设定补全）
//   /openai-plan         返回剧情走向与分章建议 JSON（验证 ENH-23 剧情推演）
//   /openai-tool         首次返回 tool_calls（优先选 mcp_ 前缀或名为 echo 的工具，
//                        否则选第一个），收到 tool 结果后返回文本（验证 MCP 调用与审计）
//   /openai-429-first    首次请求 429，之后正常（验证 RetryingAiClient 重试）
//   /openai-429-always   始终 429
//   /openai-500          始终 500（验证 5xx 重试后仍透出错误）
//   /openai-filter       400 + safety 关键字（验证内容过滤错误分类与提示）
//   /anthropic           Messages 正常流（message_start → 文本增量 → usage）
//   /anthropic-429       始终 429
//
// 观测：GET /stats 返回各场景请求计数（JSON），GET /stats/reset 清零
// （同时重置 /openai-429-first 的“首次失败”状态），便于重复演示。
import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final port = args.isNotEmpty ? int.parse(args.first) : 8899;
  final delayMs = args.length > 1 ? int.parse(args[1]) : 80;
  final server = FakeLlmServer(chunkDelay: Duration(milliseconds: delayMs));
  await server.start(port);
  stdout.writeln('fake-llm 已启动：http://127.0.0.1:$port （分片间隔 ${delayMs}ms）');
  stdout.writeln(
    '场景基址：http://127.0.0.1:$port/openai、/openai-style、/openai-extract、'
    '/openai-plan、/openai-429-first、/openai-429-always、/openai-500、'
    '/openai-filter、/anthropic、/anthropic-429',
  );
  stdout.writeln('观测：GET /stats、GET /stats/reset');
}

class FakeLlmServer {
  FakeLlmServer({this.chunkDelay = const Duration(milliseconds: 80)});

  final Duration chunkDelay;

  /// 场景名 → 已收到请求数（/stats 与 /stats/reset 不计入）。
  final Map<String, int> _counts = <String, int>{};

  /// /openai-429-first：已“失败过一次”的场景集合。
  final Set<String> _failedOnce = <String>{};

  final List<String> _reply = <String>['连接', '成功', '！（fake-llm）'];

  Future<void> start(int port) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    await for (final request in server) {
      unawaited(_handle(request));
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final segments = request.uri.pathSegments;
    final scenario = segments.isEmpty ? '' : segments.first;

    if (request.method == 'GET' &&
        (request.uri.path == '/stats/reset' || scenario == 'stats-reset')) {
      final cleared = <String, int>{..._counts};
      _counts.clear();
      _failedOnce.clear();
      await _json(request.response, 200, <String, dynamic>{'cleared': cleared});
      return;
    }
    if (request.method == 'GET' && scenario == 'stats') {
      await _json(request.response, 200, <String, dynamic>{
        'counts': _counts,
        'total': _counts.values.fold(0, (sum, n) => sum + n),
      });
      return;
    }

    if (request.method != 'POST') {
      await _json(request.response, 405, <String, dynamic>{
        'error': '仅支持 POST',
      });
      return;
    }

    _counts[scenario] = (_counts[scenario] ?? 0) + 1;
    final count = _counts[scenario];
    try {
      await _route(scenario, request);
      stdout.writeln(
        '[fake-llm] POST /${request.uri.path} → $scenario（第 $count 次）',
      );
    } catch (e) {
      stdout.writeln('[fake-llm] POST /${request.uri.path} 处理异常：$e');
    }
  }

  Future<void> _route(String scenario, HttpRequest request) {
    switch (scenario) {
      case 'openai':
        return _openaiStream(request.response);
      case 'openai-style':
        return _openaiStream(
          request.response,
          pieces: <String>[_styleGuideJson],
        );
      case 'openai-extract':
        return _openaiStream(
          request.response,
          pieces: <String>[_entityExtractionJson],
        );
      case 'openai-plan':
        return _openaiStream(request.response, pieces: <String>[_plotPlanJson]);
      case 'openai-tool':
        return _openaiToolStream(request);
      case 'openai-429-first':
        if (_failedOnce.add(scenario)) {
          return _json(request.response, 429, _rateLimitBody);
        }
        return _openaiStream(request.response);
      case 'openai-429-always':
        return _json(request.response, 429, _rateLimitBody);
      case 'openai-500':
        return _json(request.response, 500, _serverErrorBody);
      case 'openai-filter':
        return _json(request.response, 400, _contentFilterBody);
      case 'anthropic':
        return _anthropicStream(request.response);
      case 'anthropic-429':
        return _json(request.response, 429, _rateLimitBody);
      default:
        return _json(request.response, 404, <String, dynamic>{
          'error': '未知场景 /$scenario，见文件头注释',
        });
    }
  }

  // ---------- 正常流 ----------

  Future<void> _openaiStream(
    HttpResponse response, {
    List<String>? pieces,
  }) async {
    await _begin(response);
    await _sse(response, <String, dynamic>{
      'choices': <dynamic>[
        <String, dynamic>{
          'index': 0,
          'delta': <String, dynamic>{'role': 'assistant'},
          'finish_reason': null,
        },
      ],
    });
    for (final piece in pieces ?? _reply) {
      await _sse(response, <String, dynamic>{
        'choices': <dynamic>[
          <String, dynamic>{
            'index': 0,
            'delta': <String, dynamic>{'content': piece},
            'finish_reason': null,
          },
        ],
      });
    }
    await _sse(response, <String, dynamic>{
      'choices': <dynamic>[
        <String, dynamic>{
          'index': 0,
          'delta': <String, dynamic>{},
          'finish_reason': 'stop',
        },
      ],
    });
    await _sse(response, <String, dynamic>{
      'choices': <dynamic>[],
      'usage': <String, dynamic>{'prompt_tokens': 12, 'completion_tokens': 9},
    });
    response.write('data: [DONE]\n\n');
    await response.flush();
    await response.close();
  }

  /// 第一轮返回工具调用，收到工具结果后返回文本（用于验证 MCP 审计）。
  Future<void> _openaiToolStream(HttpRequest request) async {
    final raw = await utf8.decoder.bind(request).join();
    final body = jsonDecode(raw) as Map<String, dynamic>;
    final messages = (body['messages'] as List<dynamic>?) ?? const <dynamic>[];
    final tools = (body['tools'] as List<dynamic>?) ?? const <dynamic>[];
    final hasToolResult = messages.any((m) => m is Map && m['role'] == 'tool');
    final toolNames = <String>[
      for (final tool in tools)
        if (tool is Map && tool['function'] is Map)
          (tool['function'] as Map)['name'] as String? ?? '?',
    ];
    stdout.writeln(
      '[fake-llm] openai-tool：roles=${messages.map((m) => m is Map ? m['role'] : '?').join(',')} '
      'tools=$toolNames',
    );
    final response = request.response;
    await _begin(response);
    if (!hasToolResult && tools.isNotEmpty) {
      final picked = tools.firstWhere((tool) {
        if (tool is! Map || tool['function'] is! Map) return false;
        final name = (tool['function'] as Map)['name'];
        return name is String &&
            (name.startsWith('mcp_') || name.contains('echo'));
      }, orElse: () => tools.first);
      final tool = picked as Map<String, dynamic>;
      final function = tool['function'] as Map<String, dynamic>;
      final name = function['name'] as String;
      final schema = function['parameters'] as Map<String, dynamic>?;
      final properties = schema?['properties'] as Map<String, dynamic>?;
      final args = properties != null && properties.containsKey('text')
          ? '{"text":"audit-check"}'
          : '{}';
      await _sse(response, <String, dynamic>{
        'choices': <dynamic>[
          <String, dynamic>{
            'index': 0,
            'delta': <String, dynamic>{
              'tool_calls': <dynamic>[
                <String, dynamic>{
                  'index': 0,
                  'id': 'call_fake_1',
                  'type': 'function',
                  'function': <String, dynamic>{
                    'name': name,
                    'arguments': args,
                  },
                },
              ],
            },
            'finish_reason': null,
          },
        ],
      });
      await _sse(response, <String, dynamic>{
        'choices': <dynamic>[
          <String, dynamic>{
            'index': 0,
            'delta': <String, dynamic>{},
            'finish_reason': 'tool_calls',
          },
        ],
      });
      await _sse(response, <String, dynamic>{
        'choices': <dynamic>[],
        'usage': <String, dynamic>{'prompt_tokens': 20, 'completion_tokens': 5},
      });
      response.write('data: [DONE]\n\n');
      await response.flush();
      await response.close();
      return;
    }
    for (final piece in _reply) {
      await _sse(response, <String, dynamic>{
        'choices': <dynamic>[
          <String, dynamic>{
            'index': 0,
            'delta': <String, dynamic>{'content': piece},
            'finish_reason': null,
          },
        ],
      });
    }
    await _sse(response, <String, dynamic>{
      'choices': <dynamic>[
        <String, dynamic>{
          'index': 0,
          'delta': <String, dynamic>{},
          'finish_reason': 'stop',
        },
      ],
    });
    await _sse(response, <String, dynamic>{
      'choices': <dynamic>[],
      'usage': <String, dynamic>{'prompt_tokens': 30, 'completion_tokens': 9},
    });
    response.write('data: [DONE]\n\n');
    await response.flush();
    await response.close();
  }

  Future<void> _anthropicStream(HttpResponse response) async {
    await _begin(response);
    await _sse(response, <String, dynamic>{
      'type': 'message_start',
      'message': <String, dynamic>{
        'id': 'msg_fake',
        'type': 'message',
        'role': 'assistant',
        'model': 'fake-llm',
        'usage': <String, dynamic>{'input_tokens': 12, 'output_tokens': 1},
      },
    });
    await _sse(response, <String, dynamic>{
      'type': 'content_block_start',
      'index': 0,
      'content_block': <String, dynamic>{'type': 'text', 'text': ''},
    });
    for (final piece in _reply) {
      await _sse(response, <String, dynamic>{
        'type': 'content_block_delta',
        'index': 0,
        'delta': <String, dynamic>{'type': 'text_delta', 'text': piece},
      });
    }
    await _sse(response, <String, dynamic>{
      'type': 'content_block_stop',
      'index': 0,
    });
    await _sse(response, <String, dynamic>{
      'type': 'message_delta',
      'delta': <String, dynamic>{'stop_reason': 'end_turn'},
      'usage': <String, dynamic>{'output_tokens': 9},
    });
    await _sse(response, <String, dynamic>{'type': 'message_stop'});
    await response.close();
  }

  // ---------- 基础设施 ----------

  Future<void> _begin(HttpResponse response) async {
    response.statusCode = 200;
    // 关闭输出缓冲，否则 SDK 会把整段流攒到连接结束才发给客户端，
    // 真机上无法观察增量输出与“停止保留部分结果”。
    response.bufferOutput = false;
    response.headers.contentType = ContentType(
      'text',
      'event-stream',
      charset: 'utf-8',
    );
  }

  Future<void> _sse(HttpResponse response, Map<String, dynamic> payload) async {
    response.write('data: ${jsonEncode(payload)}\n\n');
    await response.flush();
    await Future<void>.delayed(chunkDelay);
  }

  Future<void> _json(
    HttpResponse response,
    int status,
    Map<String, dynamic> body,
  ) async {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    await response.close();
  }

  static const String _styleGuideJson =
      '{"perspective":"第三人称限知，跟随女主",'
      '"tone":"冷峻克制，短句为主，少用形容词",'
      '"taboos":["不用网络流行语","少用感叹号"],'
      '"sample":"雪落无声。她把伞收起来，推门走了进去。"}';

  static const String _entityExtractionJson =
      '{"characters":[{"name":"沈砚","identity":"离乡的少年","personality":'
      '["冷静","固执"],"appearance":"眉骨很高，常穿旧呢大衣"},'
      '{"name":"苏晚","identity":"诊所医生","personality":["温和","敏锐"]}],'
      '"settings":[{"type":"location","name":"雾港","content":"常年被雾笼罩的港口"},'
      '{"type":"item","name":"旧怀表","content":"沈砚父亲留下的银质怀表"}]}';

  static const String _plotPlanJson =
      '{"directions":[{"title":"雪夜决裂","summary":"苏晚主动摊牌，沈砚被迫在旧案与她之间选择。",'
      '"beats":["苏晚拿出旧照片","沈砚否认","两人不欢而散"],'
      '"hook":"灭门案线索浮出水面，但真相可能伤到苏晚"}],'
      '"chapters":[{"title":"第十二章 雪夜","summary":"两人在诊所对质，旧案时间线出现矛盾。"}]}';

  static const Map<String, dynamic> _rateLimitBody = <String, dynamic>{
    'error': <String, dynamic>{
      'message': 'Rate limit reached for requests',
      'type': 'rate_limit_error',
    },
  };

  static const Map<String, dynamic> _serverErrorBody = <String, dynamic>{
    'error': <String, dynamic>{
      'message': 'Internal server error',
      'type': 'server_error',
    },
  };

  /// 含 safety + content_filter 关键字，命中 mapHttpError 的内容过滤分支。
  static const Map<String, dynamic> _contentFilterBody = <String, dynamic>{
    'error': <String, dynamic>{
      'message': 'Your request was rejected as a result of our safety system.',
      'type': 'invalid_request_error',
      'code': 'content_filter',
    },
  };
}
