/// 技能 markdown front matter 解析（ENH-21）。
///
/// 约定与 Anthropic Agent Skills 的 SKILL.md 对齐：文件以 `---` 行开头，
/// 元数据若干行后以下一个 `---` 行结束，其余为注入 system 的正文指令：
///
/// ```markdown
/// ---
/// name: 悬疑推进
/// description: 每章结尾留下悬念，避免提前揭底
/// allowed-tools:
///   - get_chapter
///   - update_chapter
/// parameters:
///   tone: 冷峻
/// enabled: true
/// ---
/// 请在续写时保持{{tone}}的笔调，结尾留一个悬念钩子。
/// ```
///
/// 解析规则（尽量宽容，报错只指向无法继续的情况）：
/// · 开头 `---`、结尾 `---` 必须成对，否则抛 [FormatException]；
/// · name 与正文（闭标记之后的非空内容）必须存在；
/// · allowed-tools 支持行内逗号/方括号列表与缩进 `- 项` 块列表；
/// · parameters 支持缩进 `键: 值` 块映射与行内 `键=值` 逗号对；
/// · enabled 接受 true/false/1/0/yes/no（默认 true）；
/// · 未知键与无法识别的行忽略，保证前向兼容。
library;

import 'skill.dart';

/// 解析产物：直接可落库的技能草稿（不含 id）。
class SkillDraft {
  const SkillDraft({
    required this.name,
    required this.description,
    required this.instruction,
    required this.allowedTools,
    required this.parameters,
    required this.enabled,
  });

  final String name;
  final String description;
  final String instruction;
  final List<String> allowedTools;
  final Map<String, String> parameters;
  final bool enabled;
}

/// 解析全文；失败抛 [FormatException]（消息直接面向用户展示）。
SkillDraft parseSkillFrontMatter(String raw) {
  final text = raw
      .replaceFirst('\uFEFF', '') // BOM
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
  final lines = text.split('\n');

  var cursor = 0;
  while (cursor < lines.length && lines[cursor].trim().isEmpty) {
    cursor++;
  }
  if (cursor >= lines.length || lines[cursor].trim() != '---') {
    throw const FormatException('文件需要以 front matter 开头（首行为 ---）');
  }
  cursor++; // 跳过起始 ---

  final metadataEnd = _findClosing(lines, cursor);
  if (metadataEnd < 0) {
    throw const FormatException('front matter 缺少结束标记（单独一行的 ---）');
  }

  final meta = _parseMetadata(lines.sublist(cursor, metadataEnd));
  final body = lines.sublist(metadataEnd + 1).join('\n').trim();

  final name = meta.name?.trim() ?? '';
  if (name.isEmpty) {
    throw const FormatException('front matter 缺少 name（技能名不能为空）');
  }
  if (body.isEmpty) {
    throw const FormatException('front matter 之后没有正文指令');
  }
  return SkillDraft(
    name: name,
    description: meta.description?.trim() ?? '',
    instruction: body,
    allowedTools: meta.allowedTools.where((t) => t.isNotEmpty).toList(),
    parameters: meta.parameters,
    enabled: meta.enabled,
  );
}

int _findClosing(List<String> lines, int from) {
  for (var i = from; i < lines.length; i++) {
    if (lines[i].trim() == '---') return i;
  }
  return -1;
}

class _Meta {
  String? name;
  String? description;
  List<String> allowedTools = <String>[];
  Map<String, String> parameters = <String, String>{};
  bool enabled = true;
}

/// 当前块声明的类型：None=无、List=允许工具列表、Map=参数映射。
enum _BlockMode { none, tools, params }

_Meta _parseMetadata(List<String> lines) {
  final meta = _Meta();
  var block = _BlockMode.none;

  for (final rawLine in lines) {
    final line = rawLine.trimRight();
    if (line.trim().isEmpty) continue;

    final trimmed = line.trimLeft();
    final indented = line.length != trimmed.length;

    // 缩进列表项：`- 值`
    if (trimmed.startsWith('- ')) {
      if (block == _BlockMode.tools) {
        final item = _unquote(trimmed.substring(2).trim());
        if (item.isNotEmpty) meta.allowedTools.add(item);
      }
      continue;
    }

    final separator = trimmed.indexOf(':');
    if (separator <= 0) continue; // 无法识别的行：忽略
    final key = trimmed
        .substring(0, separator)
        .trim()
        .toLowerCase()
        .replaceAll('_', '-');
    final value = trimmed.substring(separator + 1).trim();

    // 块级续行：缩进的 `键: 值`
    if (indented) {
      if (block == _BlockMode.params && value.isNotEmpty) {
        meta.parameters[_unquote(key)] = _unquote(value);
      }
      continue;
    }

    switch (key) {
      case 'name':
        meta.name = _unquote(value);
        block = _BlockMode.none;
      case 'description':
        meta.description = _unquote(value);
        block = _BlockMode.none;
      case 'allowed-tools':
      case 'allowedtools':
        block = _BlockMode.tools;
        meta.allowedTools.addAll(_listValue(value));
      case 'parameters':
        block = _BlockMode.params;
        meta.parameters.addAll(_inlinePairs(value));
      case 'enabled':
        meta.enabled = _boolValue(value);
        block = _BlockMode.none;
      default:
        block = _BlockMode.none;
    }
  }
  return meta;
}

/// 行内列表：`[a, b]` / `a, b` / `a`。空值返回空表（等待块列表）。
List<String> _listValue(String value) {
  if (value.isEmpty) return <String>[];
  var content = value;
  if (content.startsWith('[') && content.endsWith(']')) {
    content = content.substring(1, content.length - 1);
  }
  return content
      .split(',')
      .map((s) => _unquote(s.trim()))
      .where((s) => s.isNotEmpty)
      .toList();
}

/// 行内参数对：`键=值, 键2=值2`。
Map<String, String> _inlinePairs(String value) {
  final result = <String, String>{};
  if (value.isEmpty) return result;
  var content = value;
  if (content.startsWith('{') && content.endsWith('}')) {
    content = content.substring(1, content.length - 1);
  }
  for (final pair in content.split(',')) {
    final separator = pair.indexOf('=');
    if (separator <= 0) continue;
    final key = _unquote(pair.substring(0, separator).trim());
    final v = _unquote(pair.substring(separator + 1).trim());
    if (key.isNotEmpty) result[key] = v;
  }
  return result;
}

bool _boolValue(String value) {
  switch (value.toLowerCase()) {
    case 'true':
    case '1':
    case 'yes':
    case 'on':
      return true;
    default:
      return false;
  }
}

String _unquote(String value) {
  if (value.length >= 2) {
    final first = value[0];
    final last = value[value.length - 1];
    if ((first == '"' && last == '"') || (first == "'" && last == "'")) {
      return value.substring(1, value.length - 1);
    }
  }
  return value;
}

/// 技能 → markdown 导出文本（front matter 往返；
/// 导入 UI 的「复制为 Markdown」与测试共用）。
String skillToMarkdown(Skill skill) {
  final buffer = StringBuffer()
    ..writeln('---')
    ..writeln('name: ${skill.name}');
  if (skill.description.isNotEmpty) {
    buffer.writeln('description: ${skill.description}');
  }
  if (skill.allowedTools.isNotEmpty) {
    buffer.writeln('allowed-tools:');
    for (final tool in skill.allowedTools) {
      buffer.writeln('  - $tool');
    }
  }
  if (skill.parameters.isNotEmpty) {
    buffer.writeln('parameters:');
    for (final entry in skill.parameters.entries) {
      buffer.writeln('  ${entry.key}: ${entry.value}');
    }
  }
  buffer.writeln('enabled: ${skill.enabled}');
  buffer.writeln('---');
  buffer.writeln(skill.instruction.trimRight());
  return buffer.toString();
}
