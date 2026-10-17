import '../../../data/repositories/chapter_repository.dart';
import '../../../data/repositories/character_repository.dart';
import '../../../data/repositories/outline_repository.dart';
import '../../../data/repositories/setting_repository.dart';
import '../agent_core.dart';

/// 单次工具返回的正文上限，避免一章正文撑爆上下文预算。
const int _maxChapterChars = 6000;

/// 检索工具单次返回的命中上限。
const int _maxSearchHits = 8;

/// 内置本地工具（M3-07）：经 Repository 取数，供灵感类任务按需展开
/// （ARCHITECTURE 5.4：续写走 ContextBuilder 预注入，桥段点子走工具按需取数）。
/// ENH-23：新增目录 / 正文检索 / 设定集工具，支撑作品问答的长篇检索。
List<Tool> buildLocalTools({
  required ChapterRepository chapters,
  required CharacterRepository characters,
  required OutlineRepository outline,
  SettingRepository? settings,
}) {
  return <Tool>[
    Tool(
      name: 'get_chapter',
      description: '按章节 id 获取该章正文，用于需要参考具体章节内容时。',
      inputSchema: const <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'id': <String, dynamic>{'type': 'integer', 'description': '章节 id'},
        },
        'required': <String>['id'],
      },
      execute: (args) async {
        final id = _asInt(args['id']);
        if (id == null) return '错误：缺少有效的章节 id';
        final chapter = await chapters.getChapter(id);
        if (chapter == null) return '错误：章节不存在（id=$id）';
        final title = chapter.title.isEmpty ? '未命名章节' : chapter.title;
        final content = chapter.content;
        final body = content.length > _maxChapterChars
            ? '${content.substring(0, _maxChapterChars)}…（后文略）'
            : content;
        return '【$title】（id=$id）\n$body';
      },
    ),
    Tool(
      name: 'list_chapters',
      description: '获取指定作品的章节目录（id、标题、字数），配合 get_chapter 使用。',
      inputSchema: const <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'workId': <String, dynamic>{
            'type': 'integer',
            'description': '作品 id',
          },
        },
        'required': <String>['workId'],
      },
      execute: (args) async {
        final workId = _asInt(args['workId']);
        if (workId == null) return '错误：缺少有效的作品 id';
        final list = await chapters.watchChapterMetas(workId).first;
        if (list.isEmpty) return '该作品暂无章节。';
        final buffer = StringBuffer();
        var index = 1;
        for (final chapter in list) {
          final title = chapter.title.isEmpty ? '未命名章节' : chapter.title;
          buffer.writeln(
            '$index. $title（id=${chapter.id}，${chapter.wordCount} 字）',
          );
          index++;
        }
        return buffer.toString().trim();
      },
    ),
    Tool(
      name: 'search_chapters',
      description: '在指定作品的章节正文与标题中检索关键词，返回命中章节与片段。',
      inputSchema: const <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'workId': <String, dynamic>{
            'type': 'integer',
            'description': '作品 id',
          },
          'keyword': <String, dynamic>{
            'type': 'string',
            'description': '要检索的关键词或人名',
          },
        },
        'required': <String>['workId', 'keyword'],
      },
      execute: (args) async {
        final workId = _asInt(args['workId']);
        final keyword = '${args['keyword'] ?? ''}'.trim();
        if (workId == null) return '错误：缺少有效的作品 id';
        if (keyword.isEmpty) return '错误：缺少检索关键词';
        final list = await chapters.listChapters(workId);
        final lower = keyword.toLowerCase();
        final hits = <String>[];
        for (final chapter in list) {
          if (hits.length >= _maxSearchHits) break;
          final title = chapter.title.isEmpty ? '未命名章节' : chapter.title;
          final inTitle = title.toLowerCase().contains(lower);
          final inContent = chapter.content.toLowerCase().contains(lower);
          if (!inTitle && !inContent) continue;
          final offset = inContent
              ? chapter.content.toLowerCase().indexOf(lower)
              : -1;
          final snippet = offset < 0
              ? (inTitle ? '（标题命中）' : chapter.content.trim())
              : _snippet(chapter.content, offset, keyword.length);
          hits.add('- $title（id=${chapter.id}）：$snippet');
        }
        if (hits.isEmpty) return '未找到包含「$keyword」的章节。';
        return hits.join('\n');
      },
    ),
    Tool(
      name: 'get_characters',
      description: '获取指定作品的全部角色卡，用于保持角色设定一致。',
      inputSchema: const <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'workId': <String, dynamic>{
            'type': 'integer',
            'description': '作品 id',
          },
        },
        'required': <String>['workId'],
      },
      execute: (args) async {
        final workId = _asInt(args['workId']);
        if (workId == null) return '错误：缺少有效的作品 id';
        final list = await characters.listCharacters(workId);
        if (list.isEmpty) return '该作品暂无角色卡。';
        return list
            .map((c) {
              final parts = <String>[
                if (c.identity.isNotEmpty) '身份：${c.identity}',
                if (c.personalityTags.isNotEmpty) '性格：${c.personalityTags}',
                if (c.appearance.isNotEmpty) '外貌：${c.appearance}',
                if (c.relations.isNotEmpty) '人际关系：${c.relations}',
                if (c.arc.isNotEmpty) '弧光：${c.arc}',
              ];
              return '- ${c.name}${parts.isEmpty ? '' : '（${parts.join('；')}）'}';
            })
            .join('\n');
      },
    ),
    Tool(
      name: 'get_settings',
      description: '获取指定作品的设定集（世界观 / 地点 / 道具）。',
      inputSchema: const <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'workId': <String, dynamic>{
            'type': 'integer',
            'description': '作品 id',
          },
        },
        'required': <String>['workId'],
      },
      execute: (args) async {
        final workId = _asInt(args['workId']);
        if (workId == null) return '错误：缺少有效的作品 id';
        if (settings == null) return '该作品暂无设定集。';
        final list = await settings.listEntries(workId);
        if (list.isEmpty) return '该作品暂无设定集。';
        return list
            .map((e) => '- [${e.type}] ${e.name}：${e.content}'.trim())
            .join('\n');
      },
    ),
    Tool(
      name: 'get_outline',
      description: '获取指定作品的章纲（各章梗概），用于把握剧情走向。',
      inputSchema: const <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'workId': <String, dynamic>{
            'type': 'integer',
            'description': '作品 id',
          },
        },
        'required': <String>['workId'],
      },
      execute: (args) async {
        final workId = _asInt(args['workId']);
        if (workId == null) return '错误：缺少有效的作品 id';
        final entries = await outline.listOutline(workId);
        final withSummary = entries
            .where((e) => e.summary.trim().isNotEmpty)
            .toList();
        if (withSummary.isEmpty) return '该作品暂无章纲。';
        // 只需章节标题映射：走元数据流，不为一张 id→标题表读入整部作品正文（ENH-12）。
        final chapterList = await chapters.watchChapterMetas(workId).first;
        final titleById = <int, String>{
          for (final c in chapterList)
            c.id: c.title.isEmpty ? '未命名章节' : c.title,
        };
        return withSummary
            .map((e) {
              final title = e.chapterId == null
                  ? '（未关联章节）'
                  : (titleById[e.chapterId] ?? '章节 ${e.chapterId}');
              final id = e.chapterId == null ? '' : '（id=${e.chapterId}）';
              return '- $title$id：${e.summary}';
            })
            .join('\n');
      },
    ),
  ];
}

String _snippet(String content, int offset, int length) {
  final start = offset > 20 ? offset - 20 : 0;
  final end = offset + length + 40 < content.length
      ? offset + length + 40
      : content.length;
  final prefix = start > 0 ? '…' : '';
  final suffix = end < content.length ? '…' : '';
  return '$prefix${content.substring(start, end)}$suffix';
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
