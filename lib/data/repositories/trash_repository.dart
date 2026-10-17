import '../dao/chapter_dao.dart';
import '../dao/work_dao.dart';
import '../db.dart';
import 'chapter_repository.dart';
import 'work_repository.dart';

/// 回收站中的章节条目（ENH-22）：附作品与卷标题，便于跨作品辨识。
class TrashedChapter {
  const TrashedChapter({
    required this.chapter,
    required this.workTitle,
    required this.volumeTitle,
  });

  final Chapter chapter;
  final String workTitle;
  final String volumeTitle;
}

/// 回收站（ENH-22）：作品 / 章节软删除后的列出、恢复与永久删除。
/// 数据完全在本机；保留期 30 天，过期项在应用启动或打开回收站时清理。
class TrashRepository {
  TrashRepository(AppDatabase db)
    : _works = WorkDao(db),
      _chapters = ChapterDao(db),
      _workRepository = WorkRepository(db),
      _chapterRepository = ChapterRepository(db);

  /// 删除后在回收站中的保留时长。
  static const Duration retention = Duration(days: 30);

  final WorkDao _works;
  final ChapterDao _chapters;
  final WorkRepository _workRepository;
  final ChapterRepository _chapterRepository;

  /// 回收站中的作品（最近删除在前），作品下的章节随作品一起展示、恢复。
  Stream<List<Work>> watchWorks() => _works.watchTrashed();

  Future<List<Work>> listWorks() => _works.findTrashed();

  /// 回收站中单独删除的章节（所属作品仍在回收站时随作品处理，不单列）。
  Future<List<TrashedChapter>> listChapters() async {
    final rows = await _chapters.findTrashed();
    return rows
        .map(
          (row) => TrashedChapter(
            chapter: row.chapter,
            workTitle: row.workTitle,
            volumeTitle: row.volumeTitle,
          ),
        )
        .toList(growable: false);
  }

  Future<void> restoreWork(int id) => _workRepository.restoreWork(id);

  Future<void> restoreChapter(int id) =>
      _chapterRepository.restoreChapterFromTrash(id);

  Future<void> purgeWork(int id) => _workRepository.deleteWork(id);

  Future<void> purgeChapter(int id) => _chapterRepository.purgeChapter(id);

  /// 清空回收站：作品连同其章节一并永久删除。
  Future<void> empty() async {
    for (final work in await _works.findTrashed()) {
      await _workRepository.deleteWork(work.id);
    }
    for (final row in await _chapters.findTrashed()) {
      await _chapterRepository.purgeChapter(row.chapter.id);
    }
  }

  /// 清理超过保留期的条目，返回清理数量。
  Future<int> purgeExpired({DateTime? now}) async {
    final cutoff = (now ?? DateTime.now()).subtract(retention);
    var removed = 0;
    for (final work in await _works.findTrashed()) {
      final deletedAt = work.deletedAt;
      if (deletedAt == null || !deletedAt.isBefore(cutoff)) continue;
      await _workRepository.deleteWork(work.id);
      removed++;
    }
    for (final row in await _chapters.findTrashed()) {
      final deletedAt = row.chapter.deletedAt;
      if (deletedAt == null || !deletedAt.isBefore(cutoff)) continue;
      await _chapterRepository.purgeChapter(row.chapter.id);
      removed++;
    }
    return removed;
  }
}
