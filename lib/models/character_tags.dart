import 'dart:convert';

/// 角色卡性格标签编解码。
/// 库中 personalityTags 存 JSON 数组字符串（见 ARCHITECTURE 4.1 CHARACTER 表）。
List<String> decodeTags(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return const <String>[];
  final Object? decoded;
  try {
    decoded = jsonDecode(trimmed);
  } on FormatException {
    // 兼容早期以空格/逗号分隔的纯文本写法。
    return parseTagInput(trimmed);
  }
  if (decoded is! List) return const <String>[];
  return decoded
      .map((e) => e.toString().trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

String encodeTags(List<String> tags) {
  final cleaned = tags.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  return cleaned.isEmpty ? '' : jsonEncode(cleaned);
}

/// 把用户输入的一行文本解析为标签（支持空格、逗号、顿号分隔），最多保留 [max] 个。
List<String> parseTagInput(String input, {int max = 10}) {
  final tags = input
      .split(RegExp(r'[\s,，、]+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  return tags.length > max ? tags.sublist(0, max) : tags;
}
