import 'package:drift/drift.dart';

import '../../core/text_search.dart';
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

/// 全书替换的命中预览（ENH-19）：一个章节一条，含正文命中数与首处命中片段。
class WorkReplaceHit {
  const WorkReplaceHit({
    required this.chapterId,
    required this.chapterTitle,
    required this.count,
    required this.snippet,
  });

  final int chapterId;
  final String chapterTitle;

  /// 本章正文中的命中处数。
  final int count;

  /// 首处命中前留 12 字、后留 24 字的片段，两端按需补省略号。
  final String snippet;
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

  Stream<List<Chapter>> watchChapters(int workId) =>
      _chapters.watchByWork(workId);

  /// 作品全部章节（含正文），按目录顺序（ENH-23 批量分析 / 检索）。
  Future<List<Chapter>> listChapters(int workId) =>
      _chapters.findByWork(workId);

  /// 目录 / 大纲等 UI 只需章节元数据（ENH-10）：不读取正文，避免自动保存时重读全书。
  Stream<List<Chapter>> watchChapterMetas(int workId) =>
      _chapters.watchMetaByWork(workId);

  Stream<Chapter?> watchChapter(int chapterId) =>
      _chapters.watchById(chapterId);

  Future<Chapter?> getChapter(int chapterId) => _chapters.findById(chapterId);

  Future<Volume?> firstVolume(int workId) => _volumes.findFirst(workId);

  // ---------- 卷 ----------

  Future<int> createVolume(int workId, String name) {
    return _db.transaction(() async {
      final volumes = await _volumes.findByWork(workId);
      final nextOrder = volumes.isEmpty ? 0 : volumes.last.sortOrder + 1;
      return _volumes.insert(
        VolumesCompanion.insert(
          workId: workId,
          name: name,
          sortOrder: nextOrder,
        ),
      );
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
      await _volumes.updateVolume(
        volumeId,
        VolumesCompanion(sortOrder: Value(other.sortOrder)),
      );
      await _volumes.updateVolume(
        other.id,
        VolumesCompanion(sortOrder: Value(volume.sortOrder)),
      );
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
      final chapterId = await _chapters.insert(
        ChaptersCompanion.insert(
          volumeId: targetVolume.id,
          title: title,
          sortOrder: sortOrder,
          updatedAt: DateTime.now(),
        ),
      );
      await _syncWorkAggregate(workId);
      return chapterId;
    });
  }

  Future<void> renameChapter(int chapterId, String title) {
    return _chapters.updateChapter(
      chapterId,
      ChaptersCompanion(title: Value(title)),
    );
  }

  Future<void> setChapterStatus(int chapterId, ChapterStatus status) {
    return _chapters.updateChapter(
      chapterId,
      ChaptersCompanion(status: Value(status.value)),
    );
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
      // ENH-14：只取旧字数与所属作品（不读整章正文），供差量与增量汇总使用。
      final meta = await _chapters.findLightById(chapterId);
      if (meta == null) return;
      final now = DateTime.now();
      final words = countWords(content);
      await _chapters.updateChapter(
        chapterId,
        ChaptersCompanion(
          title: Value(title),
          content: Value(content),
          wordCount: Value(words),
          cursorOffset: cursorOffset == null
              ? const Value.absent()
              : Value(cursorOffset),
          scrollOffset: scrollOffset == null
              ? const Value.absent()
              : Value(scrollOffset),
          updatedAt: Value(now),
        ),
      );
      await _writingStats.addWords(writingDayKey(now), words - meta.wordCount);
      await _bumpWorkAggregate(
        meta.workId,
        delta: words - meta.wordCount,
        lastEditedAt: now,
      );
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

  /// 仅保存本章写作目标（ENH-51）：不触碰正文、字数、统计与作品汇总。
  Future<void> saveChapterIntent(int chapterId, String intent) {
    return _chapters.updateChapter(
      chapterId,
      ChaptersCompanion(intent: Value(intent)),
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

  /// 移入回收站（ENH-22）：只打删除标记，30 天内可恢复。
  /// 章纲引用与快照保持不变，恢复后原样可见；作品汇总排除该章。
  Future<void> moveChapterToTrash(int chapterId) {
    return _db.transaction(() async {
      final meta = await _chapters.findLightById(chapterId);
      if (meta == null) return;
      await _chapters.markDeleted(chapterId, DateTime.now());
      await _syncWorkAggregate(meta.workId);
    });
  }

  /// 从回收站恢复章节（ENH-22），并重算作品汇总。
  Future<void> restoreChapterFromTrash(int chapterId) {
    return _db.transaction(() async {
      final meta = await _chapters.findTrashedMeta(chapterId);
      if (meta == null) return;
      await _chapters.restore(chapterId);
      await _syncWorkAggregate(meta.workId);
    });
  }

  /// 从回收站彻底删除章节（ENH-22）：清理章纲引用后硬删除，
  /// 快照随外键级联删除，最后重算作品汇总。
  Future<void> purgeChapter(int chapterId) {
    return _db.transaction(() async {
      final meta = await _chapters.findTrashedMeta(chapterId);
      if (meta == null) return;
      await _outline.clearChapterRef(chapterId);
      await _chapters.deleteById(chapterId);
      await _syncWorkAggregate(meta.workId);
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
        chapterId,
        ChaptersCompanion(sortOrder: Value(other.sortOrder)),
      );
      await _chapters.updateChapter(
        other.id,
        ChaptersCompanion(sortOrder: Value(chapter.sortOrder)),
      );
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

  /// 快照来源标记（ENH-30）：AI 首次写入正文前自动创建。
  static const String noteAiBeforeAdopt = 'ai_before_adopt';

  /// 为当前标题与正文创建一份快照；超出上限时清理最旧的一条。
  Future<int> createSnapshot({
    required int chapterId,
    required String title,
    required String content,
    String note = '',
  }) {
    return _db.transaction(() async {
      final id = await _snapshots.insert(
        ChapterSnapshotsCompanion.insert(
          chapterId: chapterId,
          title: Value(title),
          content: Value(content),
          note: Value(note),
          wordCount: Value(countWords(content)),
          createdAt: DateTime.now(),
        ),
      );
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
  Future<List<ChapterSearchHit>> search(
    String keyword, {
    int limit = 100,
  }) async {
    final kw = keyword.trim();
    if (kw.isEmpty) return const <ChapterSearchHit>[];
    final pattern = '%${_escapeLike(kw)}%';
    final content = _db.chapters.content;
    // ENH-14：命中位置与摘要片段直接在 SQL 里算好，避免把命中章节的整篇正文读回 Dart。
    // INSTR 为 1-based（0 表示正文未命中）；lower() 让 ASCII 大小写口径与 LIKE 保持一致。
    final hitIndex = FunctionCallExpression<int>('INSTR', <Expression<Object>>[
      content.lower(),
      Variable<String>(kw.toLowerCase()),
    ]);
    final contentLength = content.length;
    // 与原 _snippet 等价：命中点前留 12 字、后留 24 字（超界由 substr 自然截断）。
    final startExpr = FunctionCallExpression<int>('MAX', <Expression<Object>>[
      const Constant<int>(1),
      hitIndex - Variable<int>(12),
    ]);
    final endExpr = FunctionCallExpression<int>('MIN', <Expression<Object>>[
      hitIndex + Variable<int>(kw.length + 23),
      contentLength,
    ]);
    final hitSnippet = content.substrExpr(
      startExpr,
      endExpr - startExpr + const Constant<int>(1),
    );
    // 正文未命中（仅标题命中）时回退到正文开头 40 字。
    final headSnippet = content.substr(1, 40);

    final query =
        _db.selectOnly(_db.chapters).join([
            innerJoin(
              _db.volumes,
              _db.volumes.id.equalsExp(_db.chapters.volumeId),
            ),
            innerJoin(_db.works, _db.works.id.equalsExp(_db.volumes.workId)),
          ])
          ..addColumns(<Expression<Object>>[
            _db.chapters.id,
            _db.chapters.title,
            _db.works.id,
            _db.works.title,
            hitIndex,
            contentLength,
            hitSnippet,
            headSnippet,
          ])
          ..where(
            (_db.chapters.title.like(pattern, escapeChar: '\\') |
                    content.like(pattern, escapeChar: '\\')) &
                _db.chapters.deletedAt.isNull() &
                _db.works.deletedAt.isNull(),
          )
          ..orderBy(<OrderingTerm>[OrderingTerm.desc(_db.chapters.updatedAt)])
          ..limit(limit);
    final rows = await query.get();
    return rows
        .map((row) {
          final hit = row.read(hitIndex) ?? 0;
          final length = row.read(contentLength) ?? 0;
          final offset = hit <= 0 ? -1 : hit - 1;
          return ChapterSearchHit(
            workId: row.read(_db.works.id)!,
            workTitle: row.read(_db.works.title)!,
            chapterId: row.read(_db.chapters.id)!,
            chapterTitle: row.read(_db.chapters.title)!,
            snippet: offset < 0
                ? _headSnippet(row.read(headSnippet) ?? '', length)
                : _windowSnippet(
                    row.read(hitSnippet) ?? '',
                    offset,
                    kw.length,
                    length,
                  ),
            matchOffset: offset,
            matchLength: offset < 0 ? 0 : kw.length,
          );
        })
        .toList(growable: false);
  }

  /// 命中位置的精确 UTF-16 偏移，供搜索页点击跳转前校正高亮范围（ENH-16）。
  /// [search] 的偏移来自 SQLite 的 INSTR/substr，按码点计数，而编辑器定位用 Dart 的
  /// UTF-16 偏移，命中点之前存在 emoji 等代理对时两者会相差前者的个数。这里只读该章
  /// 正文一次（点击后即将打开的编辑器本就要读同一章），用与 SQL 相同的 lower() 口径
  /// 重新定位；检索后正文已改动导致关键词不存在时返回 null，由调用方沿用 SQL 偏移。
  Future<int?> findMatchOffset(int chapterId, String keyword) async {
    final kw = keyword.trim();
    if (kw.isEmpty) return null;
    final chapter = await getChapter(chapterId);
    if (chapter == null) return null;
    final index = _asciiLower(chapter.content).indexOf(_asciiLower(kw));
    return index < 0 ? null : index;
  }

  /// SQLite 内置 lower() 只折叠 ASCII 字母，Dart 的 toLowerCase() 做完整 Unicode
  /// 折叠；为与 [search] 的 LIKE/INSTR 口径一致，这里手工只映射 A-Z。
  static String _asciiLower(String value) => String.fromCharCodes(
    value.codeUnits.map(
      (unit) => unit >= 0x41 && unit <= 0x5A ? unit + 0x20 : unit,
    ),
  );

  static String _escapeLike(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll('%', '\\%')
      .replaceAll('_', '\\_');

  /// 正文未命中时的片段：开头 40 字，超长补省略号。
  static String _headSnippet(String head, int contentLength) =>
      contentLength > 40 ? '$head…' : head;

  /// 命中点附近的片段：命中点前留 12 字、后留 24 字，两端按需补省略号。
  static String _windowSnippet(
    String window,
    int offset,
    int keywordLength,
    int contentLength,
  ) {
    final prefix = offset > 12 ? '…' : '';
    final suffix = offset + keywordLength + 24 < contentLength ? '…' : '';
    return '$prefix$window$suffix';
  }

  // ---------- 全书查找替换（ENH-19）----------

  /// 预览 [workId] 全部章节正文中 [keyword] 的命中（按目录顺序，每章一条）。
  /// 口径与编辑器查找替换一致（非重叠命中；默认忽略大小写）。
  Future<List<WorkReplaceHit>> findReplaceHits(
    int workId,
    String keyword, {
    bool caseSensitive = false,
  }) async {
    final kw = keyword.trim();
    if (kw.isEmpty) return const <WorkReplaceHit>[];
    final chapters = await _chapters.findByWork(workId);
    final hits = <WorkReplaceHit>[];
    for (final chapter in chapters) {
      final matches = findTextMatches(
        chapter.content,
        kw,
        caseSensitive: caseSensitive,
      );
      if (matches.isEmpty) continue;
      hits.add(
        WorkReplaceHit(
          chapterId: chapter.id,
          chapterTitle: chapter.title,
          count: matches.length,
          snippet: _matchWindow(chapter.content, matches.first),
        ),
      );
    }
    return List.unmodifiable(hits);
  }

  /// 全书替换（ENH-19）：每个受影响章节先留存快照（可在版本历史找回），
  /// 再替换正文并更新字数；写作统计按各章净增的正字数累计（与单章保存口径
  /// 一致），作品汇总在同一事务内重算。返回受影响章节数与替换处数。
  Future<({int chapters, int replaced})> replaceInWork(
    int workId, {
    required String keyword,
    required String replacement,
    bool caseSensitive = false,
  }) {
    final kw = keyword.trim();
    if (kw.isEmpty) {
      return Future<({int chapters, int replaced})>.value((
        chapters: 0,
        replaced: 0,
      ));
    }
    return _db.transaction(() async {
      final rows = await _chapters.findByWork(workId);
      final now = DateTime.now();
      var affected = 0;
      var replaced = 0;
      var statsDelta = 0;
      for (final chapter in rows) {
        final result = replaceTextMatches(
          chapter.content,
          kw,
          replacement,
          caseSensitive: caseSensitive,
        );
        if (result.count == 0) continue;
        await _snapshots.insert(
          ChapterSnapshotsCompanion.insert(
            chapterId: chapter.id,
            title: Value(chapter.title),
            content: Value(chapter.content),
            wordCount: Value(chapter.wordCount),
            createdAt: now,
          ),
        );
        await _snapshots.pruneBeyond(chapter.id, maxSnapshotsPerChapter);
        final words = countWords(result.text);
        await _chapters.updateChapter(
          chapter.id,
          ChaptersCompanion(
            content: Value(result.text),
            wordCount: Value(words),
            updatedAt: Value(now),
          ),
        );
        affected++;
        replaced += result.count;
        final delta = words - chapter.wordCount;
        if (delta > 0) statsDelta += delta;
      }
      if (replaced == 0) return (chapters: 0, replaced: 0);
      await _writingStats.addWords(writingDayKey(now), statsDelta);
      await _syncWorkAggregate(workId, lastEditedAt: now);
      return (chapters: affected, replaced: replaced);
    });
  }

  /// 首处命中附近的预览片段：命中点前留 12 字、后留 24 字，两端按需补省略号。
  static String _matchWindow(String content, TextMatch match) {
    final start = match.start > 12 ? match.start - 12 : 0;
    final end = match.end + 24 < content.length
        ? match.end + 24
        : content.length;
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
        final id = await _volumes.insert(
          VolumesCompanion.insert(
            workId: workId,
            name: trimmed.length > 30 ? trimmed.substring(0, 30) : trimmed,
            sortOrder: nextOrder,
          ),
        );
        volume = (await _volumes.findById(id))!;
      }

      var sortOrder = await _chapters.nextSortOrder(volume.id);
      final now = DateTime.now();
      for (final draft in drafts) {
        final content = draft.content;
        final title = draft.title.length > 50
            ? draft.title.substring(0, 50)
            : draft.title;
        await _chapters.insert(
          ChaptersCompanion.insert(
            volumeId: volume.id,
            title: title,
            content: Value(content),
            wordCount: Value(countWords(content)),
            sortOrder: sortOrder,
            updatedAt: now,
          ),
        );
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
    final createdId = await createVolume(
      workId,
      WorkRepository.defaultVolumeName,
    );
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

  /// 增量更新作品汇总（ENH-14）：保存正文只改字数、不改章节数，
  /// 无需每次自动保存都全量扫描作品全部章节。
  Future<void> _bumpWorkAggregate(
    int workId, {
    required int delta,
    DateTime? lastEditedAt,
  }) async {
    if (workId == 0) return;
    final work = await _works.findById(workId);
    if (work == null) return;
    await _works.updateWork(
      workId,
      WorksCompanion(
        wordCount: Value(work.wordCount + delta),
        lastEditedAt: lastEditedAt == null
            ? const Value.absent()
            : Value(lastEditedAt),
      ),
    );
  }
}
