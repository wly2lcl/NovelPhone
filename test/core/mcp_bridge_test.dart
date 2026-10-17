import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:novelphone/core/ai/agent_core.dart';
import 'package:novelphone/core/ai/mcp/mcp_bridge.dart';
import 'package:novelphone/core/ai/mcp/mcp_oauth.dart';
import 'package:novelphone/data/db.dart';
import 'package:novelphone/data/repositories/chapter_repository.dart';
import 'package:novelphone/data/repositories/character_repository.dart';
import 'package:novelphone/data/repositories/outline_repository.dart';
import 'package:novelphone/data/repositories/settings_repository.dart';
import 'package:novelphone/data/repositories/token_stats_repository.dart';
import 'package:novelphone/data/repositories/work_repository.dart';
import 'package:novelphone/data/secure_key_store.dart';
import 'package:novelphone/features/ai/ai_service.dart';

/// 假会话：不发起真实网络连接，仅暴露一个回显工具。
class _FakeSession implements McpToolSession {
  final List<Map<String, dynamic>> calls = <Map<String, dynamic>>[];
  bool closed = false;

  @override
  String get serverName => '测试 MCP';

  @override
  List<Tool> get tools => <Tool>[
    Tool(
      name: '${mcpToolPrefix}echo',
      description: '远程回显',
      inputSchema: const <String, dynamic>{'type': 'object'},
      execute: (args) async {
        calls.add(args);
        return '远程结果：${args['q'] ?? ''}';
      },
    ),
  ];

  @override
  Future<void> close() async => closed = true;
}

void main() {
  group('parseAuthHeaders', () {
    test('按行解析 Key: Value，容忍 = 与空行', () {
      final headers = parseAuthHeaders(
        'Authorization: Bearer abc\n\n  X-Token = t-1  \n非法行',
      );
      expect(headers, <String, String>{
        'Authorization': 'Bearer abc',
        'X-Token': 't-1',
      });
    });

    test('空文本返回空 map', () {
      expect(parseAuthHeaders('   \n\n'), isEmpty);
    });
  });

  group('McpServerConfig', () {
    test('序列化往返保留全部字段', () {
      const config = McpServerConfig(
        id: 3,
        name: '本地服务',
        url: 'https://example.com/mcp',
        enabled: false,
        allowedTools: <String>['a', 'b'],
      );
      final restored = McpServerConfig.fromJson(config.toJson());
      expect(restored.id, 3);
      expect(restored.name, '本地服务');
      expect(restored.url, 'https://example.com/mcp');
      expect(restored.enabled, isFalse);
      expect(restored.allowedTools, <String>['a', 'b']);
    });

    test('白名单为空表示全部允许', () {
      const config = McpServerConfig(id: 1, name: 'x', url: 'u');
      expect(config.allowsTool('任意工具'), isTrue);
      final limited = config.copyWith(allowedTools: <String>['a']);
      expect(limited.allowsTool('a'), isTrue);
      expect(limited.allowsTool('b'), isFalse);
    });

    test('ENH-21：OAuth 字段序列化往返，历史配置回退 headers', () {
      const config = McpServerConfig(
        id: 4,
        name: 'OAuth 服务',
        url: 'https://oauth.example.com/mcp',
        authMode: McpAuthMode.oauth,
        oauthClientId: 'client-1',
        oauthScopes: <String>['read', 'write'],
      );
      final restored = McpServerConfig.fromJson(config.toJson());
      expect(restored.authMode, McpAuthMode.oauth);
      expect(restored.oauthClientId, 'client-1');
      expect(restored.oauthScopes, <String>['read', 'write']);

      final legacy = McpServerConfig.fromJson(<String, dynamic>{
        'id': 1,
        'name': '旧服务',
        'url': 'https://legacy.example.com/mcp',
      });
      expect(legacy.authMode, McpAuthMode.headers);
      expect(legacy.oauthClientId, isEmpty);
      expect(legacy.oauthScopes, isEmpty);
    });
  });

  group('SettingsRepository MCP 持久化', () {
    late AppDatabase db;
    late SettingsRepository settings;

    setUp(() {
      db = AppDatabase.memory();
      settings = SettingsRepository(db, InMemoryKeyStore());
    });

    tearDown(() async {
      await db.close();
    });

    test('新增 / 更新 / 删除，认证头只进安全存储', () async {
      final id = await settings.createMcpServer(
        name: '服务 A',
        url: 'https://a.example.com/mcp',
        allowedTools: <String>['echo'],
        authHeaders: 'Authorization: Bearer secret',
      );

      final list = await settings.listMcpServers();
      expect(list, hasLength(1));
      expect(list.single.id, id);
      expect(list.single.allowedTools, <String>['echo']);
      expect(await settings.hasMcpAuthHeaders(id), isTrue);
      expect(await settings.resolveMcpHeaders(id), <String, String>{
        'Authorization': 'Bearer secret',
      });
      // 配置 JSON 不得包含密钥本体
      final raw = await settings.getSetting(SettingsRepository.mcpServersKey);
      expect(raw, isNot(contains('secret')));

      await settings.updateMcpServer(
        list.single.copyWith(name: '服务 B', enabled: false),
      );
      final updated = (await settings.listMcpServers()).single;
      expect(updated.name, '服务 B');
      expect(updated.enabled, isFalse);
      // 未传认证头时保留原值
      expect(await settings.hasMcpAuthHeaders(id), isTrue);
      expect(await settings.listEnabledMcpServers(), isEmpty);

      await settings.deleteMcpServer(id);
      expect(await settings.listMcpServers(), isEmpty);
      expect(await settings.hasMcpAuthHeaders(id), isFalse);
    });

    test('ENH-21：OAuth 令牌只进安全存储，删除服务一并清除', () async {
      final id = await settings.createMcpServer(
        name: 'OAuth 服务',
        url: 'https://oauth.example.com/mcp',
        authMode: McpAuthMode.oauth,
      );
      expect(await settings.hasMcpOAuthTokens(id), isFalse);

      await settings.saveMcpOAuthTokens(
        id,
        McpOAuthTokens(
          accessToken: 'access-secret',
          refreshToken: 'refresh-secret',
          expiresAt: DateTime(2030),
        ),
      );
      expect(await settings.hasMcpOAuthTokens(id), isTrue);
      final restored = await settings.readMcpOAuthTokens(id);
      expect(restored!.accessToken, 'access-secret');
      expect(restored.refreshToken, 'refresh-secret');
      // 令牌不得进入配置 JSON
      final raw = await settings.getSetting(SettingsRepository.mcpServersKey);
      expect(raw, isNot(contains('access-secret')));

      await settings.deleteMcpServer(id);
      expect(await settings.hasMcpOAuthTokens(id), isFalse);
    });
  });

  group('AiService 桥段点子并入 MCP 工具（B-02）', () {
    late AppDatabase db;
    late SettingsRepository settings;
    late int workId;

    setUp(() async {
      db = AppDatabase.memory();
      settings = SettingsRepository(db, InMemoryKeyStore());
      workId = await WorkRepository(db).createWork(title: '长夜行');
      final groupId = await settings.createModelGroup(
        name: '灵感模型',
        provider: 'openai_compat',
        baseUrl: 'https://api.example.com/v1',
        models: <String>['m1'],
        apiKey: 'sk-test',
      );
      await settings.setTaskModel(AiTask.inspire, groupId);
    });

    tearDown(() async {
      await db.close();
    });

    /// 第一轮返回远程工具调用，第二轮返回正文。
    String sseFor(int round) {
      if (round == 0) {
        return 'data: {"choices":[{"delta":{"tool_calls":[{"index":0,'
            '"id":"call_1","function":{"name":"mcp_echo",'
            '"arguments":"{\\"q\\":\\"hi\\"}"}}]}}]}\n\ndata: [DONE]\n\n';
      }
      final payload = jsonEncode(<String, dynamic>{
        'choices': <dynamic>[
          <String, dynamic>{
            'delta': <String, dynamic>{'content': '1. 点子一'},
            'finish_reason': 'stop',
          },
        ],
        'usage': <String, dynamic>{'prompt_tokens': 10, 'completion_tokens': 5},
      });
      return 'data: $payload\n\ndata: [DONE]\n\n';
    }

    test('远程工具可用并被调用，结束后关闭会话', () async {
      await settings.createMcpServer(
        name: '测试 MCP',
        url: 'https://mcp.example.com/mcp',
        authHeaders: 'Authorization: Bearer tok',
      );
      final session = _FakeSession();
      McpServerConfig? openedConfig;
      McpCredentials? openedCredentials;

      var round = 0;
      final service = AiService(
        settings: settings,
        works: WorkRepository(db),
        chapters: ChapterRepository(db),
        characters: CharacterRepository(db),
        outline: OutlineRepository(db),
        stats: TokenStatsRepository(db),
        httpClient: MockClient((_) async {
          final body = sseFor(round++);
          return httpResponse(body);
        }),
        mcpOpener: (config, credentials) async {
          openedConfig = config;
          openedCredentials = credentials;
          return session;
        },
      );

      final events = await service
          .inspire(workId: workId, mode: InspireMode.ideas)
          .toList();

      expect(openedConfig!.name, '测试 MCP');
      expect(openedCredentials!.headers, <String, String>{
        'Authorization': 'Bearer tok',
      });
      expect(session.calls.single, <String, dynamic>{'q': 'hi'});
      expect(session.closed, isTrue);
      final finished = events.whereType<AiFinished>().single;
      expect(finished.text, contains('点子一'));
    });

    test('会话打开失败时不阻断生成', () async {
      await settings.createMcpServer(
        name: '坏服务',
        url: 'https://bad.example.com/mcp',
      );
      final service = AiService(
        settings: settings,
        works: WorkRepository(db),
        chapters: ChapterRepository(db),
        characters: CharacterRepository(db),
        outline: OutlineRepository(db),
        stats: TokenStatsRepository(db),
        httpClient: MockClient((_) async => httpResponse(sseFor(1))),
        mcpOpener: (config, credentials) async => throw StateError('连接被拒绝'),
      );

      final events = await service
          .inspire(workId: workId, mode: InspireMode.ideas)
          .toList();

      expect(events.whereType<AiFailed>(), isEmpty);
      expect(events.whereType<AiFinished>().single.text, '1. 点子一');
    });

    test('ENH-21：OAuth 服务器未授权时跳过该服务、不阻断生成', () async {
      final id = await settings.createMcpServer(
        name: 'OAuth 未授权',
        url: 'https://oauth.example.com/mcp',
        authMode: McpAuthMode.oauth,
      );
      var opened = false;
      final service = AiService(
        settings: settings,
        works: WorkRepository(db),
        chapters: ChapterRepository(db),
        characters: CharacterRepository(db),
        outline: OutlineRepository(db),
        stats: TokenStatsRepository(db),
        httpClient: MockClient((_) async => httpResponse(sseFor(1))),
        mcpOpener: (config, credentials) async {
          opened = true;
          return _FakeSession();
        },
      );

      final events = await service
          .inspire(workId: workId, mode: InspireMode.ideas)
          .toList();

      expect(opened, isFalse);
      expect(events.whereType<AiFailed>(), isEmpty);
      expect(events.whereType<AiFinished>().single.text, '1. 点子一');
      expect(await settings.hasMcpOAuthTokens(id), isFalse);
    });

    test('ENH-21：OAuth 服务器已授权时把令牌交给连接器', () async {
      final id = await settings.createMcpServer(
        name: 'OAuth 已授权',
        url: 'https://oauth.example.com/mcp',
        authMode: McpAuthMode.oauth,
      );
      await settings.saveMcpOAuthTokens(
        id,
        McpOAuthTokens(
          accessToken: 'tok-1',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      McpCredentials? openedCredentials;
      var round = 0;
      final service = AiService(
        settings: settings,
        works: WorkRepository(db),
        chapters: ChapterRepository(db),
        characters: CharacterRepository(db),
        outline: OutlineRepository(db),
        stats: TokenStatsRepository(db),
        httpClient: MockClient((_) async {
          final body = sseFor(round++);
          return httpResponse(body);
        }),
        mcpOpener: (config, credentials) async {
          openedCredentials = credentials;
          return _FakeSession();
        },
      );

      final events = await service
          .inspire(workId: workId, mode: InspireMode.ideas)
          .toList();

      expect(openedCredentials!.oauthTokens!.accessToken, 'tok-1');
      expect(events.whereType<AiFinished>().single.text, contains('点子一'));
    });
  });
}

/// 构造 SSE 响应（与 ai_check_test 的写法一致）。
http.Response httpResponse(String body) {
  return http.Response.bytes(
    utf8.encode(body),
    200,
    headers: <String, String>{'content-type': 'text/event-stream'},
  );
}
