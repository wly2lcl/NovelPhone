import 'package:drift/drift.dart';

import '../db.dart';

/// 备份文件标识与格式版本（M2-10 / M2-11）。
const String kBackupFormat = 'novelphone-backup';
const int kBackupFormatVersion = 1;

/// 备份文件 / 恢复错误分类（供展示时本地化）。
enum BackupErrorKind {
  /// 不是有效的 zip。
  invalidZip,

  /// zip 内缺少 data.json。
  missingDataEntry,

  /// data.json 反序列化失败。
  decodeFailed,

  /// data.json 顶层不是对象。
  invalidFormat,

  /// 格式标识不是 NovelPhone 备份。
  wrongFormat,

  /// 备份来自更新版本的应用。
  newerVersion,

  /// manifest 声明存在但 SHA-256 与 data.json 不匹配（ENH-22）。
  checksumMismatch,

  /// 备份表数据不完整。
  incomplete,
}

/// 备份格式错误：继承 [FormatException] 以保持既有捕获语义
/// （`on FormatException` 与既有 `isA<FormatException>()` 测试不受影响）；
/// message 与原实现逐字一致，kind/detail 供展示时本地化。
class BackupException extends FormatException {
  const BackupException(this.kind, String message, {this.detail})
    : super(message);

  final BackupErrorKind kind;

  /// message 中插值的原始信息（如缺少的条目名）。
  final String? detail;
}

/// 恢复结果统计。
class BackupRestoreReport {
  const BackupRestoreReport({
    required this.works,
    required this.chapters,
    required this.characters,
  });

  final int works;
  final int chapters;
  final int characters;
}

/// 整库备份与恢复（M2-10 / M2-11）。
/// 备份内容为全部业务表数据；API key 只存 flutter_secure_storage，从不进库，
/// 因此不存在被打包的风险（见 ARCHITECTURE 4.1 MODEL_GROUP.apiKeyRef 说明）。
class BackupRepository {
  BackupRepository(this._db);

  final AppDatabase _db;

  /// 导出全部业务表数据为可 JSON 序列化的结构。
  Future<Map<String, dynamic>> exportData() async {
    final works = await _db.select(_db.works).get();
    final volumes = await _db.select(_db.volumes).get();
    final chapters = await _db.select(_db.chapters).get();
    final characters = await _db.select(_db.characters).get();
    final outline = await _db.select(_db.outlineEntries).get();
    final inspirations = await _db.select(_db.inspirations).get();
    final snapshots = await _db.select(_db.chapterSnapshots).get();
    final dailyStats = await _db.select(_db.dailyWritingStats).get();
    final settings = await _db.select(_db.settingEntries).get();
    final relations = await _db.select(_db.characterRelations).get();

    return <String, dynamic>{
      'format': kBackupFormat,
      'version': kBackupFormatVersion,
      'schemaVersion': _db.schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'tables': <String, dynamic>{
        'works': works.map((e) => e.toJson()).toList(),
        'volumes': volumes.map((e) => e.toJson()).toList(),
        'chapters': chapters.map((e) => e.toJson()).toList(),
        'characters': characters.map((e) => e.toJson()).toList(),
        'outlineEntries': outline.map((e) => e.toJson()).toList(),
        'inspirations': inspirations.map((e) => e.toJson()).toList(),
        'chapterSnapshots': snapshots.map((e) => e.toJson()).toList(),
        'dailyWritingStats': dailyStats.map((e) => e.toJson()).toList(),
        'settingEntries': settings.map((e) => e.toJson()).toList(),
        'characterRelations': relations.map((e) => e.toJson()).toList(),
      },
    };
  }

  /// 读取备份中的作品/章节/卷，用于生成可人工查阅的 markdown。
  Future<List<BackupWorkBundle>> loadWorkBundles() async {
    final works = await _db.select(_db.works).get();
    final volumes = await _db.select(_db.volumes).get();
    final chapters = await _db.select(_db.chapters).get();

    return works
        .map((work) {
          final workVolumes = volumes
              .where((v) => v.workId == work.id)
              .toList(growable: false);
          final volumeIds = workVolumes.map((v) => v.id).toSet();
          final workChapters =
              chapters.where((c) => volumeIds.contains(c.volumeId)).toList()
                ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          return BackupWorkBundle(
            title: work.title,
            volumes: workVolumes,
            chapters: workChapters,
          );
        })
        .toList(growable: false);
  }

  /// 恢复备份。[overwrite] 为 true 时先清空本地数据（覆盖），
  /// false 时把备份中的作品整体作为新作品导入（合并，不覆盖同名作品）。
  Future<BackupRestoreReport> restore(
    Map<String, dynamic> data, {
    required bool overwrite,
  }) {
    final format = data['format'];
    if (format != kBackupFormat) {
      throw const BackupException(
        BackupErrorKind.wrongFormat,
        '不是 NovelPhone 的备份文件',
      );
    }
    final schemaVersion = data['schemaVersion'];
    if (schemaVersion is! int || schemaVersion > _db.schemaVersion) {
      throw const BackupException(
        BackupErrorKind.newerVersion,
        '备份来自更新版本的应用，请先升级 app',
      );
    }
    final tables = data['tables'];
    if (tables is! Map) {
      throw const BackupException(BackupErrorKind.incomplete, '备份内容不完整');
    }

    return _db.transaction(() async {
      if (overwrite) {
        await _db.delete(_db.dailyWritingStats).go();
        await _db.delete(_db.chapterSnapshots).go();
        await _db.delete(_db.chapters).go();
        await _db.delete(_db.outlineEntries).go();
        await _db.delete(_db.inspirations).go();
        await _db.delete(_db.characterRelations).go();
        await _db.delete(_db.characters).go();
        await _db.delete(_db.settingEntries).go();
        await _db.delete(_db.volumes).go();
        await _db.delete(_db.works).go();
      }
      final workIdMap = <int, int>{};
      final volumeIdMap = <int, int>{};

      var workCount = 0;
      for (final raw in _asList(tables['works'])) {
        // ENH-23：v12 之前导出的备份不含 styleGuide 键，补默认空串。
        final json = Map<String, dynamic>.from(raw as Map);
        json.putIfAbsent('styleGuide', () => '');
        final work = Work.fromJson(json);
        final newId = await _db
            .into(_db.works)
            .insert(
              WorksCompanion.insert(
                title: work.title,
                coverColor: work.coverColor,
                lastEditedAt: work.lastEditedAt,
                createdAt: work.createdAt,
                id: overwrite ? Value(work.id) : const Value.absent(),
                wordCount: Value(work.wordCount),
                chapterCount: Value(work.chapterCount),
                pinned: Value(work.pinned),
                styleGuide: Value(work.styleGuide),
              ),
            );
        workIdMap[work.id] = newId;
        workCount++;
      }

      for (final raw in _asList(tables['volumes'])) {
        // ENH-06：v7 之前导出的备份不含 summary 键，drift 生成的 fromJson 对
        // 非空列要求键存在，这里补默认空串以保证旧备份仍可恢复。
        // ENH-07 O6：summaryChapterId 同样补默认 0（全量归并）。
        final json = Map<String, dynamic>.from(raw as Map);
        json.putIfAbsent('summary', () => '');
        json.putIfAbsent('summaryChapterId', () => 0);
        final volume = Volume.fromJson(json);
        final workId = workIdMap[volume.workId];
        if (workId == null) continue;
        final newId = await _db
            .into(_db.volumes)
            .insert(
              VolumesCompanion.insert(
                workId: workId,
                name: volume.name,
                sortOrder: volume.sortOrder,
                id: overwrite ? Value(volume.id) : const Value.absent(),
                summary: Value(volume.summary),
                summaryChapterId: Value(volume.summaryChapterId),
              ),
            );
        volumeIdMap[volume.id] = newId;
      }

      final chapterIdMap = <int, int>{};
      var chapterCount = 0;
      for (final raw in _asList(tables['chapters'])) {
        // ENH-05：v6 之前导出的备份不含 summary 键，drift 生成的 fromJson 对
        // 非空列要求键存在，这里补默认空串以保证旧备份仍可恢复。
        // ENH-07 O4：summaryUpdatedAt 为可空列，旧备份补 null。
        final json = Map<String, dynamic>.from(raw as Map);
        json.putIfAbsent('summary', () => '');
        json.putIfAbsent('summaryUpdatedAt', () => null);
        final chapter = Chapter.fromJson(json);
        final volumeId = volumeIdMap[chapter.volumeId];
        if (volumeId == null) continue;
        final newId = await _db
            .into(_db.chapters)
            .insert(
              ChaptersCompanion.insert(
                volumeId: volumeId,
                title: chapter.title,
                sortOrder: chapter.sortOrder,
                updatedAt: chapter.updatedAt,
                id: overwrite ? Value(chapter.id) : const Value.absent(),
                content: Value(chapter.content),
                wordCount: Value(chapter.wordCount),
                status: Value(chapter.status),
                cursorOffset: Value(chapter.cursorOffset),
                scrollOffset: Value(chapter.scrollOffset),
                summary: Value(chapter.summary),
                summaryUpdatedAt: Value(chapter.summaryUpdatedAt),
              ),
            );
        chapterIdMap[chapter.id] = newId;
        chapterCount++;
      }

      // ENH-15：以下叶表（快照/写作统计/设定集/角色关系/章纲/灵感）都不需要
      // 回传新 id（其外键在上一阶段已映射好），故先攒成 Companion 列表再用
      // insertAll 一次写入，替掉「逐行 await insert」的数千次往返。
      final snapshotRows = <ChapterSnapshotsCompanion>[];
      for (final raw in _asList(tables['chapterSnapshots'])) {
        final snapshot = ChapterSnapshot.fromJson(raw);
        final chapterId = chapterIdMap[snapshot.chapterId];
        if (chapterId == null) continue;
        snapshotRows.add(
          ChapterSnapshotsCompanion.insert(
            chapterId: chapterId,
            createdAt: snapshot.createdAt,
            id: overwrite ? Value(snapshot.id) : const Value.absent(),
            title: Value(snapshot.title),
            content: Value(snapshot.content),
            wordCount: Value(snapshot.wordCount),
          ),
        );
      }
      if (snapshotRows.isNotEmpty) {
        await _db.chapterSnapshots.insertAll(snapshotRows);
      }

      final statRows = <DailyWritingStatsCompanion>[];
      for (final raw in _asList(tables['dailyWritingStats'])) {
        final stat = DailyWritingStat.fromJson(raw);
        // 无外键，按日期主键合并；已有日期保留本机数据（合并模式下不覆盖）。
        statRows.add(
          DailyWritingStatsCompanion.insert(
            day: stat.day,
            words: Value(stat.words),
          ),
        );
      }
      if (statRows.isNotEmpty) {
        await _db.dailyWritingStats.insertAll(
          statRows,
          mode: InsertMode.insertOrIgnore,
        );
      }

      var characterCount = 0;
      final characterIdMap = <int, int>{};
      for (final raw in _asList(tables['characters'])) {
        final character = Character.fromJson(raw);
        final workId = workIdMap[character.workId];
        if (workId == null) continue;
        final newId = await _db
            .into(_db.characters)
            .insert(
              CharactersCompanion.insert(
                workId: workId,
                name: character.name,
                id: overwrite ? Value(character.id) : const Value.absent(),
                identity: Value(character.identity),
                personalityTags: Value(character.personalityTags),
                appearance: Value(character.appearance),
                relations: Value(character.relations),
                arc: Value(character.arc),
              ),
            );
        characterIdMap[character.id] = newId;
        characterCount++;
      }

      final settingRows = <SettingEntriesCompanion>[];
      for (final raw in _asList(tables['settingEntries'])) {
        final entry = SettingEntry.fromJson(raw);
        final workId = workIdMap[entry.workId];
        if (workId == null) continue;
        settingRows.add(
          SettingEntriesCompanion.insert(
            workId: workId,
            name: entry.name,
            createdAt: entry.createdAt,
            id: overwrite ? Value(entry.id) : const Value.absent(),
            type: Value(entry.type),
            content: Value(entry.content),
          ),
        );
      }
      if (settingRows.isNotEmpty) {
        await _db.settingEntries.insertAll(settingRows);
      }

      final relationRows = <CharacterRelationsCompanion>[];
      for (final raw in _asList(tables['characterRelations'])) {
        final relation = CharacterRelation.fromJson(raw);
        final workId = workIdMap[relation.workId];
        final fromId = characterIdMap[relation.fromCharacterId];
        final toId = characterIdMap[relation.toCharacterId];
        if (workId == null || fromId == null || toId == null) continue;
        relationRows.add(
          CharacterRelationsCompanion.insert(
            workId: workId,
            fromCharacterId: fromId,
            toCharacterId: toId,
            id: overwrite ? Value(relation.id) : const Value.absent(),
            label: Value(relation.label),
          ),
        );
      }
      if (relationRows.isNotEmpty) {
        await _db.characterRelations.insertAll(relationRows);
      }

      final outlineRows = <OutlineEntriesCompanion>[];
      for (final raw in _asList(tables['outlineEntries'])) {
        final entry = OutlineEntry.fromJson(raw);
        final chapterId = entry.chapterId == null
            ? null
            : chapterIdMap[entry.chapterId!];
        outlineRows.add(
          OutlineEntriesCompanion.insert(
            workId: workIdMap[entry.workId] ?? 0,
            summary: Value(entry.summary),
            id: overwrite ? Value(entry.id) : const Value.absent(),
            volumeId: Value(
              entry.volumeId == null ? null : volumeIdMap[entry.volumeId!],
            ),
            chapterId: Value(chapterId),
          ),
        );
      }
      if (outlineRows.isNotEmpty) {
        await _db.outlineEntries.insertAll(outlineRows);
      }

      final inspirationRows = <InspirationsCompanion>[];
      for (final raw in _asList(tables['inspirations'])) {
        final inspiration = Inspiration.fromJson(raw);
        final workId = workIdMap[inspiration.workId];
        if (workId == null) continue;
        inspirationRows.add(
          InspirationsCompanion.insert(
            workId: workId,
            content: inspiration.content,
            createdAt: inspiration.createdAt,
            id: overwrite ? Value(inspiration.id) : const Value.absent(),
          ),
        );
      }
      if (inspirationRows.isNotEmpty) {
        await _db.inspirations.insertAll(inspirationRows);
      }

      return BackupRestoreReport(
        works: workCount,
        chapters: chapterCount,
        characters: characterCount,
      );
    });
  }

  static List<Map<String, dynamic>> _asList(Object? value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList(growable: false);
  }
}

/// 备份中的单个作品数据包（用于生成 markdown 全文）。
class BackupWorkBundle {
  const BackupWorkBundle({
    required this.title,
    required this.volumes,
    required this.chapters,
  });

  final String title;
  final List<Volume> volumes;
  final List<Chapter> chapters;
}
