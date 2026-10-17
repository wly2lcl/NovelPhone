import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/data/dao/app_setting_dao.dart';
import 'package:novelphone/data/db.dart';
import 'package:novelphone/data/repositories/chat_repository.dart';
import 'package:novelphone/models/work_chat_turn.dart';

void main() {
  late AppDatabase db;
  late ChatRepository chats;

  setUp(() {
    db = AppDatabase.memory();
    chats = ChatRepository(AppSettingDao(db));
  });

  tearDown(() async {
    await db.close();
  });

  test('保存后按作品读取，往返不丢内容', () async {
    await chats.save(1, const <WorkChatTurn>[
      WorkChatTurn(role: 'user', content: '苏晚是谁？'),
      WorkChatTurn(role: 'assistant', content: '苏晚是医女，与沈砚是旧识。'),
    ]);
    await chats.save(2, const <WorkChatTurn>[
      WorkChatTurn(role: 'user', content: '另一部作品的问题'),
    ]);

    final first = await chats.load(1);
    expect(first, hasLength(2));
    expect(first.first.role, 'user');
    expect(first.last.content, contains('医女'));

    final second = await chats.load(2);
    expect(second, hasLength(1));
    expect(second.single.content, '另一部作品的问题');
  });

  test('超过 40 条时只保留最近 40 条', () async {
    final turns = <WorkChatTurn>[
      for (var i = 0; i < 45; i++)
        WorkChatTurn(role: i.isEven ? 'user' : 'assistant', content: '第 $i 条'),
    ];
    await chats.save(1, turns);

    final loaded = await chats.load(1);
    expect(loaded, hasLength(ChatRepository.maxTurns));
    expect(loaded.first.content, '第 5 条');
    expect(loaded.last.content, '第 44 条');
  });

  test('脏数据按空历史处理，非法条目被跳过', () async {
    await chats.save(1, const <WorkChatTurn>[]);
    expect(await chats.load(1), isEmpty);

    await db
        .into(db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: ChatRepository.keyFor(1),
            value:
                '[{"role":"user","content":"保留"},'
                '{"role":"system","content":"丢弃"},'
                '{"role":"assistant","content":"  "},'
                '"坏数据"]',
          ),
        );
    final loaded = await chats.load(1);
    expect(loaded, hasLength(1));
    expect(loaded.single.content, '保留');

    await db
        .into(db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: ChatRepository.keyFor(1),
            value: 'not json',
          ),
        );
    expect(await chats.load(1), isEmpty);
  });

  test('清空只影响当前作品', () async {
    await chats.save(1, const <WorkChatTurn>[
      WorkChatTurn(role: 'user', content: '问题一'),
    ]);
    await chats.save(2, const <WorkChatTurn>[
      WorkChatTurn(role: 'user', content: '问题二'),
    ]);

    await chats.clear(1);
    expect(await chats.load(1), isEmpty);
    expect(await chats.load(2), hasLength(1));
  });
}
