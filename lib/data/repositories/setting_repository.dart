import 'package:drift/drift.dart';

import '../../models/setting_type.dart';
import '../dao/setting_dao.dart';
import '../db.dart';

/// 设定集读写（B-09）：世界观 / 地点 / 道具统一按 type 归类。
class SettingRepository {
  SettingRepository(AppDatabase db) : _dao = SettingDao(db);

  final SettingDao _dao;

  Stream<List<SettingEntry>> watchEntries(int workId) =>
      _dao.watchByWork(workId);

  Future<List<SettingEntry>> listEntries(int workId) => _dao.findByWork(workId);

  Future<int> createEntry({
    required int workId,
    required SettingType type,
    required String name,
    String content = '',
  }) {
    return _dao.insert(SettingEntriesCompanion.insert(
      workId: workId,
      type: Value(type.value),
      name: name,
      content: Value(content),
      createdAt: DateTime.now(),
    ));
  }

  Future<void> updateEntry({
    required int id,
    required SettingType type,
    required String name,
    required String content,
  }) {
    return _dao.updateEntry(
      id,
      SettingEntriesCompanion(
        type: Value(type.value),
        name: Value(name),
        content: Value(content),
      ),
    );
  }

  Future<void> deleteEntry(int id) => _dao.deleteById(id);
}