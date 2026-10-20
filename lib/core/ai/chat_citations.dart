/// 作品问答的章节引用标记（ENH-43 / ENH-47）。
///
/// 模型用 `[[ch:12]]` 标注剧情出处；标记随回答一起持久化，界面展示时
/// 去掉标记并在原位置内联为可跳转的章节 chip。
library;

/// 回答中的一段文本或一个章节引用（ENH-47 内联展示）。
class ChatTextSegment {
  const ChatTextSegment.text(this.text) : chapterId = null;
  const ChatTextSegment.citation(this.chapterId) : text = '';

  final String text;
  final int? chapterId;

  bool get isCitation => chapterId != null;
}

class ChatCitations {
  ChatCitations._();

  static final RegExp _pattern = RegExp(
    r'\[\[\s*ch\s*[:：]\s*(\d+)\s*\]\]',
    caseSensitive: false,
  );

  /// 仅包裹引用标记的空括号 / 方括号，去标记时一并移除（ENH-47）。
  static final RegExp _emptyWrapperAroundMarker = RegExp(
    r'[（(]\s*(\[\[\s*ch\s*[:：]\s*\d+\s*\]\])\s*[）)]',
    caseSensitive: false,
  );

  static final RegExp _emptyParentheses = RegExp(r'[（(]\s*[）)]');
  static final RegExp _emptyBrackets = RegExp(r'[【\[]\s*[】\]]');
  static final RegExp _duplicatePunctuation = RegExp(r'([，。！？；：、])\1+');

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

  /// 把回答拆成文本段与引用段，供 `Text.rich` 内联渲染。
  ///
  /// 同一章节重复标记只保留第一个；非法 / 非正数标记直接丢弃。
  static List<ChatTextSegment> segments(String text) {
    final normalized = text.replaceAllMapped(
      _emptyWrapperAroundMarker,
      (match) => match.group(1) ?? '',
    );
    final matches = _pattern.allMatches(normalized).toList(growable: false);
    if (matches.isEmpty) {
      final plain = normalized.trim();
      return plain.isEmpty
          ? const <ChatTextSegment>[]
          : <ChatTextSegment>[ChatTextSegment.text(plain)];
    }
    final segments = <ChatTextSegment>[];
    final seen = <int>{};
    var cursor = 0;
    for (final match in matches) {
      final gap = _cleanInline(normalized.substring(cursor, match.start));
      if (gap.isNotEmpty) segments.add(ChatTextSegment.text(gap));
      cursor = match.end;
      final id = int.tryParse(match.group(1) ?? '');
      if (id == null || id <= 0 || !seen.add(id)) continue;
      segments.add(ChatTextSegment.citation(id));
    }
    final tail = _cleanInline(normalized.substring(cursor));
    if (tail.isNotEmpty) segments.add(ChatTextSegment.text(tail));
    return _trimEdges(segments);
  }

  /// 去掉引用标记，并清理标记留下的多余空格、空括号与重复标点。
  static String strip(String text) {
    final normalized = text.replaceAllMapped(
      _emptyWrapperAroundMarker,
      (match) => match.group(1) ?? '',
    );
    if (!_pattern.hasMatch(normalized)) return normalized.trim();
    final stripped = normalized
        .replaceAll(_pattern, '')
        .replaceAll(_emptyParentheses, '')
        .replaceAll(_emptyBrackets, '')
        .replaceAllMapped(
          _duplicatePunctuation,
          (match) => match.group(1) ?? '',
        )
        .replaceAll(RegExp(r'[ \t]+(?=[，。！？；：、,.!?;:])'), '')
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return stripped.trim();
  }

  static String _cleanInline(String text) {
    return text
        .replaceAll(_emptyParentheses, '')
        .replaceAll(_emptyBrackets, '')
        .replaceAll(RegExp(r'[ \t]+(?=[，。！？；：、,.!?;:])'), '')
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ');
  }

  static List<ChatTextSegment> _trimEdges(List<ChatTextSegment> segments) {
    final result = <ChatTextSegment>[...segments];
    if (result.isNotEmpty && !result.first.isCitation) {
      final trimmed = result.first.text.trimLeft();
      result[0] = ChatTextSegment.text(trimmed);
    }
    if (result.isNotEmpty && !result.last.isCitation) {
      final trimmed = result.last.text.trimRight();
      result[result.length - 1] = ChatTextSegment.text(trimmed);
    }
    result.removeWhere(
      (segment) => segment.text.isEmpty && !segment.isCitation,
    );
    return result;
  }
}
