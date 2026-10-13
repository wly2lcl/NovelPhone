import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/data_providers.dart';
import '../../data/repositories/chapter_repository.dart';

/// 全局搜索（B-06）：跨作品检索章节标题与正文，点击命中跳转编辑器并高亮。
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _keyword = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _keyword.dispose();
    super.dispose();
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
          decoration: const InputDecoration(
            hintText: '搜索全部作品…',
            border: InputBorder.none,
          ),
          onChanged: (value) => setState(() => _query = value.trim()),
        ),
        actions: <Widget>[
          if (_query.isNotEmpty)
            IconButton(
              tooltip: '清空',
              icon: const Icon(Icons.close),
              onPressed: () {
                _keyword.clear();
                setState(() => _query = '');
              },
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
            '输入关键词，搜索全部作品的章节标题与正文。',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.paper.inkSoft),
          ),
        ),
      );
    }
    return resultsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('搜索失败：$error')),
      data: (hits) {
        if (hits.isEmpty) {
          return Center(
            child: Text('没有找到包含「$_query」的章节',
                style: TextStyle(color: context.paper.inkSoft)),
          );
        }
        return ListView.separated(
          itemCount: hits.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) =>
              _HitTile(hit: hits[index], keyword: _query),
        );
      },
    );
  }
}

class _HitTile extends StatelessWidget {
  const _HitTile({required this.hit, required this.keyword});

  final ChapterSearchHit hit;
  final String keyword;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      isThreeLine: true,
      title: _highlight(
        context,
        hit.chapterTitle.isEmpty ? '未命名章节' : hit.chapterTitle,
        Theme.of(context).textTheme.titleSmall,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(hit.workTitle,
                style: TextStyle(fontSize: 12, color: context.paper.accent)),
            const SizedBox(height: 2),
            _highlight(
              context,
              hit.snippet,
              TextStyle(
                  fontSize: 13, color: context.paper.inkSoft, height: 1.4),
            ),
          ],
        ),
      ),
      onTap: () {
        final offset = hit.matchOffset;
        final query = offset < 0
            ? ''
            : '?checkStart=$offset&checkEnd=${offset + hit.matchLength}';
        context.push('/work/${hit.workId}/chapter/${hit.chapterId}$query');
      },
    );
  }

  /// 命中关键词高亮（忽略大小写，与检索口径一致）。
  Widget _highlight(BuildContext context, String text, TextStyle? base) {
    if (keyword.isEmpty || text.isEmpty) return Text(text, style: base);
    final lowerText = text.toLowerCase();
    final lowerKeyword = keyword.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;
    while (true) {
      final index = lowerText.indexOf(lowerKeyword, start);
      if (index < 0) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      spans.add(TextSpan(
        text: text.substring(index, index + keyword.length),
        style: TextStyle(
            color: context.paper.accent, fontWeight: FontWeight.w600),
      ));
      start = index + keyword.length;
    }
    return Text.rich(TextSpan(style: base, children: spans));
  }
}