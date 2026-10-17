import '../../models/work_chat_turn.dart';
import '../dao/app_setting_dao.dart';

/// 作品问答历史（ENH-23）：按作品存于 APP_SETTING，最多保留 [maxTurns] 条。
/// 底层是全局键值表，因此不随备份导出，也不会污染作品表结构。
class ChatRepository {
  ChatRepository(this._settings);

  final AppSettingDao _settings;

  static const int maxTurns = 40;

  static String keyFor(int workId) => 'work_chat_$workId';

  Future<List<WorkChatTurn>> load(int workId) async {
    return decodeChatTurns(await _settings.get(keyFor(workId)) ?? '');
  }

  Future<void> save(int workId, List<WorkChatTurn> turns) async {
    final trimmed = turns.length > maxTurns
        ? turns.sublist(turns.length - maxTurns)
        : turns;
    await _settings.set(keyFor(workId), encodeChatTurns(trimmed));
  }

  Future<void> clear(int workId) => _settings.remove(keyFor(workId));
}
