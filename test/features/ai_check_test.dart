import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:novelphone/core/ai/ai_client.dart';
import 'package:novelphone/core/ai_flavor_rules.dart';
import 'package:novelphone/data/db.dart';
import 'package:novelphone/data/repositories/chapter_repository.dart';
import 'package:novelphone/data/repositories/character_repository.dart';
import 'package:novelphone/data/repositories/outline_repository.dart';
import 'package:novelphone/data/repositories/settings_repository.dart';
import 'package:novelphone/data/repositories/token_stats_repository.dart';
import 'package:novelphone/data/repositories/work_repository.dart';
import 'package:novelphone/data/secure_key_store.dart';
import 'package:novelphone/features/ai/ai_service.dart';

void main() {
  late AppDatabase db;
  late WorkRepository works;
  late ChapterRepository chapters;
  late SettingsRepository settings;
  late TokenStatsRepository stats;
  late int workId;
  late int chapterId;

  const chapterText = '她不禁笑了。';

  AiService serviceWith(http.Client client) => AiService(
        settings: settings,
        works: works,
        chapters: chapters,
        characters: CharacterRepository(db),
        outline: OutlineRepository(db),
        stats: stats,
        httpClient: client,
      );

  http.Response sseResponse(String content) {
    final payload = jsonEncode(<String, dynamic>{
      'choices': <dynamic>[
        <String, dynamic>{
          'delta': <String, dynamic>{'content': content},
          'finish_reason': 'stop',
        },
      ],
      'usage': <String, dynamic>{'prompt_tokens': 20, 'completion_tokens': 8},
    });
    return http.Response.bytes(
      utf8.encode('data: $payload\n\ndata: [DONE]\n\n'),
      200,
      headers: <String, String>{'content-type': 'text/event-stream'},
    );
  }

  Future<void> configureCheckModel() async {
    final id = await settings.createModelGroup(
      name: '检查模型',
      provider: 'openai_compat',
      baseUrl: 'https://api.example.com/v1',
      models: <String>['m1'],
      apiKey: 'sk-test',
    );
    await settings.setTaskModel(AiTask.check, id);
  }

  /// 续写模型组（M3-14 / M3-22 的用例回归）。
  Future<void> configureContinueModel() async {
    final id = await settings.createModelGroup(
      name: '续写模型',
      provider: 'openai_compat',
      baseUrl: 'https://api.example.com/v1',
      models: <String>['m1'],
      apiKey: 'sk-test',
    );
    await settings.setTaskModel(AiTask.continueWriting, id);
  }

  setUp(() async {
    db = AppDatabase.memory();
    works = WorkRepository(db);
    chapters = ChapterRepository(db);
    settings = SettingsRepository(db, InMemoryKeyStore());
    stats = TokenStatsRepository(db);
    workId = await works.createWork(title: '长夜行');
    chapterId = await chapters.createChapter(workId: workId, title: '第一章');
    await chapters.saveChapter(
      chapterId: chapterId,
      title: '第一章',
      content: chapterText,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('规则层即时返回结果（不联网）', () async {
    final events = await serviceWith(
      MockClient((req) async => throw StateError('不应发起网络请求')),
    ).checkFlavor(workId: workId, chapterId: chapterId).toList();

    expect(events, hasLength(1));
    final rule = events.single as CheckRuleResult;
    expect(rule.scope.segments.single.chapterId, chapterId);
    expect(
      rule.result.issues.any((i) => i.excerpt == '不禁'),
      isTrue,
    );
  });

  test('未配置检查模型时给出引导事件且保留规则结果', () async {
    final events = await serviceWith(MockClient((req) async => sseResponse('')))
        .checkFlavor(workId: workId, chapterId: chapterId, deep: true)
        .toList();

    expect(events.first, isA<CheckRuleResult>());
    expect(events.last, isA<CheckNeedsConfig>());
  });

  test('深检成功：解析 JSON、回写 token 统计', () async {
    await configureCheckModel();
    final response = '{"issues":[{"type":"套话","severity":"高","quote":"不禁",'
        '"suggestion":"删除该词"}]}';
    final events = await serviceWith(MockClient((req) async => sseResponse(response)))
        .checkFlavor(workId: workId, chapterId: chapterId, deep: true)
        .toList();

    expect(events.first, isA<CheckRuleResult>());
    expect(events.whereType<CheckDeepStarted>().single.segments, 1);
    expect(events.whereType<CheckDeepProgress>().single.done, 1);

    final finished = events.whereType<CheckDeepFinished>().single;
    final issue = finished.issues.single;
    expect(issue.type, FlavorType.cliche);
    expect(issue.severity, FlavorSeverity.high);
    expect(issue.start, 1);
    expect(issue.end, 3);
    expect(issue.source, FlavorSource.llm);
    expect(finished.fallbackText, isNull);

    final recorded = await stats.stats();
    expect(recorded.calls, 1);
    expect(recorded.rows.single.task, AiTask.check);
    expect(recorded.promptTokens, 20);
    expect(recorded.completionTokens, 8);
  });

  test('JSON 解析失败时降级为纯文本', () async {
    await configureCheckModel();
    final events = await serviceWith(
      MockClient((req) async => sseResponse('这段里"不禁"用得太多了。')),
    ).checkFlavor(workId: workId, chapterId: chapterId, deep: true).toList();

    final finished = events.whereType<CheckDeepFinished>().single;
    expect(finished.issues, isEmpty);
    expect(finished.fallbackText, contains('不禁'));
  });

  test('LLM 检测失败时保留规则结果并提示', () async {
    await configureCheckModel();
    final events = await serviceWith(
      MockClient((req) async => http.Response('{"error":{"message":"invalid key"}}', 401)),
    ).checkFlavor(workId: workId, chapterId: chapterId, deep: true).toList();

    expect(events.first, isA<CheckRuleResult>());
    final failed = events.whereType<CheckDeepFailed>().single;
    expect(failed.kind, AiErrorKind.auth);
    expect(events.whereType<CheckDeepFinished>(), isEmpty);
  });

  test('弱网中断时映射为网络错误并保留规则结果（M4-14）', () async {
    await configureCheckModel();
    final events = await serviceWith(
      MockClient((req) async => throw http.ClientException('connection aborted')),
    ).checkFlavor(workId: workId, chapterId: chapterId, deep: true).toList();

    expect(events.first, isA<CheckRuleResult>());
    final failed = events.whereType<CheckDeepFailed>().single;
    expect(failed.kind, AiErrorKind.network);
    expect(events.whereType<CheckDeepFinished>(), isEmpty);
  });

  test('整作检查拼接全部章节', () async {
    final second = await chapters.createChapter(workId: workId, title: '第二章');
    await chapters.saveChapter(chapterId: second, title: '第二章', content: '他缓缓开口。');

    final events = await serviceWith(MockClient((req) async => throw StateError('不应联网')))
        .checkFlavor(workId: workId)
        .toList();

    final rule = events.single as CheckRuleResult;
    expect(rule.scope.segments, hasLength(2));
  });

  group('AI 续写用例回归（M3-14 / M3-22）', () {
    /// 先吐一段文本、再中断的网络流（模拟弱网/断网）。
    Stream<List<int>> interruptedStream() async* {
      final payload = jsonEncode(<String, dynamic>{
        'choices': <dynamic>[
          <String, dynamic>{
            'delta': <String, dynamic>{'content': '她点头，'},
          },
        ],
      });
      yield utf8.encode('data: $payload\n\n');
      throw http.ClientException('connection reset by peer');
    }

    test('未配置续写模型时引导至设置页且不联网', () async {
      final events = await serviceWith(
        MockClient((req) async => throw StateError('不应发起网络请求')),
      ).continueWriting(workId: workId, chapterId: chapterId).toList();

      expect(events.single, isA<AiNeedsConfig>());
    });

    test('流式生成：上下文先行、文本增量、结束携带 usage 并落统计', () async {
      await configureContinueModel();
      final events = await serviceWith(MockClient((req) async => sseResponse('她点头。')))
          .continueWriting(workId: workId, chapterId: chapterId)
          .toList();

      expect(events.first, isA<AiContextBuilt>());
      expect(
        events.whereType<AiTextChunk>().map((e) => e.text).join(),
        '她点头。',
      );
      final finished = events.whereType<AiFinished>().single;
      expect(finished.text, '她点头。');
      expect(events.whereType<AiFailed>(), isEmpty);

      final recorded = await stats.stats();
      expect(recorded.calls, 1);
      expect(recorded.rows.single.task, AiTask.continueWriting);
      expect(recorded.rows.single.outputChars, '她点头。'.length);
    });

    test('生成中断时保留已生成内容并给出网络错误（M3-22）', () async {
      await configureContinueModel();
      final events = await serviceWith(MockClient.streaming(
        (request, bodyStream) async => http.StreamedResponse(
          http.ByteStream(interruptedStream()),
          200,
          headers: <String, String>{'content-type': 'text/event-stream'},
        ),
      )).continueWriting(workId: workId, chapterId: chapterId).toList();

      // 已生成的部分保留在面板中（AiFinished 先于 AiFailed），可手动保存 / 重试。
      final finished = events.whereType<AiFinished>().single;
      expect(finished.text, '她点头，');
      expect(finished.usageId, -1);
      expect(events.whereType<AiFailed>().single.kind, AiErrorKind.network);

      // 中断也按已生成字数落一条统计（outcome = aborted）。
      final recorded = await stats.stats();
      expect(recorded.calls, 1);
      expect(recorded.rows.single.outputChars, '她点头，'.length);
    });
  });

  group('AI 改写用例（ENH-04）', () {
    test('未配置任何模型时引导至设置页且不联网', () async {
      final service = serviceWith(
        MockClient((req) async => throw StateError('不应发起网络请求')),
      );

      final events = await service
          .rewrite(workId: workId, chapterId: chapterId, selectedText: chapterText)
          .toList();

      expect(events.single, isA<AiNeedsConfig>());
      expect(await service.isReady(AiTask.rewrite), isFalse);
    });

    test('未单独配置改写模型时回退续写模型组并流式生成、落 rewrite 统计', () async {
      await configureContinueModel();
      final service =
          serviceWith(MockClient((req) async => sseResponse('她轻轻笑了。')));

      // 零配置回退：改写任务未配置，但续写组可用。
      expect(await service.isReady(AiTask.rewrite), isTrue);

      final events = await service
          .rewrite(
            workId: workId,
            chapterId: chapterId,
            selectedText: chapterText,
            intent: RewriteIntent.polish,
          )
          .toList();

      final built = events.whereType<AiContextBuilt>().single;
      expect(built.context.messages.single.content,
          contains('【待改写原文】\n$chapterText'));
      expect(events.whereType<AiFinished>().single.text, '她轻轻笑了。');
      expect(events.whereType<AiFailed>(), isEmpty);

      final recorded = await stats.stats();
      expect(recorded.calls, 1);
      expect(recorded.rows.single.task, AiTask.rewrite);
      expect(recorded.rows.single.outputChars, '她轻轻笑了。'.length);
    });
  });

  group('AI 逐章摘要 / 章纲扩写 / 多候选（ENH-05）', () {
    test('未配置任何模型时引导至设置页且不联网', () async {
      final service = serviceWith(
        MockClient((req) async => throw StateError('不应发起网络请求')),
      );

      final summary = await service
          .summarizeChapter(workId: workId, chapterId: chapterId)
          .toList();
      final outline = await service
          .expandOutline(workId: workId, chapterId: chapterId, seed: '雨中摊牌')
          .toList();

      expect(summary.single, isA<AiNeedsConfig>());
      expect(outline.single, isA<AiNeedsConfig>());
      expect(await service.isReady(AiTask.summary), isFalse);
    });

    test('摘要回退续写模型组、上下文含本章正文、落 summary 统计', () async {
      await configureContinueModel();
      final events = await serviceWith(MockClient((req) async => sseResponse('沈砚离乡。')))
          .summarizeChapter(workId: workId, chapterId: chapterId)
          .toList();

      final built = events.whereType<AiContextBuilt>().single;
      expect(built.context.messages.single.content, contains(chapterText));
      expect(events.whereType<AiFinished>().single.text, '沈砚离乡。');

      final recorded = await stats.stats();
      expect(recorded.rows.single.task, AiTask.summary);
    });

    test('章纲扩写回退续写模型组、种子进入上下文、落 outline 统计', () async {
      await configureContinueModel();
      final events = await serviceWith(
        MockClient((req) async => sseResponse('分场一：雨夜相遇。')),
      ).expandOutline(workId: workId, chapterId: chapterId, seed: '雨中摊牌').toList();

      final built = events.whereType<AiContextBuilt>().single;
      expect(built.context.messages.single.content, contains('雨中摊牌'));
      expect(events.whereType<AiFinished>().single.text, '分场一：雨夜相遇。');

      final recorded = await stats.stats();
      expect(recorded.rows.single.task, AiTask.outlineExpand);
    });

    test('多候选按 variant 调整温度（版本越靠后越高）', () async {
      await configureContinueModel();
      final temperatures = <double>[];
      final service = serviceWith(MockClient((req) async {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        temperatures.add((body['temperature'] as num).toDouble());
        return sseResponse('她点头。');
      }));

      await service
          .continueWriting(workId: workId, chapterId: chapterId, variant: 0)
          .toList();
      await service
          .continueWriting(workId: workId, chapterId: chapterId, variant: 2)
          .toList();

      expect(temperatures, hasLength(2));
      expect(temperatures[1], greaterThan(temperatures[0]));
    });
  });

  group('本卷前情回顾用例（ENH-06）', () {
    test('未配置任何模型时引导至设置页且不联网', () async {
      final service = serviceWith(
        MockClient((req) async => throw StateError('不应发起网络请求')),
      );

      final events = await service
          .summarizeVolume(workId: workId, chapterId: chapterId)
          .toList();

      expect(events.single, isA<AiNeedsConfig>());
      expect(await service.isReady(AiTask.volumeSummary), isFalse);
    });

    test('回退续写模型组、上下文含本卷各章摘要、落 volume 统计', () async {
      await configureContinueModel();
      // 为第一章写入 AI 摘要：卷回顾素材应直接采用缓存内容。
      await chapters.saveChapterSummary(chapterId, '第一章摘要：她笑了。');
      final second = await chapters.createChapter(workId: workId, title: '第二章');
      await chapters.saveChapter(chapterId: second, title: '第二章', content: '他缓缓开口。');

      final service =
          serviceWith(MockClient((req) async => sseResponse('本卷：她笑了。')));
      // 零配置回退：卷回顾任务未配置，但续写组可用。
      expect(await service.isReady(AiTask.volumeSummary), isTrue);

      final events = await service
          .summarizeVolume(workId: workId, chapterId: second)
          .toList();

      final built = events.whereType<AiContextBuilt>().single;
      expect(built.context.messages.single.content, contains('第一章摘要：她笑了。'));
      expect(events.whereType<AiFinished>().single.text, '本卷：她笑了。');

      final recorded = await stats.stats();
      expect(recorded.calls, 1);
      expect(recorded.rows.single.task, AiTask.volumeSummary);
    });
  });
}