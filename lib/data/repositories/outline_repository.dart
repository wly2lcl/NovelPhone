import 'package:drift/drift.dart';

import '../dao/outline_dao.dart';
import '../db.dart';

/// 章纲读写（UI 在 M2 落地，接口在 M1 就位）。
class OutlineRepository {
  OutlineRepository(AppDatabase db) : _dao = OutlineDao(db);

  final OutlineDao _dao;

  Stream<List<OutlineEntry>> watchOutline(int workId) =>
      _dao.watchByWork(workId);

  Future<List<OutlineEntry>> listOutline(int workId) => _dao.findByWork(workId);

  Future<OutlineEntry?> findByChapter(int chapterId) =>
      _dao.findByChapter(chapterId);

  Future<int> createEntry({
    required int workId,
    int? volumeId,
    int? chapterId,
    String summary = '',
  }) {
    return _dao.insert(
      OutlineEntriesCompanion.insert(
        workId: workId,
        volumeId: Value(volumeId),
        chapterId: Value(chapterId),
        summary: Value(summary),
      ),
    );
  }

  /// 按章节写入梗概：已有则更新，无则新建。
  Future<void> saveChapterSummary({
    required int workId,
    required int chapterId,
    int? volumeId,
    required String summary,
  }) async {
    final existing = await _dao.findByChapter(chapterId);
    if (existing == null) {
      await createEntry(
        workId: workId,
        volumeId: volumeId,
        chapterId: chapterId,
        summary: summary,
      );
      return;
    }
    await _dao.updateEntry(
      existing.id,
      OutlineEntriesCompanion(
        summary: Value(summary),
        volumeId: volumeId == null ? const Value.absent() : Value(volumeId),
      ),
    );
  }

  Future<void> updateSummary(int id, String summary) {
    return _dao.updateEntry(
      id,
      OutlineEntriesCompanion(summary: Value(summary)),
    );
  }

  Future<void> deleteEntry(int id) => _dao.deleteById(id);
}
