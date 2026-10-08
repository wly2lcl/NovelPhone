import '../../../data/repositories/chapter_repository.dart';
import '../../../data/repositories/character_repository.dart';
import '../../../data/repositories/outline_repository.dart';
import '../agent_core.dart';

/// 单次工具返回的正文上限，避免一章正文撑爆上下文预算。
const int _maxChapterChars = 6000;

/// 内置本地工具（M3-07）：经 Repository 取数，供灵感类任务按需展开
/// （ARCHITECTURE 5.4：续写走 ContextBuilder 预注入，桥段点子走工具按需取数）。
List<Tool> buildLocalTools({
  required ChapterRepository chapters,
  required CharacterRepository characters,
  required OutlineRepository outline,
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
        return '【$title】\n$body';
      },
    ),
    Tool(
      name: 'get_characters',
      description: '获取指定作品的全部角色卡，用于保持角色设定一致。',
      inputSchema: const <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'workId': <String, dynamic>{'type': 'integer', 'description': '作品 id'},
        },
        'required': <String>['workId'],
      },
      execute: (args) async {
        final workId = _asInt(args['workId']);
        if (workId == null) return '错误：缺少有效的作品 id';
        final list = await characters.listCharacters(workId);
        if (list.isEmpty) return '该作品暂无角色卡。';
        return list.map((c) {
          final parts = <String>[
            if (c.identity.isNotEmpty) '身份：${c.identity}',
            if (c.personalityTags.isNotEmpty) '性格：${c.personalityTags}',
            if (c.appearance.isNotEmpty) '外貌：${c.appearance}',
            if (c.relations.isNotEmpty) '人际关系：${c.relations}',
            if (c.arc.isNotEmpty) '弧光：${c.arc}',
          ];
          return '- ${c.name}${parts.isEmpty ? '' : '（${parts.join('；')}）'}';
        }).join('\n');
      },
    ),
    Tool(
      name: 'get_outline',
      description: '获取指定作品的章纲（各章梗概），用于把握剧情走向。',
      inputSchema: const <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'workId': <String, dynamic>{'type': 'integer', 'description': '作品 id'},
        },
        'required': <String>['workId'],
      },
      execute: (args) async {
        final workId = _asInt(args['workId']);
        if (workId == null) return '错误：缺少有效的作品 id';
        final entries = await outline.listOutline(workId);
        final withSummary =
            entries.where((e) => e.summary.trim().isNotEmpty).toList();
        if (withSummary.isEmpty) return '该作品暂无章纲。';
        final chapterList = await chapters.watchChapters(workId).first;
        final titleById = <int, String>{
          for (final c in chapterList)
            c.id: c.title.isEmpty ? '未命名章节' : c.title,
        };
        return withSummary
            .map((e) {
              final title = e.chapterId == null
                  ? '（未关联章节）'
                  : (titleById[e.chapterId] ?? '章节 ${e.chapterId}');
              return '- $title：${e.summary}';
            })
            .join('\n');
      },
    ),
  ];
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}