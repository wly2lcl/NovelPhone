import 'package:drift/drift.dart';

import '../../core/word_count.dart';
import '../../core/writing_stats.dart';
import '../../models/chapter_status.dart';
import '../dao/chapter_dao.dart';
import '../dao/outline_dao.dart';
import '../dao/snapshot_dao.dart';
import '../dao/volume_dao.dart';
import '../dao/work_dao.dart';
import '../dao/writing_stats_dao.dart';
import '../db.dart';
import 'work_repository.dart';

/// 导入写入的章节草稿：由 core/importer 的分章结果转换而来。
class ChapterImportDraft {
  const ChapterImportDraft({required this.title, required this.content});

  final String title;
  final String content;
}

/// 全局搜索结果（B-06）：一条命中对应一个章节。
class ChapterSearchHit {
  const ChapterSearchHit({
    required this.workId,
    required this.workTitle,
    required this.chapterId,
    required this.chapterTitle,
    required this.snippet,
    required this.matchOffset,
    required this.matchLength,
  });

  final int workId;
  final String workTitle;
  final int chapterId;
  final String chapterTitle;

  /// 正文命中片段（未命中正文时为正文开头摘要）。
  final String snippet;

  /// 正文中首个命中的起点；-1 表示仅标题命中。
  final int matchOffset;
  final int matchLength;
}

/// 卷与章节读写。保存章节时在同一事务内更新作品冗余汇总字段
/// （ARCHITECTURE 4.3：杜绝"正文新、字数旧"）。
class ChapterRepository {
  ChapterRepository(this._db)
      : _chapters = ChapterDao(_db),
        _volumes = VolumeDao(_db),
        _works = WorkDao(_db),
        _outline = OutlineDao(_db),
        _snapshots = SnapshotDao(_db),
        _writingStats = WritingStatsDao(_db);

  /// 单章最多保留的快照数（B-05），超出后清理最旧的。
  static const int maxSnapshotsPerChapter = 50;

  final AppDatabase _db;
  final ChapterDao _chapters;
  final VolumeDao _volumes;
  final WorkDao _works;
  final OutlineDao _outline;
  final SnapshotDao _snapshots;
  final WritingStatsDao _writingStats;

  // ---------- 读取 ----------

  Stream<List<Volume>> watchVolumes(int workId) => _volumes.watchByWork(workId);

  Future<List<Volume>> listVolumes(int workId) => _volumes.findByWork(workId);

  Stream<List<Chapter>> watchChapters(int workId) => _chapters.watchByWork(workId);

  /// 目录 / 大纲等 UI 只需章节元数据（ENH-10）：不读取正文，避免自动保存时重读全书。
  Stream<List<Chapter>> watchChapterMetas(int workId) =>
      _chapters.watchMetaByWork(workId);

  Stream<Chapter?> watchChapter(int chapterId) => _chapters.watchById(chapterId);

  Future<Chapter?> getChapter(int chapterId) => _chapters.findById(chapterId);

  Future<Volume?> firstVolume(int workId) => _volumes.findFirst(workId);

  // ---------- 卷 ----------

  Future<int> createVolume(int workId, String name) {
    return _db.transaction(() async {
      final volumes = await _volumes.findByWork(workId);
      final nextOrder =
          volumes.isEmpty ? 0 : volumes.last.sortOrder + 1;
      return _volumes.insert(VolumesCompanion.insert(
        workId: workId,
        name: name,
        sortOrder: nextOrder,
      ));
    });
  }

  Future<void> renameVolume(int volumeId, String name) {
    return _volumes.updateVolume(volumeId, VolumesCompanion(name: Value(name)));
  }

  /// 仅保存 AI 生成的本卷前情回顾（ENH-06）：不触碰章节 / 字数 / 作品汇总。
  /// [coveredChapterId] 非空时同步记录本次归并覆盖到的章节（ENH-07 O6 增量归并）。
  Future<void> saveVolumeSummary(
    int volumeId,
    String summary, {
    int? coveredChapterId,
  }) {
    return _volumes.updateVolume(
      volumeId,
      VolumesCompanion(
        summary: Value(summary),
        summaryChapterId: coveredChapterId == null
            ? const Value.absent()
            : Value(coveredChapterId),
      ),
    );
  }

  /// 卷上移/下移（PRD 5.2：手机端不用拖拽交互）。
  Future<void> moveVolume(int volumeId, {required bool up}) {
    return _db.transaction(() async {
      final volume = await _volumes.findById(volumeId);
      if (volume == null) return;
      final list = await _volumes.findByWork(volume.workId);
      final index = list.indexWhere((v) => v.id == volumeId);
      final target = up ? index - 1 : index + 1;
      if (index < 0 || target < 0 || target >= list.length) return;
      final other = list[target];
      await _volumes.updateVolume(volumeId,
          VolumesCompanion(sortOrder: Value(other.sortOrder)));
      await _volumes.updateVolume(other.id,
          VolumesCompanion(sortOrder: Value(volume.sortOrder)));
    });
  }

  /// 删除卷：连同卷内章节一并删除，章纲引用置空，最后重算作品汇总。
  Future<void> deleteVolume(int volumeId) {
    return _db.transaction(() async {
      final volume = await _volumes.findById(volumeId);
      if (volume == null) return;
      final chapters = await _chapters.findMetaByVolume(volumeId);
      for (final chapter in chapters) {
        await _outline.clearChapterRef(chapter.id);
      }
      await _outline.clearVolumeRef(volumeId);
      await _chapters.deleteByVolume(volumeId);
      await _volumes.deleteById(volumeId);
      await _syncWorkAggregate(volume.workId);
    });
  }

  // ---------- 章节 ----------

  /// 新建章节。未指定卷时挂到作品的第一个卷，无卷则自动创建默认卷。
  Future<int> createChapter({
    required int workId,
    int? volumeId,
    String title = '',
  }) {
    return _db.transaction(() async {
      final targetVolume = await _resolveVolume(workId, volumeId);
      final sortOrder = await _chapters.nextSortOrder(targetVolume.id);
      final chapterId = await _chapters.insert(ChaptersCompanion.insert(
        volumeId: targetVolume.id,
        title: title,
        sortOrder: sortOrder,
        updatedAt: DateTime.now(),
      ));
      await _syncWorkAggregate(workId);
      return chapterId;
    });
  }

  Future<void> renameChapter(int chapterId, String title) {
    return _chapters.updateChapter(
        chapterId, ChaptersCompanion(title: Value(title)));
  }

  Future<void> setChapterStatus(int chapterId, ChapterStatus status) {
    return _chapters.updateChapter(
        chapterId, ChaptersCompanion(status: Value(status.value)));
  }

  /// 自动保存正文：字数、光标与滚动位置、作品汇总在同一事务内落库。
  /// B-07：正文净增的正字数同时计入当天写作统计（只加不减，供每日目标与连击）。
  Future<void> saveChapter({
    required int chapterId,
    required String title,
    required String content,
    int? cursorOffset,
    int? scrollOffset,
  }) {
    return _db.transaction(() async {
      final chapter = await _chapters.findById(chapterId);
      if (chapter == null) return;
      final now = DateTime.now();
      final words = countWords(content);
      await _chapters.updateChapter(
        chapterId,
        ChaptersCompanion(
          title: Value(title),
          content: Value(content),
          wordCount: Value(words),
          cursorOffset:
              cursorOffset == null ? const Value.absent() : Value(cursorOffset),
          scrollOffset:
              scrollOffset == null ? const Value.absent() : Value(scrollOffset),
          updatedAt: Value(now),
        ),
      );
      await _writingStats.addWords(writingDayKey(now), words - chapter.wordCount);
      await _syncWorkAggregate(await _workIdOfChapter(chapterId),
          lastEditedAt: now);
    });
  }

  /// 仅保存 AI 生成的本章摘要（ENH-05）：不触碰正文 / 字数 / 汇总，
  /// 因此不会误触整洁写作统计与作品字数。同时记录摘要更新时间（ENH-07 O4）。
  Future<void> saveChapterSummary(int chapterId, String summary) {
    return _chapters.updateChapter(
      chapterId,
      ChaptersCompanion(
        summary: Value(summary),
        summaryUpdatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 仅保存会话恢复位置（光标 / 滚动），不触碰正文与字数。
  Future<void> saveCursorPosition({
    required int chapterId,
    required int cursorOffset,
    required int scrollOffset,
  }) {
    return _chapters.updateChapter(
      chapterId,
      ChaptersCompanion(
        cursorOffset: Value(cursorOffset),
        scrollOffset: Value(scrollOffset),
      ),
    );
  }

  /// 删除章节：章纲引用置空后删除，并重算作品汇总。
  Future<void> deleteChapter(int chapterId) {
    return _db.transaction(() async {
      final chapter = await _chapters.findById(chapterId);
      if (chapter == null) return;
      final workId = await _workIdOfChapter(chapterId);
      await _outline.clearChapterRef(chapterId);
      await _chapters.deleteById(chapterId);
      await _syncWorkAggregate(workId);
    });
  }

  /// 章节在其所属卷内上移/下移。
  Future<void> moveChapter(int chapterId, {required bool up}) {
    return _db.transaction(() async {
      final chapter = await _chapters.findById(chapterId);
      if (chapter == null) return;
      final list = await _chapters.findMetaByVolume(chapter.volumeId);
      final index = list.indexWhere((c) => c.id == chapterId);
      final target = up ? index - 1 : index + 1;
      if (index < 0 || target < 0 || target >= list.length) return;
      final other = list[target];
      await _chapters.updateChapter(
          chapterId, ChaptersCompanion(sortOrder: Value(other.sortOrder)));
      await _chapters.updateChapter(
          other.id, ChaptersCompanion(sortOrder: Value(chapter.sortOrder)));
    });
  }

  /// 移动到其他卷，落在目标卷末尾。
  Future<void> moveChapterToVolume(int chapterId, int targetVolumeId) {
    return _db.transaction(() async {
      final chapter = await _chapters.findById(chapterId);
      if (chapter == null || chapter.volumeId == targetVolumeId) return;
      final sortOrder = await _chapters.nextSortOrder(targetVolumeId);
      await _chapters.updateChapter(
        chapterId,
        ChaptersCompanion(
          volumeId: Value(targetVolumeId),
          sortOrder: Value(sortOrder),
        ),
      );
    });
  }

  // ---------- 章节快照 / 版本历史（B-05）----------

  Stream<List<ChapterSnapshot>> watchSnapshots(int chapterId) =>
      _snapshots.watchMetaByChapter(chapterId);

  /// 按 id 取单个快照（ENH-10）：列表只带元数据，预览 / 恢复正文时按需单取。
  Future<ChapterSnapshot?> getSnapshot(int snapshotId) =>
      _snapshots.findById(snapshotId);

  Future<List<ChapterSnapshot>> listSnapshots(int chapterId) =>
      _snapshots.findByChapter(chapterId);

  /// 为当前标题与正文创建一份快照；超出上限时清理最旧的一条。
  Future<int> createSnapshot({
    required int chapterId,
    required String title,
    required String content,
  }) {
    return _db.transaction(() async {
      final id = await _snapshots.insert(ChapterSnapshotsCompanion.insert(
        chapterId: chapterId,
        title: Value(title),
        content: Value(content),
        wordCount: Value(countWords(content)),
        createdAt: DateTime.now(),
      ));
      await _snapshots.pruneBeyond(chapterId, maxSnapshotsPerChapter);
      return id;
    });
  }

  Future<void> deleteSnapshot(int snapshotId) =>
      _snapshots.deleteById(snapshotId);

  // ---------- 每日写作统计（B-07）----------

  /// 每日写作字数记录（按日期倒序），供今日字数与连击统计。
  Stream<List<DailyWritingStat>> watchDailyWritingStats() =>
      _writingStats.watchAll();

  Future<List<DailyWritingStat>> listDailyWritingStats() =>
      _writingStats.listAll();

  // ---------- 全局搜索（B-06）----------

  /// 在全部作品的章节标题与正文中检索关键词，按章节更新时间倒序返回。
  Future<List<ChapterSearchHit>> search(String keyword, {int limit = 100}) async {
    final kw = keyword.trim();
    if (kw.isEmpty) return const <ChapterSearchHit>[];
    final pattern = '%${_escapeLike(kw)}%';
    final query = _db.select(_db.chapters).join([
      innerJoin(_db.volumes, _db.volumes.id.equalsExp(_db.chapters.volumeId)),
      innerJoin(_db.works, _db.works.id.equalsExp(_db.volumes.workId)),
    ])
      ..where(_db.chapters.title.like(pattern, escapeChar: '\\') |
          _db.chapters.content.like(pattern, escapeChar: '\\'))
      ..orderBy([OrderingTerm.desc(_db.chapters.updatedAt)])
      ..limit(limit);
    final rows = await query.get();
    return rows.map((row) {
      final chapter = row.readTable(_db.chapters);
      final work = row.readTable(_db.works);
      final offset = _lowerIndexOf(chapter.content, kw);
      return ChapterSearchHit(
        workId: work.id,
        workTitle: work.title,
        chapterId: chapter.id,
        chapterTitle: chapter.title,
        snippet: _snippet(chapter.content, kw, offset),
        matchOffset: offset,
        matchLength: offset < 0 ? 0 : kw.length,
      );
    }).toList(growable: false);
  }

  static String _escapeLike(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll('%', '\\%')
      .replaceAll('_', '\\_');

  /// SQLite 的 LIKE 对 ASCII 不区分大小写，这里同步用忽略大小写定位命中。
  static int _lowerIndexOf(String content, String keyword) =>
      content.toLowerCase().indexOf(keyword.toLowerCase());

  static String _snippet(String content, String keyword, int offset) {
    if (content.isEmpty) return '';
    if (offset < 0) {
      return content.length > 40 ? '${content.substring(0, 40)}…' : content;
    }
    final start = (offset - 12).clamp(0, content.length);
    final end = (offset + keyword.length + 24).clamp(0, content.length);
    final prefix = start > 0 ? '…' : '';
    final suffix = end < content.length ? '…' : '';
    return '$prefix${content.substring(start, end)}$suffix';
  }

  // ---------- 导入 ----------

  /// 批量导入章节（M2-07）：同一事务内建卷并按顺序写章节，最后重算作品汇总。
  /// [volumeName] 为空时落到作品的第一个卷（无卷则自动创建默认卷）。
  Future<int> importChapters({
    required int workId,
    String? volumeName,
    required List<ChapterImportDraft> drafts,
  }) {
    if (drafts.isEmpty) return Future<int>.value(0);
    return _db.transaction(() async {
      final Volume volume;
      final trimmed = volumeName?.trim() ?? '';
      if (trimmed.isEmpty) {
        volume = await _resolveVolume(workId, null);
      } else {
        final volumes = await _volumes.findByWork(workId);
        final nextOrder = volumes.isEmpty ? 0 : volumes.last.sortOrder + 1;
        final id = await _volumes.insert(VolumesCompanion.insert(
          workId: workId,
          name: trimmed.length > 30 ? trimmed.substring(0, 30) : trimmed,
          sortOrder: nextOrder,
        ));
        volume = (await _volumes.findById(id))!;
      }

      var sortOrder = await _chapters.nextSortOrder(volume.id);
      final now = DateTime.now();
      for (final draft in drafts) {
        final content = draft.content;
        final title = draft.title.length > 50
            ? draft.title.substring(0, 50)
            : draft.title;
        await _chapters.insert(ChaptersCompanion.insert(
          volumeId: volume.id,
          title: title,
          content: Value(content),
          wordCount: Value(countWords(content)),
          sortOrder: sortOrder,
          updatedAt: now,
        ));
        sortOrder++;
      }
      await _syncWorkAggregate(workId, lastEditedAt: now);
      return drafts.length;
    });
  }

  // ---------- 内部 ----------

  /// 定位章节所属卷：优先指定卷，其次作品第一个卷，都没有则创建默认卷。
  Future<Volume> _resolveVolume(int workId, int? volumeId) async {
    if (volumeId != null) {
      final volume = await _volumes.findById(volumeId);
      if (volume != null) return volume;
    }
    final existing = await _volumes.findFirst(workId);
    if (existing != null) return existing;
    final createdId =
        await createVolume(workId, WorkRepository.defaultVolumeName);
    return (await _volumes.findById(createdId))!;
  }

  Future<int> _workIdOfChapter(int chapterId) async {
    final chapter = await _chapters.findById(chapterId);
    if (chapter == null) return 0;
    final volume = await _volumes.findById(chapter.volumeId);
    return volume?.workId ?? 0;
  }

  /// 重算作品的字数与章节数冗余字段。
  Future<void> _syncWorkAggregate(int workId, {DateTime? lastEditedAt}) async {
    if (workId == 0) return;
    final aggregate = await _chapters.aggregateByWork(workId);
    await _works.updateWork(
      workId,
      WorksCompanion(
        wordCount: Value(aggregate.words),
        chapterCount: Value(aggregate.chapters),
        lastEditedAt: lastEditedAt == null
            ? const Value.absent()
            : Value(lastEditedAt),
      ),
    );
  }
}