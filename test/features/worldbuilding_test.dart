import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/app/theme.dart';
import 'package:novelphone/data/data_providers.dart';
import 'package:novelphone/data/db.dart';
import 'package:novelphone/data/repositories/backup_repository.dart';
import 'package:novelphone/data/repositories/character_repository.dart';
import 'package:novelphone/data/repositories/setting_repository.dart';
import 'package:novelphone/data/repositories/work_repository.dart';
import 'package:novelphone/data/secure_key_store.dart';
import 'package:novelphone/features/work_detail/relation_graph_page.dart';
import 'package:novelphone/features/work_detail/worldbuilding_tab.dart';
import 'package:novelphone/models/setting_type.dart';

/// B-09：设定集（世界观/地点/道具）与人物关系图。
void main() {
  group('设定集类型', () {
    test('fromValue 命中已知值，未知值回落到世界观', () {
      expect(SettingType.fromValue('location'), SettingType.location);
      expect(SettingType.fromValue('item'), SettingType.item);
      expect(SettingType.fromValue('unknown'), SettingType.worldview);
    });
  });

  group('设定集仓储', () {
    late AppDatabase db;
    late SettingRepository settings;
    late int workId;

    setUp(() async {
      db = AppDatabase.memory();
      settings = SettingRepository(db);
      workId = await WorkRepository(db).createWork(title: '长夜行');
    });

    tearDown(() async => db.close());

    test('创建按作品归类，可按类型筛选，支持更新与删除', () async {
      final locationId = await settings.createEntry(
        workId: workId,
        type: SettingType.location,
        name: '青云城',
        content: '主角故乡',
      );
      await settings.createEntry(
        workId: workId,
        type: SettingType.item,
        name: '断水剑',
      );

      var entries = await settings.listEntries(workId);
      expect(entries, hasLength(2));
      expect(
        entries.where((e) => e.type == SettingType.location.value),
        hasLength(1),
      );

      await settings.updateEntry(
        id: locationId,
        type: SettingType.location,
        name: '青云城',
        content: '主角故乡，后被焚毁',
      );
      entries = await settings.listEntries(workId);
      expect(entries.first.content, '主角故乡，后被焚毁');

      await settings.deleteEntry(locationId);
      entries = await settings.listEntries(workId);
      expect(entries, hasLength(1));
      expect(entries.single.type, SettingType.item.value);
    });
  });

  group('角色关系', () {
    late AppDatabase db;
    late CharacterRepository characters;
    late int workId;
    late int zhangId;
    late int liId;

    setUp(() async {
      db = AppDatabase.memory();
      characters = CharacterRepository(db);
      workId = await WorkRepository(db).createWork(title: '长夜行');
      zhangId = await characters.createCharacter(workId: workId, name: '张三');
      liId = await characters.createCharacter(workId: workId, name: '李四');
    });

    tearDown(() async => db.close());

    test('建立有向关系并可改标签与端点', () async {
      final id = await characters.createRelation(
        workId: workId,
        fromCharacterId: zhangId,
        toCharacterId: liId,
        label: '师徒',
      );
      var relations = await characters.listRelations(workId);
      expect(relations.single.label, '师徒');

      await characters.updateRelation(
        id: id,
        fromCharacterId: liId,
        toCharacterId: zhangId,
        label: '宿敌',
      );
      relations = await characters.listRelations(workId);
      expect(relations.single.fromCharacterId, liId);
      expect(relations.single.label, '宿敌');
    });

    test('删除角色时关系随外键级联删除', () async {
      await characters.createRelation(
        workId: workId,
        fromCharacterId: zhangId,
        toCharacterId: liId,
        label: '师徒',
      );
      expect(await characters.listRelations(workId), hasLength(1));

      await characters.deleteCharacter(zhangId);
      expect(await characters.listRelations(workId), isEmpty);
    });

    test('备份导出与恢复保留设定集与关系（跨库重映射外键）', () async {
      final settings = SettingRepository(db);
      await settings.createEntry(
        workId: workId,
        type: SettingType.worldview,
        name: '灵气复苏',
        content: '世界背景',
      );
      await characters.createRelation(
        workId: workId,
        fromCharacterId: zhangId,
        toCharacterId: liId,
        label: '师徒',
      );
      final data = await BackupRepository(db).exportData();
      final tables = data['tables'] as Map;
      expect(tables['settingEntries'], hasLength(1));
      expect(tables['characterRelations'], hasLength(1));

      // 恢复到全新库（合并模式）：作品/角色均新分配 id，关系须重映射到新角色。
      final target = AppDatabase.memory();
      await BackupRepository(target).restore(data, overwrite: false);

      final targetWorkId = (await WorkRepository(target).listWorks()).single.id;
      final restoredEntries =
          await SettingRepository(target).listEntries(targetWorkId);
      expect(restoredEntries.single.name, '灵气复苏');

      final targetCharacters = CharacterRepository(target);
      final restoredCharacters =
          await targetCharacters.listCharacters(targetWorkId);
      final idSet = restoredCharacters.map((c) => c.id).toSet();
      final restoredRelations =
          await targetCharacters.listRelations(targetWorkId);
      expect(restoredRelations.single.label, '师徒');
      expect(idSet.contains(restoredRelations.single.fromCharacterId), isTrue);
      expect(idSet.contains(restoredRelations.single.toCharacterId), isTrue);

      await target.close();
    });
  });

  testWidgets('设定集 Tab 展示条目并按类型切换筛选', (tester) async {
    final db = AppDatabase.memory();
    final settings = SettingRepository(db);
    final workId = await WorkRepository(db).createWork(title: '长夜行');
    await settings.createEntry(
      workId: workId,
      type: SettingType.location,
      name: '青云城',
    );
    await settings.createEntry(
      workId: workId,
      type: SettingType.item,
      name: '断水剑',
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secureKeyStoreProvider.overrideWithValue(InMemoryKeyStore()),
      ],
      child: MaterialApp(
        theme: buildPaperTheme(),
        home: WorldbuildingTab(workId: workId),
      ),
    ));
    for (var i = 0; i < 60; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
      if (find.text('青云城').evaluate().isNotEmpty) break;
    }

    // 默认筛选「世界观」→ 两条都看不到。
    expect(find.text('青云城'), findsNothing);
    expect(find.text('断水剑'), findsNothing);

    await tester.tap(find.text('地点'));
    await tester.pumpAndSettle();
    expect(find.text('青云城'), findsOneWidget);
    expect(find.text('断水剑'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    await db.close();
  });

  testWidgets('人物关系图页绘制关系并列出连线', (tester) async {
    final db = AppDatabase.memory();
    final characters = CharacterRepository(db);
    final workId = await WorkRepository(db).createWork(title: '长夜行');
    final zhangId = await characters.createCharacter(workId: workId, name: '张三');
    final liId = await characters.createCharacter(workId: workId, name: '李四');
    await characters.createRelation(
      workId: workId,
      fromCharacterId: zhangId,
      toCharacterId: liId,
      label: '师徒',
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secureKeyStoreProvider.overrideWithValue(InMemoryKeyStore()),
      ],
      child: MaterialApp(
        theme: buildPaperTheme(),
        home: RelationGraphPage(workId: workId),
      ),
    ));
    for (var i = 0; i < 60; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
      if (find.text('张三 → 李四').evaluate().isNotEmpty) break;
    }

    expect(find.text('人物关系图'), findsOneWidget);
    expect(find.text('张三 → 李四'), findsOneWidget);
    expect(find.text('师徒'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    await db.close();
  });
}