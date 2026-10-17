import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/ai/skills/skill.dart';
import '../../core/ai/skills/skill_front_matter.dart';
import '../../core/exporter/share_export.dart';
import '../../data/data_providers.dart';
import '../../l10n/l10n.dart';

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
    await ref
        .read(settingsRepositoryProvider)
        .setSkillEnabled(skill.id, enabled);
    await _load();
  }

  /// 导出单个技能为带 front matter 的 Markdown 并唤起系统分享（ENH-22）。
  Future<void> _exportSkill(Skill skill) async {
    final l10n = context.l10n;
    try {
      final markdown = skillToMarkdown(skill);
      await shareExport(
        fileName: safeExportFileName(skill.name, 'md'),
        bytes: Uint8List.fromList(utf8.encode(markdown)),
        title: skill.name,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.skillExportFailed('$e'))));
    }
  }

  Future<void> _confirmDelete(Skill skill) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.skillDeleteTitle),
        content: Text(l10n.skillDeleteBody(skill.name)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(settingsRepositoryProvider).deleteSkill(skill.id);
    await _load();
  }

  /// 从 .md / .markdown / .txt 文件读取技能文本（ENH-21）。
  Future<void> _importFromFile() async {
    final l10n = context.l10n;
    String raw;
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const <String>['md', 'markdown', 'txt'],
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      raw = utf8.decode(bytes, allowMalformed: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.skillImportFailed('$e'))));
      return;
    }
    if (!mounted) return;
    await _importFromText(raw);
  }

  /// 粘贴导入：对话框内输入 front matter 文本（ENH-21）。
  Future<void> _importFromPaste() async {
    final raw = await showDialog<String>(
      context: context,
      builder: (_) => const _PasteSkillDialog(),
    );
    if (raw == null || raw.trim().isEmpty) return;
    await _importFromText(raw);
  }

  /// 解析 front matter → 预览确认 → 落库（ENH-21）。
  Future<void> _importFromText(String raw) async {
    final l10n = context.l10n;
    SkillDraft draft;
    try {
      draft = parseSkillFrontMatter(raw);
    } on FormatException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.skillImportFailed(e.message))),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.skillImportPreviewTitle),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                draft.name,
                style: Theme.of(dialogContext).textTheme.titleMedium,
              ),
              if (draft.description.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  draft.description,
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              Text(
                draft.allowedTools.isEmpty
                    ? l10n.skillToolsUnlimited
                    : l10n.skillToolsWhitelist(
                        draft.allowedTools.join(l10n.skillListSeparator),
                      ),
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Text(draft.instruction),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.skillImport),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final repo = ref.read(settingsRepositoryProvider);
    final id = await repo.createSkill(
      name: draft.name,
      instruction: draft.instruction,
      description: draft.description,
      allowedTools: draft.allowedTools,
      parameters: draft.parameters,
    );
    if (!draft.enabled) {
      await repo.setSkillEnabled(id, false);
    }
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.skillImportOk(draft.name))));
  }

  @override
  Widget build(BuildContext context) {
    final skills = _skills;
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.skillTitle),
        actions: <Widget>[
          PopupMenuButton<String>(
            tooltip: l10n.commonMoreActions,
            onSelected: (value) async {
              switch (value) {
                case 'import_file':
                  await _importFromFile();
                case 'import_paste':
                  await _importFromPaste();
              }
            },
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'import_file',
                child: Text(l10n.skillImportFromFile),
              ),
              PopupMenuItem<String>(
                value: 'import_paste',
                child: Text(l10n.skillImportFromPaste),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEdit(null),
        icon: const Icon(Icons.add),
        label: Text(l10n.skillAdd),
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
                    '${skill.description.trim().isNotEmpty ? skill.description.trim() : skill.instruction.trim()}\n'
                    '${skill.allowedTools.isEmpty ? l10n.skillToolsUnlimited : l10n.skillToolsWhitelist(skill.allowedTools.join(l10n.skillListSeparator))}',
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
                      Semantics(
                        label: l10n.commonToggleSwitch(skill.name),
                        child: Switch(
                          value: skill.enabled,
                          activeTrackColor: context.paper.accent,
                          onChanged: (value) => _toggle(skill, value),
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: l10n.commonMoreActions,
                        onSelected: (value) async {
                          switch (value) {
                            case 'export':
                              await _exportSkill(skill);
                            case 'edit':
                              await _openEdit(skill.id);
                            case 'delete':
                              await _confirmDelete(skill);
                          }
                        },
                        itemBuilder: (context) => <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                            value: 'export',
                            child: Text(context.l10n.skillExport),
                          ),
                          PopupMenuItem<String>(
                            value: 'edit',
                            child: Text(context.l10n.commonEdit),
                          ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Text(context.l10n.commonDelete),
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

/// 粘贴导入对话框：自持控制器，避免路由退出动画期间被提前释放。
class _PasteSkillDialog extends StatefulWidget {
  const _PasteSkillDialog();

  @override
  State<_PasteSkillDialog> createState() => _PasteSkillDialogState();
}

class _PasteSkillDialogState extends State<_PasteSkillDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.skillImportPasteTitle),
      content: TextField(
        controller: _controller,
        minLines: 6,
        maxLines: 12,
        autofocus: true,
        decoration: InputDecoration(hintText: l10n.skillImportPasteHint),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.skillImport),
        ),
      ],
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
            Text(context.l10n.skillEmptyTitle),
            const SizedBox(height: 4),
            Text(
              context.l10n.skillEmptyHint,
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
  final _description = TextEditingController();
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
    _description.dispose();
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
      _description.text = skill.description;
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
    final description = _description.text.trim();
    final instruction = _instruction.text.trim();
    final tools = _toolList;
    final parameters = _parameterMap;

    if (_isNew) {
      await repo.createSkill(
        name: name,
        instruction: instruction,
        description: description,
        allowedTools: tools,
        parameters: parameters,
      );
    } else {
      await repo.updateSkill(
        Skill(
          id: widget.skillId!,
          name: name,
          instruction: instruction,
          description: description,
          enabled: _enabled,
          allowedTools: tools,
          parameters: parameters,
        ),
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.skillSaved)));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isNew ? context.l10n.skillNewTitle : context.l10n.skillEditTitle,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: _loading ? null : _save,
            child: Text(context.l10n.commonSave),
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
                    decoration: InputDecoration(
                      labelText: context.l10n.skillNameLabel,
                      hintText: context.l10n.skillNameHint,
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? context.l10n.skillNameRequired
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _description,
                    maxLength: 60,
                    decoration: InputDecoration(
                      labelText: context.l10n.skillDescriptionLabel,
                      hintText: context.l10n.skillDescriptionHint,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _instruction,
                    minLines: 4,
                    maxLines: 10,
                    decoration: InputDecoration(
                      labelText: context.l10n.skillInstructionLabel,
                      hintText: context.l10n.skillInstructionHint,
                      helperText: context.l10n.skillInstructionHelper,
                      alignLabelWithHint: true,
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? context.l10n.skillInstructionRequired
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _parameters,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: context.l10n.skillParamsLabel,
                      hintText: context.l10n.skillParamsHint,
                      helperText: context.l10n.skillParamsHelper('{{', '}}'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _allowedTools,
                    minLines: 2,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: context.l10n.skillToolsLabel,
                      hintText: context.l10n.skillToolsHint,
                      helperText: context.l10n.skillToolsHelper,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.l10n.skillEnable),
                    subtitle: Text(context.l10n.skillEnableSubtitle),
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
