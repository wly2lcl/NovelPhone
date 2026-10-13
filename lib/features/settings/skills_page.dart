import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/ai/skills/skill.dart';
import '../../data/data_providers.dart';

/// 用户自定义 SKILL 管理（B-03）：维护附加指令、工具白名单与参数模板。
/// 启用的技能会在续写 / 灵感生成时作为附加 system 指令注入。
class SkillsPage extends ConsumerStatefulWidget {
  const SkillsPage({super.key});

  @override
  ConsumerState<SkillsPage> createState() => _SkillsPageState();
}

class _SkillsPageState extends ConsumerState<SkillsPage> {
  List<Skill>? _skills;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await ref.read(settingsRepositoryProvider).listSkills();
    if (mounted) setState(() => _skills = list);
  }

  Future<void> _openEdit(int? id) async {
    await context.push('/settings/skills/${id ?? 'new'}');
    await _load();
  }

  Future<void> _toggle(Skill skill, bool enabled) async {
    await ref.read(settingsRepositoryProvider).setSkillEnabled(skill.id, enabled);
    await _load();
  }

  Future<void> _confirmDelete(Skill skill) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除技能'),
        content: Text('删除「${skill.name}」后，其指令不再注入 AI 生成。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(settingsRepositoryProvider).deleteSkill(skill.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final skills = _skills;
    return Scaffold(
      appBar: AppBar(title: const Text('自定义技能')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEdit(null),
        icon: const Icon(Icons.add),
        label: const Text('新增技能'),
      ),
      body: skills == null
          ? const Center(child: CircularProgressIndicator())
          : skills.isEmpty
              ? const _EmptyHint()
              : ListView.separated(
                  itemCount: skills.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final skill = skills[index];
                    return ListTile(
                      leading: Icon(
                        skill.enabled
                            ? Icons.auto_awesome
                            : Icons.auto_awesome_outlined,
                        color: skill.enabled
                            ? context.paper.accent
                            : context.paper.inkSoft,
                      ),
                      title: Text(skill.name),
                      subtitle: Text(
                        '${skill.instruction.trim()}\n'
                        '${skill.allowedTools.isEmpty ? '工具：不限制' : '工具白名单：${skill.allowedTools.join('、')}'}',
                        maxLines: 3,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.paper.inkSoft,
                        ),
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Switch(
                            value: skill.enabled,
                            activeTrackColor: context.paper.accent,
                            onChanged: (value) => _toggle(skill, value),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) async {
                              switch (value) {
                                case 'edit':
                                  await _openEdit(skill.id);
                                case 'delete':
                                  await _confirmDelete(skill);
                              }
                            },
                            itemBuilder: (context) =>
                                const <PopupMenuEntry<String>>[
                              PopupMenuItem<String>(
                                value: 'edit',
                                child: Text('编辑'),
                              ),
                              PopupMenuItem<String>(
                                value: 'delete',
                                child: Text('删除'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      onTap: () => _openEdit(skill.id),
                    );
                  },
                ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.auto_awesome_outlined,
              size: 40,
              color: context.paper.inkSoft,
            ),
            const SizedBox(height: 12),
            const Text('还没有自定义技能'),
            const SizedBox(height: 4),
            Text(
              '写一段附加指令（如「只用短句」「避免旁白解释」），'
              '启用后会注入续写与灵感生成的 system 提示',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// 技能编辑（B-03）：指令文本 + 参数模板 + 工具白名单。
class SkillEditPage extends ConsumerStatefulWidget {
  const SkillEditPage({super.key, this.skillId});

  /// null 表示新增。
  final int? skillId;

  @override
  ConsumerState<SkillEditPage> createState() => _SkillEditPageState();
}

class _SkillEditPageState extends ConsumerState<SkillEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _instruction = TextEditingController();
  final _parameters = TextEditingController();
  final _allowedTools = TextEditingController();

  bool _enabled = true;
  bool _loading = true;

  bool get _isNew => widget.skillId == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _instruction.dispose();
    _parameters.dispose();
    _allowedTools.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_isNew) {
      setState(() => _loading = false);
      return;
    }
    final skills = await ref.read(settingsRepositoryProvider).listSkills();
    Skill? found;
    for (final candidate in skills) {
      if (candidate.id == widget.skillId) {
        found = candidate;
        break;
      }
    }
    if (found == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final skill = found;
    if (!mounted) return;
    setState(() {
      _name.text = skill.name;
      _instruction.text = skill.instruction;
      _parameters.text = skill.parameters.entries
          .map((e) => '${e.key}=${e.value}')
          .join('\n');
      _allowedTools.text = skill.allowedTools.join('\n');
      _enabled = skill.enabled;
      _loading = false;
    });
  }

  List<String> get _toolList => _allowedTools.text
      .split('\n')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  /// 每行一条 `键=值`。
  Map<String, String> get _parameterMap {
    final map = <String, String>{};
    for (final line in _parameters.text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final separator = trimmed.indexOf('=');
      if (separator <= 0) continue;
      final key = trimmed.substring(0, separator).trim();
      final value = trimmed.substring(separator + 1).trim();
      if (key.isEmpty) continue;
      map[key] = value;
    }
    return map;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final repo = ref.read(settingsRepositoryProvider);
    final name = _name.text.trim();
    final instruction = _instruction.text.trim();
    final tools = _toolList;
    final parameters = _parameterMap;

    if (_isNew) {
      await repo.createSkill(
        name: name,
        instruction: instruction,
        allowedTools: tools,
        parameters: parameters,
      );
    } else {
      await repo.updateSkill(Skill(
        id: widget.skillId!,
        name: name,
        instruction: instruction,
        enabled: _enabled,
        allowedTools: tools,
        parameters: parameters,
      ));
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已保存')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? '新增技能' : '编辑技能'),
        actions: <Widget>[
          TextButton(
            onPressed: _loading ? null : _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: <Widget>[
                  TextFormField(
                    controller: _name,
                    maxLength: 30,
                    decoration: const InputDecoration(
                      labelText: '技能名称',
                      hintText: '例如：冷硬短句',
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? '请填写技能名称' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _instruction,
                    minLines: 4,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      labelText: '指令文本',
                      hintText: '例如：只用短句，避免解释性旁白，对话不写语气副词。',
                      helperText: '会作为附加 system 指令注入续写与灵感生成',
                      alignLabelWithHint: true,
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? '请填写指令文本' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _parameters,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: '参数模板（可选）',
                      hintText: '每行一条 键=值，例如 字数=800',
                      helperText: '在指令中用 {{参数名}} 引用，注入时替换为对应值',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _allowedTools,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: '工具白名单（可选）',
                      hintText: '每行一个工具名，例如 get_chapter',
                      helperText: '留空表示不限制；内置工具 get_chapter / get_characters / '
                          'get_outline，MCP 工具以 mcp_ 开头',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('启用'),
                    subtitle: const Text('停用后不注入，也不参与工具白名单'),
                    value: _enabled,
                    activeTrackColor: context.paper.accent,
                    onChanged: (v) => setState(() => _enabled = v),
                  ),
                ],
              ),
            ),
    );
  }
}