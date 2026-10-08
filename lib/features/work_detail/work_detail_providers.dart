import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/data_providers.dart';
import '../../data/db.dart';

/// 作品详情页的数据流。
final workProvider = StreamProvider.family<Work?, int>(
  (ref, workId) => ref.watch(workRepositoryProvider).watchWork(workId),
);

final volumesProvider = StreamProvider.family<List<Volume>, int>(
  (ref, workId) => ref.watch(chapterRepositoryProvider).watchVolumes(workId),
);

final chaptersProvider = StreamProvider.family<List<Chapter>, int>(
  (ref, workId) => ref.watch(chapterRepositoryProvider).watchChapters(workId),
);

final charactersProvider = StreamProvider.family<List<Character>, int>(
  (ref, workId) =>
      ref.watch(characterRepositoryProvider).watchCharacters(workId),
);

/// 设定集（B-09）：世界观 / 地点 / 道具条目。
final settingEntriesProvider = StreamProvider.family<List<SettingEntry>, int>(
  (ref, workId) => ref.watch(settingRepositoryProvider).watchEntries(workId),
);

/// 人物关系（B-09 关系图）：作品内的角色关系列表。
final characterRelationsProvider =
    StreamProvider.family<List<CharacterRelation>, int>(
  (ref, workId) => ref.watch(characterRepositoryProvider).watchRelations(workId),
);

/// 章节快照（B-05 版本历史，按创建时间倒序）。
final snapshotsProvider = StreamProvider.family<List<ChapterSnapshot>, int>(
  (ref, chapterId) =>
      ref.watch(chapterRepositoryProvider).watchSnapshots(chapterId),
);

final outlineProvider = StreamProvider.family<List<OutlineEntry>, int>(
  (ref, workId) => ref.watch(outlineRepositoryProvider).watchOutline(workId),
);

final inspirationsProvider = StreamProvider.family<List<Inspiration>, int>(
  (ref, workId) =>
      ref.watch(inspirationRepositoryProvider).watchInspirations(workId),
);