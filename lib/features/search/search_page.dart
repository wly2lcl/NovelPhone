import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/data_providers.dart';
import '../../data/repositories/chapter_repository.dart';
import '../../l10n/l10n.dart';
import 'highlighted_text.dart';

/// 全局搜索（B-06）：跨作品检索章节标题与正文，点击命中跳转编辑器并高亮。
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  /// 输入防抖（ENH-11）：正文 LIKE 是整表扫描，逐键检索会打断输入且浪费查询。
  static const Duration _debounceDelay = Duration(milliseconds: 300);

  final TextEditingController _keyword = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _keyword.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final next = value.trim();
    if (next == _query) return;
    _debounce = Timer(_debounceDelay, () {
      if (!mounted) return;
      setState(() => _query = next);
    });
  }

  void _clear() {
    _debounce?.cancel();
    _keyword.clear();
    setState(() => _query = '');
  }

  /// 跳转编辑器前对高亮范围做精确校正（ENH-16）：SQL 检索返回的是码点偏移，
  /// 含 emoji 的章节与 Dart UTF-16 偏移会偏差；校正只多读一章正文（即将打开的
  /// 编辑器本就要读同一章），关键词已不存在时沿用 SQL 偏移。
  Future<void> _openHit(ChapterSearchHit hit, String keyword) async {
    var start = hit.matchOffset;
    var end = start < 0 ? -1 : start + hit.matchLength;
    if (start >= 0) {
      final exact = await ref
          .read(chapterRepositoryProvider)
          .findMatchOffset(hit.chapterId, keyword);
      if (exact != null) {
        start = exact;
        end = exact + hit.matchLength;
      }
    }
    if (!mounted) return;
    final query = start < 0 ? '' : '?checkStart=$start&checkEnd=$end';
    context.push('/work/${hit.workId}/chapter/${hit.chapterId}$query');
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(searchProvider(_query));
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _keyword,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: context.l10n.searchHint,
            border: InputBorder.none,
          ),
          onChanged: _onChanged,
        ),
        actions: <Widget>[
          if (_query.isNotEmpty)
            IconButton(
              tooltip: context.l10n.commonClear,
              icon: const Icon(Icons.close),
              onPressed: _clear,
            ),
        ],
      ),
      body: _buildBody(resultsAsync),
    );
  }

  Widget _buildBody(AsyncValue<List<ChapterSearchHit>> resultsAsync) {
    if (_query.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            context.l10n.searchEmptyHint,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.paper.inkSoft),
          ),
        ),
      );
    }
    return resultsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          Center(child: Text(context.l10n.searchFailed('$error'))),
      data: (hits) {
        if (hits.isEmpty) {
          return Center(
            child: Text(
              context.l10n.searchNoResults(_query),
              style: TextStyle(color: context.paper.inkSoft),
            ),
          );
        }
        return ListView.separated(
          itemCount: hits.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final hit = hits[index];
            return _HitTile(
              hit: hit,
              keyword: _query,
              onOpen: () => _openHit(hit, _query),
            );
          },
        );
      },
    );
  }
}

class _HitTile extends StatelessWidget {
  const _HitTile({
    required this.hit,
    required this.keyword,
    required this.onOpen,
  });

  final ChapterSearchHit hit;
  final String keyword;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      isThreeLine: true,
      title: HighlightedText(
        text: hit.chapterTitle.isEmpty
            ? context.l10n.commonUntitledChapter
            : hit.chapterTitle,
        keyword: keyword,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              hit.workTitle,
              style: TextStyle(fontSize: 12, color: context.paper.accent),
            ),
            const SizedBox(height: 2),
            HighlightedText(
              text: hit.snippet,
              keyword: keyword,
              style: TextStyle(
                fontSize: 13,
                color: context.paper.inkSoft,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
      onTap: onOpen,
    );
  }
}
