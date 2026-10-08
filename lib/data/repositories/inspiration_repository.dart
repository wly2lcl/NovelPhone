import '../dao/inspiration_dao.dart';
import '../db.dart';

/// 灵感箱读写（M3 接入 AI 灵感产出，本阶段先支持手工记录）。
class InspirationRepository {
  InspirationRepository(AppDatabase db) : _dao = InspirationDao(db);

  final InspirationDao _dao;

  Stream<List<Inspiration>> watchInspirations(int workId) =>
      _dao.watchByWork(workId);

  Future<List<Inspiration>> listInspirations(int workId) =>
      _dao.findByWork(workId);

  Future<int> createInspiration(int workId, String content) {
    return _dao.insert(InspirationsCompanion.insert(
      workId: workId,
      content: content,
      createdAt: DateTime.now(),
    ));
  }

  Future<void> updateInspiration(int id, String content) =>
      _dao.updateContent(id, content);

  Future<void> deleteInspiration(int id) => _dao.deleteById(id);
}