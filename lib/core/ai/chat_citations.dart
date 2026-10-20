/// 作品问答的章节引用标记（ENH-43）。
///
/// 模型用 `[[ch:12]]` 标注剧情出处；标记随回答一起持久化，界面展示时
/// 去掉标记并换成可跳转到对应章节的 chip。
class ChatCitations {
  ChatCitations._();

  static final RegExp _pattern = RegExp(
    r'\[\[\s*ch\s*[:：]\s*(\d+)\s*\]\]',
    caseSensitive: false,
  );

  /// 按出现顺序返回去重后的章节 id；重复、非法与非正数 id 忽略。
  static List<int> parse(String text) {
    final ids = <int>[];
    for (final match in _pattern.allMatches(text)) {
      final id = int.tryParse(match.group(1) ?? '');
      if (id == null || id <= 0 || ids.contains(id)) continue;
      ids.add(id);
    }
    return ids;
  }

  /// 去掉引用标记，并清理标记留下的多余空格与空行。
  static String strip(String text) {
    if (!_pattern.hasMatch(text)) return text.trim();
    return text
        .replaceAll(_pattern, '')
        .replaceAll(RegExp(r'[ \t]+(?=[，。！？；：、,.!?;:])'), '')
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}
