import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/data/data_providers.dart';
import 'package:novelphone/data/db.dart';
import 'package:novelphone/data/repositories/chapter_repository.dart';
import 'package:novelphone/data/repositories/work_repository.dart';
import 'package:novelphone/features/work_detail/work_detail_providers.dart';

/// 计数用的仓储替身：只关心「流/查询被创建了几次」。
class _CountingWorkRepository extends WorkRepository {
  _CountingWorkRepository(super._db);

  int workStreams = 0;

  @override
  Stream<Work?> watchWork(int id) {
    workStreams++;
    return super.watchWork(id);
  }
}

class _CountingChapterRepository extends ChapterRepository {
  _CountingChapterRepository(super._db);

  final List<String> searched = <String>[];

  @override
  Future<List<ChapterSearchHit>> search(String keyword, {int limit = 100}) {
    searched.add(keyword);
    return super.search(keyword, limit: limit);
  }
}

/// Provider 生命周期（ENH-11）：搜索与作品详情的数据源都改为 autoDispose，
/// 无人监听后应释放；重新订阅时重新建流/重新查询。
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
  });

  tearDown(() async {
    await db.close();
  });

  test('搜索 provider 无人监听后释放（ENH-11）', () async {
    final repo = _CountingChapterRepository(db);
    final container = ProviderContainer(
      overrides: [chapterRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final sub = container.listen(
      searchProvider('街道'),
      (_, _) {},
      fireImmediately: true,
    );
    await container.read(searchProvider('街道').future);
    expect(repo.searched, <String>['街道']);

    final sub2 = container.listen(
      searchProvider('雾'),
      (_, _) {},
      fireImmediately: true,
    );
    await container.read(searchProvider('雾').future);
    expect(repo.searched, <String>['街道', '雾']);

    // 释放监听后 provider 被销毁；重新监听会重新发起查询。
    sub.close();
    sub2.close();
    await Future<void>.delayed(Duration.zero);
    expect(container.exists(searchProvider('街道')), isFalse);

    final sub3 = container.listen(
      searchProvider('街道'),
      (_, _) {},
      fireImmediately: true,
    );
    await container.read(searchProvider('街道').future);
    expect(repo.searched, <String>['街道', '雾', '街道']);
    sub3.close();
  });

  test('作品详情流无人监听后释放（ENH-11）', () async {
    final repo = _CountingWorkRepository(db);
    final container = ProviderContainer(
      overrides: [workRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final workId = await repo.createWork(title: '长夜行');

    final sub = container.listen(
      workProvider(workId),
      (_, _) {},
      fireImmediately: true,
    );
    await Future<void>.delayed(Duration.zero);
    expect(repo.workStreams, 1);

    sub.close();
    await Future<void>.delayed(Duration.zero);
    expect(container.exists(workProvider(workId)), isFalse);

    final sub2 = container.listen(
      workProvider(workId),
      (_, _) {},
      fireImmediately: true,
    );
    await Future<void>.delayed(Duration.zero);
    expect(repo.workStreams, 2);
    sub2.close();
    await Future<void>.delayed(Duration.zero);
  });
}
