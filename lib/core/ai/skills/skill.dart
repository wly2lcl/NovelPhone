import '../agent_core.dart';

/// 用户自定义 SKILL（B-03）：在用例编排层注入的一段附加 system 指令，
/// 外加该技能允许使用的工具白名单与可选参数模板。
///
/// 字段与 Anthropic / Genkit skills 的 markdown 约定一一对应
/// （name / 正文指令 / allowed-tools），暂以 JSON 落 APP_SETTING，不含密钥。
class Skill {
  const Skill({
    required this.id,
    required this.name,
    required this.instruction,
    this.enabled = true,
    this.allowedTools = const <String>[],
    this.parameters = const <String, String>{},
  });

  final int id;
  final String name;

  /// 注入 system 的指令文本，可用 `{{参数名}}` 引用 [parameters]。
  final String instruction;
  final bool enabled;

  /// 该技能允许使用的工具名白名单；为空表示不额外限制。
  final List<String> allowedTools;

  /// 参数模板：注入前把指令中的 `{{键}}` 替换为对应值。
  final Map<String, String> parameters;

  /// 替换参数后的指令文本。
  String renderInstruction() {
    var text = instruction;
    for (final entry in parameters.entries) {
      text = text.replaceAll('{{${entry.key}}}', entry.value);
    }
    return text;
  }

  Skill copyWith({
    String? name,
    String? instruction,
    bool? enabled,
    List<String>? allowedTools,
    Map<String, String>? parameters,
  }) {
    return Skill(
      id: id,
      name: name ?? this.name,
      instruction: instruction ?? this.instruction,
      enabled: enabled ?? this.enabled,
      allowedTools: allowedTools ?? this.allowedTools,
      parameters: parameters ?? this.parameters,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'instruction': instruction,
    'enabled': enabled,
    'allowedTools': allowedTools,
    'parameters': parameters,
  };

  factory Skill.fromJson(Map<String, dynamic> json) {
    return Skill(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      instruction: json['instruction'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      allowedTools:
          (json['allowedTools'] as List?)?.whereType<String>().toList() ??
          const <String>[],
      parameters:
          (json['parameters'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
          ) ??
          const <String, String>{},
    );
  }
}

/// 把启用技能的指令拼进 system（B-03）。
String composeSkillSystem(String system, List<Skill> skills) {
  if (skills.isEmpty) return system;
  final buffer = StringBuffer(system);
  for (final skill in skills) {
    final body = skill.renderInstruction().trim();
    if (body.isEmpty) continue;
    buffer.write('\n\n【用户技能：${skill.name}】\n$body');
  }
  return buffer.toString();
}

/// 按启用技能的工具白名单过滤可用工具（B-03）；
/// 所有技能都未声明白名单时表示不限制，原样返回。
List<Tool> filterToolsBySkills(List<Tool> tools, List<Skill> skills) {
  final allowed = <String>{};
  for (final skill in skills) {
    allowed.addAll(skill.allowedTools);
  }
  if (allowed.isEmpty) return tools;
  return tools
      .where((tool) => allowed.contains(tool.name))
      .toList(growable: false);
}
