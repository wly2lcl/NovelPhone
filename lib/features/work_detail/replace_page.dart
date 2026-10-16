import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/data_providers.dart';
import '../../data/repositories/chapter_repository.dart';
import '../../l10n/l10n.dart';
import '../search/highlighted_text.dart';

/// 全书查找替换（ENH-19）：预览全部章节的命中，一键替换（自动快照可回退）。
class WorkReplacePage extends ConsumerStatefulWidget {
  const WorkReplacePage({super.key, required this.workId});

  final int workId;

  @override
  ConsumerState<WorkReplacePage> createState() => _WorkReplacePageState();
}

class _WorkReplacePageState extends ConsumerState<WorkReplacePage> {
  /// 输入防抖（与全局搜索同口径）：正文匹配要读全书，逐键检索会打断输入。
  static const Duration _debounceDelay = Duration(milliseconds: 300);

  final TextEditingController _keyword = TextEditingController();
  final TextEditingController _replacement = TextEditingController();
  Timer? _debounce;
  bool _caseSensitive = false;

  String _query = '';
  List<WorkReplaceHit>? _hits;
  bool _loading = false;
  bool _replacing = false;
  String? _error;

  /// 检索序号：丢弃过期响应（快速输入时前一次检索可能后返回）。
  int _searchSeq = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _keyword.dispose();
    _replacement.dispose();
    super.dispose();
  }

  int get _matchCount =>
      _hits?.fold<int>(0, (sum, hit) => sum + hit.count) ?? 0;

  int get _chapterCount => _hits?.length ?? 0;

  void _onKeywordChanged(String value) {
    _debounce?.cancel();
    final next = value.trim();
    if (next == _query) return;
    if (next.isEmpty) {
      _searchSeq++;
      setState(() {
        _query = '';
        _hits = null;
        _loading = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(_debounceDelay, () => _search(next));
  }

  Future<void> _search(String query) async {
    final seq = ++_searchSeq;
    setState(() {
      _query = query;
      _loading = true;
      _error = null;
    });
    try {
      final hits = await ref
          .read(chapterRepositoryProvider)
          .findReplaceHits(widget.workId, query, caseSensitive: _caseSensitive);
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _hits = hits;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  void _toggleCaseSensitive() {
    setState(() => _caseSensitive = !_caseSensitive);
    if (_query.isNotEmpty) _search(_query);
  }

  Future<void> _confirmReplaceAll() async {
    if (_hits?.isNotEmpty != true || _replacing) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.replaceConfirmTitle),
        content: Text(
          context.l10n.replaceConfirmBody(_chapterCount, _matchCount),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.findReplaceReplaceAll),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _replacing = true);
    try {
      final result = await ref
          .read(chapterRepositoryProvider)
          .replaceInWork(
            widget.workId,
            keyword: _query,
            replacement: _replacement.text,
            caseSensitive: _caseSensitive,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.replaceDone(result.chapters, result.replaced),
          ),
        ),
      );
      await _search(_query);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.searchFailed('$error'))),
      );
    } finally {
      if (mounted) setState(() => _replacing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.replaceTitle)),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: <Widget>[
                TextField(
                  controller: _keyword,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: context.l10n.findReplaceFindHint,
                    isDense: true,
                  ),
                  onChanged: _onKeywordChanged,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _replacement,
                  decoration: InputDecoration(
                    hintText: context.l10n.findReplaceReplacementHint,
                    isDense: true,
                  ),
                ),
                Row(
                  children: <Widget>[
                    IconButton(
                      tooltip: context.l10n.findReplaceCaseSensitive,
                      isSelected: _caseSensitive,
                      icon: const Icon(Icons.text_fields),
                      selectedIcon: Icon(
                        Icons.text_fields,
                        color: context.paper.accent,
                      ),
                      onPressed: _toggleCaseSensitive,
                    ),
                    const Spacer(),
                    if (_hits != null && !_loading)
                      Text(
                        context.l10n.replaceSummary(_matchCount, _chapterCount),
                        style: TextStyle(
                          fontSize: 13,
                          color: context.paper.inkSoft,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildPreview()),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _hits?.isNotEmpty == true && !_replacing
                ? _confirmReplaceAll
                : null,
            icon: const Icon(Icons.find_replace),
            label: Text(context.l10n.findReplaceReplaceAll),
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (_query.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            context.l10n.replaceEmptyHint,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.paper.inkSoft),
          ),
        ),
      );
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    final error = _error;
    if (error != null) {
      return Center(child: Text(context.l10n.searchFailed(error)));
    }
    final hits = _hits ?? const <WorkReplaceHit>[];
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
        return _ReplaceHitTile(
          hit: hit,
          keyword: _query,
          onOpen: () =>
              context.push('/work/${widget.workId}/chapter/${hit.chapterId}'),
        );
      },
    );
  }
}

class _ReplaceHitTile extends StatelessWidget {
  const _ReplaceHitTile({
    required this.hit,
    required this.keyword,
    required this.onOpen,
  });

  final WorkReplaceHit hit;
  final String keyword;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final title = hit.chapterTitle.isEmpty
        ? context.l10n.commonUntitledChapter
        : hit.chapterTitle;
    return ListTile(
      isThreeLine: true,
      title: Row(
        children: <Widget>[
          Expanded(
            child: HighlightedText(
              text: title,
              keyword: keyword,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Text(
            context.l10n.findReplaceMatchCount(hit.count),
            style: TextStyle(fontSize: 12, color: context.paper.accent),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: HighlightedText(
          text: hit.snippet,
          keyword: keyword,
          style: TextStyle(
            fontSize: 13,
            color: context.paper.inkSoft,
            height: 1.4,
          ),
        ),
      ),
      onTap: onOpen,
    );
  }
}
