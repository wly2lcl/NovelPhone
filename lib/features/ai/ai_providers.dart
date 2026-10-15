import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../data/data_providers.dart';
import '../../data/db.dart';
import '../../data/repositories/token_stats_repository.dart';
import 'ai_service.dart';

/// 全 App 共享的 HTTP 客户端（ENH-12）：AI 生成复用同一条连接（keep-alive），
/// 避免每次生成都新建 `http.Client` 又重新握手、且旧客户端从不关闭。
final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// AI 用例编排实例（ARCHITECTURE 2.2：features 经此访问 AI 层）。
final aiServiceProvider = Provider<AiService>((ref) {
  return AiService(
    settings: ref.watch(settingsRepositoryProvider),
    works: ref.watch(workRepositoryProvider),
    chapters: ref.watch(chapterRepositoryProvider),
    characters: ref.watch(characterRepositoryProvider),
    outline: ref.watch(outlineRepositoryProvider),
    stats: ref.watch(tokenStatsRepositoryProvider),
    settingRepository: ref.watch(settingRepositoryProvider),
    httpClient: ref.watch(httpClientProvider),
  );
});

final modelGroupsProvider = StreamProvider<List<ModelGroup>>(
  (ref) => ref.watch(settingsRepositoryProvider).watchModelGroups(),
);

/// 任务 → 模型映射（autoDispose，ENH-11：离开设置页即释放流订阅）。
final taskModelIdProvider =
    StreamProvider.autoDispose.family<int?, String>(
  (ref, task) => ref.watch(settingsRepositoryProvider).watchTaskModelId(task),
);

final tokenStatsProvider = StreamProvider<TokenStats>(
  (ref) => ref.watch(tokenStatsRepositoryProvider).watchStats(),
);

/// 检查问题处置率计数（M4-12，ARCHITECTURE 4.2）。
final checkStatsProvider = FutureProvider<({int total, int handled})>(
  (ref) => ref.watch(settingsRepositoryProvider).readCheckStats(),
);