/// 清洗 AI 输出（ENH-07 O8）：去除行首 markdown 标记（# 标题 / - * + 列表 /
/// 数字编号）、行尾空白与多余空行。仅在落库前调用，不改动面板中的 AI 原文。
String sanitizeAiText(String text) {
  final cleaned = <String>[];
  for (final raw in text.split('\n')) {
    var line = raw.trimRight();
    line = line.replaceFirst(RegExp(r'^\s*#{1,6}\s*'), '');
    line = line.replaceFirst(RegExp(r'^\s*[-*+]\s+'), '');
    // ASCII 点号必须紧跟空白才算编号，避免误删「1.5」「3.14」等正文小数；
    // 中文编号分隔符（、和全/半角右括号）本身无歧义，允许零空白。
    line = line.replaceFirst(RegExp(r'^\s*\d+\.\s+'), '');
    line = line.replaceFirst(RegExp(r'^\s*\d+[、)）]\s*'), '');
    cleaned.add(line);
  }
  final buffer = StringBuffer();
  var blank = false;
  for (final line in cleaned) {
    if (line.trim().isEmpty) {
      if (buffer.isEmpty || blank) continue;
      blank = true;
    } else {
      blank = false;
    }
    buffer.writeln(line);
  }
  return buffer.toString().trim();
}
