import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/data_providers.dart';
import '../../data/db.dart';

/// 作品详情页的数据流。
///
/// 全部使用 autoDispose（ENH-11）：这些流只在作品详情相关页面消费，
/// 离开页面后无人监听即释放 drift 流订阅，避免常驻内存与后台查询。
final workProvider = StreamProvider.autoDispose.family<Work?, int>(
  (ref, workId) => ref.watch(workRepositoryProvider).watchWork(workId),
);

final volumesProvider = StreamProvider.autoDispose.family<List<Volume>, int>(
  (ref, workId) => ref.watch(chapterRepositoryProvider).watchVolumes(workId),
);

/// 章节列表（ENH-10）：只带元数据、不含正文，供目录 / 大纲 / 检查范围使用；
/// 需要正文的场景（AI 上下文、导出、编辑器）直接用 repository.watchChapters。
final chaptersProvider = StreamProvider.autoDispose.family<List<Chapter>, int>(
  (ref, workId) =>
      ref.watch(chapterRepositoryProvider).watchChapterMetas(workId),
);

final charactersProvider = StreamProvider.autoDispose
    .family<List<Character>, int>(
      (ref, workId) =>
          ref.watch(characterRepositoryProvider).watchCharacters(workId),
    );

/// 设定集（B-09）：世界观 / 地点 / 道具条目。
final settingEntriesProvider = StreamProvider.autoDispose
    .family<List<SettingEntry>, int>(
      (ref, workId) =>
          ref.watch(settingRepositoryProvider).watchEntries(workId),
    );

/// 人物关系（B-09 关系图）：作品内的角色关系列表。
final characterRelationsProvider = StreamProvider.autoDispose
    .family<List<CharacterRelation>, int>(
      (ref, workId) =>
          ref.watch(characterRepositoryProvider).watchRelations(workId),
    );

/// 章节快照（B-05 版本历史，按创建时间倒序）。
final snapshotsProvider = StreamProvider.autoDispose
    .family<List<ChapterSnapshot>, int>(
      (ref, chapterId) =>
          ref.watch(chapterRepositoryProvider).watchSnapshots(chapterId),
    );

final outlineProvider = StreamProvider.autoDispose
    .family<List<OutlineEntry>, int>(
      (ref, workId) =>
          ref.watch(outlineRepositoryProvider).watchOutline(workId),
    );

final inspirationsProvider = StreamProvider.autoDispose
    .family<List<Inspiration>, int>(
      (ref, workId) =>
          ref.watch(inspirationRepositoryProvider).watchInspirations(workId),
    );
