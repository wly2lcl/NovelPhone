import 'package:drift/drift.dart';

import '../../models/work_cover_colors.dart';
import '../dao/volume_dao.dart';
import '../dao/work_dao.dart';
import '../db.dart';

/// 作品读写：领域操作的唯一入口（ARCHITECTURE 6.1）。
class WorkRepository {
  WorkRepository(this._db) : _works = WorkDao(_db), _volumes = VolumeDao(_db);

  final AppDatabase _db;
  final WorkDao _works;
  final VolumeDao _volumes;

  /// 新建作品时默认创建的卷名，保证新作品有卷可挂章节。
  static const String defaultVolumeName = '第一卷';

  /// 作品数量上限（PRD 5.1）。
  static const int maxWorks = 200;

  Stream<List<Work>> watchWorks() => _works.watchAll();

  Future<List<Work>> listWorks() => _works.findAll();

  Stream<Work?> watchWork(int id) => _works.watchById(id);

  Future<Work?> getWork(int id) => _works.findById(id);

  Future<int> countWorks() => _works.count();

  /// 新建作品：作品与默认卷在同一事务内创建。
  Future<int> createWork({required String title, int? coverColor}) {
    return _db.transaction(() async {
      final now = DateTime.now();
      final workId = await _works.insert(
        WorksCompanion.insert(
          title: title,
          coverColor: coverColor ?? WorkCoverColors.random(),
          lastEditedAt: now,
          createdAt: now,
        ),
      );
      await _volumes.insert(
        VolumesCompanion.insert(
          workId: workId,
          name: defaultVolumeName,
          sortOrder: 0,
        ),
      );
      return workId;
    });
  }

  Future<void> renameWork(int id, String title) {
    return _works.updateWork(id, WorksCompanion(title: Value(title)));
  }

  Future<void> setPinned(int id, bool pinned) {
    return _works.updateWork(id, WorksCompanion(pinned: Value(pinned)));
  }

  /// 删除作品：单事务删除其全部关联行（PRD 5.1，不可恢复）。
  Future<void> deleteWork(int id) {
    return _db.transaction(() async {
      final volumeIds = (await _volumes.findByWork(
        id,
      )).map((v) => v.id).toList();
      if (volumeIds.isNotEmpty) {
        await (_db.delete(
          _db.chapters,
        )..where((t) => t.volumeId.isIn(volumeIds))).go();
      }
      await (_db.delete(
        _db.outlineEntries,
      )..where((t) => t.workId.equals(id))).go();
      await (_db.delete(
        _db.characters,
      )..where((t) => t.workId.equals(id))).go();
      await (_db.delete(
        _db.inspirations,
      )..where((t) => t.workId.equals(id))).go();
      await (_db.delete(_db.volumes)..where((t) => t.workId.equals(id))).go();
      await _works.deleteById(id);
    });
  }

  /// 移入回收站（ENH-22）：只打删除标记，作品内容与章节原样保留。
  Future<void> moveWorkToTrash(int id) {
    return _works.markDeleted(id, DateTime.now());
  }

  /// 回收站作品（最近删除在前）。
  Stream<List<Work>> watchTrashedWorks() => _works.watchTrashed();

  Future<List<Work>> listTrashedWorks() => _works.findTrashed();

  Future<void> restoreWork(int id) => _works.restore(id);
}
