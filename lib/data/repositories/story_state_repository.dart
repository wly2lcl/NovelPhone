import 'package:drift/drift.dart';

import '../../models/story_state_kind.dart';
import '../dao/story_state_dao.dart';
import '../db.dart';

/// 故事状态卡读写（ENH-31）：角色当下状态、伏笔 open/closed、时间线事件。
class StoryStateRepository {
  StoryStateRepository(AppDatabase db) : _dao = StoryStateDao(db);

  final StoryStateDao _dao;

  Stream<List<StoryState>> watchEntries(int workId) => _dao.watchByWork(workId);

  Future<List<StoryState>> listEntries(int workId) => _dao.findByWork(workId);

  Future<int> createEntry({
    required int workId,
    required StoryStateKind kind,
    required String title,
    String detail = '',
    String status = 'open',
    int? chapterId,
    int sortOrder = 0,
  }) {
    return _dao.insert(
      StoryStatesCompanion.insert(
        workId: workId,
        kind: kind.value,
        title: title,
        detail: Value(detail),
        status: Value(status),
        chapterId: Value(chapterId),
        sortOrder: Value(sortOrder),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> updateEntry({
    required int id,
    required StoryStateKind kind,
    required String title,
    required String detail,
    String status = 'open',
    int? chapterId,
    int sortOrder = 0,
  }) {
    return _dao.updateEntry(
      id,
      StoryStatesCompanion(
        kind: Value(kind.value),
        title: Value(title),
        detail: Value(detail),
        status: Value(status),
        chapterId: Value(chapterId),
        sortOrder: Value(sortOrder),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> setStatus(int id, String status) {
    return _dao.updateEntry(
      id,
      StoryStatesCompanion(
        status: Value(status),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteEntry(int id) => _dao.deleteById(id);
}
