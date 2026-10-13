import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/data_providers.dart';
import '../../data/db.dart';
import '../../data/repositories/token_stats_repository.dart';
import 'ai_service.dart';

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
  );
});

final modelGroupsProvider = StreamProvider<List<ModelGroup>>(
  (ref) => ref.watch(settingsRepositoryProvider).watchModelGroups(),
);

final taskModelIdProvider = StreamProvider.family<int?, String>(
  (ref, task) => ref.watch(settingsRepositoryProvider).watchTaskModelId(task),
);

final tokenStatsProvider = StreamProvider<TokenStats>(
  (ref) => ref.watch(tokenStatsRepositoryProvider).watchStats(),
);

/// 检查问题处置率计数（M4-12，ARCHITECTURE 4.2）。
final checkStatsProvider = FutureProvider<({int total, int handled})>(
  (ref) => ref.watch(settingsRepositoryProvider).readCheckStats(),
);