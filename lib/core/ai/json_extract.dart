import 'dart:convert';

/// 从模型输出中抽取 JSON：容忍代码块包裹与前后解释文字。
dynamic extractJson(String raw) {
  final cleaned = raw
      .replaceAll('```json', '')
      .replaceAll('```JSON', '')
      .replaceAll('```', '')
      .trim();
  if (cleaned.isEmpty) return null;
  final direct = _tryDecode(cleaned);
  if (direct != null) return direct;

  final objectStart = cleaned.indexOf('{');
  final objectEnd = cleaned.lastIndexOf('}');
  if (objectStart != -1 && objectEnd > objectStart) {
    final decoded = _tryDecode(cleaned.substring(objectStart, objectEnd + 1));
    if (decoded != null) return decoded;
  }
  final arrayStart = cleaned.indexOf('[');
  final arrayEnd = cleaned.lastIndexOf(']');
  if (arrayStart != -1 && arrayEnd > arrayStart) {
    return _tryDecode(cleaned.substring(arrayStart, arrayEnd + 1));
  }
  return null;
}

/// 读取第一个非空字符串字段（兼容模型返回的不同键名）。
String readJsonString(Map<dynamic, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return '';
}

/// 读取可能被模型写成字符串或数组的字段，统一用 [separator] 拼接。
String readJsonText(
  Map<dynamic, dynamic> map,
  List<String> keys, {
  String separator = '\n',
}) {
  for (final key in keys) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is List) {
      final parts = value
          .whereType<Object?>()
          .map((item) => '$item'.trim())
          .where((item) => item.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) return parts.join(separator);
    }
  }
  return '';
}

dynamic _tryDecode(String text) {
  try {
    return jsonDecode(text);
  } catch (_) {
    return null;
  }
}
