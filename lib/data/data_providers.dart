import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db.dart';
import 'dao/app_setting_dao.dart';
import 'repositories/backup_repository.dart';
import 'repositories/chapter_repository.dart';
import 'repositories/character_repository.dart';
import 'repositories/chat_repository.dart';
import 'repositories/inspiration_repository.dart';
import 'repositories/mcp_audit_repository.dart';
import 'repositories/outline_repository.dart';
import 'repositories/setting_repository.dart';
import 'repositories/settings_repository.dart';
import 'repositories/token_stats_repository.dart';
import 'repositories/trash_repository.dart';
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

/// 回收站（ENH-22）：作品 / 章节软删除的恢复与永久删除。
final trashRepositoryProvider = Provider<TrashRepository>(
  (ref) => TrashRepository(ref.watch(databaseProvider)),
);

final characterRepositoryProvider = Provider<CharacterRepository>(
  (ref) => CharacterRepository(ref.watch(databaseProvider)),
);

/// 设定集（B-09）：世界观 / 地点 / 道具。
final settingRepositoryProvider = Provider<SettingRepository>(
  (ref) => SettingRepository(ref.watch(databaseProvider)),
);

/// 全局搜索（B-06）：按关键词检索全部作品的章节标题与正文。
/// autoDispose（ENH-11）：关键词变化后释放上一词的查询，避免输入过的每个
/// 前缀都常驻内存。
final searchProvider = FutureProvider.autoDispose
    .family<List<ChapterSearchHit>, String>(
      (ref, keyword) => ref.watch(chapterRepositoryProvider).search(keyword),
    );

/// 每日写作字数（B-07）：写作统计页据此计算今日字数与连击。
/// autoDispose（ENH-11）：离开统计页即释放流订阅。
final dailyWritingStatsProvider =
    StreamProvider.autoDispose<List<DailyWritingStat>>(
      (ref) => ref.watch(chapterRepositoryProvider).watchDailyWritingStats(),
    );

final outlineRepositoryProvider = Provider<OutlineRepository>(
  (ref) => OutlineRepository(ref.watch(databaseProvider)),
);

final inspirationRepositoryProvider = Provider<InspirationRepository>(
  (ref) => InspirationRepository(ref.watch(databaseProvider)),
);

/// 作品问答历史（ENH-23）：按作品存于 APP_SETTING，最多 40 条。
final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(AppSettingDao(ref.watch(databaseProvider))),
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

/// MCP 工具调用审计（ENH-22）：最近 100 次远程调用记录。
final mcpAuditRepositoryProvider = Provider<McpAuditRepository>(
  (ref) => McpAuditRepository(ref.watch(settingsRepositoryProvider)),
);

final tokenStatsRepositoryProvider = Provider<TokenStatsRepository>(
  (ref) => TokenStatsRepository(ref.watch(databaseProvider)),
);
