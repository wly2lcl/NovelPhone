import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// 关键词高亮文本（忽略大小写，与检索口径一致）。
class HighlightedText extends StatelessWidget {
  const HighlightedText({
    super.key,
    required this.text,
    required this.keyword,
    this.style,
  });

  final String text;
  final String keyword;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (keyword.isEmpty || text.isEmpty) return Text(text, style: style);
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
      spans.add(
        TextSpan(
          text: text.substring(index, index + keyword.length),
          style: TextStyle(
            color: context.paper.accent,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      start = index + keyword.length;
    }
    return Text.rich(TextSpan(style: style, children: spans));
  }
}
