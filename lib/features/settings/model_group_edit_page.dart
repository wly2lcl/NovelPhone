import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/ai/ai_client_factory.dart';
import '../../data/data_providers.dart';
import '../../data/db.dart';
import '../../data/repositories/settings_repository.dart';
import '../ai/ai_providers.dart';

/// 模型组编辑（M3-18 / M3-19）：新增或修改模型组，key 只写安全存储。
class ModelGroupEditPage extends ConsumerStatefulWidget {
  const ModelGroupEditPage({super.key, this.groupId});

  /// null 表示新增。
  final int? groupId;

  @override
  ConsumerState<ModelGroupEditPage> createState() => _ModelGroupEditPageState();
}

class _ModelGroupEditPageState extends ConsumerState<ModelGroupEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _baseUrl = TextEditingController();
  final _models = TextEditingController();
  final _apiKey = TextEditingController();
  final _maxTokens = TextEditingController(text: '1024');
  final _contextWindow = TextEditingController(text: '32000');

  String _provider = AiProvider.openaiCompat;
  double _temperature = 0.8;
  bool _enabled = true;
  bool _hasKey = false;
  bool _loading = true;
  bool _testing = false;
  String? _testMessage;
  bool _testOk = false;

  bool get _isNew => widget.groupId == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _baseUrl.dispose();
    _models.dispose();
    _apiKey.dispose();
    _maxTokens.dispose();
    _contextWindow.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_isNew) {
      _baseUrl.text = _presetBaseUrl(AiProvider.openaiCompat);
      setState(() => _loading = false);
      return;
    }
    final repo = ref.read(settingsRepositoryProvider);
    final group = await repo.getModelGroup(widget.groupId!);
    if (group == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final hasKey = await repo.hasApiKey(group.id);
    if (!mounted) return;
    setState(() {
      _name.text = group.name;
      _provider = group.provider;
      _baseUrl.text = group.baseUrl;
      _models.text = SettingsRepository.parseModels(group.models).join('\n');
      _temperature = group.temperature;
      _maxTokens.text = '${group.maxTokens}';
      _contextWindow.text = '${group.contextWindow}';
      _enabled = group.enabled;
      _hasKey = hasKey;
      _loading = false;
    });
  }

  static String _presetBaseUrl(String provider) => provider == AiProvider.anthropic
      ? 'https://api.anthropic.com/v1'
      : 'https://api.openai.com/v1';

  List<String> get _modelList => _models.text
      .split('\n')
      .map((m) => m.trim())
      .where((m) => m.isNotEmpty)
      .toList();

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final repo = ref.read(settingsRepositoryProvider);
    final models = _modelList;
    final maxTokens = int.tryParse(_maxTokens.text.trim()) ?? 1024;
    final contextWindow = int.tryParse(_contextWindow.text.trim()) ?? 32000;
    final apiKey = _apiKey.text.trim();

    if (_isNew) {
      await repo.createModelGroup(
        name: _name.text.trim(),
        provider: _provider,
        baseUrl: _baseUrl.text.trim(),
        models: models,
        temperature: _temperature,
        maxTokens: maxTokens,
        contextWindow: contextWindow,
        enabled: _enabled,
        apiKey: apiKey.isEmpty ? null : apiKey,
      );
    } else {
      await repo.updateModelGroup(
        id: widget.groupId!,
        name: _name.text.trim(),
        provider: _provider,
        baseUrl: _baseUrl.text.trim(),
        models: models,
        temperature: _temperature,
        maxTokens: maxTokens,
        contextWindow: contextWindow,
        enabled: _enabled,
        apiKey: apiKey.isEmpty ? null : apiKey,
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已保存')),
    );
    Navigator.of(context).pop();
  }

  /// 测试连接（M3-18）：用当前表单内容构造一次最小请求。
  Future<void> _testConnection() async {
    final models = _modelList;
    if (models.isEmpty) {
      setState(() {
        _testOk = false;
        _testMessage = '请先填写至少一个模型名';
      });
      return;
    }
    final apiKey = _apiKey.text.trim().isNotEmpty
        ? _apiKey.text.trim()
        : (_isNew ? '' : await ref.read(settingsRepositoryProvider).readApiKey(widget.groupId!) ?? '');
    if (apiKey.isEmpty) {
      setState(() {
        _testOk = false;
        _testMessage = '请先填写 API Key';
      });
      return;
    }
    setState(() {
      _testing = true;
      _testMessage = null;
    });
    final group = ModelGroup(
      id: widget.groupId ?? 0,
      name: _name.text.trim(),
      provider: _provider,
      baseUrl: _baseUrl.text.trim(),
      apiKeyRef: '',
      models: SettingsRepository.encodeModels(models),
      temperature: _temperature,
      maxTokens: int.tryParse(_maxTokens.text.trim()) ?? 1024,
      contextWindow: int.tryParse(_contextWindow.text.trim()) ?? 32000,
      enabled: _enabled,
    );
    final result = await ref
        .read(aiServiceProvider)
        .testConnection(group: group, apiKey: apiKey);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testOk = result.ok;
      _testMessage = result.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? '新增模型组' : '编辑模型组'),
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
                      labelText: '名称',
                      hintText: '例如：DeepSeek 官方',
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? '请填写名称' : null,
                  ),
                  const SizedBox(height: 16),
                  const _FieldLabel('协议类型'),
                  SegmentedButton<String>(
                    segments: const <ButtonSegment<String>>[
                      ButtonSegment<String>(
                        value: AiProvider.openaiCompat,
                        label: Text('OpenAI 兼容'),
                      ),
                      ButtonSegment<String>(
                        value: AiProvider.anthropic,
                        label: Text('Anthropic'),
                      ),
                      ButtonSegment<String>(
                        value: AiProvider.responses,
                        label: Text('Responses'),
                      ),
                    ],
                    selected: <String>{_provider},
                    onSelectionChanged: (selection) {
                      final next = selection.first;
                      setState(() {
                        _provider = next;
                        _baseUrl.text = _presetBaseUrl(next);
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _baseUrl,
                    decoration: const InputDecoration(
                      labelText: 'Base URL',
                      helperText: '需包含 /v1，例如 https://api.deepseek.com/v1',
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? '请填写 Base URL' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _models,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: '模型列表',
                      helperText: '每行一个，第一行为默认使用的模型',
                    ),
                    validator: (_) => _modelList.isEmpty ? '请至少填写一个模型名' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _apiKey,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'API Key',
                      hintText: _hasKey ? '已保存，留空则不修改' : '粘贴服务商提供的 Key',
                      helperText: '仅保存在本机安全存储，不会随备份导出',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      const _FieldLabel('温度'),
                      Expanded(
                        child: Slider(
                          value: _temperature,
                          min: 0,
                          max: 2,
                          divisions: 20,
                          label: _temperature.toStringAsFixed(1),
                          activeColor: PaperColors.accent,
                          onChanged: (v) => setState(() => _temperature = v),
                        ),
                      ),
                      Text(_temperature.toStringAsFixed(1)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextFormField(
                          controller: _maxTokens,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: '输出上限 token'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _contextWindow,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '上下文窗口',
                            helperText: '预算取其 50%',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('启用'),
                    subtitle: const Text('停用后不会被任务映射使用'),
                    value: _enabled,
                    activeTrackColor: PaperColors.accent,
                    onChanged: (v) => setState(() => _enabled = v),
                  ),
                  const Divider(height: 24),
                  Row(
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: _testing ? null : _testConnection,
                        icon: _testing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 1.6),
                              )
                            : const Icon(Icons.wifi_tethering, size: 18),
                        label: const Text('测试连接'),
                      ),
                    ],
                  ),
                  if (_testMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _testMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          color: _testOk
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFB3261E),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Text(text, style: const TextStyle(color: PaperColors.inkSoft)),
    );
  }
}