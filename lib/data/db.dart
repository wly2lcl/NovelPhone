import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'db.g.dart';

/// 作品。wordCount / chapterCount 为冗余汇总字段，随章节保存事务内更新。
/// 对应 docs/ARCHITECTURE.md 4.1 ER 图的 WORK 表。
class Works extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 50)();
  IntColumn get coverColor => integer()();
  IntColumn get wordCount => integer().withDefault(const Constant(0))();
  IntColumn get chapterCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastEditedAt => dateTime()();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
}

/// 卷。章节归属卷，卷按 sortOrder 上移/下移排序。
class Volumes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workId =>
      integer().references(Works, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 30)();
  IntColumn get sortOrder => integer()();
}

/// 章节。cursorOffset / scrollOffset 供会话恢复，不参与 AI 上下文组装。
class Chapters extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get volumeId =>
      integer().references(Volumes, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().withLength(min: 0, max: 50)();
  TextColumn get content => text().withDefault(const Constant(''))();
  IntColumn get wordCount => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('draft'))();
  IntColumn get sortOrder => integer()();
  IntColumn get cursorOffset => integer().withDefault(const Constant(0))();
  IntColumn get scrollOffset => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();

  /// AI 生成的本章摘要（ENH-05）：供后续章节续写 / 改写时注入「前情回顾」，
  /// 区别于作者在 OUTLINE_ENTRY 手写的章纲梗概。
  TextColumn get summary => text().withDefault(const Constant(''))();
}

/// 章节快照（B-05）：手动创建的版本历史，仅存标题与正文全文，随章节级联删除。
/// 不参与 AI 上下文组装，也不随编辑自动保存而变化。
class ChapterSnapshots extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get chapterId =>
      integer().references(Chapters, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get content => text().withDefault(const Constant(''))();
  IntColumn get wordCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
}

/// 角色卡。personalityTags 存 JSON 数组字符串。
class Characters extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workId =>
      integer().references(Works, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 20)();
  TextColumn get identity => text().withDefault(const Constant(''))();
  TextColumn get personalityTags => text().withDefault(const Constant(''))();
  TextColumn get appearance => text().withDefault(const Constant(''))();
  TextColumn get relations => text().withDefault(const Constant(''))();
  TextColumn get arc => text().withDefault(const Constant(''))();
}

/// 章纲。按卷组织、每章一条梗概；删除章节时 chapterId 置空而非级联删除。
class OutlineEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workId =>
      integer().references(Works, #id, onDelete: KeyAction.cascade)();
  IntColumn get volumeId =>
      integer().nullable().references(Volumes, #id, onDelete: KeyAction.setNull)();
  IntColumn get chapterId =>
      integer().nullable().references(Chapters, #id, onDelete: KeyAction.setNull)();
  TextColumn get summary => text().withDefault(const Constant(''))();
}

/// 灵感箱（M2 落地 UI，表结构在 M1 建好）。
class Inspirations extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workId =>
      integer().references(Works, #id, onDelete: KeyAction.cascade)();
  TextColumn get content => text()();
  DateTimeColumn get createdAt => dateTime()();
}

/// AI 调用记录（M3 引入）：token 统计与采纳率 / 忽略率的唯一数据源。
/// workId / chapterId 可空，作品或章节删除时置空而非级联，统计不随作品消失。
class AiUsages extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workId =>
      integer().nullable().references(Works, #id, onDelete: KeyAction.setNull)();
  IntColumn get chapterId => integer()
      .nullable()
      .references(Chapters, #id, onDelete: KeyAction.setNull)();
  TextColumn get task => text()(); // continue / inspire / check
  TextColumn get model => text()();
  IntColumn get promptTokens => integer().withDefault(const Constant(0))();
  IntColumn get completionTokens => integer().withDefault(const Constant(0))();

  /// AI 生成的总字数与最终被插入正文字数，支撑 PRD 2.2 的字符口径采纳率。
  IntColumn get outputChars => integer().withDefault(const Constant(0))();
  IntColumn get adoptedChars => integer().withDefault(const Constant(0))();
  TextColumn get outcome =>
      text().withDefault(const Constant('pending'))(); // adopted/ignored/regenerated/aborted/pending
  DateTimeColumn get createdAt => dateTime()();
}

/// 模型组（M3 引入）：一个模型组对应一个 AiClient 实例。
/// apiKeyRef 仅为 flutter_secure_storage 引用，key 本体不落库（ARCHITECTURE 4.1）。
class ModelGroups extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get provider => text().withDefault(const Constant('openai_compat'))();
  TextColumn get name => text().withLength(min: 1, max: 30)();
  TextColumn get baseUrl => text()();
  TextColumn get apiKeyRef => text().withDefault(const Constant(''))();
  TextColumn get models => text().withDefault(const Constant(''))(); // JSON 数组字符串
  RealColumn get temperature => real().withDefault(const Constant(0.8))();
  IntColumn get maxTokens => integer().withDefault(const Constant(1024))();
  IntColumn get contextWindow => integer().withDefault(const Constant(32000))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
}

/// 全局键值设置（M3 引入）：默认模型、任务→模型映射（task_model_*）等，不含凭证。
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => <Column>{key};
}

/// 每日写作字数（B-07）：按本地日期累计当天净增的正字数，供每日目标与连击统计。
class DailyWritingStats extends Table {
  TextColumn get day => text()(); // yyyy-MM-dd（本地时区）
  IntColumn get words => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => <Column>{day};
}

/// 设定集条目（B-09）：世界观 / 地点 / 道具，用 type 区分，随作品级联删除。
class SettingEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workId =>
      integer().references(Works, #id, onDelete: KeyAction.cascade)();
  TextColumn get type => text().withDefault(const Constant('worldview'))();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get content => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
}

/// 角色关系（B-09 人物关系图）：一条有向关系 from → to，两端角色删除时级联删除。
class CharacterRelations extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workId =>
      integer().references(Works, #id, onDelete: KeyAction.cascade)();
  @ReferenceName('outgoingRelations')
  IntColumn get fromCharacterId =>
      integer().references(Characters, #id, onDelete: KeyAction.cascade)();
  @ReferenceName('incomingRelations')
  IntColumn get toCharacterId =>
      integer().references(Characters, #id, onDelete: KeyAction.cascade)();
  TextColumn get label => text().withDefault(const Constant(''))();
}

@DriftDatabase(tables: [
  Works,
  Volumes,
  Chapters,
  ChapterSnapshots,
  Characters,
  OutlineEntries,
  Inspirations,
  AiUsages,
  ModelGroups,
  AppSettings,
  DailyWritingStats,
  SettingEntries,
  CharacterRelations,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// 仅测试使用：内存库。
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          // v2（M3）：追加 AI_USAGE / MODEL_GROUP / APP_SETTING 三表。
          if (from < 2) {
            await m.createTable(aiUsages);
            await m.createTable(modelGroups);
            await m.createTable(appSettings);
          }
          // v3（B-05）：追加 CHAPTER_SNAPSHOT 表（章节版本历史）。
          if (from < 3) {
            await m.createTable(chapterSnapshots);
          }
          // v4（B-07）：追加 DAILY_WRITING_STAT 表（每日写作字数）。
          if (from < 4) {
            await m.createTable(dailyWritingStats);
          }
          // v5（B-09）：追加 SETTING_ENTRY（设定集）与 CHARACTER_RELATION（人物关系）表。
          if (from < 5) {
            await m.createTable(settingEntries);
            await m.createTable(characterRelations);
          }
          // v6（ENH-05）：CHAPTER 追加 AI 摘要列（前情回顾）。
          if (from < 6) {
            await m.addColumn(chapters, chapters.summary);
          }
        },
        beforeOpen: (details) async {
          // 级联删除依赖外键约束，SQLite 默认关闭，需每连接开启。
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

/// 打开设备上的应用数据库（应用私有目录，随 app 卸载删除）。
QueryExecutor openAppDatabase() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'novelphone.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}