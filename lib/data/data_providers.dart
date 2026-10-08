import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db.dart';
import 'repositories/backup_repository.dart';
import 'repositories/chapter_repository.dart';
import 'repositories/character_repository.dart';
import 'repositories/inspiration_repository.dart';
import 'repositories/outline_repository.dart';
import 'repositories/setting_repository.dart';
import 'repositories/settings_repository.dart';
import 'repositories/token_stats_repository.dart';
import 'repositories/work_repository.dart';
import 'secure_key_store.dart';

/// 应用数据库（测试中可用内存库覆盖）。
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(openAppDatabase());
  ref.onDispose(db.close);
  return db;
});

final workRepositoryProvider = Provider<WorkRepository>(
  (ref) => WorkRepository(ref.watch(databaseProvider)),
);

final chapterRepositoryProvider = Provider<ChapterRepository>(
  (ref) => ChapterRepository(ref.watch(databaseProvider)),
);

final characterRepositoryProvider = Provider<CharacterRepository>(
  (ref) => CharacterRepository(ref.watch(databaseProvider)),
);

/// 设定集（B-09）：世界观 / 地点 / 道具。
final settingRepositoryProvider = Provider<SettingRepository>(
  (ref) => SettingRepository(ref.watch(databaseProvider)),
);

/// 全局搜索（B-06）：按关键词检索全部作品的章节标题与正文。
final searchProvider =
    FutureProvider.family<List<ChapterSearchHit>, String>(
  (ref, keyword) => ref.watch(chapterRepositoryProvider).search(keyword),
);

/// 每日写作字数（B-07）：写作统计页据此计算今日字数与连击。
final dailyWritingStatsProvider = StreamProvider<List<DailyWritingStat>>(
  (ref) => ref.watch(chapterRepositoryProvider).watchDailyWritingStats(),
);

final outlineRepositoryProvider = Provider<OutlineRepository>(
  (ref) => OutlineRepository(ref.watch(databaseProvider)),
);

final inspirationRepositoryProvider = Provider<InspirationRepository>(
  (ref) => InspirationRepository(ref.watch(databaseProvider)),
);

final backupRepositoryProvider = Provider<BackupRepository>(
  (ref) => BackupRepository(ref.watch(databaseProvider)),
);

/// API key 安全存储（测试中可用内存实现覆盖）。
final secureKeyStoreProvider = Provider<SecureKeyStore>(
  (ref) => FlutterSecureKeyStore(),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(
    ref.watch(databaseProvider),
    ref.watch(secureKeyStoreProvider),
  ),
);

final tokenStatsRepositoryProvider = Provider<TokenStatsRepository>(
  (ref) => TokenStatsRepository(ref.watch(databaseProvider)),
);