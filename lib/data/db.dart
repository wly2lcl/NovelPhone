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

  /// 回收站标记（ENH-22）：非空表示已移入回收站，30 天后彻底删除。
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// 作品级文风档案（ENH-23）：JSON 字符串，见 `WorkStyleGuide`。
  TextColumn get styleGuide => text().withDefault(const Constant(''))();
}

/// 卷。章节归属卷，卷按 sortOrder 上移/下移排序。
@TableIndex(name: 'volumes_work_id', columns: {#workId})
class Volumes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workId =>
      integer().references(Works, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 30)();
  IntColumn get sortOrder => integer()();

  /// 本卷前情回顾摘要（ENH-06）：由卷内章节摘要归并生成，供后续章节续写 / 改写注入。
  TextColumn get summary => text().withDefault(const Constant(''))();

  /// 上次归并覆盖到的章节 id（ENH-07 O6）：支持卷回顾增量滚动归并，0 表示全量。
  IntColumn get summaryChapterId => integer().withDefault(const Constant(0))();
}

/// 章节。cursorOffset / scrollOffset 供会话恢复，不参与 AI 上下文组装。
@TableIndex(name: 'chapters_volume_id', columns: {#volumeId})
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

  /// 摘要生成 / 更新时间（ENH-07 O4）：正文在此之后有改动时提示摘要可能过期。
  DateTimeColumn get summaryUpdatedAt => dateTime().nullable()();

  /// 回收站标记（ENH-22）：非空表示已移入回收站，30 天后彻底删除。
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// 章节快照（B-05）：手动创建的版本历史，仅存标题与正文全文，随章节级联删除。
/// 不参与 AI 上下文组装，也不随编辑自动保存而变化。
@TableIndex(name: 'chapter_snapshots_chapter_id', columns: {#chapterId})
class ChapterSnapshots extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get chapterId =>
      integer().references(Chapters, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get content => text().withDefault(const Constant(''))();

  /// 快照来源标记（ENH-30）：如 `ai_before_adopt`，空串表示手动创建。
  TextColumn get note => text().withDefault(const Constant(''))();
  IntColumn get wordCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
}

/// 角色卡。personalityTags / aliases 存 JSON 数组字符串。
@TableIndex(name: 'characters_work_id', columns: {#workId})
class Characters extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workId =>
      integer().references(Works, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 20)();
  TextColumn get identity => text().withDefault(const Constant(''))();
  TextColumn get personalityTags => text().withDefault(const Constant(''))();

  /// 别名 / 称谓（ENH-40）：JSON 数组字符串，如 `["沈公子","小砚"]`。
  /// 用于上下文角色匹配与本地检索的别名扩展。
  TextColumn get aliases => text().withDefault(const Constant(''))();
  TextColumn get appearance => text().withDefault(const Constant(''))();
  TextColumn get relations => text().withDefault(const Constant(''))();
  TextColumn get arc => text().withDefault(const Constant(''))();
}

/// 章纲。按卷组织、每章一条梗概；删除章节时 chapterId 置空而非级联删除。
@TableIndex(name: 'outline_entries_work_id', columns: {#workId})
class OutlineEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workId =>
      integer().references(Works, #id, onDelete: KeyAction.cascade)();
  IntColumn get volumeId => integer().nullable().references(
    Volumes,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get chapterId => integer().nullable().references(
    Chapters,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get summary => text().withDefault(const Constant(''))();
}

/// 灵感箱（M2 落地 UI，表结构在 M1 建好）。
@TableIndex(name: 'inspirations_work_id', columns: {#workId})
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
  IntColumn get workId => integer().nullable().references(
    Works,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get chapterId => integer().nullable().references(
    Chapters,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get task => text()(); // continue / inspire / check
  TextColumn get model => text()();
  IntColumn get promptTokens => integer().withDefault(const Constant(0))();
  IntColumn get completionTokens => integer().withDefault(const Constant(0))();

  /// AI 生成的总字数与最终被插入正文字数，支撑 PRD 2.2 的字符口径采纳率。
  IntColumn get outputChars => integer().withDefault(const Constant(0))();
  IntColumn get adoptedChars => integer().withDefault(const Constant(0))();

  /// AI 原稿到最终采纳文本的编辑比例（ENH-30，0~100，空值表示旧记录）。
  IntColumn get adoptedEditPercent => integer().nullable()();
  TextColumn get outcome => text().withDefault(
    const Constant('pending'),
  )(); // adopted/ignored/regenerated/aborted/pending
  DateTimeColumn get createdAt => dateTime()();
}

/// 模型组（M3 引入）：一个模型组对应一个 AiClient 实例。
/// apiKeyRef 仅为 flutter_secure_storage 引用，key 本体不落库（ARCHITECTURE 4.1）。
class ModelGroups extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get provider =>
      text().withDefault(const Constant('openai_compat'))();
  TextColumn get name => text().withLength(min: 1, max: 30)();
  TextColumn get baseUrl => text()();
  TextColumn get apiKeyRef => text().withDefault(const Constant(''))();
  TextColumn get models =>
      text().withDefault(const Constant(''))(); // JSON 数组字符串
  RealColumn get temperature => real().withDefault(const Constant(0.8))();
  IntColumn get maxTokens => integer().withDefault(const Constant(1024))();
  IntColumn get contextWindow => integer().withDefault(const Constant(32000))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  /// 费用估算（ENH-23）：每百万 token 单价（元），0 表示未填写。
  RealColumn get inputPricePerMillion =>
      real().withDefault(const Constant(0))();
  RealColumn get outputPricePerMillion =>
      real().withDefault(const Constant(0))();
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
@TableIndex(name: 'setting_entries_work_id', columns: {#workId})
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
@TableIndex(name: 'character_relations_work_id', columns: {#workId})
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

/// 故事状态卡（ENH-31）：角色状态 / 伏笔 / 时间线三类结构化条目。
/// 与角色卡、章纲互补——这里记录「当下状态」与「待回收线索」，供 AI 续写注入。
@TableIndex(name: 'story_states_work_id', columns: {#workId})
class StoryStates extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workId =>
      integer().references(Works, #id, onDelete: KeyAction.cascade)();
  TextColumn get kind => text()(); // character / foreshadow / timeline
  TextColumn get title => text().withLength(min: 1, max: 50)();
  TextColumn get detail => text().withDefault(const Constant(''))();

  /// 伏笔状态：open / closed；角色与时间线条目固定存 open。
  TextColumn get status => text().withDefault(const Constant('open'))();
  IntColumn get chapterId => integer().nullable().references(
    Chapters,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();
}

@DriftDatabase(
  tables: [
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
    StoryStates,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// 仅测试使用：内存库。
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 15;

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
      // v7（ENH-06）：VOLUME 追加本卷前情回顾摘要列。
      if (from < 7) {
        await m.addColumn(volumes, volumes.summary);
      }
      // v8（ENH-07）：CHAPTER 追加摘要更新时间列；VOLUME 追加归并覆盖章节 id 列
      // （支撑摘要过期提示与卷回顾滚动增量归并）。
      if (from < 8) {
        await m.addColumn(chapters, chapters.summaryUpdatedAt);
        await m.addColumn(volumes, volumes.summaryChapterId);
      }
      // v9（ENH-08）：为热点外键列补索引（作品/卷维度列表查询的全表扫描）。
      if (from < 9) {
        await m.createIndex(volumesWorkId);
        await m.createIndex(chaptersVolumeId);
        await m.createIndex(chapterSnapshotsChapterId);
        await m.createIndex(charactersWorkId);
        await m.createIndex(outlineEntriesWorkId);
        await m.createIndex(inspirationsWorkId);
      }
      // v10（ENH-13）：设定集 / 角色关系表补 workId 索引（作品维度查询）。
      if (from < 10) {
        await m.createIndex(settingEntriesWorkId);
        await m.createIndex(characterRelationsWorkId);
      }
      // v11（ENH-22）：作品 / 章节追加回收站标记列（软删除）。
      if (from < 11) {
        await m.addColumn(works, works.deletedAt);
        await m.addColumn(chapters, chapters.deletedAt);
      }
      // v12（ENH-23）：作品追加文风档案；模型组追加费用估算单价。
      if (from < 12) {
        await m.addColumn(works, works.styleGuide);
        await m.addColumn(modelGroups, modelGroups.inputPricePerMillion);
        await m.addColumn(modelGroups, modelGroups.outputPricePerMillion);
      }
      // v13（ENH-30）：快照来源标记；AI 用量追加采纳编辑比例。
      if (from < 13) {
        await m.addColumn(chapterSnapshots, chapterSnapshots.note);
        await m.addColumn(aiUsages, aiUsages.adoptedEditPercent);
      }
      // v14（ENH-31）：追加 STORY_STATE 表（角色状态 / 伏笔 / 时间线）。
      if (from < 14) {
        await m.createTable(storyStates);
        await m.createIndex(storyStatesWorkId);
      }
      // v15（ENH-40）：角色卡追加别名 / 称谓列。
      if (from < 15) {
        await m.addColumn(characters, characters.aliases);
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
