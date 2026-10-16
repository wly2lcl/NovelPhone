import 'package:drift/drift.dart';

import '../dao/character_dao.dart';
import '../dao/relation_dao.dart';
import '../db.dart';

/// 角色卡读写（UI 在 M2 落地，接口在 M1 就位）。
class CharacterRepository {
  CharacterRepository(AppDatabase db)
    : _dao = CharacterDao(db),
      _relations = RelationDao(db);

  final CharacterDao _dao;
  final RelationDao _relations;

  Stream<List<Character>> watchCharacters(int workId) =>
      _dao.watchByWork(workId);

  Future<List<Character>> listCharacters(int workId) => _dao.findByWork(workId);

  Future<Character?> getCharacter(int id) => _dao.findById(id);

  Future<int> createCharacter({
    required int workId,
    required String name,
    String identity = '',
    String personalityTags = '',
    String appearance = '',
    String relations = '',
    String arc = '',
  }) {
    return _dao.insert(
      CharactersCompanion.insert(
        workId: workId,
        name: name,
        identity: Value(identity),
        personalityTags: Value(personalityTags),
        appearance: Value(appearance),
        relations: Value(relations),
        arc: Value(arc),
      ),
    );
  }

  Future<void> updateCharacter({
    required int id,
    required String name,
    required String identity,
    required String personalityTags,
    required String appearance,
    required String relations,
    required String arc,
  }) {
    return _dao.updateCharacter(
      id,
      CharactersCompanion(
        name: Value(name),
        identity: Value(identity),
        personalityTags: Value(personalityTags),
        appearance: Value(appearance),
        relations: Value(relations),
        arc: Value(arc),
      ),
    );
  }

  Future<void> deleteCharacter(int id) => _dao.deleteById(id);

  // ---------- 角色关系（B-09 人物关系图）----------

  Stream<List<CharacterRelation>> watchRelations(int workId) =>
      _relations.watchByWork(workId);

  Future<List<CharacterRelation>> listRelations(int workId) =>
      _relations.findByWork(workId);

  /// 建立一条有向关系 from → to；两端角色删除时随外键级联删除。
  Future<int> createRelation({
    required int workId,
    required int fromCharacterId,
    required int toCharacterId,
    String label = '',
  }) {
    return _relations.insert(
      CharacterRelationsCompanion.insert(
        workId: workId,
        fromCharacterId: fromCharacterId,
        toCharacterId: toCharacterId,
        label: Value(label),
      ),
    );
  }

  Future<void> updateRelation({
    required int id,
    required int fromCharacterId,
    required int toCharacterId,
    required String label,
  }) {
    return _relations.updateRelation(
      id,
      CharacterRelationsCompanion(
        fromCharacterId: Value(fromCharacterId),
        toCharacterId: Value(toCharacterId),
        label: Value(label),
      ),
    );
  }

  Future<void> deleteRelation(int id) => _relations.deleteById(id);
}
