import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/ai/ai_client_factory.dart';
import '../../core/ai/mcp/mcp_bridge.dart';
import '../../core/ai/mcp/mcp_oauth.dart';
import '../../core/ai/skills/skill.dart';
import '../../core/writing_stats.dart';
import '../../models/cloud_backup_config.dart';
import '../dao/app_setting_dao.dart';
import '../dao/model_group_dao.dart';
import '../db.dart';
import '../secure_key_store.dart';

/// AI 任务类型（与 AI_USAGE.task 及 `task_model_*` 键对应）。
class AiTask {
  const AiTask._();

  static const String continueWriting = 'continue';
  static const String inspire = 'inspire';
  static const String rewrite = 'rewrite';
  static const String check = 'check';

  /// ENH-05：AI 逐章摘要（前情回顾）与 AI 章纲扩写。
  static const String summary = 'summary';
  static const String outlineExpand = 'outline';

  /// ENH-06：本卷前情回顾（滚动摘要）。
  static const String volumeSummary = 'volume';

  /// ENH-22：设定一致性检查。
  static const String continuity = 'continuity';

  /// ENH-23：文风提取、设定补全、剧情推演、作品问答。
  static const String style = 'style';
  static const String extract = 'extract';
  static const String plan = 'plan';
  static const String chat = 'chat';

  static const List<String> all = <String>[
    continueWriting,
    inspire,
    rewrite,
    check,
    summary,
    outlineExpand,
    volumeSummary,
    continuity,
    style,
    extract,
    plan,
    chat,
  ];

  static String label(String task) {
    switch (task) {
      case continueWriting:
        return 'AI 续写';
      case inspire:
        return 'AI 灵感';
      case rewrite:
        return 'AI 改写';
      case check:
        return 'AI 感检查';
      case summary:
        return 'AI 逐章摘要';
      case outlineExpand:
        return 'AI 章纲扩写';
      case volumeSummary:
        return 'AI 本卷前情回顾';
      case continuity:
        return 'AI 设定一致性检查';
      case style:
        return 'AI 文风提取';
      case extract:
        return 'AI 设定补全';
      case plan:
        return 'AI 剧情推演';
      case chat:
        return 'AI 作品问答';
      default:
        return task;
    }
  }
}

/// 已解析出 key 的模型配置，供用例构造 AiClient。
class ResolvedModel {
  const ResolvedModel({required this.group, required this.apiKey});

  final ModelGroup group;
  final String apiKey;
}

/// 设置读写（ARCHITECTURE 6.1）：模型组、任务→模型映射落在 APP_SETTING，
/// API key 只经 [SecureKeyStore] 读写，库中仅存 apiKeyRef 引用。
class SettingsRepository {
  SettingsRepository(AppDatabase db, SecureKeyStore keyStore)
    : _groups = ModelGroupDao(db),
      _settings = AppSettingDao(db),
      _keyStore = keyStore;

  final ModelGroupDao _groups;
  final AppSettingDao _settings;
  final SecureKeyStore _keyStore;

  /// 模型组的 key 引用（库中只存这个标识，key 本体在安全存储）。
  static String keyRefFor(int groupId) => 'model_group_$groupId';

  // ---------- 模型组 ----------

  Stream<List<ModelGroup>> watchModelGroups() => _groups.watchAll();

  Future<List<ModelGroup>> listModelGroups() => _groups.findAll();

  Future<ModelGroup?> getModelGroup(int id) => _groups.findById(id);

  Future<int> createModelGroup({
    required String name,
    required String provider,
    required String baseUrl,
    required List<String> models,
    double temperature = 0.8,
    int maxTokens = 1024,
    int contextWindow = 32000,
    double inputPricePerMillion = 0,
    double outputPricePerMillion = 0,
    bool enabled = true,
    String? apiKey,
  }) async {
    final id = await _groups.insert(
      ModelGroupsCompanion.insert(
        name: name,
        baseUrl: baseUrl,
        provider: Value(_normalizeProvider(provider)),
        models: Value(encodeModels(models)),
        temperature: Value(temperature),
        maxTokens: Value(maxTokens),
        contextWindow: Value(contextWindow),
        inputPricePerMillion: Value(inputPricePerMillion),
        outputPricePerMillion: Value(outputPricePerMillion),
        enabled: Value(enabled),
      ),
    );
    final ref = keyRefFor(id);
    await _groups.updateGroup(id, ModelGroupsCompanion(apiKeyRef: Value(ref)));
    if (apiKey != null && apiKey.isNotEmpty) {
      await _keyStore.write(ref, apiKey);
    }
    return id;
  }

  Future<void> updateModelGroup({
    required int id,
    required String name,
    required String provider,
    required String baseUrl,
    required List<String> models,
    required double temperature,
    required int maxTokens,
    required int contextWindow,
    required bool enabled,
    double inputPricePerMillion = 0,
    double outputPricePerMillion = 0,
    String? apiKey,
  }) async {
    await _groups.updateGroup(
      id,
      ModelGroupsCompanion(
        name: Value(name),
        provider: Value(_normalizeProvider(provider)),
        baseUrl: Value(baseUrl),
        models: Value(encodeModels(models)),
        temperature: Value(temperature),
        maxTokens: Value(maxTokens),
        contextWindow: Value(contextWindow),
        inputPricePerMillion: Value(inputPricePerMillion),
        outputPricePerMillion: Value(outputPricePerMillion),
        enabled: Value(enabled),
      ),
    );
    if (apiKey != null && apiKey.isNotEmpty) {
      await _keyStore.write(keyRefFor(id), apiKey);
    }
  }

  Future<void> setModelGroupEnabled(int id, bool enabled) {
    return _groups.updateGroup(
      id,
      ModelGroupsCompanion(enabled: Value(enabled)),
    );
  }

  /// 删除模型组：同时清除安全存储中的 key 与引用该组的任务映射。
  Future<void> deleteModelGroup(int id) async {
    for (final task in AiTask.all) {
      if (await taskModelId(task) == id) {
        await _settings.remove(_taskKey(task));
      }
    }
    await _keyStore.delete(keyRefFor(id));
    await _groups.deleteById(id);
  }

  // ---------- key ----------

  Future<String?> readApiKey(int groupId) => _keyStore.read(keyRefFor(groupId));

  Future<bool> hasApiKey(int groupId) async {
    final value = await _keyStore.read(keyRefFor(groupId));
    return value != null && value.isNotEmpty;
  }

  // ---------- 任务 → 模型映射 ----------

  static String _taskKey(String task) => 'task_model_$task';

  Stream<int?> watchTaskModelId(String task) =>
      _settings.watch(_taskKey(task)).map((v) => int.tryParse(v ?? ''));

  Future<int?> taskModelId(String task) async =>
      int.tryParse(await _settings.get(_taskKey(task)) ?? '');

  Future<void> setTaskModel(String task, int? groupId) async {
    if (groupId == null) {
      await _settings.remove(_taskKey(task));
    } else {
      await _settings.set(_taskKey(task), '$groupId');
    }
  }

  /// 解析任务使用的模型组（须启用）。
  Future<ModelGroup?> resolveTaskModel(String task) async {
    final id = await taskModelId(task);
    if (id == null) return null;
    final group = await _groups.findById(id);
    if (group == null || !group.enabled) return null;
    return group;
  }

  /// 解析任务使用的模型组与 key；任一缺失返回 null（调用方引导至设置页）。
  Future<ResolvedModel?> resolveTaskModelWithKey(String task) async {
    final group = await resolveTaskModel(task);
    if (group == null) return null;
    final apiKey = await readApiKey(group.id);
    if (apiKey == null || apiKey.isEmpty) return null;
    return ResolvedModel(group: group, apiKey: apiKey);
  }

  // ---------- 检查问题处置率计数器（ARCHITECTURE 4.2 / PRD 7）----------

  static const String checkStatTotalKey = 'check_stat_total';
  static const String checkStatHandledKey = 'check_stat_handled';

  /// AI 首次联网前的告知是否已确认（COMPLIANCE §3）。
  static const String aiNoticeAckKey = 'ai_notice_ack';

  Future<bool> hasConfirmedAiNotice() async =>
      await getSetting(aiNoticeAckKey) == '1';

  Future<void> confirmAiNotice() => setSetting(aiNoticeAckKey, '1');

  /// 检查会话结束时累加问题总数与已处置数（替换 / 忽略）。
  Future<void> addCheckStats({required int total, required int handled}) async {
    if (total <= 0 && handled <= 0) return;
    final stats = await readCheckStats();
    await setSetting(checkStatTotalKey, '${stats.total + total}');
    await setSetting(checkStatHandledKey, '${stats.handled + handled}');
  }

  Future<({int total, int handled})> readCheckStats() async {
    final total = int.tryParse(await getSetting(checkStatTotalKey) ?? '') ?? 0;
    final handled =
        int.tryParse(await getSetting(checkStatHandledKey) ?? '') ?? 0;
    return (total: total, handled: handled);
  }

  /// 是否已具备可用的模型配置（用于编辑器入口的引导判断）。
  Future<bool> hasUsableModel() async {
    final groups = await _groups.findAll();
    for (final group in groups) {
      if (!group.enabled) continue;
      if (await hasApiKey(group.id)) return true;
    }
    return false;
  }

  // ---------- MCP server（B-02）----------

  /// MCP server 配置列表的落库键（仅存 URL / 名称 / 白名单，不含密钥）。
  static const String mcpServersKey = 'mcp_servers';

  /// 认证头文本在安全存储中的引用键（与 apiKeyRef 同策略）。
  static String mcpAuthRef(int id) => 'mcp_server_$id';

  /// OAuth 令牌在安全存储中的引用键（ENH-21；JSON：access/refresh/expiresAt）。
  static String mcpOAuthRef(int id) => 'mcp_oauth_$id';

  Future<List<McpServerConfig>> listMcpServers() async {
    final raw = await getSetting(mcpServersKey);
    if (raw == null || raw.trim().isEmpty) return <McpServerConfig>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => McpServerConfig.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
    } catch (_) {
      // 容忍历史脏数据
    }
    return <McpServerConfig>[];
  }

  /// 可参与工具调用的 server（已启用且填了 URL）。
  Future<List<McpServerConfig>> listEnabledMcpServers() async {
    final servers = await listMcpServers();
    return servers
        .where((s) => s.enabled && s.url.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<void> saveMcpServers(List<McpServerConfig> servers) => setSetting(
    mcpServersKey,
    jsonEncode(servers.map((s) => s.toJson()).toList()),
  );

  /// 新增 server，返回分配到的 id。
  Future<int> createMcpServer({
    required String name,
    required String url,
    bool enabled = true,
    List<String> allowedTools = const <String>[],
    String? authHeaders,
    McpAuthMode authMode = McpAuthMode.headers,
    String oauthClientId = '',
    List<String> oauthScopes = const <String>[],
  }) async {
    final servers = await listMcpServers();
    var nextId = 1;
    for (final server in servers) {
      if (server.id >= nextId) nextId = server.id + 1;
    }
    servers.add(
      McpServerConfig(
        id: nextId,
        name: name,
        url: url,
        enabled: enabled,
        allowedTools: allowedTools,
        authMode: authMode,
        oauthClientId: oauthClientId,
        oauthScopes: oauthScopes,
      ),
    );
    await saveMcpServers(servers);
    if (authHeaders != null && authHeaders.trim().isNotEmpty) {
      await _keyStore.write(mcpAuthRef(nextId), authHeaders);
    }
    return nextId;
  }

  /// 更新 server（不存在则追加）；[authHeaders] 为空表示保持原有认证头。
  Future<void> updateMcpServer(
    McpServerConfig config, {
    String? authHeaders,
  }) async {
    final servers = await listMcpServers();
    final index = servers.indexWhere((s) => s.id == config.id);
    if (index >= 0) {
      servers[index] = config;
    } else {
      servers.add(config);
    }
    await saveMcpServers(servers);
    if (authHeaders != null && authHeaders.trim().isNotEmpty) {
      await _keyStore.write(mcpAuthRef(config.id), authHeaders);
    }
  }

  /// 删除 server：同时清除安全存储中的认证头与 OAuth 令牌。
  Future<void> deleteMcpServer(int id) async {
    final servers = await listMcpServers();
    servers.removeWhere((s) => s.id == id);
    await saveMcpServers(servers);
    await _keyStore.delete(mcpAuthRef(id));
    await _keyStore.delete(mcpOAuthRef(id));
  }

  Future<String?> readMcpAuthHeaders(int id) => _keyStore.read(mcpAuthRef(id));

  Future<bool> hasMcpAuthHeaders(int id) async {
    final value = await _keyStore.read(mcpAuthRef(id));
    return value != null && value.trim().isNotEmpty;
  }

  /// 读取 server 的认证头并解析为请求头 map。
  Future<Map<String, String>> resolveMcpHeaders(int id) async =>
      parseAuthHeaders(await readMcpAuthHeaders(id) ?? '');

  // ---------- MCP OAuth 令牌（ENH-21）----------

  /// 读取已持久化的 OAuth 令牌；无记录或数据损坏返回 null。
  Future<McpOAuthTokens?> readMcpOAuthTokens(int id) async {
    final raw = await _keyStore.read(mcpOAuthRef(id));
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return McpOAuthTokens.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (_) {
      // 容忍历史脏数据
    }
    return null;
  }

  /// 是否已有可用的 OAuth 令牌（设置页授权状态展示用）。
  Future<bool> hasMcpOAuthTokens(int id) async =>
      await readMcpOAuthTokens(id) != null;

  Future<void> saveMcpOAuthTokens(int id, McpOAuthTokens tokens) =>
      _keyStore.write(mcpOAuthRef(id), jsonEncode(tokens.toJson()));

  Future<void> clearMcpOAuthTokens(int id) => _keyStore.delete(mcpOAuthRef(id));

  // ---------- 用户自定义 SKILL（B-03）----------

  /// SKILL 列表的落库键（纯文本配置，不含任何密钥）。
  static const String skillsKey = 'ai_skills';

  Future<List<Skill>> listSkills() async {
    final raw = await getSetting(skillsKey);
    if (raw == null || raw.trim().isEmpty) return <Skill>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Skill.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
    } catch (_) {
      // 容忍历史脏数据
    }
    return <Skill>[];
  }

  /// 参与编排注入的技能（已启用且填了指令）。
  Future<List<Skill>> listEnabledSkills() async {
    final skills = await listSkills();
    return skills
        .where((s) => s.enabled && s.instruction.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<void> saveSkills(List<Skill> skills) =>
      setSetting(skillsKey, jsonEncode(skills.map((s) => s.toJson()).toList()));

  /// 新增技能，返回分配到的 id。
  Future<int> createSkill({
    required String name,
    required String instruction,
    String description = '',
    List<String> allowedTools = const <String>[],
    Map<String, String> parameters = const <String, String>{},
  }) async {
    final skills = await listSkills();
    var nextId = 1;
    for (final skill in skills) {
      if (skill.id >= nextId) nextId = skill.id + 1;
    }
    skills.add(
      Skill(
        id: nextId,
        name: name,
        instruction: instruction,
        description: description,
        allowedTools: allowedTools,
        parameters: parameters,
      ),
    );
    await saveSkills(skills);
    return nextId;
  }

  /// 更新技能（不存在则追加）。
  Future<void> updateSkill(Skill skill) async {
    final skills = await listSkills();
    final index = skills.indexWhere((s) => s.id == skill.id);
    if (index >= 0) {
      skills[index] = skill;
    } else {
      skills.add(skill);
    }
    await saveSkills(skills);
  }

  Future<void> setSkillEnabled(int id, bool enabled) async {
    final skills = await listSkills();
    final index = skills.indexWhere((s) => s.id == id);
    if (index < 0) return;
    skills[index] = skills[index].copyWith(enabled: enabled);
    await saveSkills(skills);
  }

  Future<void> deleteSkill(int id) async {
    final skills = await listSkills();
    skills.removeWhere((s) => s.id == id);
    await saveSkills(skills);
  }

  // ---------- 写作统计设置（B-07）----------

  /// 每日字数目标（0 表示未设置目标）。
  static const String dailyWordTargetKey = 'daily_word_target';

  /// 番茄钟时长（分钟），夹紧到 1~120。
  static const String pomodoroMinutesKey = 'pomodoro_minutes';

  /// 某天已完成番茄钟数的落库键（按本地日期分键）。
  static String pomodoroDoneKey(DateTime date) =>
      'pomodoro_done_${writingDayKey(date)}';

  Future<int> dailyWordTarget() async =>
      int.tryParse(await getSetting(dailyWordTargetKey) ?? '') ?? 0;

  Future<void> setDailyWordTarget(int target) =>
      setSetting(dailyWordTargetKey, '${target < 0 ? 0 : target}');

  Future<int> pomodoroMinutes() async => _clampPomodoro(
    int.tryParse(await getSetting(pomodoroMinutesKey) ?? '') ?? 25,
  );

  Future<void> setPomodoroMinutes(int minutes) =>
      setSetting(pomodoroMinutesKey, '${_clampPomodoro(minutes)}');

  /// 今日已完成的番茄钟数量。
  Future<int> pomodoroDoneToday({DateTime? now}) async =>
      int.tryParse(
        await getSetting(pomodoroDoneKey(now ?? DateTime.now())) ?? '',
      ) ??
      0;

  /// 记录一个完成的番茄钟，返回今日累计数。
  Future<int> incrementPomodoroDone({DateTime? now}) async {
    final done = await pomodoroDoneToday(now: now);
    await setSetting(pomodoroDoneKey(now ?? DateTime.now()), '${done + 1}');
    return done + 1;
  }

  static int _clampPomodoro(int minutes) =>
      minutes < 1 ? 1 : (minutes > 120 ? 120 : minutes);

  // ---------- 云备份（B-08）----------

  /// 云备份非敏感配置的落库键（不含任何凭证）。
  static const String cloudBackupConfigKey = 'cloud_backup_config';

  /// 云凭证在安全存储中的固定引用键。
  static const String cloudAccessKeyRef = 'cloud_backup_access_key';
  static const String cloudSecretKeyRef = 'cloud_backup_secret_key';

  Future<CloudBackupConfig> cloudBackupConfig() async {
    final raw = await getSetting(cloudBackupConfigKey);
    if (raw == null || raw.trim().isEmpty) return const CloudBackupConfig();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return CloudBackupConfig.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (_) {
      // 容忍历史脏数据
    }
    return const CloudBackupConfig();
  }

  Future<void> saveCloudBackupConfig(CloudBackupConfig config) =>
      setSetting(cloudBackupConfigKey, jsonEncode(config.toJson()));

  Future<String?> readCloudAccessKey() => _keyStore.read(cloudAccessKeyRef);

  Future<String?> readCloudSecretKey() => _keyStore.read(cloudSecretKeyRef);

  /// 保存云凭证：空值表示保持原有（不落库、不进备份、不上传）。
  Future<void> saveCloudCredentials({
    String? accessKey,
    String? secretKey,
  }) async {
    if (accessKey != null && accessKey.trim().isNotEmpty) {
      await _keyStore.write(cloudAccessKeyRef, accessKey.trim());
    }
    if (secretKey != null && secretKey.trim().isNotEmpty) {
      await _keyStore.write(cloudSecretKeyRef, secretKey.trim());
    }
  }

  Future<void> clearCloudCredentials() async {
    await _keyStore.delete(cloudAccessKeyRef);
    await _keyStore.delete(cloudSecretKeyRef);
  }

  /// 上次成功云备份（手动或自动）的时间落库键。
  static const String cloudLastBackupAtKey = 'cloud_backup_last_at';

  /// 读取上次成功云备份时间；无记录返回 null。
  Future<DateTime?> cloudLastBackupAt() async {
    final raw = await getSetting(cloudLastBackupAtKey);
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw.trim());
  }

  /// 记录上次成功云备份时间（用于自动备份到期判据）。
  Future<void> setCloudLastBackupAt(DateTime time) =>
      setSetting(cloudLastBackupAtKey, time.toIso8601String());

  // ---------- 通用设置 ----------

  Future<String?> getSetting(String key) => _settings.get(key);

  Future<void> setSetting(String key, String value) =>
      _settings.set(key, value);

  /// 应用锁开关（ENH-25）：默认关闭，开启后启动 / 回前台需系统验证。
  static const String appLockEnabledKey = 'app_lock_enabled';

  Stream<bool> watchAppLockEnabled() =>
      _settings.watch(appLockEnabledKey).map((value) => value == '1');

  Future<bool> appLockEnabled() async =>
      await getSetting(appLockEnabledKey) == '1';

  Future<void> setAppLockEnabled(bool enabled) =>
      setSetting(appLockEnabledKey, enabled ? '1' : '0');

  /// 截屏 / 后台缩略图保护（ENH-26）：默认关闭。
  /// Android 通过 FLAG_SECURE 阻止截屏、录屏与最近任务缩略图；
  /// iOS 在应用失活时以原生遮罩覆盖窗口。
  static const String screenProtectionEnabledKey = 'screen_protection_enabled';

  Stream<bool> watchScreenProtectionEnabled() =>
      _settings.watch(screenProtectionEnabledKey).map((value) => value == '1');

  Future<bool> screenProtectionEnabled() async =>
      await getSetting(screenProtectionEnabledKey) == '1';

  Future<void> setScreenProtectionEnabled(bool enabled) =>
      setSetting(screenProtectionEnabledKey, enabled ? '1' : '0');

  /// 备份密码（ENH-26）：只存设备安全存储，不入库、不随备份导出。
  /// 开启加密后自动备份与手动备份共用该密码；关闭加密时删除。
  static const String backupPassphraseRef = 'backup_passphrase';

  Future<String?> readBackupPassphrase() => _keyStore.read(backupPassphraseRef);

  Future<void> saveBackupPassphrase(String passphrase) =>
      _keyStore.write(backupPassphraseRef, passphrase);

  Future<void> clearBackupPassphrase() => _keyStore.delete(backupPassphraseRef);

  /// 备份加密开关（ENH-26）：默认关闭；关闭时新备份为明文 zip。
  static const String backupEncryptionEnabledKey = 'backup_encryption_enabled';

  Stream<bool> watchBackupEncryptionEnabled() =>
      _settings.watch(backupEncryptionEnabledKey).map((value) => value == '1');

  Future<bool> backupEncryptionEnabled() async =>
      await getSetting(backupEncryptionEnabledKey) == '1';

  Future<void> setBackupEncryptionEnabled(bool enabled) =>
      setSetting(backupEncryptionEnabledKey, enabled ? '1' : '0');

  /// 月度 AI 预算（元，ENH-24）。0 表示未设置预算。
  static const String aiMonthlyBudgetKey = 'ai_monthly_budget_cny';

  Stream<double> watchMonthlyBudget() =>
      _settings.watch(aiMonthlyBudgetKey).map(_parseBudget);

  Future<double> monthlyBudget() async =>
      _parseBudget(await getSetting(aiMonthlyBudgetKey));

  Future<void> setMonthlyBudget(double value) {
    if (value <= 0) return _settings.remove(aiMonthlyBudgetKey);
    return setSetting(aiMonthlyBudgetKey, value.toStringAsFixed(2));
  }

  static double _parseBudget(String? raw) {
    final value = double.tryParse(raw?.trim() ?? '') ?? 0;
    return value.isFinite && value > 0 ? value : 0;
  }

  static String _normalizeProvider(String provider) {
    if (provider == AiProvider.anthropic) return AiProvider.anthropic;
    if (provider == AiProvider.responses) return AiProvider.responses;
    return AiProvider.openaiCompat;
  }

  static List<String> parseModels(String raw) {
    if (raw.trim().isEmpty) return const <String>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.whereType<String>().toList();
    } catch (_) {
      // 容忍历史脏数据
    }
    return const <String>[];
  }

  static String encodeModels(List<String> models) => jsonEncode(
    models.where((m) => m.trim().isNotEmpty).map((m) => m.trim()).toList(),
  );
}
