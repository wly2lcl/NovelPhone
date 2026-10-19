// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'NovelPhone';

  @override
  String get commonCancel => '取消';

  @override
  String get commonDelete => '删除';

  @override
  String get commonSettings => '设置';

  @override
  String commonCreateFailed(String detail) {
    return '创建失败：$detail';
  }

  @override
  String get worksSearchTooltip => '全局搜索';

  @override
  String get worksNew => '新建作品';

  @override
  String worksLoadFailed(String detail) {
    return '读取作品失败：$detail';
  }

  @override
  String get worksEmptyTitle => '还没有作品';

  @override
  String get worksEmptyHint => '把脑中的故事写下来，从第一部作品开始。';

  @override
  String get worksEmptyCreate => '创建第一部作品';

  @override
  String get worksPin => '置顶';

  @override
  String get worksUnpin => '取消置顶';

  @override
  String get worksDelete => '删除作品';

  @override
  String worksDeleteConfirm(String title) {
    return '删除《$title》？';
  }

  @override
  String get worksDeleteConfirmBody => '作品连同章节将移入回收站，30 天内可在回收站恢复。';

  @override
  String worksLastEdited(String time) {
    return '最后编辑 $time';
  }

  @override
  String worksLimitReached(int max) {
    return '作品数量已达上限 $max 部';
  }

  @override
  String chapterCount(int count) {
    return '$count 章';
  }

  @override
  String get newWorkTitleRequired => '请填写作品标题';

  @override
  String newWorkTitleMax(int max) {
    return '标题最多 $max 字';
  }

  @override
  String get newWorkTitleLabel => '作品标题';

  @override
  String get newWorkTitleHint => '例如：长夜行';

  @override
  String get newWorkCoverLabel => '封面色块';

  @override
  String get newWorkCreating => '创建中…';

  @override
  String get newWorkCreate => '创建作品';

  @override
  String get timeJustNow => '刚刚';

  @override
  String timeMinutesAgo(int count) {
    return '$count 分钟前';
  }

  @override
  String timeHoursAgo(int count) {
    return '$count 小时前';
  }

  @override
  String get timeYesterday => '昨天';

  @override
  String timeDaysAgo(int count) {
    return '$count 天前';
  }

  @override
  String wordCountExact(String count) {
    return '$count 字';
  }

  @override
  String wordCountWan(String value) {
    return '$value 万字';
  }

  @override
  String wordCountK(String value) {
    return '$value 千字';
  }

  @override
  String wordCountM(String value) {
    return '$value 百万字';
  }

  @override
  String tokenCountScaled(String value) {
    return '$value 万';
  }

  @override
  String tokenCountMega(String value) {
    return '$value 百万';
  }

  @override
  String get commonSave => '保存';

  @override
  String get commonConfirm => '确定';

  @override
  String get commonEdit => '编辑';

  @override
  String get commonMoreActions => '更多操作';

  @override
  String get commonRename => '重命名';

  @override
  String get commonRetry => '重试';

  @override
  String get commonClose => '关闭';

  @override
  String get commonRestore => '恢复';

  @override
  String get commonAdd => '添加';

  @override
  String get commonDone => '完成';

  @override
  String get commonCopy => '复制';

  @override
  String get commonBack => '返回';

  @override
  String get commonMore => '更多';

  @override
  String get commonClear => '清空';

  @override
  String get commonReset => '重置';

  @override
  String get commonUntitledChapter => '未命名章节';

  @override
  String get chapterStatusDraft => '草稿';

  @override
  String get chapterStatusRevising => '修订中';

  @override
  String get chapterStatusFinished => '定稿';

  @override
  String get settingTypeWorldview => '世界观';

  @override
  String get settingTypeLocation => '地点';

  @override
  String get settingTypeItem => '道具';

  @override
  String get localeSystem => '跟随系统';

  @override
  String get localeZh => '简体中文';

  @override
  String get localeEn => 'English';

  @override
  String get editorChapterTitleDialog => '章节标题';

  @override
  String get editorChapterSummaryTooltip => '本章梗概';

  @override
  String get editorAiToolsTooltip => 'AI 章节工具';

  @override
  String get editorToolSummarize => '生成本章摘要';

  @override
  String get editorToolVolumeSummary => '生成本卷前情回顾';

  @override
  String get editorToolOutlineExpand => 'AI 扩写本章纲';

  @override
  String get editorToolContinuity => '设定一致性检查';

  @override
  String get editorToolEditSummary => '查看/编辑本章摘要';

  @override
  String get editorExitFocusMode => '退出专注模式';

  @override
  String get editorFocusMode => '专注模式';

  @override
  String get editorBodyHint => '在这里写下正文…';

  @override
  String get editorSelectRewriteText => '请先在正文中选中要改写的段落';

  @override
  String get editorNeedOutlineSeed => '请先用顶栏「本章梗概」写一句话梗概，AI 再据此扩写';

  @override
  String get editorNoEarlierChapters => '本卷还没有更早的章节内容，暂无法生成本卷前情回顾';

  @override
  String get editorNoModelTitle => '尚未配置模型';

  @override
  String get editorNoModelBody => '请先在设置中添加模型组并填写 API Key，再使用 AI 功能。';

  @override
  String get editorContinuityTitle => '设定一致性检查';

  @override
  String get editorContinuityRunning => '正在检查设定一致性…';

  @override
  String get editorContinuityEmpty => '本章还没有正文，先写一些内容再检查';

  @override
  String get editorContinuityEmptyResult => '模型未返回内容，请重试';

  @override
  String get editorContinuityTruncated => '上下文超出模型窗口，部分设定资料已被省略，结果可能不完整。';

  @override
  String get editorLater => '稍后';

  @override
  String get editorGoSettings => '去设置';

  @override
  String get editorOriginalChanged => '原文已变化，请重新选中后再改写';

  @override
  String get editorSummaryTitle => '本章 AI 摘要';

  @override
  String get editorSummaryHint => 'AI 生成的前情摘要，可手动修改；用于后续章节的剧情衔接';

  @override
  String get editorSummaryStale => '正文已改动，摘要可能过期，建议重新生成';

  @override
  String get editorSaving => '保存中';

  @override
  String get editorSaved => '已保存';

  @override
  String get editorSaveFailed => '保存失败，点击重试';

  @override
  String get editorAiContinue => 'AI 续写';

  @override
  String get editorAiInspire => 'AI 灵感';

  @override
  String get editorAiRewrite => 'AI 改写';

  @override
  String get editorFind => '查找';

  @override
  String get editorAiCheck => 'AI 感';

  @override
  String get editorMoveParagraph => '段落移动';

  @override
  String get editorMoveParagraphUp => '本段上移';

  @override
  String get editorMoveParagraphDown => '本段下移';

  @override
  String get editorUndo => '撤销';

  @override
  String get editorRedo => '重做';

  @override
  String editorChapterWords(String words) {
    return '本章 $words';
  }

  @override
  String editorWholeWorkWords(String words) {
    return '全书 $words';
  }

  @override
  String editorLastSaved(String time) {
    return '最后保存 $time';
  }

  @override
  String get aiPanelTitleContinue => 'AI 续写';

  @override
  String get aiPanelTitleInspireIdeas => 'AI 灵感 · 桥段点子';

  @override
  String get aiPanelTitleInspireOpening => 'AI 灵感 · 开篇助手';

  @override
  String get aiPanelTitleRewrite => 'AI 改写';

  @override
  String get aiPanelTitleSummarize => 'AI 逐章摘要';

  @override
  String get aiPanelTitleOutlineExpand => 'AI 章纲扩写';

  @override
  String get aiPanelTitleVolumeSummary => 'AI 本卷前情回顾';

  @override
  String get aiPanelNewDirection => '换个方向';

  @override
  String get aiPanelDirectionHint => '补充一句方向指令，例如：让两人在此摊牌';

  @override
  String get aiPanelRegenerate => '重新生成';

  @override
  String aiPanelElapsedSeconds(int seconds) {
    return '$seconds 秒';
  }

  @override
  String get aiPanelCollapse => '收起';

  @override
  String get aiPanelModeIdeas => '桥段点子';

  @override
  String get aiPanelModeOpening => '开篇助手';

  @override
  String get aiPanelInstructionHint => '补充指令（可选），例如：让她的话更冷淡';

  @override
  String aiPanelLengthLabel(int count) {
    return '篇幅 $count 字';
  }

  @override
  String get aiPanelCandidateCount => '3 个候选';

  @override
  String aiPanelVersion(int n) {
    return '版本 $n';
  }

  @override
  String aiPanelContextTitle(int estimated, int budget) {
    return 'AI 看到的上下文（估算 $estimated / 预算 $budget token）';
  }

  @override
  String get aiPanelTruncated => '已省略较早前文';

  @override
  String get aiPanelResultHint => 'AI 产出将在这里流式显示，可直接编辑后再插入正文';

  @override
  String get aiPanelNeedsConfig => '尚未配置可用的模型与 API Key';

  @override
  String get aiPanelReplaceOriginal => '替换原文';

  @override
  String get aiPanelSaveSummary => '保存摘要';

  @override
  String get aiPanelSaveToOutline => '保存到章纲';

  @override
  String get aiPanelSaveVolumeSummary => '保存前情回顾';

  @override
  String get aiPanelInsertAtCursor => '插入光标处';

  @override
  String get aiPanelStop => '停止';

  @override
  String get aiPanelSaveToInspiration => '存入灵感箱';

  @override
  String get aiPanelDiscard => '放弃';

  @override
  String get aiPanelSavedToInspiration => '已存入灵感箱';

  @override
  String get rewriteIntentPolish => '润色';

  @override
  String get rewriteIntentExpand => '扩写';

  @override
  String get rewriteIntentCondense => '缩写';

  @override
  String get rewriteIntentTone => '改语气';

  @override
  String get aiSectionChapterText => '本章正文';

  @override
  String get aiSectionTaskMode => '任务模式';

  @override
  String get aiSectionChapterSynopsis => '本章梗概';

  @override
  String get aiSectionVolumeMaterial => '本卷素材（上一版回顾 + 新增章节）';

  @override
  String get aiSectionVolumeOutline => '卷级大纲';

  @override
  String get aiSectionPreviousSummary => '前文摘要';

  @override
  String get aiSectionCharacters => '相关角色卡';

  @override
  String get aiSectionSettings => '设定集';

  @override
  String get aiSectionChapterOutline => '本章章纲';

  @override
  String get aiSectionChapterTail => '本章已写内容（尾部）';

  @override
  String get aiSectionRequirements => '生成要求';

  @override
  String get aiSectionUserSkills => '用户技能';

  @override
  String get flavorTitle => 'AI 感检查';

  @override
  String flavorShownOfTotal(int shown, int total) {
    return '仅显示前 $shown 条，共 $total 条';
  }

  @override
  String flavorIssueCount(int count) {
    return '$count 处';
  }

  @override
  String flavorDeepProgress(int done, int total) {
    return '深检 $done/$total';
  }

  @override
  String get flavorScope => '范围';

  @override
  String get flavorWholeWork => '整部作品';

  @override
  String flavorChapterItem(String title, String words) {
    return '$title（$words）';
  }

  @override
  String flavorMetrics(int cliche, String density, String repeat, int dash) {
    return '套话 $cliche 处 · 密度 $density/千字 · 句式重复率 $repeat% · 破折号/省略号 $dash 处';
  }

  @override
  String get flavorDeepRunning => '深检中…';

  @override
  String get flavorDeepCheck => 'LLM 深检';

  @override
  String get flavorRecheck => '重新检查';

  @override
  String get flavorEditInEditor => '修改请在编辑器中完成';

  @override
  String flavorEstimatedTokens(String tokens) {
    return '预估 ~$tokens token';
  }

  @override
  String flavorMeasuredTokens(String input, String output) {
    return '实测 输入 $input + 输出 $output';
  }

  @override
  String get flavorNeedsConfigMessage => '尚未配置 AI 感检查所用的模型，深检不可用。';

  @override
  String flavorDeepFailed(String error) {
    return '深检失败（已保留规则结果）：$error';
  }

  @override
  String get flavorRetryDeepCheck => '重试深检';

  @override
  String get flavorFallbackNotice => '模型未返回结构化结果，原文如下：';

  @override
  String get flavorFilterAll => '全部';

  @override
  String get flavorSeverityHigh => '高';

  @override
  String get flavorSeverityMedium => '中';

  @override
  String get flavorSeverityLow => '低';

  @override
  String get flavorTypeCliche => '套话';

  @override
  String get flavorTypeRepetition => '句式重复';

  @override
  String get flavorTypeTranslationese => '翻译腔';

  @override
  String get flavorTypeOversummary => '过度总结';

  @override
  String get flavorTypePacing => '节奏拖沓';

  @override
  String get flavorEmptyHint => '该范围没有正文，无可检查内容';

  @override
  String get flavorCleanHint => '未发现明显的 AI 味问题';

  @override
  String get flavorDeepBadge => '深检';

  @override
  String get flavorLocateInText => '定位到原文';

  @override
  String get flavorDeleteWord => '一键删除该词';

  @override
  String flavorReplaceWith(String replacement) {
    return '一键替换为「$replacement」';
  }

  @override
  String get flavorIgnoreThis => '忽略这条';

  @override
  String flavorIgnoreAllType(String type) {
    return '忽略全部「$type」';
  }

  @override
  String flavorOriginalText(String excerpt) {
    return '原文：$excerpt';
  }

  @override
  String flavorSuggestion(String suggestion) {
    return '建议：$suggestion';
  }

  @override
  String get flavorLocate => '定位';

  @override
  String get flavorReplace => '替换';

  @override
  String get flavorIgnore => '忽略';

  @override
  String get flavorDeletedWord => '已删除该词';

  @override
  String flavorReplacedWith(String replacement) {
    return '已替换为「$replacement」';
  }

  @override
  String get flavorOriginalChanged => '原文已变化，请重新运行检查';

  @override
  String get snapshotCreated => '已创建快照';

  @override
  String get snapshotRestoreVersion => '恢复此版本';

  @override
  String get snapshotRestored => '已恢复到该版本';

  @override
  String get snapshotEmptyChapter => '（空章节）';

  @override
  String get snapshotHistoryTitle => '版本历史';

  @override
  String get snapshotCreate => '创建快照';

  @override
  String get snapshotEmptyHint => '还没有快照。写作途中点「创建快照」留存一个版本。';

  @override
  String get snapshotDiffAction => '与原稿对比';

  @override
  String get snapshotDiffTitle => '与当前版本对比';

  @override
  String get snapshotDiffNoChanges => '与当前版本一致，无改动';

  @override
  String snapshotDiffAdded(int count) {
    return '$count 段新增';
  }

  @override
  String snapshotDiffRemoved(int count) {
    return '$count 段删除';
  }

  @override
  String snapshotDiffHidden(int count) {
    return '… 省略 $count 行未改动';
  }

  @override
  String findReplaceReplacedCount(int count) {
    return '已替换 $count 处';
  }

  @override
  String get findReplaceFindHint => '查找';

  @override
  String get findReplaceCaseSensitive => '区分大小写';

  @override
  String findReplaceMatchCount(int count) {
    return '$count 处';
  }

  @override
  String get findReplaceReplacementHint => '替换为';

  @override
  String get findReplaceReplace => '替换';

  @override
  String get findReplaceReplaceAll => '全部替换';

  @override
  String get replaceTitle => '全书查找替换';

  @override
  String get replaceEmptyHint => '输入查找内容，预览全书章节的匹配结果';

  @override
  String replaceSummary(int matches, int chapters) {
    return '共 $matches 处命中，涉及 $chapters 章';
  }

  @override
  String get replaceConfirmTitle => '全部替换？';

  @override
  String replaceConfirmBody(int chapters, int matches) {
    return '将在 $chapters 章中共替换 $matches 处文本。替换前会自动为受影响章节创建快照，可在版本历史中恢复。';
  }

  @override
  String replaceDone(int chapters, int matches) {
    return '已替换：$chapters 章共 $matches 处';
  }

  @override
  String aiErrorNetwork(String detail) {
    return '网络请求失败：$detail';
  }

  @override
  String aiErrorAuth(int status) {
    return '鉴权失败（$status）：请到设置页检查 API Key';
  }

  @override
  String get aiErrorRateLimit => '请求过于频繁（429），请稍后重试';

  @override
  String aiErrorServer(int status) {
    return '模型服务暂时不可用（$status），请稍后重试';
  }

  @override
  String aiErrorContentFilter(String detail) {
    return '内容被模型服务商拒绝：$detail';
  }

  @override
  String aiErrorBadRequest(int status, String detail) {
    return '请求失败（$status）：$detail';
  }

  @override
  String aiErrorProviderError(String detail) {
    return '模型服务返回错误：$detail';
  }

  @override
  String aiErrorProviderFailed(String detail) {
    return '模型服务返回失败：$detail';
  }

  @override
  String get aiErrorIncompleteOutput => '模型输出被截断（incomplete），请缩短上下文或提高输出上限';

  @override
  String get aiErrorToolLoop => 'AI 工具调用轮次超限，已停止';

  @override
  String get cloudErrorEndpointMissing => '请先填写 Endpoint';

  @override
  String cloudErrorNetwork(String detail) {
    return '网络请求失败：$detail';
  }

  @override
  String get cloudErrorSignatureMismatch =>
      '签名校验失败（SignatureDoesNotMatch）：请检查 AccessKey / SecretKey、Endpoint 与 Region 是否匹配';

  @override
  String get cloudErrorForbidden => '访问被拒绝（403）：请检查 AccessKey / SecretKey 与桶权限';

  @override
  String get cloudErrorNotFound => '资源不存在（404）：请检查 Endpoint、桶名与路径前缀';

  @override
  String get cloudErrorClockSkew =>
      '设备时钟与服务器偏差过大（RequestTimeTooSkewed）：请校准系统时间';

  @override
  String cloudErrorHttp(int status, String detail) {
    return '云端返回 HTTP $status：$detail';
  }

  @override
  String get backupErrorInvalidZip => '文件不是有效的 zip 备份';

  @override
  String backupErrorMissingEntry(String entry) {
    return '备份文件缺少 $entry';
  }

  @override
  String get backupErrorDecodeFailed => '备份内容解析失败';

  @override
  String get backupErrorInvalidFormat => '备份内容格式不正确';

  @override
  String get backupErrorWrongFormat => '不是 NovelPhone 的备份文件';

  @override
  String get backupErrorNewerVersion => '备份来自更新版本的应用，请先升级 app';

  @override
  String get backupErrorChecksumMismatch => '备份文件校验失败，内容可能已损坏';

  @override
  String get backupErrorIncomplete => '备份内容不完整';

  @override
  String get backupPreviewTitle => '恢复前确认';

  @override
  String backupPreviewSource(String name) {
    return '备份文件：$name';
  }

  @override
  String backupPreviewExportedAt(String time) {
    return '导出时间：$time';
  }

  @override
  String backupPreviewSchema(int version) {
    return '数据版本：v$version';
  }

  @override
  String backupPreviewCounts(int works, int chapters, int characters) {
    return '$works 部作品 · $chapters 章 · $characters 个角色卡';
  }

  @override
  String get backupPreviewChecksumOk => 'SHA-256 完整性校验通过';

  @override
  String get backupPreviewChecksumLegacy => '旧版备份，未包含完整性校验信息';

  @override
  String get backupPreviewContinue => '继续恢复';

  @override
  String get modelTestOk => '连接成功';

  @override
  String modelTestOkDetail(String detail) {
    return '连接成功：$detail';
  }

  @override
  String get modelTestMissingModel => '请先填写模型名';

  @override
  String get modelTestMissingKey => '请先填写 API Key';

  @override
  String modelTestFailed(String detail) {
    return '连接失败：$detail';
  }

  @override
  String get searchHint => '搜索全部作品…';

  @override
  String get searchEmptyHint => '输入关键词，搜索全部作品的章节标题与正文。';

  @override
  String searchFailed(String detail) {
    return '搜索失败：$detail';
  }

  @override
  String searchNoResults(String keyword) {
    return '没有找到包含「$keyword」的章节';
  }

  @override
  String get statsTitle => '写作统计';

  @override
  String get statsTodayTitle => '今日写作';

  @override
  String get statsSetTarget => '设定目标';

  @override
  String statsWordsOfGoal(int goal) {
    return ' / $goal 字';
  }

  @override
  String statsWordsOnly(int count) {
    return ' 字';
  }

  @override
  String statsGoalRemaining(int count) {
    return '距离目标还差 $count 字';
  }

  @override
  String get statsGoalReached => '已达成今日目标';

  @override
  String get statsStreakTitle => '连续写作';

  @override
  String statsStreakDays(int count) {
    return '$count 天';
  }

  @override
  String get statsStreakKeepGoing => '保持下去，别断更';

  @override
  String get statsStreakStart => '今天写一点，开启连击';

  @override
  String get statsTrendTitle => '写作趋势';

  @override
  String get statsTrendRange7 => '7 天';

  @override
  String get statsTrendRange30 => '30 天';

  @override
  String statsTrendTotal(int days, int words) {
    return '近 $days 天共 $words 字';
  }

  @override
  String get statsTrendEmpty => '最近还没有写作记录';

  @override
  String get statsHeatmapTitle => '写作热力图';

  @override
  String statsHeatmapActiveDays(int count) {
    return '近一年共 $count 天有写作';
  }

  @override
  String get statsHeatmapLess => '少';

  @override
  String get statsHeatmapMore => '多';

  @override
  String get statsHeatmapWeekMon => '一';

  @override
  String get statsHeatmapWeekWed => '三';

  @override
  String get statsHeatmapWeekFri => '五';

  @override
  String get statsPomodoroTitle => '番茄钟';

  @override
  String statsPomodoroMinutes(int count) {
    return '$count 分钟';
  }

  @override
  String get statsPomodoroStart => '开始';

  @override
  String get statsPomodoroPause => '暂停';

  @override
  String statsPomodoroDoneToday(int count) {
    return '今日已完成 $count 个番茄钟';
  }

  @override
  String get statsPomodoroFinished => '番茄钟完成，休息一下吧';

  @override
  String get statsDailyTargetTitle => '每日字数目标';

  @override
  String get statsDailyTargetHint => '0 表示不设目标';

  @override
  String get statsDailyTargetUnit => '字';

  @override
  String get statsPomodoroDurationTitle => '番茄钟时长';

  @override
  String get statsPomodoroDurationHint => '1~120';

  @override
  String get statsPomodoroDurationUnit => '分钟';

  @override
  String get appearanceTitle => '写作外观';

  @override
  String get appearanceDarkPaper => '夜间纸张';

  @override
  String get appearanceDarkPaperSubtitle => '深色护眼背景，适合关灯后写作';

  @override
  String get appearanceFontSize => '正文字号';

  @override
  String get appearanceLineHeight => '行距';

  @override
  String get appearancePreview => '预览';

  @override
  String get appearancePreviewText =>
      '长夜将尽，她推开窗，风雪扑面而来。\n远处的灯一盏盏熄灭，只有案头那支蜡烛还亮着。';

  @override
  String get summaryEditTitle => '编辑本章梗概';

  @override
  String get summaryEditHint => '说明本章要发生什么（0-1000 字）；AI 章纲扩写也以此为一句话梗概';

  @override
  String get aiNoticeTitle => '使用 AI 前请知悉';

  @override
  String get aiNoticeBody =>
      '你的作品正文与设定默认只保存在本机。当你使用 AI 功能时，应用会把你自行配置的模型服务商所需的最小上下文（当前章节内容、章纲、相关角色卡等）通过网络直接发送给你配置的服务商，不会经过 NovelPhone 的服务器。\n\n你的 API Key 保存在设备安全区，不会上传。\n\n点击\"我已了解\"表示你已知悉并同意上述传输行为。';

  @override
  String get aiNoticeConfirm => '我已了解';

  @override
  String get settingsSectionAiModels => 'AI 与模型';

  @override
  String get settingsModelGroups => '模型组与 API Key';

  @override
  String get settingsModelGroupsSubtitle => '按服务商管理 key、baseUrl、模型列表与生成参数';

  @override
  String get settingsTaskMapping => '任务与模型映射';

  @override
  String get settingsTaskMappingSubtitle => '为续写、问答、体检等各类 AI 任务指定模型组';

  @override
  String get settingsTokenStats => 'Token 与采纳统计';

  @override
  String get settingsAiBudget => '月度 AI 预算';

  @override
  String settingsAiBudgetValue(String value) {
    return '¥$value / 月';
  }

  @override
  String get settingsMcpServers => 'MCP 工具服务';

  @override
  String get settingsMcpServersSubtitle => '接入远程 MCP server，把其工具提供给 AI 调用';

  @override
  String get settingsSkills => '自定义技能';

  @override
  String get settingsSkillsSubtitle => '附加指令与工具白名单，注入续写与灵感生成';

  @override
  String get settingsMcpAudit => 'MCP 调用审计';

  @override
  String get settingsMcpAuditSubtitle => '最近 100 次远程工具调用记录（仅存本机）';

  @override
  String get mcpAuditTitle => 'MCP 调用审计';

  @override
  String get mcpAuditEmpty => '还没有 MCP 工具调用记录';

  @override
  String get mcpAuditEmptyHint => '在灵感生成中启用 MCP 服务器后，远程工具调用会记录在这里。';

  @override
  String get mcpAuditClear => '清空记录';

  @override
  String get mcpAuditClearConfirmTitle => '清空调用审计？';

  @override
  String get mcpAuditClearConfirmBody => '全部调用记录将从本机删除，此操作不可恢复。';

  @override
  String get mcpAuditCleared => '调用记录已清空';

  @override
  String get mcpAuditSuccess => '成功';

  @override
  String get mcpAuditFailure => '失败';

  @override
  String get mcpAuditArguments => '参数';

  @override
  String get mcpAuditResult => '结果';

  @override
  String get settingsSectionWriting => '写作';

  @override
  String get settingsAppearance => '写作外观';

  @override
  String get settingsAppearanceSubtitle => '夜间纸张、正文字号与行距';

  @override
  String get settingsThemeMode => '深浅模式';

  @override
  String get themeModeSystem => '跟随系统';

  @override
  String get themeModeLight => '浅色';

  @override
  String get themeModeDark => '深色';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsWritingStats => '写作统计';

  @override
  String get settingsWritingStatsSubtitle => '每日字数目标、连续写作天数与番茄钟';

  @override
  String get settingsSectionData => '数据';

  @override
  String get settingsBackupHint => '作品数据全部保存在本机。卸载应用或换机前，请先「备份到文件」，否则数据将无法找回。';

  @override
  String get settingsBackupToFile => '备份到文件';

  @override
  String get settingsBackupToFileSubtitle => '导出全部作品与正文，用于换机或防丢失';

  @override
  String get settingsRestoreFromBackup => '从备份恢复';

  @override
  String get settingsRestoreFromBackupSubtitle => '选择备份文件，可合并为新作品或覆盖本机数据';

  @override
  String get settingsCloudBackup => '云备份';

  @override
  String get settingsCloudBackupSubtitle =>
      '备份到你自己的对象存储（S3 / OSS / COS 等），默认关闭';

  @override
  String get settingsTrash => '回收站';

  @override
  String get settingsTrashSubtitle => '恢复误删的作品与章节（保留 30 天）';

  @override
  String get trashTitle => '回收站';

  @override
  String get trashHint => '回收站中的内容保留 30 天，到期后自动永久删除。';

  @override
  String get trashTabWorks => '作品';

  @override
  String get trashTabChapters => '章节';

  @override
  String get trashEmptyWorks => '回收站里没有作品';

  @override
  String get trashEmptyChapters => '回收站里没有章节';

  @override
  String trashDeletedAt(String time) {
    return '删除于 $time';
  }

  @override
  String trashChapterMeta(String work, String volume) {
    return '《$work》· $volume';
  }

  @override
  String get trashRestore => '恢复';

  @override
  String get trashDeleteForever => '永久删除';

  @override
  String trashPurgeTitle(String title) {
    return '永久删除「$title」？';
  }

  @override
  String get trashPurgeWorkBody => '作品的全部章节、角色卡与章纲将被永久删除，且无法恢复。';

  @override
  String get trashPurgeChapterBody => '本章正文与版本历史将被永久删除，且无法恢复。';

  @override
  String get trashPurged => '已永久删除';

  @override
  String trashRestored(String title) {
    return '已恢复「$title」';
  }

  @override
  String get trashEmptyAction => '清空回收站';

  @override
  String get trashEmptyConfirmTitle => '清空回收站？';

  @override
  String get trashEmptyConfirmBody => '回收站中的全部作品与章节将被永久删除，且无法恢复。';

  @override
  String get trashEmptyDone => '回收站已清空';

  @override
  String trashLoadFailed(String detail) {
    return '加载失败：$detail';
  }

  @override
  String worksMovedToTrash(String title) {
    return '《$title》已移入回收站';
  }

  @override
  String get chaptersMovedToTrash => '章节已移入回收站';

  @override
  String get commonUndo => '撤销';

  @override
  String get modelGroupsNew => '新增模型组';

  @override
  String modelGroupsLoadFailed(String detail) {
    return '加载失败：$detail';
  }

  @override
  String get modelGroupsEmptyTitle => '还没有模型组';

  @override
  String get modelGroupsEmptyHint => '添加服务商与 API Key 后，续写与灵感功能才能使用';

  @override
  String get modelGroupsOpenAiCompat => 'OpenAI 兼容';

  @override
  String get modelGroupsNoModel => '未填写模型';

  @override
  String get modelGroupsModelSeparator => '、';

  @override
  String get modelGroupsNoKey => '未填 Key';

  @override
  String get modelGroupsDeleteTitle => '删除模型组';

  @override
  String modelGroupsDeleteConfirm(String name) {
    return '删除「$name」后，其 API Key 也会一并从本机移除。';
  }

  @override
  String get modelGroupsDeleted => '已删除模型组';

  @override
  String get modelEditTitle => '编辑模型组';

  @override
  String get modelEditNameLabel => '名称';

  @override
  String get modelEditNameHint => '例如：DeepSeek 官方';

  @override
  String get modelEditNameRequired => '请填写名称';

  @override
  String get modelEditProtocolLabel => '协议类型';

  @override
  String get modelEditBaseUrlHelper => '需包含 /v1，例如 https://api.deepseek.com/v1';

  @override
  String get modelEditBaseUrlRequired => '请填写 Base URL';

  @override
  String get modelEditModelsLabel => '模型列表';

  @override
  String get modelEditModelsHelper => '每行一个，第一行为默认使用的模型';

  @override
  String get modelEditModelsRequired => '请至少填写一个模型名';

  @override
  String get modelEditApiKeySaved => '已保存，留空则不修改';

  @override
  String get modelEditApiKeyHint => '粘贴服务商提供的 Key';

  @override
  String get modelEditApiKeyHelper => '仅保存在本机安全存储，不会随备份导出';

  @override
  String get modelEditTemperature => '温度';

  @override
  String get modelEditMaxTokensLabel => '输出上限 token';

  @override
  String get modelEditContextWindow => '上下文窗口';

  @override
  String get modelEditContextWindowHelper => '预算取其 50%';

  @override
  String get modelEditEnabled => '启用';

  @override
  String get modelEditEnabledSubtitle => '停用后不会被任务映射使用';

  @override
  String get modelEditTestConnection => '测试连接';

  @override
  String get modelEditTestNoModel => '请先填写至少一个模型名';

  @override
  String get modelEditTestNoApiKey => '请先填写 API Key';

  @override
  String get modelEditSaved => '已保存';

  @override
  String taskMapLoadFailed(String detail) {
    return '加载失败：$detail';
  }

  @override
  String get taskMapEmptyHint => '请先在「模型组与 API Key」中添加模型组';

  @override
  String get taskMapIntro => '为每类 AI 任务指定使用的模型组；未指定则对应功能不可用。';

  @override
  String get taskMapUnassigned => '未指定';

  @override
  String get aiTaskContinue => 'AI 续写';

  @override
  String get aiTaskInspire => 'AI 灵感';

  @override
  String get aiTaskRewrite => 'AI 改写';

  @override
  String get aiTaskCheck => 'AI 感检查';

  @override
  String get aiTaskSummary => 'AI 逐章摘要';

  @override
  String get aiTaskOutlineExpand => 'AI 章纲扩写';

  @override
  String get aiTaskVolumeSummary => 'AI 本卷前情回顾';

  @override
  String get aiTaskContinuity => 'AI 设定一致性检查';

  @override
  String get tokenStatsResetTitle => '重置统计';

  @override
  String get tokenStatsResetBody => '清空全部生成与采纳记录，不可恢复。';

  @override
  String tokenStatsLoadFailed(String detail) {
    return '加载失败：$detail';
  }

  @override
  String get tokenStatsEmpty => '还没有生成记录';

  @override
  String get tokenStatsCalls => '生成次数';

  @override
  String get tokenStatsTotalTokens => 'Token 合计';

  @override
  String get tokenStatsAdoptionRate => '采纳率';

  @override
  String get tokenStatsIgnoreRate => '忽略率';

  @override
  String get tokenStatsCheckHandledRate => '检查问题处置率';

  @override
  String tokenStatsRowCalls(int count) {
    return '$count 次';
  }

  @override
  String tokenStatsRowTokens(String prompt, String completion) {
    return '输入 $prompt · 输出 $completion';
  }

  @override
  String tokenStatsRowChars(int output, int adopted) {
    return '生成 $output 字 · 采纳 $adopted 字';
  }

  @override
  String tokenStatsRowCounts(int adopted, int ignored) {
    return '采纳 $adopted 次 · 忽略 $ignored 次';
  }

  @override
  String get statStatusAdopted => '已采纳';

  @override
  String get statStatusIgnored => '已忽略';

  @override
  String get statStatusRegenerated => '重新生成';

  @override
  String get statStatusAborted => '已中止';

  @override
  String get statStatusPending => '待处置';

  @override
  String get backupShareTitle => 'NovelPhone 备份';

  @override
  String backupRestoreDone(int works, int chapters, int characters) {
    return '恢复完成：$works 部作品、$chapters 章、$characters 个角色卡';
  }

  @override
  String get backupRestoreModeTitle => '选择恢复方式';

  @override
  String get backupRestoreModeBody =>
      '合并：把备份中的作品作为新作品导入，不清空现有数据。\n覆盖：先清空本机全部作品，再按备份原样还原，无法撤销。';

  @override
  String get backupRestoreModeMerge => '合并';

  @override
  String get backupRestoreModeOverwrite => '覆盖';

  @override
  String get cloudSaved => '已保存';

  @override
  String get cloudTitle => '云备份';

  @override
  String get cloudEnable => '启用云备份';

  @override
  String get cloudEnableSubtitle => '关闭时不联网、不产生任何云端请求';

  @override
  String get cloudProviderLabel => '服务商';

  @override
  String get cloudProviderAwsS3 => 'AWS S3';

  @override
  String get cloudProviderAliyunOss => '阿里云 OSS';

  @override
  String get cloudProviderQiniuKodo => '七牛云 Kodo';

  @override
  String get cloudProviderTencentCos => '腾讯云 COS';

  @override
  String get cloudProviderHuaweiObs => '华为云 OBS';

  @override
  String get cloudRegionHintAwsS3 => '例如 us-east-1';

  @override
  String get cloudRegionHintAliyunOss => '例如 cn-hangzhou';

  @override
  String get cloudRegionHintQiniuKodo => '例如 cn-east-1';

  @override
  String get cloudRegionHintTencentCos => '例如 ap-guangzhou';

  @override
  String get cloudRegionHintHuaweiObs => '例如 cn-north-4';

  @override
  String get cloudEndpointHintAwsS3 => '不带桶名，例如 s3.us-east-1.amazonaws.com';

  @override
  String get cloudEndpointHintAliyunOss =>
      '不带桶名，例如 oss-cn-hangzhou.aliyuncs.com';

  @override
  String get cloudEndpointHintQiniuKodo => '不带桶名，例如 s3-cn-east-1.qiniucs.com';

  @override
  String get cloudEndpointHintTencentCos =>
      '不带桶名，例如 cos.ap-guangzhou.myqcloud.com';

  @override
  String get cloudEndpointHintHuaweiObs =>
      '不带桶名，例如 obs.cn-north-4.myhuaweicloud.com';

  @override
  String get cloudRegionRequired => '请填写Region';

  @override
  String get cloudEndpointRequired => '请填写Endpoint';

  @override
  String get cloudBucketRequired => '请填写桶名';

  @override
  String get cloudBucketLabel => '存储桶 Bucket';

  @override
  String get cloudPrefixLabel => '路径前缀';

  @override
  String cloudPrefixHelper(String prefix) {
    return '默认 $prefix';
  }

  @override
  String get cloudKeepCountLabel => '保留份数';

  @override
  String get cloudKeepCountHelper => '超出后自动删除最旧的备份，最小 1';

  @override
  String get cloudKeepCountInvalid => '请填写不小于 1 的整数';

  @override
  String get cloudCredentialsHelper => '仅保存在本机安全存储，不会随备份导出';

  @override
  String get cloudSecretHintSaved => '已保存，留空则不修改';

  @override
  String get cloudTestConnection => '测试连接';

  @override
  String get cloudBackupNow => '立即备份';

  @override
  String get cloudRefreshRemote => '刷新远端备份';

  @override
  String get cloudTestOk => '连接成功：桶与凭证可用';

  @override
  String cloudBackupOk(String objectKey, String size) {
    return '备份成功：$objectKey（$size）';
  }

  @override
  String cloudBackupOkPruned(int count) {
    return '，已清理 $count 份旧备份';
  }

  @override
  String get cloudRemoteEmpty => '远端暂无备份';

  @override
  String cloudRemoteCount(int count) {
    return '远端共 $count 份备份';
  }

  @override
  String get cloudNeedEndpointRegionBucket => '请先完整填写 Endpoint、Region 与桶名';

  @override
  String get cloudNeedCredentials => '请先填写 AccessKey 与 SecretKey';

  @override
  String get cloudAutoTitle => '自动备份';

  @override
  String get cloudAutoSubtitle => '开启后于启动 / 回到前台时，距上次备份满所选间隔则自动备份';

  @override
  String get cloudIntervalLabel => '备份频率';

  @override
  String get cloudIntervalEvery12h => '每 12 小时';

  @override
  String get cloudIntervalDaily => '每天';

  @override
  String get cloudIntervalWeekly => '每周';

  @override
  String get cloudRemoteSection => '远端备份';

  @override
  String get cloudRemoteTapRefresh => '点击「刷新远端备份」查看已有备份';

  @override
  String get cloudPrivacyHint =>
      '云备份默认关闭，仅在你开启并触发时联网（含开启自动备份后按频率触发）。备份内容与本地 zip 一致（含正文，不含任何 API Key）；AccessKey / SecretKey 只保存在本机安全存储。';

  @override
  String get mcpDeleteTitle => '删除 MCP 服务';

  @override
  String mcpDeleteBody(String name) {
    return '删除「$name」后，其认证头也会一并从本机移除。';
  }

  @override
  String get mcpTitle => 'MCP 工具服务';

  @override
  String get mcpAdd => '新增服务';

  @override
  String get mcpAllTools => '全部工具可用';

  @override
  String mcpWhitelist(String tools) {
    return '白名单：$tools';
  }

  @override
  String get mcpListSeparator => '、';

  @override
  String get mcpEmptyTitle => '还没有 MCP 服务';

  @override
  String get mcpEmptyHint => '添加远程 MCP server 后，其工具会在「桥段点子」生成时供 AI 调用';

  @override
  String get mcpSaved => '已保存';

  @override
  String get mcpEndpointMissing => '请先填写 MCP 端点地址';

  @override
  String get mcpTestOkNoTools => '连接成功，但该服务未暴露工具';

  @override
  String mcpTestOkTools(int count, String names) {
    return '连接成功，$count 个工具：$names';
  }

  @override
  String mcpTestFailed(String detail) {
    return '连接失败：$detail';
  }

  @override
  String get mcpNewTitle => '新增 MCP 服务';

  @override
  String get mcpEditTitle => '编辑 MCP 服务';

  @override
  String get mcpNameLabel => '名称';

  @override
  String get mcpNameHint => '例如：我的本地 MCP 服务';

  @override
  String get mcpNameRequired => '请填写名称';

  @override
  String get mcpEndpointLabel => 'MCP 端点地址';

  @override
  String get mcpEndpointHelper =>
      'Streamable HTTP 完整地址，例如 https://example.com/mcp';

  @override
  String get mcpEndpointRequired => '请填写端点地址';

  @override
  String get mcpEndpointInvalid => '请填写带 http(s):// 的完整地址';

  @override
  String get mcpAuthLabel => '认证请求头';

  @override
  String get mcpAuthHintSaved => '已保存，留空则不修改';

  @override
  String get mcpAuthHint => '每行一条，例如 Authorization: Bearer xxx';

  @override
  String get mcpAuthHelper => '仅保存在本机安全存储，不会随备份导出';

  @override
  String get mcpToolsLabel => '工具白名单';

  @override
  String get mcpToolsHelper => '每行一个远程工具名；留空表示全部允许';

  @override
  String get mcpEnable => '启用';

  @override
  String get mcpEnableSubtitle => '停用后其工具不会暴露给 AI';

  @override
  String get mcpTestConnection => '测试连接';

  @override
  String mcpEnableSwitch(String name) {
    return '启用「$name」';
  }

  @override
  String get mcpAuthModeLabel => '认证方式';

  @override
  String get mcpAuthModeHeaders => '自定义请求头';

  @override
  String get mcpAuthModeOAuth => 'OAuth 2.1（PKCE）';

  @override
  String get mcpOAuthClientIdLabel => 'OAuth Client ID（选填）';

  @override
  String get mcpOAuthClientIdHint => '留空则自动动态注册';

  @override
  String get mcpOAuthClientIdHelper => '预注册的客户端 ID；动态注册成功后会自动回填并保存';

  @override
  String get mcpOAuthScopesLabel => '授权范围（选填）';

  @override
  String get mcpOAuthScopesHelper => '空格或逗号分隔；留空则由服务器决定';

  @override
  String get mcpOAuthStatusAuthorized => '已授权：访问令牌已保存在本机';

  @override
  String get mcpOAuthStatusNotAuthorized => '未授权：请先完成授权，OAuth 服务器才能使用';

  @override
  String get mcpOAuthAuthorize => '开始授权';

  @override
  String get mcpOAuthReauthorize => '重新授权';

  @override
  String get mcpOAuthClear => '清除授权';

  @override
  String get mcpOAuthClearTitle => '清除 OAuth 授权';

  @override
  String get mcpOAuthClearBody => '将删除本服务器已保存的访问令牌；之后使用该服务器的功能会提示重新授权。';

  @override
  String get mcpOAuthCleared => '已清除授权令牌';

  @override
  String get mcpOAuthSuccess => '授权成功，令牌已保存';

  @override
  String mcpOAuthFailed(String detail) {
    return '授权失败：$detail';
  }

  @override
  String get mcpOAuthSaveFirst => '请先保存该服务，再测试连接或授权';

  @override
  String get mcpOAuthSecureHint =>
      '令牌只保存在本机安全存储，不会随备份导出；授权在系统浏览器中完成（PKCE，无客户端密钥落地）。';

  @override
  String get skillImport => '导入技能';

  @override
  String get skillExport => '导出 / 分享';

  @override
  String skillExportFailed(String detail) {
    return '导出失败：$detail';
  }

  @override
  String get skillImportFromFile => '从文件导入';

  @override
  String get skillImportFromPaste => '粘贴导入';

  @override
  String get skillImportPasteTitle => '粘贴技能 Markdown';

  @override
  String get skillImportPasteHint => '粘贴以 front matter（---）开头的技能文本';

  @override
  String get skillImportPreviewTitle => '确认导入技能';

  @override
  String skillImportOk(String name) {
    return '已导入「$name」';
  }

  @override
  String skillImportFailed(String detail) {
    return '导入失败：$detail';
  }

  @override
  String get skillDescriptionLabel => '技能简介（选填）';

  @override
  String get skillDescriptionHint => '一句话说明这个技能的用途';

  @override
  String commonToggleSwitch(String name) {
    return '启用「$name」';
  }

  @override
  String newWorkCoverOptionLabel(int index) {
    return '封面色块 $index';
  }

  @override
  String get a11yHeatmapLabel => '写作热力图：色块越深，表示当天写下的字数越多';

  @override
  String get a11yTrendChartLabel => '字数趋势图：按天统计的写作字数';

  @override
  String get a11yRelationGraphLabel => '人物关系图，节点可拖动调整位置';

  @override
  String get skillDeleteTitle => '删除技能';

  @override
  String skillDeleteBody(String name) {
    return '删除「$name」后，其指令不再注入 AI 生成。';
  }

  @override
  String get skillTitle => '自定义技能';

  @override
  String get skillAdd => '新增技能';

  @override
  String get skillToolsUnlimited => '工具：不限制';

  @override
  String skillToolsWhitelist(String tools) {
    return '工具白名单：$tools';
  }

  @override
  String get skillListSeparator => '、';

  @override
  String get skillEmptyTitle => '还没有自定义技能';

  @override
  String get skillEmptyHint =>
      '写一段附加指令（如「只用短句」「避免旁白解释」），启用后会注入续写与灵感生成的 system 提示';

  @override
  String get skillSaved => '已保存';

  @override
  String get skillNewTitle => '新增技能';

  @override
  String get skillEditTitle => '编辑技能';

  @override
  String get skillNameLabel => '技能名称';

  @override
  String get skillNameHint => '例如：冷硬短句';

  @override
  String get skillNameRequired => '请填写技能名称';

  @override
  String get skillInstructionLabel => '指令文本';

  @override
  String get skillInstructionHint => '例如：只用短句，避免解释性旁白，对话不写语气副词。';

  @override
  String get skillInstructionHelper => '会作为附加 system 指令注入续写与灵感生成';

  @override
  String get skillInstructionRequired => '请填写指令文本';

  @override
  String get skillParamsLabel => '参数模板（可选）';

  @override
  String get skillParamsHint => '每行一条 键=值，例如 字数=800';

  @override
  String skillParamsHelper(String open, String close) {
    return '在指令中用 $open参数名$close 引用，注入时替换为对应值';
  }

  @override
  String get skillToolsLabel => '工具白名单（可选）';

  @override
  String get skillToolsHint => '每行一个工具名，例如 get_chapter';

  @override
  String get skillToolsHelper =>
      '留空表示不限制；内置工具 get_chapter / get_characters / get_outline，MCP 工具以 mcp_ 开头';

  @override
  String get skillEnable => '启用';

  @override
  String get skillEnableSubtitle => '停用后不注入，也不参与工具白名单';

  @override
  String get workDetailTitleFallback => '作品';

  @override
  String get workDetailTabChapters => '章节';

  @override
  String get workDetailTabCharacters => '角色卡';

  @override
  String get workDetailTabWorldbuilding => '设定集';

  @override
  String get workDetailTabOutline => '章纲';

  @override
  String get workDetailRunFlavorCheck => '运行 AI 感检查';

  @override
  String get workDetailImportTxtDocx => '导入 txt / docx / Markdown / EPUB';

  @override
  String get workDetailInspirationsTitle => '灵感箱';

  @override
  String get workDetailAiSettings => 'AI 设置';

  @override
  String get workDetailStyleGuide => '文风档案';

  @override
  String get styleGuideTitle => '文风档案';

  @override
  String get styleGuideIntro => '文风档案会注入续写、改写、开篇与剧情推演，让 AI 更贴近你的写法。';

  @override
  String get styleGuidePerspective => '叙事人称与视角';

  @override
  String get styleGuidePerspectiveHint => '例如：第三人称限知，跟随女主';

  @override
  String get styleGuideTone => '语言风格与基调';

  @override
  String get styleGuideToneHint => '例如：冷峻克制，短句为主，少用形容词';

  @override
  String get styleGuideTaboos => '禁忌与偏好';

  @override
  String get styleGuideTaboosHint => '例如：不用网络流行语，少用感叹号';

  @override
  String get styleGuideSample => '示例段落';

  @override
  String get styleGuideSampleHint => '粘贴一段你的正文，AI 会模仿语感与节奏';

  @override
  String get styleGuideExtract => 'AI 从最近章节提取';

  @override
  String get styleGuideExtracting => '正在分析最近章节…';

  @override
  String get styleGuideExtractTitle => 'AI 提取结果';

  @override
  String get styleGuideExtractConfirm => '将用 AI 结果覆盖对应字段，是否继续？';

  @override
  String get styleGuideApply => '填入表单';

  @override
  String get styleGuideApplied => '已填入表单，确认后请保存';

  @override
  String get styleGuideSaved => '文风档案已保存';

  @override
  String styleGuideExtractFailed(String message) {
    return '提取失败：$message';
  }

  @override
  String get modelEditInputPrice => '输入单价（元/百万 token）';

  @override
  String get modelEditOutputPrice => '输出单价（元/百万 token）';

  @override
  String get modelEditPriceHelper => '选填，用于 token 统计页估算费用';

  @override
  String get entityExtractTitle => 'AI 设定补全';

  @override
  String get entityExtractIntro => '从最近章节抽取角色与世界观 / 地点 / 道具，预览去重后可一键建档。';

  @override
  String get entityExtractStart => 'AI 抽取设定';

  @override
  String get entityExtractRunning => '正在阅读最近章节…';

  @override
  String get entityExtractEmpty => '没有发现可补充的新条目。';

  @override
  String get entityExtractParseFailed => 'AI 返回内容无法解析，请重试。';

  @override
  String get entityExtractCharacters => '角色卡';

  @override
  String get entityExtractSettings => '设定条目';

  @override
  String get entityExtractRelations => '角色关系';

  @override
  String get entityExtractRelationMissing => '关系两端的角色不在本轮抽取中';

  @override
  String get entityExtractExisting => '已存在';

  @override
  String entityExtractApply(int count) {
    return '应用所选（$count）';
  }

  @override
  String entityExtractApplied(int characters, int settings, int relations) {
    return '已添加 $characters 个角色、$settings 条设定、$relations 条关系';
  }

  @override
  String entityExtractFailed(String message) {
    return '抽取失败：$message';
  }

  @override
  String get workDetailRenameWork => '重命名作品';

  @override
  String workDetailImportedCount(int count) {
    return '已导入 $count 章';
  }

  @override
  String get workDetailRecordInspiration => '记录灵感';

  @override
  String get workDetailEditInspiration => '编辑灵感';

  @override
  String get workDetailInspirationHint => '写点什么…';

  @override
  String get workDetailInspirationsEmpty => '灵感箱是空的';

  @override
  String get workDetailInspirationsEmptyHint =>
      '随手记下桥段、设定或一句对白，AI 灵感产出的点子也会存到这里。';

  @override
  String get workDetailDeleteInspirationConfirm => '删除这条灵感？';

  @override
  String get chaptersNewVolume => '新建卷';

  @override
  String get chaptersNewVolumeHint => '例如：第二卷 风起';

  @override
  String get chaptersCreate => '创建';

  @override
  String get chaptersEmptyTitle => '还没有章节';

  @override
  String get chaptersEmptyHint => '在下方「新建卷」后即可开始写第一章。';

  @override
  String chaptersVolumeHeader(String volume, int count) {
    return '$volume（$count 章）';
  }

  @override
  String get chaptersVolumeActions => '卷操作';

  @override
  String get chaptersRenameVolume => '重命名卷';

  @override
  String get chaptersVolumeSummaryAction => '查看/编辑本卷前情回顾';

  @override
  String get chaptersMoveUp => '上移';

  @override
  String get chaptersMoveDown => '下移';

  @override
  String get chaptersDeleteVolume => '删除卷';

  @override
  String get chaptersVolumeSummaryTitle => '本卷前情回顾';

  @override
  String get chaptersVolumeSummaryHint => 'AI 生成或手写的本卷前情回顾，用于后续章节的剧情衔接';

  @override
  String chaptersDeleteVolumeConfirm(String volume) {
    return '删除「$volume」？';
  }

  @override
  String get chaptersDeleteVolumeEmptyBody => '该卷下没有章节。';

  @override
  String chaptersDeleteVolumeBody(int count) {
    return '该卷下的 $count 个章节会一并删除，此操作不可恢复。';
  }

  @override
  String get chaptersAddChapterInVolume => '在本卷新建章节';

  @override
  String get chaptersRenameChapter => '重命名章节';

  @override
  String get chaptersMoveToVolume => '移动到其他卷';

  @override
  String chaptersMarkAs(String status) {
    return '标记为$status';
  }

  @override
  String get chaptersDeleteChapter => '删除章节';

  @override
  String get chaptersNoOtherVolume => '没有其他卷可移动';

  @override
  String chaptersDeleteChapterConfirm(String title) {
    return '删除「$title」？';
  }

  @override
  String get chaptersDeleteChapterBody => '章节将移入回收站，30 天内可在回收站恢复。';

  @override
  String get outlineOrphanSection => '未关联章节的梗概';

  @override
  String get outlineEmptyEntry => '（空梗概）';

  @override
  String get outlineEmptyTitle => '还没有章纲';

  @override
  String get outlineEmptyHint => '先在「章节」Tab 创建章节，即可为每章写一句话梗概。';

  @override
  String get outlineNoSummary => '未填写梗概';

  @override
  String get charactersNewCard => '新建角色卡';

  @override
  String get charactersEditCard => '编辑角色卡';

  @override
  String get charactersEmptyTitle => '还没有角色卡';

  @override
  String get charactersEmptyHint => '为角色建立档案后，AI 续写与灵感会自动带上相关角色设定。';

  @override
  String get charactersIdentityEmpty => '身份未填写';

  @override
  String get charactersNameLabel => '姓名（必填，1-20 字）';

  @override
  String get charactersIdentityLabel => '身份';

  @override
  String get charactersTagsLabel => '性格标签（最多 10 个，空格或逗号分隔）';

  @override
  String get charactersAppearanceLabel => '外貌特征';

  @override
  String get charactersRelationsLabel => '人际关系';

  @override
  String get charactersArcLabel => '角色弧光';

  @override
  String get charactersNameError => '姓名需 1-20 字';

  @override
  String get charactersTagsError => '性格标签最多 10 个';

  @override
  String charactersDeleteConfirm(String name) {
    return '删除「$name」？';
  }

  @override
  String get charactersDeleteBody => '删除后角色卡不可恢复。';

  @override
  String get worldbuildingNewEntry => '新建设定';

  @override
  String get worldbuildingEditEntry => '编辑设定';

  @override
  String worldbuildingEmptyTitle(String type) {
    return '还没有$type';
  }

  @override
  String worldbuildingEmptyHint(String type) {
    return '记录作品的$type设定，方便写作时随时查阅。';
  }

  @override
  String get worldbuildingNameLabel => '名称（必填，1-50 字）';

  @override
  String get worldbuildingContentLabel => '设定内容';

  @override
  String get worldbuildingNameError => '名称需 1-50 字';

  @override
  String worldbuildingDeleteConfirm(String name) {
    return '删除「$name」？';
  }

  @override
  String get worldbuildingDeleteBody => '删除后设定条目不可恢复。';

  @override
  String get relationGraphTitle => '人物关系图';

  @override
  String get relationGraphEmpty => '还没有关系，点击右下角添加';

  @override
  String get relationGraphDeletedCharacter => '已删除角色';

  @override
  String get relationGraphAdd => '添加关系';

  @override
  String get relationGraphEdit => '编辑关系';

  @override
  String get relationGraphMinCharacters => '至少需要两个角色卡才能绘制关系图';

  @override
  String get relationGraphCharacterA => '角色 A';

  @override
  String get relationGraphCharacterB => '角色 B';

  @override
  String get relationGraphLabelField => '关系（如：师徒、宿敌）';

  @override
  String get relationGraphSelectTwo => '请选择两个不同的角色';

  @override
  String get importPageTitle => '导入文稿';

  @override
  String get importPagePickFile => '选择文稿文件（txt / docx / md / epub）';

  @override
  String get importPageRepickFile => '重新选择文件';

  @override
  String importPageConfirmButton(int count) {
    return '确认导入 $count 章';
  }

  @override
  String get importPageFileTooLarge => '文件超过 10MB 上限，请先在电脑上拆分后再导入';

  @override
  String get importPageNoContent => '没有解析到正文内容，请确认文件格式';

  @override
  String importPageParseFailed(String detail) {
    return '解析失败：$detail';
  }

  @override
  String importPageFailed(String detail) {
    return '导入失败：$detail';
  }

  @override
  String get importPageDialogEmptyTitle => '存在空章节';

  @override
  String importPageDialogEmptyBody(int count) {
    return '有 $count 章没有正文。保留这些空章节吗？';
  }

  @override
  String get importPageKeepAll => '全部保留';

  @override
  String get importPageDropEmpty => '丢弃空章节';

  @override
  String get importPageNoImportable => '没有可导入的章节';

  @override
  String get importPagePickHintTitle => '导入旧稿';

  @override
  String get importPagePickHintBody =>
      '支持 txt（UTF-8 / GBK）、docx、Markdown（.md）与 EPUB。导入后按「第 X 章」等标题自动分章，可在下一步预览并调整。';

  @override
  String importPageFileSummary(String encoding, int count, int words) {
    return '编码 $encoding · $count 章 · 共 $words 字';
  }

  @override
  String get importPageMergeIntoPrevious => '并入上一章';

  @override
  String get exportActionsFormatTxt => '纯文本（.txt）';

  @override
  String get exportActionsFormatMarkdown => 'Markdown（.md）';

  @override
  String get exportActionsFormatDocx => 'Word 文档（.docx）';

  @override
  String get exportActionsFormatEpub => 'EPUB 电子书（.epub）';

  @override
  String get exportActionsChapterTitle => '导出本章';

  @override
  String get exportActionsShareChapterTitle => '导出章节';

  @override
  String get exportActionsExportWorkTitle => '导出作品';

  @override
  String get exportActionsNoChapters => '这部作品还没有章节，暂无可导出的内容';

  @override
  String exportActionsShareFailed(String detail) {
    return '导出失败：$detail';
  }

  @override
  String get settingsSectionSecurity => '安全';

  @override
  String get settingsAppLock => '应用锁';

  @override
  String get settingsAppLockSubtitle => '启动或回到前台时验证指纹 / 面容 / 锁屏密码';

  @override
  String get settingsAppLockUnavailable => '设备未设置锁屏或生物识别，无法启用应用锁';

  @override
  String get settingsAppLockDenied => '验证未通过，应用锁设置未变更';

  @override
  String get settingsAppLockEnabled => '应用锁已开启';

  @override
  String get settingsAppLockDisabled => '应用锁已关闭';

  @override
  String get settingsAppLockAuthReason => '验证身份以修改应用锁';

  @override
  String get appLockTitle => '应用已锁定';

  @override
  String get appLockMessage => '验证身份后继续写作';

  @override
  String get appLockReason => '解锁 NovelPhone';

  @override
  String get appLockUnlock => '解锁';

  @override
  String get appLockFailed => '验证未通过，请重试';

  @override
  String get settingsSectionAbout => '关于';

  @override
  String get settingsAbout => '关于 NovelPhone';

  @override
  String get settingsAboutSubtitle => '版本、隐私说明与开源许可';

  @override
  String get aboutTagline => '本地优先的手机端 AI 小说写作工具';

  @override
  String aboutVersion(String version) {
    return '版本 $version';
  }

  @override
  String get aboutPrivacyTitle => '隐私说明';

  @override
  String get aboutPrivacyNoAccount => '默认不收集任何数据：无账号、无广告、无遥测。';

  @override
  String get aboutPrivacyLocal => '作品正文、设定、角色与写作统计全部保存在设备本地，离线可用。';

  @override
  String get aboutPrivacyKey =>
      'API Key 与云备份凭证存放在系统安全区（keychain / keystore），不入数据库、不随备份导出。';

  @override
  String get aboutPrivacyNetwork =>
      '联网仅发生在你主动使用 AI、MCP 工具服务或云备份时，直连你自行配置的服务商，不经过任何中转服务器。';

  @override
  String get aboutPrivacyOffline => '本地规则引擎的 AI 感检查完全离线，绝不联网扫描你的正文。';

  @override
  String get aboutPrivacyErase => '卸载应用即同时清除本地数据与安全区中的凭证。';

  @override
  String get aboutPrivacyPolicyLink => '查看完整隐私政策（浏览器打开）';

  @override
  String get aboutPrivacyLinkFailed => '无法打开浏览器，请稍后重试。';

  @override
  String get aboutLicenses => '开源许可';

  @override
  String get aboutLicensesSubtitle => 'NovelPhone 使用以下第三方开源组件，保留其原始许可。';

  @override
  String get aboutLicensesAction => '查看许可清单';

  @override
  String get plotPlanTitle => '剧情推演';

  @override
  String get plotPlanIntro => '基于已有章纲、角色与最近正文，推演后续走向与分章建议；满意的条目可存入灵感箱或转为章纲。';

  @override
  String get plotPlanDirection => '希望的方向（可选）';

  @override
  String get plotPlanDirectionHint => '例如：让女主主动摊牌，但暂时不要揭露身世';

  @override
  String get plotPlanStart => '开始推演';

  @override
  String get plotPlanRunning => '正在推演剧情…';

  @override
  String get plotPlanRegenerate => '重新推演';

  @override
  String get plotPlanDirections => '剧情走向';

  @override
  String get plotPlanChapters => '分章建议';

  @override
  String get plotPlanHook => '看点与风险';

  @override
  String get plotPlanSaveInspiration => '存入灵感箱';

  @override
  String get plotPlanSaved => '已存入灵感箱';

  @override
  String get plotPlanToOutline => '转为章纲';

  @override
  String get plotPlanOutlineSaved => '已写入章纲';

  @override
  String get plotPlanParseFailed => 'AI 返回的不是结构化结果，已按原文展示。';

  @override
  String plotPlanFailed(String message) {
    return '推演失败：$message';
  }

  @override
  String get batchSummaryTitle => '批量生成摘要';

  @override
  String get batchSummaryIntro => '为缺少摘要或正文已更新的章节依次生成前情摘要，结果直接写回章节。';

  @override
  String batchSummaryStart(int count) {
    return '生成缺失摘要（$count）';
  }

  @override
  String get batchSummaryAll => '全部重新生成';

  @override
  String batchSummaryRunning(int current, int total) {
    return '正在生成第 $current/$total 章…';
  }

  @override
  String get batchSummaryStopping => '将在当前章节完成后停止…';

  @override
  String get batchSummaryCancel => '停止';

  @override
  String get batchSummaryEmpty => '所有章节摘要都是最新的。';

  @override
  String get batchSummaryMissing => '缺少摘要';

  @override
  String get batchSummaryStale => '正文已更新';

  @override
  String get batchSummaryCurrent => '摘要已是最新';

  @override
  String batchSummaryDone(int count) {
    return '已生成 $count 章摘要';
  }

  @override
  String batchSummaryFailed(String message) {
    return '生成失败：$message';
  }

  @override
  String get batchSummaryResult => '生成结果';

  @override
  String get batchSummaryEmptyResult => 'AI 未返回内容';

  @override
  String get chatTitle => '作品问答';

  @override
  String get chatIntro => '基于作品设定、章纲与正文回答你的问题；需要细节时会自动检索相关章节。';

  @override
  String get chatEmpty => '和 AI 聊聊这部作品';

  @override
  String get chatInputHint => '输入问题…';

  @override
  String get chatSend => '发送';

  @override
  String get chatStop => '停止';

  @override
  String get chatThinking => '正在思考…';

  @override
  String get chatNoReply => '（没有返回内容）';

  @override
  String get chatClearTitle => '清空对话';

  @override
  String get chatClearBody => '将删除这部作品的问答记录，不影响作品内容。是否继续？';

  @override
  String get chatClearAction => '清空';

  @override
  String get chatContextTitle => '上下文详情';

  @override
  String chatContextUsage(int estimated, int budget) {
    return '已注入约 $estimated / $budget token';
  }

  @override
  String get chatSuggestionGoal => '主角目前的目标是什么？';

  @override
  String get chatSuggestionForeshadow => '哪些伏笔还没回收？';

  @override
  String get chatSuggestionRelationship => '梳理主要人物关系';

  @override
  String get editorContinuityStop => '停止';

  @override
  String get editorContinuityStopped => '已停止生成，以下是已生成的内容。';

  @override
  String get editorContinuityStoppedEmpty => '已停止，尚未收到内容。';

  @override
  String get continuityScanTitle => '全书一致性体检';

  @override
  String get continuityScanIntro =>
      '逐章检查正文与角色卡、设定集、章纲、前情是否冲突。全书按顺序执行，避免并发触发服务商限流；可随时停止并保留已完成的结果。';

  @override
  String get continuityScanEmpty => '没有可检查的章节，请先写正文。';

  @override
  String get continuityScanStart => '开始全书体检';

  @override
  String get continuityScanRerun => '重新体检';

  @override
  String continuityScanRunning(int current, int total) {
    return '正在检查第 $current / $total 章…';
  }

  @override
  String get continuityScanStopping => '当前章完成后停止…';

  @override
  String get continuityScanCancel => '停止体检';

  @override
  String get continuityScanResult => '检查结果';

  @override
  String continuityScanProgress(int done, int total) {
    return '已完成 $done / $total 章';
  }

  @override
  String get continuityScanNoIssues => '未发现冲突';

  @override
  String get continuityScanHasIssues => '发现疑似冲突，点击查看';

  @override
  String get continuityScanChapterFailed => '本章检查失败';

  @override
  String continuityScanFailedLine(String message) {
    return '检查失败：$message';
  }

  @override
  String get continuityScanCopyAll => '复制全部结果';

  @override
  String get continuityScanCopied => '已复制到剪贴板';

  @override
  String get aiTaskStyle => 'AI 文风提取';

  @override
  String get aiTaskExtract => 'AI 设定补全';

  @override
  String get aiTaskPlan => 'AI 剧情推演';

  @override
  String get aiTaskChat => 'AI 作品问答';

  @override
  String get tokenStatsEstimatedCost => '预计费用';

  @override
  String tokenStatsCostValue(String amount) {
    return '¥$amount';
  }

  @override
  String get tokenStatsCostHint => '在模型组中填写每百万 token 单价后，可在这里估算费用。';

  @override
  String tokenStatsCostPartial(int count) {
    return '$count 个模型未填写单价，未计入费用。';
  }

  @override
  String get tokenStatsMonthly => '本月预算';

  @override
  String get tokenStatsBudgetUnset => '未设置月度预算';

  @override
  String get tokenStatsBudgetSet => '设置月度预算';

  @override
  String get tokenStatsBudgetEdit => '编辑预算';

  @override
  String tokenStatsBudgetUsage(String used, String budget) {
    return '本月已用 ¥$used / 预算 ¥$budget';
  }

  @override
  String tokenStatsBudgetUsedOnly(String used) {
    return '本月已用 ¥$used';
  }

  @override
  String tokenStatsBudgetPercent(String percent) {
    return '已用 $percent%';
  }

  @override
  String get tokenStatsBudgetExceeded => '本月预算已用完，继续调用将超出预算。';

  @override
  String get tokenStatsBudgetWarning => '本月预算已用超过 80%。';

  @override
  String get tokenStatsBudgetNoPrice => '模型未填写单价，无法估算当月花费。';

  @override
  String get tokenStatsBudgetDialogTitle => '月度 AI 预算';

  @override
  String get tokenStatsBudgetDialogBody => '按自然月统计 AI 调用费用；留空或 0 表示不限制。';

  @override
  String get tokenStatsBudgetField => '预算金额（元）';

  @override
  String get tokenStatsBudgetInvalid => '请输入有效的金额';

  @override
  String get tokenStatsBudgetSaved => '月度预算已更新';

  @override
  String modelGroupsPriceLine(String input, String output) {
    return '¥$input / ¥$output 每百万 token';
  }

  @override
  String get modelGroupsNoPrice => '未填单价';

  @override
  String get settingsScreenProtection => '截屏保护';

  @override
  String get settingsScreenProtectionSubtitle => '阻止截屏、录屏与后台缩略图泄露正文';

  @override
  String get settingsScreenProtectionEnabled => '截屏保护已开启';

  @override
  String get settingsScreenProtectionDisabled => '截屏保护已关闭';

  @override
  String get settingsBackupEncryption => '备份加密';

  @override
  String get settingsBackupEncryptionOff => '未开启：备份文件为明文 zip';

  @override
  String get settingsBackupEncryptionOn => '已开启：导出与云备份使用 AES-256-GCM 加密';

  @override
  String get settingsBackupEncryptionEnabled => '备份加密已开启';

  @override
  String get settingsBackupEncryptionDisabled => '备份加密已关闭';

  @override
  String get settingsBackupEncryptionDisableTitle => '关闭备份加密？';

  @override
  String get settingsBackupEncryptionDisableBody =>
      '已加密的旧备份仍需原密码恢复；之后的新备份将以明文保存。';

  @override
  String get settingsBackupEncryptionDisableAction => '关闭';

  @override
  String get backupEncryptMissingPassphrase => '未找到备份密码，请先在设置中重新设置';

  @override
  String get backupPassphraseSetTitle => '设置备份密码';

  @override
  String backupPassphraseSetBody(int count) {
    return '密码至少 $count 位。忘记密码将无法恢复此后的加密备份，请妥善保管。';
  }

  @override
  String get backupPassphraseLabel => '备份密码';

  @override
  String get backupPassphraseConfirmLabel => '再次输入密码';

  @override
  String backupPassphraseTooShort(int count) {
    return '密码至少 $count 位';
  }

  @override
  String get backupPassphraseMismatch => '两次输入的密码不一致';

  @override
  String get backupPassphraseRequired => '请输入备份密码';

  @override
  String get backupPassphrasePromptTitle => '输入备份密码';

  @override
  String get backupPassphrasePromptBody => '该备份文件已加密，请输入导出时设置的密码。';

  @override
  String get backupPassphraseUnlock => '解密恢复';

  @override
  String get backupErrorDecryptionFailed => '密码错误或备份文件已损坏，无法解密';
}
