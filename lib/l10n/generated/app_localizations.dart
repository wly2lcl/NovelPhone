import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'NovelPhone'**
  String get appTitle;

  /// No description provided for @commonCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get commonCancel;

  /// No description provided for @commonDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get commonDelete;

  /// No description provided for @commonSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get commonSettings;

  /// No description provided for @commonCreateFailed.
  ///
  /// In zh, this message translates to:
  /// **'创建失败：{detail}'**
  String commonCreateFailed(String detail);

  /// No description provided for @worksSearchTooltip.
  ///
  /// In zh, this message translates to:
  /// **'全局搜索'**
  String get worksSearchTooltip;

  /// No description provided for @worksNew.
  ///
  /// In zh, this message translates to:
  /// **'新建作品'**
  String get worksNew;

  /// No description provided for @worksLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'读取作品失败：{detail}'**
  String worksLoadFailed(String detail);

  /// No description provided for @worksEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有作品'**
  String get worksEmptyTitle;

  /// No description provided for @worksEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'把脑中的故事写下来，从第一部作品开始。'**
  String get worksEmptyHint;

  /// No description provided for @worksEmptyCreate.
  ///
  /// In zh, this message translates to:
  /// **'创建第一部作品'**
  String get worksEmptyCreate;

  /// No description provided for @worksPin.
  ///
  /// In zh, this message translates to:
  /// **'置顶'**
  String get worksPin;

  /// No description provided for @worksUnpin.
  ///
  /// In zh, this message translates to:
  /// **'取消置顶'**
  String get worksUnpin;

  /// No description provided for @worksDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除作品'**
  String get worksDelete;

  /// No description provided for @worksDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'删除《{title}》？'**
  String worksDeleteConfirm(String title);

  /// No description provided for @worksDeleteConfirmBody.
  ///
  /// In zh, this message translates to:
  /// **'作品连同章节将移入回收站，30 天内可在回收站恢复。'**
  String get worksDeleteConfirmBody;

  /// No description provided for @worksLastEdited.
  ///
  /// In zh, this message translates to:
  /// **'最后编辑 {time}'**
  String worksLastEdited(String time);

  /// No description provided for @worksLimitReached.
  ///
  /// In zh, this message translates to:
  /// **'作品数量已达上限 {max} 部'**
  String worksLimitReached(int max);

  /// No description provided for @chapterCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 章'**
  String chapterCount(int count);

  /// No description provided for @newWorkTitleRequired.
  ///
  /// In zh, this message translates to:
  /// **'请填写作品标题'**
  String get newWorkTitleRequired;

  /// No description provided for @newWorkTitleMax.
  ///
  /// In zh, this message translates to:
  /// **'标题最多 {max} 字'**
  String newWorkTitleMax(int max);

  /// No description provided for @newWorkTitleLabel.
  ///
  /// In zh, this message translates to:
  /// **'作品标题'**
  String get newWorkTitleLabel;

  /// No description provided for @newWorkTitleHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：长夜行'**
  String get newWorkTitleHint;

  /// No description provided for @newWorkCoverLabel.
  ///
  /// In zh, this message translates to:
  /// **'封面色块'**
  String get newWorkCoverLabel;

  /// No description provided for @newWorkCreating.
  ///
  /// In zh, this message translates to:
  /// **'创建中…'**
  String get newWorkCreating;

  /// No description provided for @newWorkCreate.
  ///
  /// In zh, this message translates to:
  /// **'创建作品'**
  String get newWorkCreate;

  /// No description provided for @timeJustNow.
  ///
  /// In zh, this message translates to:
  /// **'刚刚'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In zh, this message translates to:
  /// **'{count} 分钟前'**
  String timeMinutesAgo(int count);

  /// No description provided for @timeHoursAgo.
  ///
  /// In zh, this message translates to:
  /// **'{count} 小时前'**
  String timeHoursAgo(int count);

  /// No description provided for @timeYesterday.
  ///
  /// In zh, this message translates to:
  /// **'昨天'**
  String get timeYesterday;

  /// No description provided for @timeDaysAgo.
  ///
  /// In zh, this message translates to:
  /// **'{count} 天前'**
  String timeDaysAgo(int count);

  /// No description provided for @wordCountExact.
  ///
  /// In zh, this message translates to:
  /// **'{count} 字'**
  String wordCountExact(String count);

  /// No description provided for @wordCountWan.
  ///
  /// In zh, this message translates to:
  /// **'{value} 万字'**
  String wordCountWan(String value);

  /// No description provided for @wordCountK.
  ///
  /// In zh, this message translates to:
  /// **'{value} 千字'**
  String wordCountK(String value);

  /// No description provided for @wordCountM.
  ///
  /// In zh, this message translates to:
  /// **'{value} 百万字'**
  String wordCountM(String value);

  /// No description provided for @tokenCountScaled.
  ///
  /// In zh, this message translates to:
  /// **'{value} 万'**
  String tokenCountScaled(String value);

  /// No description provided for @tokenCountMega.
  ///
  /// In zh, this message translates to:
  /// **'{value} 百万'**
  String tokenCountMega(String value);

  /// No description provided for @commonSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get commonSave;

  /// No description provided for @commonConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get commonConfirm;

  /// No description provided for @commonEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get commonEdit;

  /// No description provided for @commonMoreActions.
  ///
  /// In zh, this message translates to:
  /// **'更多操作'**
  String get commonMoreActions;

  /// No description provided for @commonRename.
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get commonRename;

  /// No description provided for @commonRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get commonRetry;

  /// No description provided for @commonClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get commonClose;

  /// No description provided for @commonRestore.
  ///
  /// In zh, this message translates to:
  /// **'恢复'**
  String get commonRestore;

  /// No description provided for @commonAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get commonAdd;

  /// No description provided for @commonDone.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get commonDone;

  /// No description provided for @commonCopy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get commonCopy;

  /// No description provided for @commonBack.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get commonBack;

  /// No description provided for @commonMore.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get commonMore;

  /// No description provided for @commonClear.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get commonClear;

  /// No description provided for @commonReset.
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get commonReset;

  /// No description provided for @commonUntitledChapter.
  ///
  /// In zh, this message translates to:
  /// **'未命名章节'**
  String get commonUntitledChapter;

  /// No description provided for @chapterStatusDraft.
  ///
  /// In zh, this message translates to:
  /// **'草稿'**
  String get chapterStatusDraft;

  /// No description provided for @chapterStatusRevising.
  ///
  /// In zh, this message translates to:
  /// **'修订中'**
  String get chapterStatusRevising;

  /// No description provided for @chapterStatusFinished.
  ///
  /// In zh, this message translates to:
  /// **'定稿'**
  String get chapterStatusFinished;

  /// No description provided for @settingTypeWorldview.
  ///
  /// In zh, this message translates to:
  /// **'世界观'**
  String get settingTypeWorldview;

  /// No description provided for @settingTypeLocation.
  ///
  /// In zh, this message translates to:
  /// **'地点'**
  String get settingTypeLocation;

  /// No description provided for @settingTypeItem.
  ///
  /// In zh, this message translates to:
  /// **'道具'**
  String get settingTypeItem;

  /// No description provided for @localeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get localeSystem;

  /// No description provided for @localeZh.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get localeZh;

  /// No description provided for @localeEn.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get localeEn;

  /// No description provided for @editorChapterTitleDialog.
  ///
  /// In zh, this message translates to:
  /// **'章节标题'**
  String get editorChapterTitleDialog;

  /// No description provided for @editorChapterSummaryTooltip.
  ///
  /// In zh, this message translates to:
  /// **'本章梗概'**
  String get editorChapterSummaryTooltip;

  /// No description provided for @editorAiToolsTooltip.
  ///
  /// In zh, this message translates to:
  /// **'AI 章节工具'**
  String get editorAiToolsTooltip;

  /// No description provided for @editorToolSummarize.
  ///
  /// In zh, this message translates to:
  /// **'生成本章摘要'**
  String get editorToolSummarize;

  /// No description provided for @editorToolVolumeSummary.
  ///
  /// In zh, this message translates to:
  /// **'生成本卷前情回顾'**
  String get editorToolVolumeSummary;

  /// No description provided for @editorToolOutlineExpand.
  ///
  /// In zh, this message translates to:
  /// **'AI 扩写本章纲'**
  String get editorToolOutlineExpand;

  /// No description provided for @editorToolContinuity.
  ///
  /// In zh, this message translates to:
  /// **'设定一致性检查'**
  String get editorToolContinuity;

  /// No description provided for @editorToolStoryState.
  ///
  /// In zh, this message translates to:
  /// **'提取本章状态变化'**
  String get editorToolStoryState;

  /// No description provided for @editorToolEditSummary.
  ///
  /// In zh, this message translates to:
  /// **'查看/编辑本章摘要'**
  String get editorToolEditSummary;

  /// No description provided for @editorExitFocusMode.
  ///
  /// In zh, this message translates to:
  /// **'退出专注模式'**
  String get editorExitFocusMode;

  /// No description provided for @editorFocusMode.
  ///
  /// In zh, this message translates to:
  /// **'专注模式'**
  String get editorFocusMode;

  /// No description provided for @editorBodyHint.
  ///
  /// In zh, this message translates to:
  /// **'在这里写下正文…'**
  String get editorBodyHint;

  /// No description provided for @editorSelectRewriteText.
  ///
  /// In zh, this message translates to:
  /// **'请先在正文中选中要改写的段落'**
  String get editorSelectRewriteText;

  /// No description provided for @editorNeedOutlineSeed.
  ///
  /// In zh, this message translates to:
  /// **'请先用顶栏「本章梗概」写一句话梗概，AI 再据此扩写'**
  String get editorNeedOutlineSeed;

  /// No description provided for @editorNoEarlierChapters.
  ///
  /// In zh, this message translates to:
  /// **'本卷还没有更早的章节内容，暂无法生成本卷前情回顾'**
  String get editorNoEarlierChapters;

  /// No description provided for @editorNoModelTitle.
  ///
  /// In zh, this message translates to:
  /// **'尚未配置模型'**
  String get editorNoModelTitle;

  /// No description provided for @editorNoModelBody.
  ///
  /// In zh, this message translates to:
  /// **'请先在设置中添加模型组并填写 API Key，再使用 AI 功能。'**
  String get editorNoModelBody;

  /// No description provided for @editorContinuityTitle.
  ///
  /// In zh, this message translates to:
  /// **'设定一致性检查'**
  String get editorContinuityTitle;

  /// No description provided for @editorContinuityRunning.
  ///
  /// In zh, this message translates to:
  /// **'正在检查设定一致性…'**
  String get editorContinuityRunning;

  /// No description provided for @editorContinuityEmpty.
  ///
  /// In zh, this message translates to:
  /// **'本章还没有正文，先写一些内容再检查'**
  String get editorContinuityEmpty;

  /// No description provided for @editorContinuityEmptyResult.
  ///
  /// In zh, this message translates to:
  /// **'模型未返回内容，请重试'**
  String get editorContinuityEmptyResult;

  /// No description provided for @editorContinuityTruncated.
  ///
  /// In zh, this message translates to:
  /// **'上下文超出模型窗口，部分设定资料已被省略，结果可能不完整。'**
  String get editorContinuityTruncated;

  /// No description provided for @editorLater.
  ///
  /// In zh, this message translates to:
  /// **'稍后'**
  String get editorLater;

  /// No description provided for @editorGoSettings.
  ///
  /// In zh, this message translates to:
  /// **'去设置'**
  String get editorGoSettings;

  /// No description provided for @editorOriginalChanged.
  ///
  /// In zh, this message translates to:
  /// **'原文已变化，请重新选中后再改写'**
  String get editorOriginalChanged;

  /// No description provided for @editorSummaryTitle.
  ///
  /// In zh, this message translates to:
  /// **'本章 AI 摘要'**
  String get editorSummaryTitle;

  /// No description provided for @editorSummaryHint.
  ///
  /// In zh, this message translates to:
  /// **'AI 生成的前情摘要，可手动修改；用于后续章节的剧情衔接'**
  String get editorSummaryHint;

  /// No description provided for @editorSummaryStale.
  ///
  /// In zh, this message translates to:
  /// **'正文已改动，摘要可能过期，建议重新生成'**
  String get editorSummaryStale;

  /// No description provided for @editorSaving.
  ///
  /// In zh, this message translates to:
  /// **'保存中'**
  String get editorSaving;

  /// No description provided for @editorSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get editorSaved;

  /// No description provided for @editorSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败，点击重试'**
  String get editorSaveFailed;

  /// No description provided for @editorAiContinue.
  ///
  /// In zh, this message translates to:
  /// **'AI 续写'**
  String get editorAiContinue;

  /// No description provided for @editorAiInspire.
  ///
  /// In zh, this message translates to:
  /// **'AI 灵感'**
  String get editorAiInspire;

  /// No description provided for @editorAiRewrite.
  ///
  /// In zh, this message translates to:
  /// **'AI 改写'**
  String get editorAiRewrite;

  /// No description provided for @editorFind.
  ///
  /// In zh, this message translates to:
  /// **'查找'**
  String get editorFind;

  /// No description provided for @editorAiCheck.
  ///
  /// In zh, this message translates to:
  /// **'AI 感'**
  String get editorAiCheck;

  /// No description provided for @editorMoveParagraph.
  ///
  /// In zh, this message translates to:
  /// **'段落移动'**
  String get editorMoveParagraph;

  /// No description provided for @editorMoveParagraphUp.
  ///
  /// In zh, this message translates to:
  /// **'本段上移'**
  String get editorMoveParagraphUp;

  /// No description provided for @editorMoveParagraphDown.
  ///
  /// In zh, this message translates to:
  /// **'本段下移'**
  String get editorMoveParagraphDown;

  /// No description provided for @editorUndo.
  ///
  /// In zh, this message translates to:
  /// **'撤销'**
  String get editorUndo;

  /// No description provided for @editorRedo.
  ///
  /// In zh, this message translates to:
  /// **'重做'**
  String get editorRedo;

  /// No description provided for @editorChapterWords.
  ///
  /// In zh, this message translates to:
  /// **'本章 {words}'**
  String editorChapterWords(String words);

  /// No description provided for @editorWholeWorkWords.
  ///
  /// In zh, this message translates to:
  /// **'全书 {words}'**
  String editorWholeWorkWords(String words);

  /// No description provided for @editorLastSaved.
  ///
  /// In zh, this message translates to:
  /// **'最后保存 {time}'**
  String editorLastSaved(String time);

  /// No description provided for @aiPanelTitleContinue.
  ///
  /// In zh, this message translates to:
  /// **'AI 续写'**
  String get aiPanelTitleContinue;

  /// No description provided for @aiPanelTitleInspireIdeas.
  ///
  /// In zh, this message translates to:
  /// **'AI 灵感 · 桥段点子'**
  String get aiPanelTitleInspireIdeas;

  /// No description provided for @aiPanelTitleInspireOpening.
  ///
  /// In zh, this message translates to:
  /// **'AI 灵感 · 开篇助手'**
  String get aiPanelTitleInspireOpening;

  /// No description provided for @aiPanelTitleRewrite.
  ///
  /// In zh, this message translates to:
  /// **'AI 改写'**
  String get aiPanelTitleRewrite;

  /// No description provided for @aiPanelTitleSummarize.
  ///
  /// In zh, this message translates to:
  /// **'AI 逐章摘要'**
  String get aiPanelTitleSummarize;

  /// No description provided for @aiPanelTitleOutlineExpand.
  ///
  /// In zh, this message translates to:
  /// **'AI 章纲扩写'**
  String get aiPanelTitleOutlineExpand;

  /// No description provided for @aiPanelTitleVolumeSummary.
  ///
  /// In zh, this message translates to:
  /// **'AI 本卷前情回顾'**
  String get aiPanelTitleVolumeSummary;

  /// No description provided for @aiPanelNewDirection.
  ///
  /// In zh, this message translates to:
  /// **'换个方向'**
  String get aiPanelNewDirection;

  /// No description provided for @aiPanelDirectionHint.
  ///
  /// In zh, this message translates to:
  /// **'补充一句方向指令，例如：让两人在此摊牌'**
  String get aiPanelDirectionHint;

  /// No description provided for @aiPanelRegenerate.
  ///
  /// In zh, this message translates to:
  /// **'重新生成'**
  String get aiPanelRegenerate;

  /// No description provided for @aiPanelElapsedSeconds.
  ///
  /// In zh, this message translates to:
  /// **'{seconds} 秒'**
  String aiPanelElapsedSeconds(int seconds);

  /// No description provided for @aiPanelCollapse.
  ///
  /// In zh, this message translates to:
  /// **'收起'**
  String get aiPanelCollapse;

  /// No description provided for @aiPanelModeIdeas.
  ///
  /// In zh, this message translates to:
  /// **'桥段点子'**
  String get aiPanelModeIdeas;

  /// No description provided for @aiPanelModeOpening.
  ///
  /// In zh, this message translates to:
  /// **'开篇助手'**
  String get aiPanelModeOpening;

  /// No description provided for @aiPanelInstructionHint.
  ///
  /// In zh, this message translates to:
  /// **'补充指令（可选），例如：让她的话更冷淡'**
  String get aiPanelInstructionHint;

  /// No description provided for @aiPanelLengthLabel.
  ///
  /// In zh, this message translates to:
  /// **'篇幅 {count} 字'**
  String aiPanelLengthLabel(int count);

  /// No description provided for @aiPanelCandidateCount.
  ///
  /// In zh, this message translates to:
  /// **'3 个候选'**
  String get aiPanelCandidateCount;

  /// No description provided for @aiPanelVersion.
  ///
  /// In zh, this message translates to:
  /// **'版本 {n}'**
  String aiPanelVersion(int n);

  /// No description provided for @aiPanelMixCandidates.
  ///
  /// In zh, this message translates to:
  /// **'跨候选组合'**
  String get aiPanelMixCandidates;

  /// No description provided for @candidateMixTitle.
  ///
  /// In zh, this message translates to:
  /// **'跨候选组合'**
  String get candidateMixTitle;

  /// No description provided for @candidateMixIntro.
  ///
  /// In zh, this message translates to:
  /// **'每个段落可以选自不同候选，组合结果会替换当前候选内容，正文不会被直接改动。'**
  String get candidateMixIntro;

  /// No description provided for @candidateMixSlot.
  ///
  /// In zh, this message translates to:
  /// **'第 {count} 段'**
  String candidateMixSlot(int count);

  /// No description provided for @candidateMixCandidate.
  ///
  /// In zh, this message translates to:
  /// **'候选 {index}'**
  String candidateMixCandidate(int index);

  /// No description provided for @candidateMixApply.
  ///
  /// In zh, this message translates to:
  /// **'组合并采纳 {count} 段'**
  String candidateMixApply(int count);

  /// No description provided for @aiPanelContextTitle.
  ///
  /// In zh, this message translates to:
  /// **'AI 看到的上下文（估算 {estimated} / 预算 {budget} token）'**
  String aiPanelContextTitle(int estimated, int budget);

  /// No description provided for @aiPanelTruncated.
  ///
  /// In zh, this message translates to:
  /// **'已省略较早前文'**
  String get aiPanelTruncated;

  /// No description provided for @aiPanelResultHint.
  ///
  /// In zh, this message translates to:
  /// **'AI 产出将在这里流式显示，可直接编辑后再插入正文'**
  String get aiPanelResultHint;

  /// No description provided for @aiPanelNeedsConfig.
  ///
  /// In zh, this message translates to:
  /// **'尚未配置可用的模型与 API Key'**
  String get aiPanelNeedsConfig;

  /// No description provided for @aiPanelReplaceOriginal.
  ///
  /// In zh, this message translates to:
  /// **'替换原文'**
  String get aiPanelReplaceOriginal;

  /// No description provided for @aiPanelSaveSummary.
  ///
  /// In zh, this message translates to:
  /// **'保存摘要'**
  String get aiPanelSaveSummary;

  /// No description provided for @aiPanelSaveToOutline.
  ///
  /// In zh, this message translates to:
  /// **'保存到章纲'**
  String get aiPanelSaveToOutline;

  /// No description provided for @aiPanelSaveVolumeSummary.
  ///
  /// In zh, this message translates to:
  /// **'保存前情回顾'**
  String get aiPanelSaveVolumeSummary;

  /// No description provided for @aiPanelInsertAtCursor.
  ///
  /// In zh, this message translates to:
  /// **'插入光标处'**
  String get aiPanelInsertAtCursor;

  /// No description provided for @aiPanelStop.
  ///
  /// In zh, this message translates to:
  /// **'停止'**
  String get aiPanelStop;

  /// No description provided for @aiPanelSaveToInspiration.
  ///
  /// In zh, this message translates to:
  /// **'存入灵感箱'**
  String get aiPanelSaveToInspiration;

  /// No description provided for @aiPanelDiscard.
  ///
  /// In zh, this message translates to:
  /// **'放弃'**
  String get aiPanelDiscard;

  /// No description provided for @aiPanelSavedToInspiration.
  ///
  /// In zh, this message translates to:
  /// **'已存入灵感箱'**
  String get aiPanelSavedToInspiration;

  /// No description provided for @aiPanelMerge.
  ///
  /// In zh, this message translates to:
  /// **'分段采纳'**
  String get aiPanelMerge;

  /// No description provided for @aiPanelRevise.
  ///
  /// In zh, this message translates to:
  /// **'继续修改'**
  String get aiPanelRevise;

  /// No description provided for @aiPanelReviseHint.
  ///
  /// In zh, this message translates to:
  /// **'告诉 AI 怎么改，例如：对白更克制，删掉最后一句'**
  String get aiPanelReviseHint;

  /// No description provided for @aiPanelReviseNeedInstruction.
  ///
  /// In zh, this message translates to:
  /// **'请先填写修改意见'**
  String get aiPanelReviseNeedInstruction;

  /// No description provided for @aiPanelRevising.
  ///
  /// In zh, this message translates to:
  /// **'正在按意见修改…'**
  String get aiPanelRevising;

  /// No description provided for @aiReviseQuickMoreDetail.
  ///
  /// In zh, this message translates to:
  /// **'更具体'**
  String get aiReviseQuickMoreDetail;

  /// No description provided for @aiReviseQuickTighter.
  ///
  /// In zh, this message translates to:
  /// **'更紧凑'**
  String get aiReviseQuickTighter;

  /// No description provided for @aiReviseQuickDialog.
  ///
  /// In zh, this message translates to:
  /// **'加强对话'**
  String get aiReviseQuickDialog;

  /// No description provided for @aiReviseQuickEnding.
  ///
  /// In zh, this message translates to:
  /// **'换个结尾'**
  String get aiReviseQuickEnding;

  /// No description provided for @aiReviseQuickRemoveAi.
  ///
  /// In zh, this message translates to:
  /// **'去 AI 味'**
  String get aiReviseQuickRemoveAi;

  /// No description provided for @aiPanelCompareOriginal.
  ///
  /// In zh, this message translates to:
  /// **'对比原文'**
  String get aiPanelCompareOriginal;

  /// No description provided for @aiPanelCompareOriginalTitle.
  ///
  /// In zh, this message translates to:
  /// **'对比原文与改写结果'**
  String get aiPanelCompareOriginalTitle;

  /// No description provided for @aiMergeTitle.
  ///
  /// In zh, this message translates to:
  /// **'分段采纳 AI 结果'**
  String get aiMergeTitle;

  /// No description provided for @aiMergeHint.
  ///
  /// In zh, this message translates to:
  /// **'勾选要写入正文的段落，可直接修改文字；未勾选的段落不会写入。'**
  String get aiMergeHint;

  /// No description provided for @aiMergeSelectAll.
  ///
  /// In zh, this message translates to:
  /// **'全选'**
  String get aiMergeSelectAll;

  /// No description provided for @aiMergeSelectNone.
  ///
  /// In zh, this message translates to:
  /// **'全不选'**
  String get aiMergeSelectNone;

  /// No description provided for @aiMergeSelected.
  ///
  /// In zh, this message translates to:
  /// **'已选 {selected}/{total} 段'**
  String aiMergeSelected(int selected, int total);

  /// No description provided for @aiMergeChanged.
  ///
  /// In zh, this message translates to:
  /// **'改动'**
  String get aiMergeChanged;

  /// No description provided for @aiMergeApply.
  ///
  /// In zh, this message translates to:
  /// **'采用 {count} 段'**
  String aiMergeApply(int count);

  /// No description provided for @aiMergeRejectTitle.
  ///
  /// In zh, this message translates to:
  /// **'哪些段落未采纳？'**
  String get aiMergeRejectTitle;

  /// No description provided for @aiMergeRejectHint.
  ///
  /// In zh, this message translates to:
  /// **'有 {count} 段未采纳。选一个主要原因，只保存在本机，用于后续生成避雷。'**
  String aiMergeRejectHint(int count);

  /// No description provided for @aiMergeRejectConfirm.
  ///
  /// In zh, this message translates to:
  /// **'记录并采纳'**
  String get aiMergeRejectConfirm;

  /// No description provided for @aiFeedbackTitle.
  ///
  /// In zh, this message translates to:
  /// **'这次结果哪里不合适？'**
  String get aiFeedbackTitle;

  /// No description provided for @aiFeedbackHint.
  ///
  /// In zh, this message translates to:
  /// **'原因只保存在本机，并用于后续生成时避雷。'**
  String get aiFeedbackHint;

  /// No description provided for @aiFeedbackTooAi.
  ///
  /// In zh, this message translates to:
  /// **'太像 AI'**
  String get aiFeedbackTooAi;

  /// No description provided for @aiFeedbackOffCharacter.
  ///
  /// In zh, this message translates to:
  /// **'角色出戏'**
  String get aiFeedbackOffCharacter;

  /// No description provided for @aiFeedbackSlowPace.
  ///
  /// In zh, this message translates to:
  /// **'节奏拖沓'**
  String get aiFeedbackSlowPace;

  /// No description provided for @aiFeedbackOffSetting.
  ///
  /// In zh, this message translates to:
  /// **'设定不符'**
  String get aiFeedbackOffSetting;

  /// No description provided for @aiFeedbackOther.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get aiFeedbackOther;

  /// No description provided for @aiFeedbackSkip.
  ///
  /// In zh, this message translates to:
  /// **'直接放弃'**
  String get aiFeedbackSkip;

  /// No description provided for @aiFeedbackConfirm.
  ///
  /// In zh, this message translates to:
  /// **'记录并放弃'**
  String get aiFeedbackConfirm;

  /// No description provided for @aiFeedbackRecorded.
  ///
  /// In zh, this message translates to:
  /// **'已记录，后续生成会参考'**
  String get aiFeedbackRecorded;

  /// No description provided for @aiPreferencesTitle.
  ///
  /// In zh, this message translates to:
  /// **'作者协作偏好'**
  String get aiPreferencesTitle;

  /// No description provided for @aiPreferencesDescription.
  ///
  /// In zh, this message translates to:
  /// **'这些偏好只保存在本机，用于后续续写 / 改写；不随备份导出。'**
  String get aiPreferencesDescription;

  /// No description provided for @aiPreferencesEnabled.
  ///
  /// In zh, this message translates to:
  /// **'生成时参考本机偏好'**
  String get aiPreferencesEnabled;

  /// No description provided for @aiPreferencesEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有记录。放弃结果时选择原因、采纳结果后会自动积累参考片段。'**
  String get aiPreferencesEmpty;

  /// No description provided for @aiPreferencesReasons.
  ///
  /// In zh, this message translates to:
  /// **'放弃原因'**
  String get aiPreferencesReasons;

  /// No description provided for @aiPreferencesParagraphReasons.
  ///
  /// In zh, this message translates to:
  /// **'分段未采纳原因'**
  String get aiPreferencesParagraphReasons;

  /// No description provided for @aiPreferencesSamples.
  ///
  /// In zh, this message translates to:
  /// **'最近采纳片段'**
  String get aiPreferencesSamples;

  /// No description provided for @aiPreferencesNoSamples.
  ///
  /// In zh, this message translates to:
  /// **'暂无采纳片段'**
  String get aiPreferencesNoSamples;

  /// No description provided for @aiPreferencesCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 次'**
  String aiPreferencesCount(int count);

  /// No description provided for @aiPreferencesClear.
  ///
  /// In zh, this message translates to:
  /// **'清空偏好与样本'**
  String get aiPreferencesClear;

  /// No description provided for @aiPreferencesClearTitle.
  ///
  /// In zh, this message translates to:
  /// **'清空作者协作偏好？'**
  String get aiPreferencesClearTitle;

  /// No description provided for @aiPreferencesClearBody.
  ///
  /// In zh, this message translates to:
  /// **'原因计数与最近采纳片段将被删除，且无法恢复。'**
  String get aiPreferencesClearBody;

  /// No description provided for @aiPreferencesCleared.
  ///
  /// In zh, this message translates to:
  /// **'已清空作者协作偏好'**
  String get aiPreferencesCleared;

  /// No description provided for @aiRevisionOriginal.
  ///
  /// In zh, this message translates to:
  /// **'原稿'**
  String get aiRevisionOriginal;

  /// No description provided for @aiRevisionNumber.
  ///
  /// In zh, this message translates to:
  /// **'修订 {number}'**
  String aiRevisionNumber(int number);

  /// No description provided for @aiRevisionCompare.
  ///
  /// In zh, this message translates to:
  /// **'对比上一版'**
  String get aiRevisionCompare;

  /// No description provided for @aiRevisionCompareTitle.
  ///
  /// In zh, this message translates to:
  /// **'对比修订版本'**
  String get aiRevisionCompareTitle;

  /// No description provided for @rewriteIntentPolish.
  ///
  /// In zh, this message translates to:
  /// **'润色'**
  String get rewriteIntentPolish;

  /// No description provided for @rewriteIntentExpand.
  ///
  /// In zh, this message translates to:
  /// **'扩写'**
  String get rewriteIntentExpand;

  /// No description provided for @rewriteIntentCondense.
  ///
  /// In zh, this message translates to:
  /// **'缩写'**
  String get rewriteIntentCondense;

  /// No description provided for @rewriteIntentTone.
  ///
  /// In zh, this message translates to:
  /// **'改语气'**
  String get rewriteIntentTone;

  /// No description provided for @aiSectionChapterText.
  ///
  /// In zh, this message translates to:
  /// **'本章正文'**
  String get aiSectionChapterText;

  /// No description provided for @aiSectionTaskMode.
  ///
  /// In zh, this message translates to:
  /// **'任务模式'**
  String get aiSectionTaskMode;

  /// No description provided for @aiSectionChapterSynopsis.
  ///
  /// In zh, this message translates to:
  /// **'本章梗概'**
  String get aiSectionChapterSynopsis;

  /// No description provided for @aiSectionVolumeMaterial.
  ///
  /// In zh, this message translates to:
  /// **'本卷素材（上一版回顾 + 新增章节）'**
  String get aiSectionVolumeMaterial;

  /// No description provided for @aiSectionVolumeOutline.
  ///
  /// In zh, this message translates to:
  /// **'卷级大纲'**
  String get aiSectionVolumeOutline;

  /// No description provided for @aiSectionPreviousSummary.
  ///
  /// In zh, this message translates to:
  /// **'前文摘要'**
  String get aiSectionPreviousSummary;

  /// No description provided for @aiSectionCharacters.
  ///
  /// In zh, this message translates to:
  /// **'相关角色卡'**
  String get aiSectionCharacters;

  /// No description provided for @aiSectionSettings.
  ///
  /// In zh, this message translates to:
  /// **'设定集'**
  String get aiSectionSettings;

  /// No description provided for @aiSectionChapterOutline.
  ///
  /// In zh, this message translates to:
  /// **'本章章纲'**
  String get aiSectionChapterOutline;

  /// No description provided for @aiSectionChapterTail.
  ///
  /// In zh, this message translates to:
  /// **'本章已写内容（尾部）'**
  String get aiSectionChapterTail;

  /// No description provided for @aiSectionRequirements.
  ///
  /// In zh, this message translates to:
  /// **'生成要求'**
  String get aiSectionRequirements;

  /// No description provided for @aiSectionUserSkills.
  ///
  /// In zh, this message translates to:
  /// **'用户技能'**
  String get aiSectionUserSkills;

  /// No description provided for @aiSectionPreferences.
  ///
  /// In zh, this message translates to:
  /// **'作者协作偏好'**
  String get aiSectionPreferences;

  /// No description provided for @aiSectionCandidateStrategy.
  ///
  /// In zh, this message translates to:
  /// **'候选侧重'**
  String get aiSectionCandidateStrategy;

  /// No description provided for @flavorTitle.
  ///
  /// In zh, this message translates to:
  /// **'AI 感检查'**
  String get flavorTitle;

  /// No description provided for @flavorShownOfTotal.
  ///
  /// In zh, this message translates to:
  /// **'仅显示前 {shown} 条，共 {total} 条'**
  String flavorShownOfTotal(int shown, int total);

  /// No description provided for @flavorIssueCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 处'**
  String flavorIssueCount(int count);

  /// No description provided for @flavorDeepProgress.
  ///
  /// In zh, this message translates to:
  /// **'深检 {done}/{total}'**
  String flavorDeepProgress(int done, int total);

  /// No description provided for @flavorScope.
  ///
  /// In zh, this message translates to:
  /// **'范围'**
  String get flavorScope;

  /// No description provided for @flavorWholeWork.
  ///
  /// In zh, this message translates to:
  /// **'整部作品'**
  String get flavorWholeWork;

  /// No description provided for @flavorChapterItem.
  ///
  /// In zh, this message translates to:
  /// **'{title}（{words}）'**
  String flavorChapterItem(String title, String words);

  /// No description provided for @flavorMetrics.
  ///
  /// In zh, this message translates to:
  /// **'套话 {cliche} 处 · 密度 {density}/千字 · 句式重复率 {repeat}% · 破折号/省略号 {dash} 处'**
  String flavorMetrics(int cliche, String density, String repeat, int dash);

  /// No description provided for @flavorDeepRunning.
  ///
  /// In zh, this message translates to:
  /// **'深检中…'**
  String get flavorDeepRunning;

  /// No description provided for @flavorDeepCheck.
  ///
  /// In zh, this message translates to:
  /// **'LLM 深检'**
  String get flavorDeepCheck;

  /// No description provided for @flavorRecheck.
  ///
  /// In zh, this message translates to:
  /// **'重新检查'**
  String get flavorRecheck;

  /// No description provided for @flavorEditInEditor.
  ///
  /// In zh, this message translates to:
  /// **'修改请在编辑器中完成'**
  String get flavorEditInEditor;

  /// No description provided for @flavorEstimatedTokens.
  ///
  /// In zh, this message translates to:
  /// **'预估 ~{tokens} token'**
  String flavorEstimatedTokens(String tokens);

  /// No description provided for @flavorMeasuredTokens.
  ///
  /// In zh, this message translates to:
  /// **'实测 输入 {input} + 输出 {output}'**
  String flavorMeasuredTokens(String input, String output);

  /// No description provided for @flavorNeedsConfigMessage.
  ///
  /// In zh, this message translates to:
  /// **'尚未配置 AI 感检查所用的模型，深检不可用。'**
  String get flavorNeedsConfigMessage;

  /// No description provided for @flavorDeepFailed.
  ///
  /// In zh, this message translates to:
  /// **'深检失败（已保留规则结果）：{error}'**
  String flavorDeepFailed(String error);

  /// No description provided for @flavorRetryDeepCheck.
  ///
  /// In zh, this message translates to:
  /// **'重试深检'**
  String get flavorRetryDeepCheck;

  /// No description provided for @flavorFallbackNotice.
  ///
  /// In zh, this message translates to:
  /// **'模型未返回结构化结果，原文如下：'**
  String get flavorFallbackNotice;

  /// No description provided for @flavorFilterAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get flavorFilterAll;

  /// No description provided for @flavorSeverityHigh.
  ///
  /// In zh, this message translates to:
  /// **'高'**
  String get flavorSeverityHigh;

  /// No description provided for @flavorSeverityMedium.
  ///
  /// In zh, this message translates to:
  /// **'中'**
  String get flavorSeverityMedium;

  /// No description provided for @flavorSeverityLow.
  ///
  /// In zh, this message translates to:
  /// **'低'**
  String get flavorSeverityLow;

  /// No description provided for @flavorTypeCliche.
  ///
  /// In zh, this message translates to:
  /// **'套话'**
  String get flavorTypeCliche;

  /// No description provided for @flavorTypeRepetition.
  ///
  /// In zh, this message translates to:
  /// **'句式重复'**
  String get flavorTypeRepetition;

  /// No description provided for @flavorTypeTranslationese.
  ///
  /// In zh, this message translates to:
  /// **'翻译腔'**
  String get flavorTypeTranslationese;

  /// No description provided for @flavorTypeOversummary.
  ///
  /// In zh, this message translates to:
  /// **'过度总结'**
  String get flavorTypeOversummary;

  /// No description provided for @flavorTypePacing.
  ///
  /// In zh, this message translates to:
  /// **'节奏拖沓'**
  String get flavorTypePacing;

  /// No description provided for @flavorEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'该范围没有正文，无可检查内容'**
  String get flavorEmptyHint;

  /// No description provided for @flavorCleanHint.
  ///
  /// In zh, this message translates to:
  /// **'未发现明显的 AI 味问题'**
  String get flavorCleanHint;

  /// No description provided for @flavorDeepBadge.
  ///
  /// In zh, this message translates to:
  /// **'深检'**
  String get flavorDeepBadge;

  /// No description provided for @flavorLocateInText.
  ///
  /// In zh, this message translates to:
  /// **'定位到原文'**
  String get flavorLocateInText;

  /// No description provided for @flavorDeleteWord.
  ///
  /// In zh, this message translates to:
  /// **'一键删除该词'**
  String get flavorDeleteWord;

  /// No description provided for @flavorReplaceWith.
  ///
  /// In zh, this message translates to:
  /// **'一键替换为「{replacement}」'**
  String flavorReplaceWith(String replacement);

  /// No description provided for @flavorIgnoreThis.
  ///
  /// In zh, this message translates to:
  /// **'忽略这条'**
  String get flavorIgnoreThis;

  /// No description provided for @flavorIgnoreAllType.
  ///
  /// In zh, this message translates to:
  /// **'忽略全部「{type}」'**
  String flavorIgnoreAllType(String type);

  /// No description provided for @flavorOriginalText.
  ///
  /// In zh, this message translates to:
  /// **'原文：{excerpt}'**
  String flavorOriginalText(String excerpt);

  /// No description provided for @flavorSuggestion.
  ///
  /// In zh, this message translates to:
  /// **'建议：{suggestion}'**
  String flavorSuggestion(String suggestion);

  /// No description provided for @flavorLocate.
  ///
  /// In zh, this message translates to:
  /// **'定位'**
  String get flavorLocate;

  /// No description provided for @flavorReplace.
  ///
  /// In zh, this message translates to:
  /// **'替换'**
  String get flavorReplace;

  /// No description provided for @flavorIgnore.
  ///
  /// In zh, this message translates to:
  /// **'忽略'**
  String get flavorIgnore;

  /// No description provided for @flavorDeletedWord.
  ///
  /// In zh, this message translates to:
  /// **'已删除该词'**
  String get flavorDeletedWord;

  /// No description provided for @flavorReplacedWith.
  ///
  /// In zh, this message translates to:
  /// **'已替换为「{replacement}」'**
  String flavorReplacedWith(String replacement);

  /// No description provided for @flavorOriginalChanged.
  ///
  /// In zh, this message translates to:
  /// **'原文已变化，请重新运行检查'**
  String get flavorOriginalChanged;

  /// No description provided for @snapshotCreated.
  ///
  /// In zh, this message translates to:
  /// **'已创建快照'**
  String get snapshotCreated;

  /// No description provided for @snapshotRestoreVersion.
  ///
  /// In zh, this message translates to:
  /// **'恢复此版本'**
  String get snapshotRestoreVersion;

  /// No description provided for @snapshotRestored.
  ///
  /// In zh, this message translates to:
  /// **'已恢复到该版本'**
  String get snapshotRestored;

  /// No description provided for @snapshotEmptyChapter.
  ///
  /// In zh, this message translates to:
  /// **'（空章节）'**
  String get snapshotEmptyChapter;

  /// No description provided for @snapshotHistoryTitle.
  ///
  /// In zh, this message translates to:
  /// **'版本历史'**
  String get snapshotHistoryTitle;

  /// No description provided for @snapshotNoteAiBeforeAdopt.
  ///
  /// In zh, this message translates to:
  /// **'AI 采纳前'**
  String get snapshotNoteAiBeforeAdopt;

  /// No description provided for @snapshotCreate.
  ///
  /// In zh, this message translates to:
  /// **'创建快照'**
  String get snapshotCreate;

  /// No description provided for @snapshotEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'还没有快照。写作途中点「创建快照」留存一个版本。'**
  String get snapshotEmptyHint;

  /// No description provided for @snapshotDiffAction.
  ///
  /// In zh, this message translates to:
  /// **'与原稿对比'**
  String get snapshotDiffAction;

  /// No description provided for @snapshotDiffTitle.
  ///
  /// In zh, this message translates to:
  /// **'与当前版本对比'**
  String get snapshotDiffTitle;

  /// No description provided for @snapshotDiffNoChanges.
  ///
  /// In zh, this message translates to:
  /// **'与当前版本一致，无改动'**
  String get snapshotDiffNoChanges;

  /// No description provided for @snapshotDiffAdded.
  ///
  /// In zh, this message translates to:
  /// **'{count} 段新增'**
  String snapshotDiffAdded(int count);

  /// No description provided for @snapshotDiffRemoved.
  ///
  /// In zh, this message translates to:
  /// **'{count} 段删除'**
  String snapshotDiffRemoved(int count);

  /// No description provided for @snapshotDiffHidden.
  ///
  /// In zh, this message translates to:
  /// **'… 省略 {count} 行未改动'**
  String snapshotDiffHidden(int count);

  /// No description provided for @findReplaceReplacedCount.
  ///
  /// In zh, this message translates to:
  /// **'已替换 {count} 处'**
  String findReplaceReplacedCount(int count);

  /// No description provided for @findReplaceFindHint.
  ///
  /// In zh, this message translates to:
  /// **'查找'**
  String get findReplaceFindHint;

  /// No description provided for @findReplaceCaseSensitive.
  ///
  /// In zh, this message translates to:
  /// **'区分大小写'**
  String get findReplaceCaseSensitive;

  /// No description provided for @findReplaceMatchCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 处'**
  String findReplaceMatchCount(int count);

  /// No description provided for @findReplaceReplacementHint.
  ///
  /// In zh, this message translates to:
  /// **'替换为'**
  String get findReplaceReplacementHint;

  /// No description provided for @findReplaceReplace.
  ///
  /// In zh, this message translates to:
  /// **'替换'**
  String get findReplaceReplace;

  /// No description provided for @findReplaceReplaceAll.
  ///
  /// In zh, this message translates to:
  /// **'全部替换'**
  String get findReplaceReplaceAll;

  /// No description provided for @replaceTitle.
  ///
  /// In zh, this message translates to:
  /// **'全书查找替换'**
  String get replaceTitle;

  /// No description provided for @replaceEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'输入查找内容，预览全书章节的匹配结果'**
  String get replaceEmptyHint;

  /// No description provided for @replaceSummary.
  ///
  /// In zh, this message translates to:
  /// **'共 {matches} 处命中，涉及 {chapters} 章'**
  String replaceSummary(int matches, int chapters);

  /// No description provided for @replaceConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'全部替换？'**
  String get replaceConfirmTitle;

  /// No description provided for @replaceConfirmBody.
  ///
  /// In zh, this message translates to:
  /// **'将在 {chapters} 章中共替换 {matches} 处文本。替换前会自动为受影响章节创建快照，可在版本历史中恢复。'**
  String replaceConfirmBody(int chapters, int matches);

  /// No description provided for @replaceDone.
  ///
  /// In zh, this message translates to:
  /// **'已替换：{chapters} 章共 {matches} 处'**
  String replaceDone(int chapters, int matches);

  /// No description provided for @aiErrorNetwork.
  ///
  /// In zh, this message translates to:
  /// **'网络请求失败：{detail}'**
  String aiErrorNetwork(String detail);

  /// No description provided for @aiErrorAuth.
  ///
  /// In zh, this message translates to:
  /// **'鉴权失败（{status}）：请到设置页检查 API Key'**
  String aiErrorAuth(int status);

  /// No description provided for @aiErrorRateLimit.
  ///
  /// In zh, this message translates to:
  /// **'请求过于频繁（429），请稍后重试'**
  String get aiErrorRateLimit;

  /// No description provided for @aiErrorServer.
  ///
  /// In zh, this message translates to:
  /// **'模型服务暂时不可用（{status}），请稍后重试'**
  String aiErrorServer(int status);

  /// No description provided for @aiErrorContentFilter.
  ///
  /// In zh, this message translates to:
  /// **'内容被模型服务商拒绝：{detail}'**
  String aiErrorContentFilter(String detail);

  /// No description provided for @aiErrorBadRequest.
  ///
  /// In zh, this message translates to:
  /// **'请求失败（{status}）：{detail}'**
  String aiErrorBadRequest(int status, String detail);

  /// No description provided for @aiErrorProviderError.
  ///
  /// In zh, this message translates to:
  /// **'模型服务返回错误：{detail}'**
  String aiErrorProviderError(String detail);

  /// No description provided for @aiErrorProviderFailed.
  ///
  /// In zh, this message translates to:
  /// **'模型服务返回失败：{detail}'**
  String aiErrorProviderFailed(String detail);

  /// No description provided for @aiErrorIncompleteOutput.
  ///
  /// In zh, this message translates to:
  /// **'模型输出被截断（incomplete），请缩短上下文或提高输出上限'**
  String get aiErrorIncompleteOutput;

  /// No description provided for @aiErrorToolLoop.
  ///
  /// In zh, this message translates to:
  /// **'AI 工具调用轮次超限，已停止'**
  String get aiErrorToolLoop;

  /// No description provided for @cloudErrorEndpointMissing.
  ///
  /// In zh, this message translates to:
  /// **'请先填写 Endpoint'**
  String get cloudErrorEndpointMissing;

  /// No description provided for @cloudErrorNetwork.
  ///
  /// In zh, this message translates to:
  /// **'网络请求失败：{detail}'**
  String cloudErrorNetwork(String detail);

  /// No description provided for @cloudErrorSignatureMismatch.
  ///
  /// In zh, this message translates to:
  /// **'签名校验失败（SignatureDoesNotMatch）：请检查 AccessKey / SecretKey、Endpoint 与 Region 是否匹配'**
  String get cloudErrorSignatureMismatch;

  /// No description provided for @cloudErrorForbidden.
  ///
  /// In zh, this message translates to:
  /// **'访问被拒绝（403）：请检查 AccessKey / SecretKey 与桶权限'**
  String get cloudErrorForbidden;

  /// No description provided for @cloudErrorNotFound.
  ///
  /// In zh, this message translates to:
  /// **'资源不存在（404）：请检查 Endpoint、桶名与路径前缀'**
  String get cloudErrorNotFound;

  /// No description provided for @cloudErrorClockSkew.
  ///
  /// In zh, this message translates to:
  /// **'设备时钟与服务器偏差过大（RequestTimeTooSkewed）：请校准系统时间'**
  String get cloudErrorClockSkew;

  /// No description provided for @cloudErrorHttp.
  ///
  /// In zh, this message translates to:
  /// **'云端返回 HTTP {status}：{detail}'**
  String cloudErrorHttp(int status, String detail);

  /// No description provided for @backupErrorInvalidZip.
  ///
  /// In zh, this message translates to:
  /// **'文件不是有效的 zip 备份'**
  String get backupErrorInvalidZip;

  /// No description provided for @backupErrorMissingEntry.
  ///
  /// In zh, this message translates to:
  /// **'备份文件缺少 {entry}'**
  String backupErrorMissingEntry(String entry);

  /// No description provided for @backupErrorDecodeFailed.
  ///
  /// In zh, this message translates to:
  /// **'备份内容解析失败'**
  String get backupErrorDecodeFailed;

  /// No description provided for @backupErrorInvalidFormat.
  ///
  /// In zh, this message translates to:
  /// **'备份内容格式不正确'**
  String get backupErrorInvalidFormat;

  /// No description provided for @backupErrorWrongFormat.
  ///
  /// In zh, this message translates to:
  /// **'不是 NovelPhone 的备份文件'**
  String get backupErrorWrongFormat;

  /// No description provided for @backupErrorNewerVersion.
  ///
  /// In zh, this message translates to:
  /// **'备份来自更新版本的应用，请先升级 app'**
  String get backupErrorNewerVersion;

  /// No description provided for @backupErrorChecksumMismatch.
  ///
  /// In zh, this message translates to:
  /// **'备份文件校验失败，内容可能已损坏'**
  String get backupErrorChecksumMismatch;

  /// No description provided for @backupErrorIncomplete.
  ///
  /// In zh, this message translates to:
  /// **'备份内容不完整'**
  String get backupErrorIncomplete;

  /// No description provided for @backupPreviewTitle.
  ///
  /// In zh, this message translates to:
  /// **'恢复前确认'**
  String get backupPreviewTitle;

  /// No description provided for @backupPreviewSource.
  ///
  /// In zh, this message translates to:
  /// **'备份文件：{name}'**
  String backupPreviewSource(String name);

  /// No description provided for @backupPreviewExportedAt.
  ///
  /// In zh, this message translates to:
  /// **'导出时间：{time}'**
  String backupPreviewExportedAt(String time);

  /// No description provided for @backupPreviewSchema.
  ///
  /// In zh, this message translates to:
  /// **'数据版本：v{version}'**
  String backupPreviewSchema(int version);

  /// No description provided for @backupPreviewCounts.
  ///
  /// In zh, this message translates to:
  /// **'{works} 部作品 · {chapters} 章 · {characters} 个角色卡'**
  String backupPreviewCounts(int works, int chapters, int characters);

  /// No description provided for @backupPreviewChecksumOk.
  ///
  /// In zh, this message translates to:
  /// **'SHA-256 完整性校验通过'**
  String get backupPreviewChecksumOk;

  /// No description provided for @backupPreviewChecksumLegacy.
  ///
  /// In zh, this message translates to:
  /// **'旧版备份，未包含完整性校验信息'**
  String get backupPreviewChecksumLegacy;

  /// No description provided for @backupPreviewContinue.
  ///
  /// In zh, this message translates to:
  /// **'继续恢复'**
  String get backupPreviewContinue;

  /// No description provided for @modelTestOk.
  ///
  /// In zh, this message translates to:
  /// **'连接成功'**
  String get modelTestOk;

  /// No description provided for @modelTestOkDetail.
  ///
  /// In zh, this message translates to:
  /// **'连接成功：{detail}'**
  String modelTestOkDetail(String detail);

  /// No description provided for @modelTestMissingModel.
  ///
  /// In zh, this message translates to:
  /// **'请先填写模型名'**
  String get modelTestMissingModel;

  /// No description provided for @modelTestMissingKey.
  ///
  /// In zh, this message translates to:
  /// **'请先填写 API Key'**
  String get modelTestMissingKey;

  /// No description provided for @modelTestFailed.
  ///
  /// In zh, this message translates to:
  /// **'连接失败：{detail}'**
  String modelTestFailed(String detail);

  /// No description provided for @searchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索全部作品…'**
  String get searchHint;

  /// No description provided for @searchEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'输入关键词，搜索全部作品的章节标题与正文。'**
  String get searchEmptyHint;

  /// No description provided for @searchFailed.
  ///
  /// In zh, this message translates to:
  /// **'搜索失败：{detail}'**
  String searchFailed(String detail);

  /// No description provided for @searchNoResults.
  ///
  /// In zh, this message translates to:
  /// **'没有找到包含「{keyword}」的章节'**
  String searchNoResults(String keyword);

  /// No description provided for @statsTitle.
  ///
  /// In zh, this message translates to:
  /// **'写作统计'**
  String get statsTitle;

  /// No description provided for @statsTodayTitle.
  ///
  /// In zh, this message translates to:
  /// **'今日写作'**
  String get statsTodayTitle;

  /// No description provided for @statsSetTarget.
  ///
  /// In zh, this message translates to:
  /// **'设定目标'**
  String get statsSetTarget;

  /// No description provided for @statsWordsOfGoal.
  ///
  /// In zh, this message translates to:
  /// **' / {goal} 字'**
  String statsWordsOfGoal(int goal);

  /// No description provided for @statsWordsOnly.
  ///
  /// In zh, this message translates to:
  /// **' 字'**
  String statsWordsOnly(int count);

  /// No description provided for @statsGoalRemaining.
  ///
  /// In zh, this message translates to:
  /// **'距离目标还差 {count} 字'**
  String statsGoalRemaining(int count);

  /// No description provided for @statsGoalReached.
  ///
  /// In zh, this message translates to:
  /// **'已达成今日目标'**
  String get statsGoalReached;

  /// No description provided for @statsStreakTitle.
  ///
  /// In zh, this message translates to:
  /// **'连续写作'**
  String get statsStreakTitle;

  /// No description provided for @statsStreakDays.
  ///
  /// In zh, this message translates to:
  /// **'{count} 天'**
  String statsStreakDays(int count);

  /// No description provided for @statsStreakKeepGoing.
  ///
  /// In zh, this message translates to:
  /// **'保持下去，别断更'**
  String get statsStreakKeepGoing;

  /// No description provided for @statsStreakStart.
  ///
  /// In zh, this message translates to:
  /// **'今天写一点，开启连击'**
  String get statsStreakStart;

  /// No description provided for @statsTrendTitle.
  ///
  /// In zh, this message translates to:
  /// **'写作趋势'**
  String get statsTrendTitle;

  /// No description provided for @statsTrendRange7.
  ///
  /// In zh, this message translates to:
  /// **'7 天'**
  String get statsTrendRange7;

  /// No description provided for @statsTrendRange30.
  ///
  /// In zh, this message translates to:
  /// **'30 天'**
  String get statsTrendRange30;

  /// No description provided for @statsTrendTotal.
  ///
  /// In zh, this message translates to:
  /// **'近 {days} 天共 {words} 字'**
  String statsTrendTotal(int days, int words);

  /// No description provided for @statsTrendEmpty.
  ///
  /// In zh, this message translates to:
  /// **'最近还没有写作记录'**
  String get statsTrendEmpty;

  /// No description provided for @statsHeatmapTitle.
  ///
  /// In zh, this message translates to:
  /// **'写作热力图'**
  String get statsHeatmapTitle;

  /// No description provided for @statsHeatmapActiveDays.
  ///
  /// In zh, this message translates to:
  /// **'近一年共 {count} 天有写作'**
  String statsHeatmapActiveDays(int count);

  /// No description provided for @statsHeatmapLess.
  ///
  /// In zh, this message translates to:
  /// **'少'**
  String get statsHeatmapLess;

  /// No description provided for @statsHeatmapMore.
  ///
  /// In zh, this message translates to:
  /// **'多'**
  String get statsHeatmapMore;

  /// No description provided for @statsHeatmapWeekMon.
  ///
  /// In zh, this message translates to:
  /// **'一'**
  String get statsHeatmapWeekMon;

  /// No description provided for @statsHeatmapWeekWed.
  ///
  /// In zh, this message translates to:
  /// **'三'**
  String get statsHeatmapWeekWed;

  /// No description provided for @statsHeatmapWeekFri.
  ///
  /// In zh, this message translates to:
  /// **'五'**
  String get statsHeatmapWeekFri;

  /// No description provided for @statsPomodoroTitle.
  ///
  /// In zh, this message translates to:
  /// **'番茄钟'**
  String get statsPomodoroTitle;

  /// No description provided for @statsPomodoroMinutes.
  ///
  /// In zh, this message translates to:
  /// **'{count} 分钟'**
  String statsPomodoroMinutes(int count);

  /// No description provided for @statsPomodoroStart.
  ///
  /// In zh, this message translates to:
  /// **'开始'**
  String get statsPomodoroStart;

  /// No description provided for @statsPomodoroPause.
  ///
  /// In zh, this message translates to:
  /// **'暂停'**
  String get statsPomodoroPause;

  /// No description provided for @statsPomodoroDoneToday.
  ///
  /// In zh, this message translates to:
  /// **'今日已完成 {count} 个番茄钟'**
  String statsPomodoroDoneToday(int count);

  /// No description provided for @statsPomodoroFinished.
  ///
  /// In zh, this message translates to:
  /// **'番茄钟完成，休息一下吧'**
  String get statsPomodoroFinished;

  /// No description provided for @statsDailyTargetTitle.
  ///
  /// In zh, this message translates to:
  /// **'每日字数目标'**
  String get statsDailyTargetTitle;

  /// No description provided for @statsDailyTargetHint.
  ///
  /// In zh, this message translates to:
  /// **'0 表示不设目标'**
  String get statsDailyTargetHint;

  /// No description provided for @statsDailyTargetUnit.
  ///
  /// In zh, this message translates to:
  /// **'字'**
  String get statsDailyTargetUnit;

  /// No description provided for @statsPomodoroDurationTitle.
  ///
  /// In zh, this message translates to:
  /// **'番茄钟时长'**
  String get statsPomodoroDurationTitle;

  /// No description provided for @statsPomodoroDurationHint.
  ///
  /// In zh, this message translates to:
  /// **'1~120'**
  String get statsPomodoroDurationHint;

  /// No description provided for @statsPomodoroDurationUnit.
  ///
  /// In zh, this message translates to:
  /// **'分钟'**
  String get statsPomodoroDurationUnit;

  /// No description provided for @appearanceTitle.
  ///
  /// In zh, this message translates to:
  /// **'写作外观'**
  String get appearanceTitle;

  /// No description provided for @appearanceDarkPaper.
  ///
  /// In zh, this message translates to:
  /// **'夜间纸张'**
  String get appearanceDarkPaper;

  /// No description provided for @appearanceDarkPaperSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'深色护眼背景，适合关灯后写作'**
  String get appearanceDarkPaperSubtitle;

  /// No description provided for @appearanceFontSize.
  ///
  /// In zh, this message translates to:
  /// **'正文字号'**
  String get appearanceFontSize;

  /// No description provided for @appearanceLineHeight.
  ///
  /// In zh, this message translates to:
  /// **'行距'**
  String get appearanceLineHeight;

  /// No description provided for @appearancePreview.
  ///
  /// In zh, this message translates to:
  /// **'预览'**
  String get appearancePreview;

  /// No description provided for @appearancePreviewText.
  ///
  /// In zh, this message translates to:
  /// **'长夜将尽，她推开窗，风雪扑面而来。\n远处的灯一盏盏熄灭，只有案头那支蜡烛还亮着。'**
  String get appearancePreviewText;

  /// No description provided for @summaryEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑本章梗概'**
  String get summaryEditTitle;

  /// No description provided for @summaryEditHint.
  ///
  /// In zh, this message translates to:
  /// **'说明本章要发生什么（0-1000 字）；AI 章纲扩写也以此为一句话梗概'**
  String get summaryEditHint;

  /// No description provided for @aiNoticeTitle.
  ///
  /// In zh, this message translates to:
  /// **'使用 AI 前请知悉'**
  String get aiNoticeTitle;

  /// No description provided for @aiNoticeBody.
  ///
  /// In zh, this message translates to:
  /// **'你的作品正文与设定默认只保存在本机。当你使用 AI 功能时，应用会把你自行配置的模型服务商所需的最小上下文（当前章节内容、章纲、相关角色卡等）通过网络直接发送给你配置的服务商，不会经过 NovelPhone 的服务器。\n\n你的 API Key 保存在设备安全区，不会上传。\n\n点击\"我已了解\"表示你已知悉并同意上述传输行为。'**
  String get aiNoticeBody;

  /// No description provided for @aiNoticeConfirm.
  ///
  /// In zh, this message translates to:
  /// **'我已了解'**
  String get aiNoticeConfirm;

  /// No description provided for @settingsSectionAiModels.
  ///
  /// In zh, this message translates to:
  /// **'AI 与模型'**
  String get settingsSectionAiModels;

  /// No description provided for @settingsModelGroups.
  ///
  /// In zh, this message translates to:
  /// **'模型组与 API Key'**
  String get settingsModelGroups;

  /// No description provided for @settingsModelGroupsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'按服务商管理 key、baseUrl、模型列表与生成参数'**
  String get settingsModelGroupsSubtitle;

  /// No description provided for @settingsTaskMapping.
  ///
  /// In zh, this message translates to:
  /// **'任务与模型映射'**
  String get settingsTaskMapping;

  /// No description provided for @settingsTaskMappingSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'为续写、问答、体检等各类 AI 任务指定模型组'**
  String get settingsTaskMappingSubtitle;

  /// No description provided for @settingsTokenStats.
  ///
  /// In zh, this message translates to:
  /// **'Token 与采纳统计'**
  String get settingsTokenStats;

  /// No description provided for @settingsAiBudget.
  ///
  /// In zh, this message translates to:
  /// **'月度 AI 预算'**
  String get settingsAiBudget;

  /// No description provided for @settingsAiBudgetValue.
  ///
  /// In zh, this message translates to:
  /// **'¥{value} / 月'**
  String settingsAiBudgetValue(String value);

  /// No description provided for @settingsMcpServers.
  ///
  /// In zh, this message translates to:
  /// **'MCP 工具服务'**
  String get settingsMcpServers;

  /// No description provided for @settingsMcpServersSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'接入远程 MCP server，把其工具提供给 AI 调用'**
  String get settingsMcpServersSubtitle;

  /// No description provided for @settingsSkills.
  ///
  /// In zh, this message translates to:
  /// **'自定义技能'**
  String get settingsSkills;

  /// No description provided for @settingsSkillsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'附加指令与工具白名单，注入续写与灵感生成'**
  String get settingsSkillsSubtitle;

  /// No description provided for @settingsMcpAudit.
  ///
  /// In zh, this message translates to:
  /// **'MCP 调用审计'**
  String get settingsMcpAudit;

  /// No description provided for @settingsMcpAuditSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'最近 100 次远程工具调用记录（仅存本机）'**
  String get settingsMcpAuditSubtitle;

  /// No description provided for @mcpAuditTitle.
  ///
  /// In zh, this message translates to:
  /// **'MCP 调用审计'**
  String get mcpAuditTitle;

  /// No description provided for @mcpAuditEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有 MCP 工具调用记录'**
  String get mcpAuditEmpty;

  /// No description provided for @mcpAuditEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'在灵感生成中启用 MCP 服务器后，远程工具调用会记录在这里。'**
  String get mcpAuditEmptyHint;

  /// No description provided for @mcpAuditClear.
  ///
  /// In zh, this message translates to:
  /// **'清空记录'**
  String get mcpAuditClear;

  /// No description provided for @mcpAuditClearConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'清空调用审计？'**
  String get mcpAuditClearConfirmTitle;

  /// No description provided for @mcpAuditClearConfirmBody.
  ///
  /// In zh, this message translates to:
  /// **'全部调用记录将从本机删除，此操作不可恢复。'**
  String get mcpAuditClearConfirmBody;

  /// No description provided for @mcpAuditCleared.
  ///
  /// In zh, this message translates to:
  /// **'调用记录已清空'**
  String get mcpAuditCleared;

  /// No description provided for @mcpAuditSuccess.
  ///
  /// In zh, this message translates to:
  /// **'成功'**
  String get mcpAuditSuccess;

  /// No description provided for @mcpAuditFailure.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get mcpAuditFailure;

  /// No description provided for @mcpAuditArguments.
  ///
  /// In zh, this message translates to:
  /// **'参数'**
  String get mcpAuditArguments;

  /// No description provided for @mcpAuditResult.
  ///
  /// In zh, this message translates to:
  /// **'结果'**
  String get mcpAuditResult;

  /// No description provided for @settingsSectionWriting.
  ///
  /// In zh, this message translates to:
  /// **'写作'**
  String get settingsSectionWriting;

  /// No description provided for @settingsAppearance.
  ///
  /// In zh, this message translates to:
  /// **'写作外观'**
  String get settingsAppearance;

  /// No description provided for @settingsAppearanceSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'夜间纸张、正文字号与行距'**
  String get settingsAppearanceSubtitle;

  /// No description provided for @settingsThemeMode.
  ///
  /// In zh, this message translates to:
  /// **'深浅模式'**
  String get settingsThemeMode;

  /// No description provided for @themeModeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get themeModeSystem;

  /// No description provided for @themeModeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get themeModeLight;

  /// No description provided for @themeModeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get themeModeDark;

  /// No description provided for @settingsLanguage.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get settingsLanguage;

  /// No description provided for @settingsWritingStats.
  ///
  /// In zh, this message translates to:
  /// **'写作统计'**
  String get settingsWritingStats;

  /// No description provided for @settingsWritingStatsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'每日字数目标、连续写作天数与番茄钟'**
  String get settingsWritingStatsSubtitle;

  /// No description provided for @settingsSectionData.
  ///
  /// In zh, this message translates to:
  /// **'数据'**
  String get settingsSectionData;

  /// No description provided for @settingsBackupHint.
  ///
  /// In zh, this message translates to:
  /// **'作品数据全部保存在本机。卸载应用或换机前，请先「备份到文件」，否则数据将无法找回。'**
  String get settingsBackupHint;

  /// No description provided for @settingsBackupToFile.
  ///
  /// In zh, this message translates to:
  /// **'备份到文件'**
  String get settingsBackupToFile;

  /// No description provided for @settingsBackupToFileSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'导出全部作品与正文，用于换机或防丢失'**
  String get settingsBackupToFileSubtitle;

  /// No description provided for @settingsRestoreFromBackup.
  ///
  /// In zh, this message translates to:
  /// **'从备份恢复'**
  String get settingsRestoreFromBackup;

  /// No description provided for @settingsRestoreFromBackupSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'选择备份文件，可合并为新作品或覆盖本机数据'**
  String get settingsRestoreFromBackupSubtitle;

  /// No description provided for @settingsCloudBackup.
  ///
  /// In zh, this message translates to:
  /// **'云备份'**
  String get settingsCloudBackup;

  /// No description provided for @settingsCloudBackupSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'备份到你自己的对象存储（S3 / OSS / COS 等），默认关闭'**
  String get settingsCloudBackupSubtitle;

  /// No description provided for @settingsTrash.
  ///
  /// In zh, this message translates to:
  /// **'回收站'**
  String get settingsTrash;

  /// No description provided for @settingsTrashSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'恢复误删的作品与章节（保留 30 天）'**
  String get settingsTrashSubtitle;

  /// No description provided for @trashTitle.
  ///
  /// In zh, this message translates to:
  /// **'回收站'**
  String get trashTitle;

  /// No description provided for @trashHint.
  ///
  /// In zh, this message translates to:
  /// **'回收站中的内容保留 30 天，到期后自动永久删除。'**
  String get trashHint;

  /// No description provided for @trashTabWorks.
  ///
  /// In zh, this message translates to:
  /// **'作品'**
  String get trashTabWorks;

  /// No description provided for @trashTabChapters.
  ///
  /// In zh, this message translates to:
  /// **'章节'**
  String get trashTabChapters;

  /// No description provided for @trashEmptyWorks.
  ///
  /// In zh, this message translates to:
  /// **'回收站里没有作品'**
  String get trashEmptyWorks;

  /// No description provided for @trashEmptyChapters.
  ///
  /// In zh, this message translates to:
  /// **'回收站里没有章节'**
  String get trashEmptyChapters;

  /// No description provided for @trashDeletedAt.
  ///
  /// In zh, this message translates to:
  /// **'删除于 {time}'**
  String trashDeletedAt(String time);

  /// No description provided for @trashChapterMeta.
  ///
  /// In zh, this message translates to:
  /// **'《{work}》· {volume}'**
  String trashChapterMeta(String work, String volume);

  /// No description provided for @trashRestore.
  ///
  /// In zh, this message translates to:
  /// **'恢复'**
  String get trashRestore;

  /// No description provided for @trashDeleteForever.
  ///
  /// In zh, this message translates to:
  /// **'永久删除'**
  String get trashDeleteForever;

  /// No description provided for @trashPurgeTitle.
  ///
  /// In zh, this message translates to:
  /// **'永久删除「{title}」？'**
  String trashPurgeTitle(String title);

  /// No description provided for @trashPurgeWorkBody.
  ///
  /// In zh, this message translates to:
  /// **'作品的全部章节、角色卡与章纲将被永久删除，且无法恢复。'**
  String get trashPurgeWorkBody;

  /// No description provided for @trashPurgeChapterBody.
  ///
  /// In zh, this message translates to:
  /// **'本章正文与版本历史将被永久删除，且无法恢复。'**
  String get trashPurgeChapterBody;

  /// No description provided for @trashPurged.
  ///
  /// In zh, this message translates to:
  /// **'已永久删除'**
  String get trashPurged;

  /// No description provided for @trashRestored.
  ///
  /// In zh, this message translates to:
  /// **'已恢复「{title}」'**
  String trashRestored(String title);

  /// No description provided for @trashEmptyAction.
  ///
  /// In zh, this message translates to:
  /// **'清空回收站'**
  String get trashEmptyAction;

  /// No description provided for @trashEmptyConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'清空回收站？'**
  String get trashEmptyConfirmTitle;

  /// No description provided for @trashEmptyConfirmBody.
  ///
  /// In zh, this message translates to:
  /// **'回收站中的全部作品与章节将被永久删除，且无法恢复。'**
  String get trashEmptyConfirmBody;

  /// No description provided for @trashEmptyDone.
  ///
  /// In zh, this message translates to:
  /// **'回收站已清空'**
  String get trashEmptyDone;

  /// No description provided for @trashLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败：{detail}'**
  String trashLoadFailed(String detail);

  /// No description provided for @worksMovedToTrash.
  ///
  /// In zh, this message translates to:
  /// **'《{title}》已移入回收站'**
  String worksMovedToTrash(String title);

  /// No description provided for @chaptersMovedToTrash.
  ///
  /// In zh, this message translates to:
  /// **'章节已移入回收站'**
  String get chaptersMovedToTrash;

  /// No description provided for @commonUndo.
  ///
  /// In zh, this message translates to:
  /// **'撤销'**
  String get commonUndo;

  /// No description provided for @modelGroupsNew.
  ///
  /// In zh, this message translates to:
  /// **'新增模型组'**
  String get modelGroupsNew;

  /// No description provided for @modelGroupsLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败：{detail}'**
  String modelGroupsLoadFailed(String detail);

  /// No description provided for @modelGroupsEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有模型组'**
  String get modelGroupsEmptyTitle;

  /// No description provided for @modelGroupsEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'添加服务商与 API Key 后，续写与灵感功能才能使用'**
  String get modelGroupsEmptyHint;

  /// No description provided for @modelGroupsOpenAiCompat.
  ///
  /// In zh, this message translates to:
  /// **'OpenAI 兼容'**
  String get modelGroupsOpenAiCompat;

  /// No description provided for @modelGroupsNoModel.
  ///
  /// In zh, this message translates to:
  /// **'未填写模型'**
  String get modelGroupsNoModel;

  /// No description provided for @modelGroupsModelSeparator.
  ///
  /// In zh, this message translates to:
  /// **'、'**
  String get modelGroupsModelSeparator;

  /// No description provided for @modelGroupsNoKey.
  ///
  /// In zh, this message translates to:
  /// **'未填 Key'**
  String get modelGroupsNoKey;

  /// No description provided for @modelGroupsDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除模型组'**
  String get modelGroupsDeleteTitle;

  /// No description provided for @modelGroupsDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'删除「{name}」后，其 API Key 也会一并从本机移除。'**
  String modelGroupsDeleteConfirm(String name);

  /// No description provided for @modelGroupsDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除模型组'**
  String get modelGroupsDeleted;

  /// No description provided for @modelEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑模型组'**
  String get modelEditTitle;

  /// No description provided for @modelEditNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get modelEditNameLabel;

  /// No description provided for @modelEditNameHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：DeepSeek 官方'**
  String get modelEditNameHint;

  /// No description provided for @modelEditNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请填写名称'**
  String get modelEditNameRequired;

  /// No description provided for @modelEditProtocolLabel.
  ///
  /// In zh, this message translates to:
  /// **'协议类型'**
  String get modelEditProtocolLabel;

  /// No description provided for @modelEditBaseUrlHelper.
  ///
  /// In zh, this message translates to:
  /// **'需包含 /v1，例如 https://api.deepseek.com/v1'**
  String get modelEditBaseUrlHelper;

  /// No description provided for @modelEditBaseUrlRequired.
  ///
  /// In zh, this message translates to:
  /// **'请填写 Base URL'**
  String get modelEditBaseUrlRequired;

  /// No description provided for @modelEditModelsLabel.
  ///
  /// In zh, this message translates to:
  /// **'模型列表'**
  String get modelEditModelsLabel;

  /// No description provided for @modelEditModelsHelper.
  ///
  /// In zh, this message translates to:
  /// **'每行一个，第一行为默认使用的模型'**
  String get modelEditModelsHelper;

  /// No description provided for @modelEditModelsRequired.
  ///
  /// In zh, this message translates to:
  /// **'请至少填写一个模型名'**
  String get modelEditModelsRequired;

  /// No description provided for @modelEditApiKeySaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存，留空则不修改'**
  String get modelEditApiKeySaved;

  /// No description provided for @modelEditApiKeyHint.
  ///
  /// In zh, this message translates to:
  /// **'粘贴服务商提供的 Key'**
  String get modelEditApiKeyHint;

  /// No description provided for @modelEditApiKeyHelper.
  ///
  /// In zh, this message translates to:
  /// **'仅保存在本机安全存储，不会随备份导出'**
  String get modelEditApiKeyHelper;

  /// No description provided for @modelEditTemperature.
  ///
  /// In zh, this message translates to:
  /// **'温度'**
  String get modelEditTemperature;

  /// No description provided for @modelEditMaxTokensLabel.
  ///
  /// In zh, this message translates to:
  /// **'输出上限 token'**
  String get modelEditMaxTokensLabel;

  /// No description provided for @modelEditContextWindow.
  ///
  /// In zh, this message translates to:
  /// **'上下文窗口'**
  String get modelEditContextWindow;

  /// No description provided for @modelEditContextWindowHelper.
  ///
  /// In zh, this message translates to:
  /// **'预算取其 50%'**
  String get modelEditContextWindowHelper;

  /// No description provided for @modelEditEnabled.
  ///
  /// In zh, this message translates to:
  /// **'启用'**
  String get modelEditEnabled;

  /// No description provided for @modelEditEnabledSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'停用后不会被任务映射使用'**
  String get modelEditEnabledSubtitle;

  /// No description provided for @modelEditTestConnection.
  ///
  /// In zh, this message translates to:
  /// **'测试连接'**
  String get modelEditTestConnection;

  /// No description provided for @modelEditTestNoModel.
  ///
  /// In zh, this message translates to:
  /// **'请先填写至少一个模型名'**
  String get modelEditTestNoModel;

  /// No description provided for @modelEditTestNoApiKey.
  ///
  /// In zh, this message translates to:
  /// **'请先填写 API Key'**
  String get modelEditTestNoApiKey;

  /// No description provided for @modelEditSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get modelEditSaved;

  /// No description provided for @taskMapLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败：{detail}'**
  String taskMapLoadFailed(String detail);

  /// No description provided for @taskMapEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'请先在「模型组与 API Key」中添加模型组'**
  String get taskMapEmptyHint;

  /// No description provided for @taskMapIntro.
  ///
  /// In zh, this message translates to:
  /// **'为每类 AI 任务指定使用的模型组；未指定则对应功能不可用。'**
  String get taskMapIntro;

  /// No description provided for @taskMapUnassigned.
  ///
  /// In zh, this message translates to:
  /// **'未指定'**
  String get taskMapUnassigned;

  /// No description provided for @taskModelRecommendTitle.
  ///
  /// In zh, this message translates to:
  /// **'按采纳质量推荐'**
  String get taskModelRecommendTitle;

  /// No description provided for @taskModelRecommendIntro.
  ///
  /// In zh, this message translates to:
  /// **'基于近 30 天各模型的采纳率；至少 3 次调用、且比当前映射高 10 个百分点才会推荐。'**
  String get taskModelRecommendIntro;

  /// No description provided for @taskModelRecommendStat.
  ///
  /// In zh, this message translates to:
  /// **'{model} · {calls} 次调用 · 采纳率 {adoption}%（原样 {verbatim}%）'**
  String taskModelRecommendStat(
    String model,
    int calls,
    int adoption,
    int verbatim,
  );

  /// No description provided for @taskModelRecommendCurrent.
  ///
  /// In zh, this message translates to:
  /// **'当前：{model}'**
  String taskModelRecommendCurrent(String model);

  /// No description provided for @taskModelRecommendNoCurrent.
  ///
  /// In zh, this message translates to:
  /// **'当前未单独指定，使用回退模型'**
  String get taskModelRecommendNoCurrent;

  /// No description provided for @taskModelRecommendApply.
  ///
  /// In zh, this message translates to:
  /// **'改用「{group}」'**
  String taskModelRecommendApply(String group);

  /// No description provided for @taskModelRecommendApplied.
  ///
  /// In zh, this message translates to:
  /// **'已切换到「{group}」'**
  String taskModelRecommendApplied(String group);

  /// No description provided for @aiTaskContinue.
  ///
  /// In zh, this message translates to:
  /// **'AI 续写'**
  String get aiTaskContinue;

  /// No description provided for @aiTaskInspire.
  ///
  /// In zh, this message translates to:
  /// **'AI 灵感'**
  String get aiTaskInspire;

  /// No description provided for @aiTaskRewrite.
  ///
  /// In zh, this message translates to:
  /// **'AI 改写'**
  String get aiTaskRewrite;

  /// No description provided for @aiTaskCheck.
  ///
  /// In zh, this message translates to:
  /// **'AI 感检查'**
  String get aiTaskCheck;

  /// No description provided for @aiTaskSummary.
  ///
  /// In zh, this message translates to:
  /// **'AI 逐章摘要'**
  String get aiTaskSummary;

  /// No description provided for @aiTaskOutlineExpand.
  ///
  /// In zh, this message translates to:
  /// **'AI 章纲扩写'**
  String get aiTaskOutlineExpand;

  /// No description provided for @aiTaskVolumeSummary.
  ///
  /// In zh, this message translates to:
  /// **'AI 本卷前情回顾'**
  String get aiTaskVolumeSummary;

  /// No description provided for @aiTaskContinuity.
  ///
  /// In zh, this message translates to:
  /// **'AI 设定一致性检查'**
  String get aiTaskContinuity;

  /// No description provided for @tokenStatsResetTitle.
  ///
  /// In zh, this message translates to:
  /// **'重置统计'**
  String get tokenStatsResetTitle;

  /// No description provided for @tokenStatsResetBody.
  ///
  /// In zh, this message translates to:
  /// **'清空全部生成与采纳记录，不可恢复。'**
  String get tokenStatsResetBody;

  /// No description provided for @tokenStatsLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败：{detail}'**
  String tokenStatsLoadFailed(String detail);

  /// No description provided for @tokenStatsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有生成记录'**
  String get tokenStatsEmpty;

  /// No description provided for @tokenStatsCalls.
  ///
  /// In zh, this message translates to:
  /// **'生成次数'**
  String get tokenStatsCalls;

  /// No description provided for @tokenStatsTotalTokens.
  ///
  /// In zh, this message translates to:
  /// **'Token 合计'**
  String get tokenStatsTotalTokens;

  /// No description provided for @tokenStatsAdoptionRate.
  ///
  /// In zh, this message translates to:
  /// **'采纳率'**
  String get tokenStatsAdoptionRate;

  /// No description provided for @tokenStatsVerbatimRate.
  ///
  /// In zh, this message translates to:
  /// **'原样采纳率'**
  String get tokenStatsVerbatimRate;

  /// No description provided for @tokenStatsIgnoreRate.
  ///
  /// In zh, this message translates to:
  /// **'忽略率'**
  String get tokenStatsIgnoreRate;

  /// No description provided for @tokenStatsCheckHandledRate.
  ///
  /// In zh, this message translates to:
  /// **'检查问题处置率'**
  String get tokenStatsCheckHandledRate;

  /// No description provided for @tokenStatsRowCalls.
  ///
  /// In zh, this message translates to:
  /// **'{count} 次'**
  String tokenStatsRowCalls(int count);

  /// No description provided for @tokenStatsRowTokens.
  ///
  /// In zh, this message translates to:
  /// **'输入 {prompt} · 输出 {completion}'**
  String tokenStatsRowTokens(String prompt, String completion);

  /// No description provided for @tokenStatsRowChars.
  ///
  /// In zh, this message translates to:
  /// **'生成 {output} 字 · 采纳 {adopted} 字'**
  String tokenStatsRowChars(int output, int adopted);

  /// No description provided for @tokenStatsRowCounts.
  ///
  /// In zh, this message translates to:
  /// **'采纳 {adopted} 次 · 忽略 {ignored} 次'**
  String tokenStatsRowCounts(int adopted, int ignored);

  /// No description provided for @statStatusAdopted.
  ///
  /// In zh, this message translates to:
  /// **'已采纳'**
  String get statStatusAdopted;

  /// No description provided for @statStatusIgnored.
  ///
  /// In zh, this message translates to:
  /// **'已忽略'**
  String get statStatusIgnored;

  /// No description provided for @statStatusRegenerated.
  ///
  /// In zh, this message translates to:
  /// **'重新生成'**
  String get statStatusRegenerated;

  /// No description provided for @statStatusAborted.
  ///
  /// In zh, this message translates to:
  /// **'已中止'**
  String get statStatusAborted;

  /// No description provided for @statStatusPending.
  ///
  /// In zh, this message translates to:
  /// **'待处置'**
  String get statStatusPending;

  /// No description provided for @backupShareTitle.
  ///
  /// In zh, this message translates to:
  /// **'NovelPhone 备份'**
  String get backupShareTitle;

  /// No description provided for @backupRestoreDone.
  ///
  /// In zh, this message translates to:
  /// **'恢复完成：{works} 部作品、{chapters} 章、{characters} 个角色卡'**
  String backupRestoreDone(int works, int chapters, int characters);

  /// No description provided for @backupRestoreModeTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择恢复方式'**
  String get backupRestoreModeTitle;

  /// No description provided for @backupRestoreModeBody.
  ///
  /// In zh, this message translates to:
  /// **'合并：把备份中的作品作为新作品导入，不清空现有数据。\n覆盖：先清空本机全部作品，再按备份原样还原，无法撤销。'**
  String get backupRestoreModeBody;

  /// No description provided for @backupRestoreModeMerge.
  ///
  /// In zh, this message translates to:
  /// **'合并'**
  String get backupRestoreModeMerge;

  /// No description provided for @backupRestoreModeOverwrite.
  ///
  /// In zh, this message translates to:
  /// **'覆盖'**
  String get backupRestoreModeOverwrite;

  /// No description provided for @cloudSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get cloudSaved;

  /// No description provided for @cloudTitle.
  ///
  /// In zh, this message translates to:
  /// **'云备份'**
  String get cloudTitle;

  /// No description provided for @cloudEnable.
  ///
  /// In zh, this message translates to:
  /// **'启用云备份'**
  String get cloudEnable;

  /// No description provided for @cloudEnableSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'关闭时不联网、不产生任何云端请求'**
  String get cloudEnableSubtitle;

  /// No description provided for @cloudProviderLabel.
  ///
  /// In zh, this message translates to:
  /// **'服务商'**
  String get cloudProviderLabel;

  /// No description provided for @cloudProviderAwsS3.
  ///
  /// In zh, this message translates to:
  /// **'AWS S3'**
  String get cloudProviderAwsS3;

  /// No description provided for @cloudProviderAliyunOss.
  ///
  /// In zh, this message translates to:
  /// **'阿里云 OSS'**
  String get cloudProviderAliyunOss;

  /// No description provided for @cloudProviderQiniuKodo.
  ///
  /// In zh, this message translates to:
  /// **'七牛云 Kodo'**
  String get cloudProviderQiniuKodo;

  /// No description provided for @cloudProviderTencentCos.
  ///
  /// In zh, this message translates to:
  /// **'腾讯云 COS'**
  String get cloudProviderTencentCos;

  /// No description provided for @cloudProviderHuaweiObs.
  ///
  /// In zh, this message translates to:
  /// **'华为云 OBS'**
  String get cloudProviderHuaweiObs;

  /// No description provided for @cloudRegionHintAwsS3.
  ///
  /// In zh, this message translates to:
  /// **'例如 us-east-1'**
  String get cloudRegionHintAwsS3;

  /// No description provided for @cloudRegionHintAliyunOss.
  ///
  /// In zh, this message translates to:
  /// **'例如 cn-hangzhou'**
  String get cloudRegionHintAliyunOss;

  /// No description provided for @cloudRegionHintQiniuKodo.
  ///
  /// In zh, this message translates to:
  /// **'例如 cn-east-1'**
  String get cloudRegionHintQiniuKodo;

  /// No description provided for @cloudRegionHintTencentCos.
  ///
  /// In zh, this message translates to:
  /// **'例如 ap-guangzhou'**
  String get cloudRegionHintTencentCos;

  /// No description provided for @cloudRegionHintHuaweiObs.
  ///
  /// In zh, this message translates to:
  /// **'例如 cn-north-4'**
  String get cloudRegionHintHuaweiObs;

  /// No description provided for @cloudEndpointHintAwsS3.
  ///
  /// In zh, this message translates to:
  /// **'不带桶名，例如 s3.us-east-1.amazonaws.com'**
  String get cloudEndpointHintAwsS3;

  /// No description provided for @cloudEndpointHintAliyunOss.
  ///
  /// In zh, this message translates to:
  /// **'不带桶名，例如 oss-cn-hangzhou.aliyuncs.com'**
  String get cloudEndpointHintAliyunOss;

  /// No description provided for @cloudEndpointHintQiniuKodo.
  ///
  /// In zh, this message translates to:
  /// **'不带桶名，例如 s3-cn-east-1.qiniucs.com'**
  String get cloudEndpointHintQiniuKodo;

  /// No description provided for @cloudEndpointHintTencentCos.
  ///
  /// In zh, this message translates to:
  /// **'不带桶名，例如 cos.ap-guangzhou.myqcloud.com'**
  String get cloudEndpointHintTencentCos;

  /// No description provided for @cloudEndpointHintHuaweiObs.
  ///
  /// In zh, this message translates to:
  /// **'不带桶名，例如 obs.cn-north-4.myhuaweicloud.com'**
  String get cloudEndpointHintHuaweiObs;

  /// No description provided for @cloudRegionRequired.
  ///
  /// In zh, this message translates to:
  /// **'请填写Region'**
  String get cloudRegionRequired;

  /// No description provided for @cloudEndpointRequired.
  ///
  /// In zh, this message translates to:
  /// **'请填写Endpoint'**
  String get cloudEndpointRequired;

  /// No description provided for @cloudBucketRequired.
  ///
  /// In zh, this message translates to:
  /// **'请填写桶名'**
  String get cloudBucketRequired;

  /// No description provided for @cloudBucketLabel.
  ///
  /// In zh, this message translates to:
  /// **'存储桶 Bucket'**
  String get cloudBucketLabel;

  /// No description provided for @cloudPrefixLabel.
  ///
  /// In zh, this message translates to:
  /// **'路径前缀'**
  String get cloudPrefixLabel;

  /// No description provided for @cloudPrefixHelper.
  ///
  /// In zh, this message translates to:
  /// **'默认 {prefix}'**
  String cloudPrefixHelper(String prefix);

  /// No description provided for @cloudKeepCountLabel.
  ///
  /// In zh, this message translates to:
  /// **'保留份数'**
  String get cloudKeepCountLabel;

  /// No description provided for @cloudKeepCountHelper.
  ///
  /// In zh, this message translates to:
  /// **'超出后自动删除最旧的备份，最小 1'**
  String get cloudKeepCountHelper;

  /// No description provided for @cloudKeepCountInvalid.
  ///
  /// In zh, this message translates to:
  /// **'请填写不小于 1 的整数'**
  String get cloudKeepCountInvalid;

  /// No description provided for @cloudCredentialsHelper.
  ///
  /// In zh, this message translates to:
  /// **'仅保存在本机安全存储，不会随备份导出'**
  String get cloudCredentialsHelper;

  /// No description provided for @cloudSecretHintSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存，留空则不修改'**
  String get cloudSecretHintSaved;

  /// No description provided for @cloudTestConnection.
  ///
  /// In zh, this message translates to:
  /// **'测试连接'**
  String get cloudTestConnection;

  /// No description provided for @cloudBackupNow.
  ///
  /// In zh, this message translates to:
  /// **'立即备份'**
  String get cloudBackupNow;

  /// No description provided for @cloudRefreshRemote.
  ///
  /// In zh, this message translates to:
  /// **'刷新远端备份'**
  String get cloudRefreshRemote;

  /// No description provided for @cloudTestOk.
  ///
  /// In zh, this message translates to:
  /// **'连接成功：桶与凭证可用'**
  String get cloudTestOk;

  /// No description provided for @cloudBackupOk.
  ///
  /// In zh, this message translates to:
  /// **'备份成功：{objectKey}（{size}）'**
  String cloudBackupOk(String objectKey, String size);

  /// No description provided for @cloudBackupOkPruned.
  ///
  /// In zh, this message translates to:
  /// **'，已清理 {count} 份旧备份'**
  String cloudBackupOkPruned(int count);

  /// No description provided for @cloudRemoteEmpty.
  ///
  /// In zh, this message translates to:
  /// **'远端暂无备份'**
  String get cloudRemoteEmpty;

  /// No description provided for @cloudRemoteCount.
  ///
  /// In zh, this message translates to:
  /// **'远端共 {count} 份备份'**
  String cloudRemoteCount(int count);

  /// No description provided for @cloudNeedEndpointRegionBucket.
  ///
  /// In zh, this message translates to:
  /// **'请先完整填写 Endpoint、Region 与桶名'**
  String get cloudNeedEndpointRegionBucket;

  /// No description provided for @cloudNeedCredentials.
  ///
  /// In zh, this message translates to:
  /// **'请先填写 AccessKey 与 SecretKey'**
  String get cloudNeedCredentials;

  /// No description provided for @cloudAutoTitle.
  ///
  /// In zh, this message translates to:
  /// **'自动备份'**
  String get cloudAutoTitle;

  /// No description provided for @cloudAutoSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'开启后于启动 / 回到前台时，距上次备份满所选间隔则自动备份'**
  String get cloudAutoSubtitle;

  /// No description provided for @cloudIntervalLabel.
  ///
  /// In zh, this message translates to:
  /// **'备份频率'**
  String get cloudIntervalLabel;

  /// No description provided for @cloudIntervalEvery12h.
  ///
  /// In zh, this message translates to:
  /// **'每 12 小时'**
  String get cloudIntervalEvery12h;

  /// No description provided for @cloudIntervalDaily.
  ///
  /// In zh, this message translates to:
  /// **'每天'**
  String get cloudIntervalDaily;

  /// No description provided for @cloudIntervalWeekly.
  ///
  /// In zh, this message translates to:
  /// **'每周'**
  String get cloudIntervalWeekly;

  /// No description provided for @cloudRemoteSection.
  ///
  /// In zh, this message translates to:
  /// **'远端备份'**
  String get cloudRemoteSection;

  /// No description provided for @cloudRemoteTapRefresh.
  ///
  /// In zh, this message translates to:
  /// **'点击「刷新远端备份」查看已有备份'**
  String get cloudRemoteTapRefresh;

  /// No description provided for @cloudPrivacyHint.
  ///
  /// In zh, this message translates to:
  /// **'云备份默认关闭，仅在你开启并触发时联网（含开启自动备份后按频率触发）。备份内容与本地 zip 一致（含正文，不含任何 API Key）；AccessKey / SecretKey 只保存在本机安全存储。'**
  String get cloudPrivacyHint;

  /// No description provided for @mcpDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除 MCP 服务'**
  String get mcpDeleteTitle;

  /// No description provided for @mcpDeleteBody.
  ///
  /// In zh, this message translates to:
  /// **'删除「{name}」后，其认证头也会一并从本机移除。'**
  String mcpDeleteBody(String name);

  /// No description provided for @mcpTitle.
  ///
  /// In zh, this message translates to:
  /// **'MCP 工具服务'**
  String get mcpTitle;

  /// No description provided for @mcpAdd.
  ///
  /// In zh, this message translates to:
  /// **'新增服务'**
  String get mcpAdd;

  /// No description provided for @mcpAllTools.
  ///
  /// In zh, this message translates to:
  /// **'全部工具可用'**
  String get mcpAllTools;

  /// No description provided for @mcpWhitelist.
  ///
  /// In zh, this message translates to:
  /// **'白名单：{tools}'**
  String mcpWhitelist(String tools);

  /// No description provided for @mcpListSeparator.
  ///
  /// In zh, this message translates to:
  /// **'、'**
  String get mcpListSeparator;

  /// No description provided for @mcpEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有 MCP 服务'**
  String get mcpEmptyTitle;

  /// No description provided for @mcpEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'添加远程 MCP server 后，其工具会在「桥段点子」生成时供 AI 调用'**
  String get mcpEmptyHint;

  /// No description provided for @mcpSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get mcpSaved;

  /// No description provided for @mcpEndpointMissing.
  ///
  /// In zh, this message translates to:
  /// **'请先填写 MCP 端点地址'**
  String get mcpEndpointMissing;

  /// No description provided for @mcpTestOkNoTools.
  ///
  /// In zh, this message translates to:
  /// **'连接成功，但该服务未暴露工具'**
  String get mcpTestOkNoTools;

  /// No description provided for @mcpTestOkTools.
  ///
  /// In zh, this message translates to:
  /// **'连接成功，{count} 个工具：{names}'**
  String mcpTestOkTools(int count, String names);

  /// No description provided for @mcpTestFailed.
  ///
  /// In zh, this message translates to:
  /// **'连接失败：{detail}'**
  String mcpTestFailed(String detail);

  /// No description provided for @mcpNewTitle.
  ///
  /// In zh, this message translates to:
  /// **'新增 MCP 服务'**
  String get mcpNewTitle;

  /// No description provided for @mcpEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑 MCP 服务'**
  String get mcpEditTitle;

  /// No description provided for @mcpNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get mcpNameLabel;

  /// No description provided for @mcpNameHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：我的本地 MCP 服务'**
  String get mcpNameHint;

  /// No description provided for @mcpNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请填写名称'**
  String get mcpNameRequired;

  /// No description provided for @mcpEndpointLabel.
  ///
  /// In zh, this message translates to:
  /// **'MCP 端点地址'**
  String get mcpEndpointLabel;

  /// No description provided for @mcpEndpointHelper.
  ///
  /// In zh, this message translates to:
  /// **'Streamable HTTP 完整地址，例如 https://example.com/mcp'**
  String get mcpEndpointHelper;

  /// No description provided for @mcpEndpointRequired.
  ///
  /// In zh, this message translates to:
  /// **'请填写端点地址'**
  String get mcpEndpointRequired;

  /// No description provided for @mcpEndpointInvalid.
  ///
  /// In zh, this message translates to:
  /// **'请填写带 http(s):// 的完整地址'**
  String get mcpEndpointInvalid;

  /// No description provided for @mcpAuthLabel.
  ///
  /// In zh, this message translates to:
  /// **'认证请求头'**
  String get mcpAuthLabel;

  /// No description provided for @mcpAuthHintSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存，留空则不修改'**
  String get mcpAuthHintSaved;

  /// No description provided for @mcpAuthHint.
  ///
  /// In zh, this message translates to:
  /// **'每行一条，例如 Authorization: Bearer xxx'**
  String get mcpAuthHint;

  /// No description provided for @mcpAuthHelper.
  ///
  /// In zh, this message translates to:
  /// **'仅保存在本机安全存储，不会随备份导出'**
  String get mcpAuthHelper;

  /// No description provided for @mcpToolsLabel.
  ///
  /// In zh, this message translates to:
  /// **'工具白名单'**
  String get mcpToolsLabel;

  /// No description provided for @mcpToolsHelper.
  ///
  /// In zh, this message translates to:
  /// **'每行一个远程工具名；留空表示全部允许'**
  String get mcpToolsHelper;

  /// No description provided for @mcpEnable.
  ///
  /// In zh, this message translates to:
  /// **'启用'**
  String get mcpEnable;

  /// No description provided for @mcpEnableSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'停用后其工具不会暴露给 AI'**
  String get mcpEnableSubtitle;

  /// No description provided for @mcpTestConnection.
  ///
  /// In zh, this message translates to:
  /// **'测试连接'**
  String get mcpTestConnection;

  /// No description provided for @mcpEnableSwitch.
  ///
  /// In zh, this message translates to:
  /// **'启用「{name}」'**
  String mcpEnableSwitch(String name);

  /// No description provided for @mcpAuthModeLabel.
  ///
  /// In zh, this message translates to:
  /// **'认证方式'**
  String get mcpAuthModeLabel;

  /// No description provided for @mcpAuthModeHeaders.
  ///
  /// In zh, this message translates to:
  /// **'自定义请求头'**
  String get mcpAuthModeHeaders;

  /// No description provided for @mcpAuthModeOAuth.
  ///
  /// In zh, this message translates to:
  /// **'OAuth 2.1（PKCE）'**
  String get mcpAuthModeOAuth;

  /// No description provided for @mcpOAuthClientIdLabel.
  ///
  /// In zh, this message translates to:
  /// **'OAuth Client ID（选填）'**
  String get mcpOAuthClientIdLabel;

  /// No description provided for @mcpOAuthClientIdHint.
  ///
  /// In zh, this message translates to:
  /// **'留空则自动动态注册'**
  String get mcpOAuthClientIdHint;

  /// No description provided for @mcpOAuthClientIdHelper.
  ///
  /// In zh, this message translates to:
  /// **'预注册的客户端 ID；动态注册成功后会自动回填并保存'**
  String get mcpOAuthClientIdHelper;

  /// No description provided for @mcpOAuthScopesLabel.
  ///
  /// In zh, this message translates to:
  /// **'授权范围（选填）'**
  String get mcpOAuthScopesLabel;

  /// No description provided for @mcpOAuthScopesHelper.
  ///
  /// In zh, this message translates to:
  /// **'空格或逗号分隔；留空则由服务器决定'**
  String get mcpOAuthScopesHelper;

  /// No description provided for @mcpOAuthStatusAuthorized.
  ///
  /// In zh, this message translates to:
  /// **'已授权：访问令牌已保存在本机'**
  String get mcpOAuthStatusAuthorized;

  /// No description provided for @mcpOAuthStatusNotAuthorized.
  ///
  /// In zh, this message translates to:
  /// **'未授权：请先完成授权，OAuth 服务器才能使用'**
  String get mcpOAuthStatusNotAuthorized;

  /// No description provided for @mcpOAuthAuthorize.
  ///
  /// In zh, this message translates to:
  /// **'开始授权'**
  String get mcpOAuthAuthorize;

  /// No description provided for @mcpOAuthReauthorize.
  ///
  /// In zh, this message translates to:
  /// **'重新授权'**
  String get mcpOAuthReauthorize;

  /// No description provided for @mcpOAuthClear.
  ///
  /// In zh, this message translates to:
  /// **'清除授权'**
  String get mcpOAuthClear;

  /// No description provided for @mcpOAuthClearTitle.
  ///
  /// In zh, this message translates to:
  /// **'清除 OAuth 授权'**
  String get mcpOAuthClearTitle;

  /// No description provided for @mcpOAuthClearBody.
  ///
  /// In zh, this message translates to:
  /// **'将删除本服务器已保存的访问令牌；之后使用该服务器的功能会提示重新授权。'**
  String get mcpOAuthClearBody;

  /// No description provided for @mcpOAuthCleared.
  ///
  /// In zh, this message translates to:
  /// **'已清除授权令牌'**
  String get mcpOAuthCleared;

  /// No description provided for @mcpOAuthSuccess.
  ///
  /// In zh, this message translates to:
  /// **'授权成功，令牌已保存'**
  String get mcpOAuthSuccess;

  /// No description provided for @mcpOAuthFailed.
  ///
  /// In zh, this message translates to:
  /// **'授权失败：{detail}'**
  String mcpOAuthFailed(String detail);

  /// No description provided for @mcpOAuthSaveFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先保存该服务，再测试连接或授权'**
  String get mcpOAuthSaveFirst;

  /// No description provided for @mcpOAuthSecureHint.
  ///
  /// In zh, this message translates to:
  /// **'令牌只保存在本机安全存储，不会随备份导出；授权在系统浏览器中完成（PKCE，无客户端密钥落地）。'**
  String get mcpOAuthSecureHint;

  /// No description provided for @skillImport.
  ///
  /// In zh, this message translates to:
  /// **'导入技能'**
  String get skillImport;

  /// No description provided for @skillExport.
  ///
  /// In zh, this message translates to:
  /// **'导出 / 分享'**
  String get skillExport;

  /// No description provided for @skillExportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导出失败：{detail}'**
  String skillExportFailed(String detail);

  /// No description provided for @skillImportFromFile.
  ///
  /// In zh, this message translates to:
  /// **'从文件导入'**
  String get skillImportFromFile;

  /// No description provided for @skillImportFromPaste.
  ///
  /// In zh, this message translates to:
  /// **'粘贴导入'**
  String get skillImportFromPaste;

  /// No description provided for @skillImportPasteTitle.
  ///
  /// In zh, this message translates to:
  /// **'粘贴技能 Markdown'**
  String get skillImportPasteTitle;

  /// No description provided for @skillImportPasteHint.
  ///
  /// In zh, this message translates to:
  /// **'粘贴以 front matter（---）开头的技能文本'**
  String get skillImportPasteHint;

  /// No description provided for @skillImportPreviewTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认导入技能'**
  String get skillImportPreviewTitle;

  /// No description provided for @skillImportOk.
  ///
  /// In zh, this message translates to:
  /// **'已导入「{name}」'**
  String skillImportOk(String name);

  /// No description provided for @skillImportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导入失败：{detail}'**
  String skillImportFailed(String detail);

  /// No description provided for @skillDescriptionLabel.
  ///
  /// In zh, this message translates to:
  /// **'技能简介（选填）'**
  String get skillDescriptionLabel;

  /// No description provided for @skillDescriptionHint.
  ///
  /// In zh, this message translates to:
  /// **'一句话说明这个技能的用途'**
  String get skillDescriptionHint;

  /// No description provided for @commonToggleSwitch.
  ///
  /// In zh, this message translates to:
  /// **'启用「{name}」'**
  String commonToggleSwitch(String name);

  /// No description provided for @newWorkCoverOptionLabel.
  ///
  /// In zh, this message translates to:
  /// **'封面色块 {index}'**
  String newWorkCoverOptionLabel(int index);

  /// No description provided for @a11yHeatmapLabel.
  ///
  /// In zh, this message translates to:
  /// **'写作热力图：色块越深，表示当天写下的字数越多'**
  String get a11yHeatmapLabel;

  /// No description provided for @a11yTrendChartLabel.
  ///
  /// In zh, this message translates to:
  /// **'字数趋势图：按天统计的写作字数'**
  String get a11yTrendChartLabel;

  /// No description provided for @a11yRelationGraphLabel.
  ///
  /// In zh, this message translates to:
  /// **'人物关系图，节点可拖动调整位置'**
  String get a11yRelationGraphLabel;

  /// No description provided for @skillDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除技能'**
  String get skillDeleteTitle;

  /// No description provided for @skillDeleteBody.
  ///
  /// In zh, this message translates to:
  /// **'删除「{name}」后，其指令不再注入 AI 生成。'**
  String skillDeleteBody(String name);

  /// No description provided for @skillTitle.
  ///
  /// In zh, this message translates to:
  /// **'自定义技能'**
  String get skillTitle;

  /// No description provided for @skillAdd.
  ///
  /// In zh, this message translates to:
  /// **'新增技能'**
  String get skillAdd;

  /// No description provided for @skillToolsUnlimited.
  ///
  /// In zh, this message translates to:
  /// **'工具：不限制'**
  String get skillToolsUnlimited;

  /// No description provided for @skillToolsWhitelist.
  ///
  /// In zh, this message translates to:
  /// **'工具白名单：{tools}'**
  String skillToolsWhitelist(String tools);

  /// No description provided for @skillListSeparator.
  ///
  /// In zh, this message translates to:
  /// **'、'**
  String get skillListSeparator;

  /// No description provided for @skillEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有自定义技能'**
  String get skillEmptyTitle;

  /// No description provided for @skillEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'写一段附加指令（如「只用短句」「避免旁白解释」），启用后会注入续写与灵感生成的 system 提示'**
  String get skillEmptyHint;

  /// No description provided for @skillSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get skillSaved;

  /// No description provided for @skillNewTitle.
  ///
  /// In zh, this message translates to:
  /// **'新增技能'**
  String get skillNewTitle;

  /// No description provided for @skillEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑技能'**
  String get skillEditTitle;

  /// No description provided for @skillNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'技能名称'**
  String get skillNameLabel;

  /// No description provided for @skillNameHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：冷硬短句'**
  String get skillNameHint;

  /// No description provided for @skillNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请填写技能名称'**
  String get skillNameRequired;

  /// No description provided for @skillInstructionLabel.
  ///
  /// In zh, this message translates to:
  /// **'指令文本'**
  String get skillInstructionLabel;

  /// No description provided for @skillInstructionHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：只用短句，避免解释性旁白，对话不写语气副词。'**
  String get skillInstructionHint;

  /// No description provided for @skillInstructionHelper.
  ///
  /// In zh, this message translates to:
  /// **'会作为附加 system 指令注入续写与灵感生成'**
  String get skillInstructionHelper;

  /// No description provided for @skillInstructionRequired.
  ///
  /// In zh, this message translates to:
  /// **'请填写指令文本'**
  String get skillInstructionRequired;

  /// No description provided for @skillParamsLabel.
  ///
  /// In zh, this message translates to:
  /// **'参数模板（可选）'**
  String get skillParamsLabel;

  /// No description provided for @skillParamsHint.
  ///
  /// In zh, this message translates to:
  /// **'每行一条 键=值，例如 字数=800'**
  String get skillParamsHint;

  /// No description provided for @skillParamsHelper.
  ///
  /// In zh, this message translates to:
  /// **'在指令中用 {open}参数名{close} 引用，注入时替换为对应值'**
  String skillParamsHelper(String open, String close);

  /// No description provided for @skillToolsLabel.
  ///
  /// In zh, this message translates to:
  /// **'工具白名单（可选）'**
  String get skillToolsLabel;

  /// No description provided for @skillToolsHint.
  ///
  /// In zh, this message translates to:
  /// **'每行一个工具名，例如 get_chapter'**
  String get skillToolsHint;

  /// No description provided for @skillToolsHelper.
  ///
  /// In zh, this message translates to:
  /// **'留空表示不限制；内置工具 get_chapter / get_characters / get_outline，MCP 工具以 mcp_ 开头'**
  String get skillToolsHelper;

  /// No description provided for @skillEnable.
  ///
  /// In zh, this message translates to:
  /// **'启用'**
  String get skillEnable;

  /// No description provided for @skillEnableSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'停用后不注入，也不参与工具白名单'**
  String get skillEnableSubtitle;

  /// No description provided for @workDetailTitleFallback.
  ///
  /// In zh, this message translates to:
  /// **'作品'**
  String get workDetailTitleFallback;

  /// No description provided for @workDetailTabChapters.
  ///
  /// In zh, this message translates to:
  /// **'章节'**
  String get workDetailTabChapters;

  /// No description provided for @workDetailTabCharacters.
  ///
  /// In zh, this message translates to:
  /// **'角色卡'**
  String get workDetailTabCharacters;

  /// No description provided for @workDetailTabWorldbuilding.
  ///
  /// In zh, this message translates to:
  /// **'设定集'**
  String get workDetailTabWorldbuilding;

  /// No description provided for @workDetailTabOutline.
  ///
  /// In zh, this message translates to:
  /// **'章纲'**
  String get workDetailTabOutline;

  /// No description provided for @workDetailRunFlavorCheck.
  ///
  /// In zh, this message translates to:
  /// **'运行 AI 感检查'**
  String get workDetailRunFlavorCheck;

  /// No description provided for @workDetailImportTxtDocx.
  ///
  /// In zh, this message translates to:
  /// **'导入 txt / docx / Markdown / EPUB'**
  String get workDetailImportTxtDocx;

  /// No description provided for @workDetailInspirationsTitle.
  ///
  /// In zh, this message translates to:
  /// **'灵感箱'**
  String get workDetailInspirationsTitle;

  /// No description provided for @storyStateTitle.
  ///
  /// In zh, this message translates to:
  /// **'故事状态卡'**
  String get storyStateTitle;

  /// No description provided for @storyStateTabCharacter.
  ///
  /// In zh, this message translates to:
  /// **'角色状态'**
  String get storyStateTabCharacter;

  /// No description provided for @storyStateTabForeshadow.
  ///
  /// In zh, this message translates to:
  /// **'伏笔'**
  String get storyStateTabForeshadow;

  /// No description provided for @storyStateTabTimeline.
  ///
  /// In zh, this message translates to:
  /// **'时间线'**
  String get storyStateTabTimeline;

  /// No description provided for @storyStateEmptyCharacter.
  ///
  /// In zh, this message translates to:
  /// **'暂无角色状态'**
  String get storyStateEmptyCharacter;

  /// No description provided for @storyStateEmptyForeshadow.
  ///
  /// In zh, this message translates to:
  /// **'暂未记录伏笔'**
  String get storyStateEmptyForeshadow;

  /// No description provided for @storyStateEmptyTimeline.
  ///
  /// In zh, this message translates to:
  /// **'暂无时间线事件'**
  String get storyStateEmptyTimeline;

  /// No description provided for @storyStateEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'记录当下状态与未回收伏笔，AI 续写会自动参考。'**
  String get storyStateEmptyHint;

  /// No description provided for @storyStateAdd.
  ///
  /// In zh, this message translates to:
  /// **'新增'**
  String get storyStateAdd;

  /// No description provided for @storyStateEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get storyStateEdit;

  /// No description provided for @storyStateDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get storyStateDelete;

  /// No description provided for @storyStateDeleted.
  ///
  /// In zh, this message translates to:
  /// **'状态卡已删除'**
  String get storyStateDeleted;

  /// No description provided for @storyStateSaved.
  ///
  /// In zh, this message translates to:
  /// **'状态卡已保存'**
  String get storyStateSaved;

  /// No description provided for @storyStateTitleRequired.
  ///
  /// In zh, this message translates to:
  /// **'请填写标题'**
  String get storyStateTitleRequired;

  /// No description provided for @storyStateFieldTitle.
  ///
  /// In zh, this message translates to:
  /// **'标题'**
  String get storyStateFieldTitle;

  /// No description provided for @storyStateFieldDetail.
  ///
  /// In zh, this message translates to:
  /// **'详情'**
  String get storyStateFieldDetail;

  /// No description provided for @storyStateFieldChapter.
  ///
  /// In zh, this message translates to:
  /// **'关联章节'**
  String get storyStateFieldChapter;

  /// No description provided for @storyStateNoChapter.
  ///
  /// In zh, this message translates to:
  /// **'不关联'**
  String get storyStateNoChapter;

  /// No description provided for @storyStateOpen.
  ///
  /// In zh, this message translates to:
  /// **'未回收'**
  String get storyStateOpen;

  /// No description provided for @storyStateClosed.
  ///
  /// In zh, this message translates to:
  /// **'已回收'**
  String get storyStateClosed;

  /// No description provided for @storyStateTitleHintCharacter.
  ///
  /// In zh, this message translates to:
  /// **'角色名'**
  String get storyStateTitleHintCharacter;

  /// No description provided for @storyStateTitleHintForeshadow.
  ///
  /// In zh, this message translates to:
  /// **'伏笔名称'**
  String get storyStateTitleHintForeshadow;

  /// No description provided for @storyStateTitleHintTimeline.
  ///
  /// In zh, this message translates to:
  /// **'事件'**
  String get storyStateTitleHintTimeline;

  /// No description provided for @storyStateDetailHint.
  ///
  /// In zh, this message translates to:
  /// **'角色当下状态 / 伏笔线索 / 事件经过'**
  String get storyStateDetailHint;

  /// No description provided for @storyStateMoreActions.
  ///
  /// In zh, this message translates to:
  /// **'更多操作'**
  String get storyStateMoreActions;

  /// No description provided for @storyStateDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除这条状态卡？'**
  String get storyStateDeleteTitle;

  /// No description provided for @storyStateDeleteBody.
  ///
  /// In zh, this message translates to:
  /// **'删除后不可恢复。'**
  String get storyStateDeleteBody;

  /// No description provided for @storyStateExtractTitle.
  ///
  /// In zh, this message translates to:
  /// **'AI 提取状态变化'**
  String get storyStateExtractTitle;

  /// No description provided for @storyStateExtractIntro.
  ///
  /// In zh, this message translates to:
  /// **'AI 会从本章正文提取角色当下状态、伏笔进展与时间线事件，并与现有卡片对照；勾选后才会写入。'**
  String get storyStateExtractIntro;

  /// No description provided for @storyStateExtractRunning.
  ///
  /// In zh, this message translates to:
  /// **'正在提取本章状态变化…'**
  String get storyStateExtractRunning;

  /// No description provided for @storyStateExtractFailed.
  ///
  /// In zh, this message translates to:
  /// **'提取失败：{message}'**
  String storyStateExtractFailed(String message);

  /// No description provided for @storyStateExtractParseFailed.
  ///
  /// In zh, this message translates to:
  /// **'AI 返回的状态变化无法解析，请重试'**
  String get storyStateExtractParseFailed;

  /// No description provided for @storyStateExtractEmpty.
  ///
  /// In zh, this message translates to:
  /// **'本章没有可提取的状态变化'**
  String get storyStateExtractEmpty;

  /// No description provided for @storyStateExtractNew.
  ///
  /// In zh, this message translates to:
  /// **'新增'**
  String get storyStateExtractNew;

  /// No description provided for @storyStateExtractUpdate.
  ///
  /// In zh, this message translates to:
  /// **'更新'**
  String get storyStateExtractUpdate;

  /// No description provided for @storyStateExtractUnchanged.
  ///
  /// In zh, this message translates to:
  /// **'与现有卡片一致'**
  String get storyStateExtractUnchanged;

  /// No description provided for @storyStateExtractApply.
  ///
  /// In zh, this message translates to:
  /// **'应用选中项（{count}）'**
  String storyStateExtractApply(int count);

  /// No description provided for @storyStateExtractApplied.
  ///
  /// In zh, this message translates to:
  /// **'已新增 {created} 张、更新 {updated} 张状态卡'**
  String storyStateExtractApplied(int created, int updated);

  /// No description provided for @workDetailAiSettings.
  ///
  /// In zh, this message translates to:
  /// **'AI 设置'**
  String get workDetailAiSettings;

  /// No description provided for @workDetailAiPreferences.
  ///
  /// In zh, this message translates to:
  /// **'作者协作偏好'**
  String get workDetailAiPreferences;

  /// No description provided for @workDetailStyleGuide.
  ///
  /// In zh, this message translates to:
  /// **'文风档案'**
  String get workDetailStyleGuide;

  /// No description provided for @styleGuideTitle.
  ///
  /// In zh, this message translates to:
  /// **'文风档案'**
  String get styleGuideTitle;

  /// No description provided for @styleGuideIntro.
  ///
  /// In zh, this message translates to:
  /// **'文风档案会注入续写、改写、开篇与剧情推演，让 AI 更贴近你的写法。'**
  String get styleGuideIntro;

  /// No description provided for @styleGuidePerspective.
  ///
  /// In zh, this message translates to:
  /// **'叙事人称与视角'**
  String get styleGuidePerspective;

  /// No description provided for @styleGuidePerspectiveHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：第三人称限知，跟随女主'**
  String get styleGuidePerspectiveHint;

  /// No description provided for @styleGuideTone.
  ///
  /// In zh, this message translates to:
  /// **'语言风格与基调'**
  String get styleGuideTone;

  /// No description provided for @styleGuideToneHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：冷峻克制，短句为主，少用形容词'**
  String get styleGuideToneHint;

  /// No description provided for @styleGuideTaboos.
  ///
  /// In zh, this message translates to:
  /// **'禁忌与偏好'**
  String get styleGuideTaboos;

  /// No description provided for @styleGuideTaboosHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：不用网络流行语，少用感叹号'**
  String get styleGuideTaboosHint;

  /// No description provided for @styleGuideSample.
  ///
  /// In zh, this message translates to:
  /// **'示例段落'**
  String get styleGuideSample;

  /// No description provided for @styleGuideSampleHint.
  ///
  /// In zh, this message translates to:
  /// **'粘贴一段你的正文，AI 会模仿语感与节奏'**
  String get styleGuideSampleHint;

  /// No description provided for @styleGuideExtract.
  ///
  /// In zh, this message translates to:
  /// **'AI 从最近章节提取'**
  String get styleGuideExtract;

  /// No description provided for @styleGuideExtracting.
  ///
  /// In zh, this message translates to:
  /// **'正在分析最近章节…'**
  String get styleGuideExtracting;

  /// No description provided for @styleGuideExtractTitle.
  ///
  /// In zh, this message translates to:
  /// **'AI 提取结果'**
  String get styleGuideExtractTitle;

  /// No description provided for @styleGuideExtractConfirm.
  ///
  /// In zh, this message translates to:
  /// **'将用 AI 结果覆盖对应字段，是否继续？'**
  String get styleGuideExtractConfirm;

  /// No description provided for @styleGuideApply.
  ///
  /// In zh, this message translates to:
  /// **'填入表单'**
  String get styleGuideApply;

  /// No description provided for @styleGuideApplied.
  ///
  /// In zh, this message translates to:
  /// **'已填入表单，确认后请保存'**
  String get styleGuideApplied;

  /// No description provided for @styleGuideSaved.
  ///
  /// In zh, this message translates to:
  /// **'文风档案已保存'**
  String get styleGuideSaved;

  /// No description provided for @styleGuideExtractFailed.
  ///
  /// In zh, this message translates to:
  /// **'提取失败：{message}'**
  String styleGuideExtractFailed(String message);

  /// No description provided for @modelEditInputPrice.
  ///
  /// In zh, this message translates to:
  /// **'输入单价（元/百万 token）'**
  String get modelEditInputPrice;

  /// No description provided for @modelEditOutputPrice.
  ///
  /// In zh, this message translates to:
  /// **'输出单价（元/百万 token）'**
  String get modelEditOutputPrice;

  /// No description provided for @modelEditPriceHelper.
  ///
  /// In zh, this message translates to:
  /// **'选填，用于 token 统计页估算费用'**
  String get modelEditPriceHelper;

  /// No description provided for @entityExtractTitle.
  ///
  /// In zh, this message translates to:
  /// **'AI 设定补全'**
  String get entityExtractTitle;

  /// No description provided for @entityExtractIntro.
  ///
  /// In zh, this message translates to:
  /// **'从最近章节抽取角色与世界观 / 地点 / 道具，预览去重后可一键建档。'**
  String get entityExtractIntro;

  /// No description provided for @entityExtractStart.
  ///
  /// In zh, this message translates to:
  /// **'AI 抽取设定'**
  String get entityExtractStart;

  /// No description provided for @entityExtractRunning.
  ///
  /// In zh, this message translates to:
  /// **'正在阅读最近章节…'**
  String get entityExtractRunning;

  /// No description provided for @entityExtractEmpty.
  ///
  /// In zh, this message translates to:
  /// **'没有发现可补充的新条目。'**
  String get entityExtractEmpty;

  /// No description provided for @entityExtractParseFailed.
  ///
  /// In zh, this message translates to:
  /// **'AI 返回内容无法解析，请重试。'**
  String get entityExtractParseFailed;

  /// No description provided for @entityExtractCharacters.
  ///
  /// In zh, this message translates to:
  /// **'角色卡'**
  String get entityExtractCharacters;

  /// No description provided for @entityExtractSettings.
  ///
  /// In zh, this message translates to:
  /// **'设定条目'**
  String get entityExtractSettings;

  /// No description provided for @entityExtractRelations.
  ///
  /// In zh, this message translates to:
  /// **'角色关系'**
  String get entityExtractRelations;

  /// No description provided for @entityExtractRelationMissing.
  ///
  /// In zh, this message translates to:
  /// **'关系两端的角色不在本轮抽取中'**
  String get entityExtractRelationMissing;

  /// No description provided for @entityExtractExisting.
  ///
  /// In zh, this message translates to:
  /// **'已存在'**
  String get entityExtractExisting;

  /// No description provided for @entityExtractApply.
  ///
  /// In zh, this message translates to:
  /// **'应用所选（{count}）'**
  String entityExtractApply(int count);

  /// No description provided for @entityExtractApplied.
  ///
  /// In zh, this message translates to:
  /// **'已添加 {characters} 个角色、{settings} 条设定、{relations} 条关系'**
  String entityExtractApplied(int characters, int settings, int relations);

  /// No description provided for @entityExtractFailed.
  ///
  /// In zh, this message translates to:
  /// **'抽取失败：{message}'**
  String entityExtractFailed(String message);

  /// No description provided for @workDetailRenameWork.
  ///
  /// In zh, this message translates to:
  /// **'重命名作品'**
  String get workDetailRenameWork;

  /// No description provided for @workDetailImportedCount.
  ///
  /// In zh, this message translates to:
  /// **'已导入 {count} 章'**
  String workDetailImportedCount(int count);

  /// No description provided for @workDetailRecordInspiration.
  ///
  /// In zh, this message translates to:
  /// **'记录灵感'**
  String get workDetailRecordInspiration;

  /// No description provided for @workDetailEditInspiration.
  ///
  /// In zh, this message translates to:
  /// **'编辑灵感'**
  String get workDetailEditInspiration;

  /// No description provided for @workDetailInspirationHint.
  ///
  /// In zh, this message translates to:
  /// **'写点什么…'**
  String get workDetailInspirationHint;

  /// No description provided for @workDetailInspirationsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'灵感箱是空的'**
  String get workDetailInspirationsEmpty;

  /// No description provided for @workDetailInspirationsEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'随手记下桥段、设定或一句对白，AI 灵感产出的点子也会存到这里。'**
  String get workDetailInspirationsEmptyHint;

  /// No description provided for @workDetailDeleteInspirationConfirm.
  ///
  /// In zh, this message translates to:
  /// **'删除这条灵感？'**
  String get workDetailDeleteInspirationConfirm;

  /// No description provided for @chaptersNewVolume.
  ///
  /// In zh, this message translates to:
  /// **'新建卷'**
  String get chaptersNewVolume;

  /// No description provided for @chaptersNewVolumeHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：第二卷 风起'**
  String get chaptersNewVolumeHint;

  /// No description provided for @chaptersCreate.
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get chaptersCreate;

  /// No description provided for @chaptersEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有章节'**
  String get chaptersEmptyTitle;

  /// No description provided for @chaptersEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'在下方「新建卷」后即可开始写第一章。'**
  String get chaptersEmptyHint;

  /// No description provided for @chaptersVolumeHeader.
  ///
  /// In zh, this message translates to:
  /// **'{volume}（{count} 章）'**
  String chaptersVolumeHeader(String volume, int count);

  /// No description provided for @chaptersVolumeActions.
  ///
  /// In zh, this message translates to:
  /// **'卷操作'**
  String get chaptersVolumeActions;

  /// No description provided for @chaptersRenameVolume.
  ///
  /// In zh, this message translates to:
  /// **'重命名卷'**
  String get chaptersRenameVolume;

  /// No description provided for @chaptersVolumeSummaryAction.
  ///
  /// In zh, this message translates to:
  /// **'查看/编辑本卷前情回顾'**
  String get chaptersVolumeSummaryAction;

  /// No description provided for @chaptersMoveUp.
  ///
  /// In zh, this message translates to:
  /// **'上移'**
  String get chaptersMoveUp;

  /// No description provided for @chaptersMoveDown.
  ///
  /// In zh, this message translates to:
  /// **'下移'**
  String get chaptersMoveDown;

  /// No description provided for @chaptersDeleteVolume.
  ///
  /// In zh, this message translates to:
  /// **'删除卷'**
  String get chaptersDeleteVolume;

  /// No description provided for @chaptersVolumeSummaryTitle.
  ///
  /// In zh, this message translates to:
  /// **'本卷前情回顾'**
  String get chaptersVolumeSummaryTitle;

  /// No description provided for @chaptersVolumeSummaryHint.
  ///
  /// In zh, this message translates to:
  /// **'AI 生成或手写的本卷前情回顾，用于后续章节的剧情衔接'**
  String get chaptersVolumeSummaryHint;

  /// No description provided for @chaptersDeleteVolumeConfirm.
  ///
  /// In zh, this message translates to:
  /// **'删除「{volume}」？'**
  String chaptersDeleteVolumeConfirm(String volume);

  /// No description provided for @chaptersDeleteVolumeEmptyBody.
  ///
  /// In zh, this message translates to:
  /// **'该卷下没有章节。'**
  String get chaptersDeleteVolumeEmptyBody;

  /// No description provided for @chaptersDeleteVolumeBody.
  ///
  /// In zh, this message translates to:
  /// **'该卷下的 {count} 个章节会一并删除，此操作不可恢复。'**
  String chaptersDeleteVolumeBody(int count);

  /// No description provided for @chaptersAddChapterInVolume.
  ///
  /// In zh, this message translates to:
  /// **'在本卷新建章节'**
  String get chaptersAddChapterInVolume;

  /// No description provided for @chaptersRenameChapter.
  ///
  /// In zh, this message translates to:
  /// **'重命名章节'**
  String get chaptersRenameChapter;

  /// No description provided for @chaptersMoveToVolume.
  ///
  /// In zh, this message translates to:
  /// **'移动到其他卷'**
  String get chaptersMoveToVolume;

  /// No description provided for @chaptersMarkAs.
  ///
  /// In zh, this message translates to:
  /// **'标记为{status}'**
  String chaptersMarkAs(String status);

  /// No description provided for @chaptersDeleteChapter.
  ///
  /// In zh, this message translates to:
  /// **'删除章节'**
  String get chaptersDeleteChapter;

  /// No description provided for @chaptersNoOtherVolume.
  ///
  /// In zh, this message translates to:
  /// **'没有其他卷可移动'**
  String get chaptersNoOtherVolume;

  /// No description provided for @chaptersDeleteChapterConfirm.
  ///
  /// In zh, this message translates to:
  /// **'删除「{title}」？'**
  String chaptersDeleteChapterConfirm(String title);

  /// No description provided for @chaptersDeleteChapterBody.
  ///
  /// In zh, this message translates to:
  /// **'章节将移入回收站，30 天内可在回收站恢复。'**
  String get chaptersDeleteChapterBody;

  /// No description provided for @outlineOrphanSection.
  ///
  /// In zh, this message translates to:
  /// **'未关联章节的梗概'**
  String get outlineOrphanSection;

  /// No description provided for @outlineEmptyEntry.
  ///
  /// In zh, this message translates to:
  /// **'（空梗概）'**
  String get outlineEmptyEntry;

  /// No description provided for @outlineEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有章纲'**
  String get outlineEmptyTitle;

  /// No description provided for @outlineEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'先在「章节」Tab 创建章节，即可为每章写一句话梗概。'**
  String get outlineEmptyHint;

  /// No description provided for @outlineNoSummary.
  ///
  /// In zh, this message translates to:
  /// **'未填写梗概'**
  String get outlineNoSummary;

  /// No description provided for @charactersNewCard.
  ///
  /// In zh, this message translates to:
  /// **'新建角色卡'**
  String get charactersNewCard;

  /// No description provided for @charactersEditCard.
  ///
  /// In zh, this message translates to:
  /// **'编辑角色卡'**
  String get charactersEditCard;

  /// No description provided for @charactersEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有角色卡'**
  String get charactersEmptyTitle;

  /// No description provided for @charactersEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'为角色建立档案后，AI 续写与灵感会自动带上相关角色设定。'**
  String get charactersEmptyHint;

  /// No description provided for @charactersIdentityEmpty.
  ///
  /// In zh, this message translates to:
  /// **'身份未填写'**
  String get charactersIdentityEmpty;

  /// No description provided for @charactersNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'姓名（必填，1-20 字）'**
  String get charactersNameLabel;

  /// No description provided for @charactersIdentityLabel.
  ///
  /// In zh, this message translates to:
  /// **'身份'**
  String get charactersIdentityLabel;

  /// No description provided for @charactersTagsLabel.
  ///
  /// In zh, this message translates to:
  /// **'性格标签（最多 10 个，空格或逗号分隔）'**
  String get charactersTagsLabel;

  /// No description provided for @charactersAppearanceLabel.
  ///
  /// In zh, this message translates to:
  /// **'外貌特征'**
  String get charactersAppearanceLabel;

  /// No description provided for @charactersRelationsLabel.
  ///
  /// In zh, this message translates to:
  /// **'人际关系'**
  String get charactersRelationsLabel;

  /// No description provided for @charactersArcLabel.
  ///
  /// In zh, this message translates to:
  /// **'角色弧光'**
  String get charactersArcLabel;

  /// No description provided for @charactersNameError.
  ///
  /// In zh, this message translates to:
  /// **'姓名需 1-20 字'**
  String get charactersNameError;

  /// No description provided for @charactersTagsError.
  ///
  /// In zh, this message translates to:
  /// **'性格标签最多 10 个'**
  String get charactersTagsError;

  /// No description provided for @charactersDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'删除「{name}」？'**
  String charactersDeleteConfirm(String name);

  /// No description provided for @charactersDeleteBody.
  ///
  /// In zh, this message translates to:
  /// **'删除后角色卡不可恢复。'**
  String get charactersDeleteBody;

  /// No description provided for @worldbuildingNewEntry.
  ///
  /// In zh, this message translates to:
  /// **'新建设定'**
  String get worldbuildingNewEntry;

  /// No description provided for @worldbuildingEditEntry.
  ///
  /// In zh, this message translates to:
  /// **'编辑设定'**
  String get worldbuildingEditEntry;

  /// No description provided for @worldbuildingEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有{type}'**
  String worldbuildingEmptyTitle(String type);

  /// No description provided for @worldbuildingEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'记录作品的{type}设定，方便写作时随时查阅。'**
  String worldbuildingEmptyHint(String type);

  /// No description provided for @worldbuildingNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'名称（必填，1-50 字）'**
  String get worldbuildingNameLabel;

  /// No description provided for @worldbuildingContentLabel.
  ///
  /// In zh, this message translates to:
  /// **'设定内容'**
  String get worldbuildingContentLabel;

  /// No description provided for @worldbuildingNameError.
  ///
  /// In zh, this message translates to:
  /// **'名称需 1-50 字'**
  String get worldbuildingNameError;

  /// No description provided for @worldbuildingDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'删除「{name}」？'**
  String worldbuildingDeleteConfirm(String name);

  /// No description provided for @worldbuildingDeleteBody.
  ///
  /// In zh, this message translates to:
  /// **'删除后设定条目不可恢复。'**
  String get worldbuildingDeleteBody;

  /// No description provided for @relationGraphTitle.
  ///
  /// In zh, this message translates to:
  /// **'人物关系图'**
  String get relationGraphTitle;

  /// No description provided for @relationGraphEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有关系，点击右下角添加'**
  String get relationGraphEmpty;

  /// No description provided for @relationGraphDeletedCharacter.
  ///
  /// In zh, this message translates to:
  /// **'已删除角色'**
  String get relationGraphDeletedCharacter;

  /// No description provided for @relationGraphAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加关系'**
  String get relationGraphAdd;

  /// No description provided for @relationGraphEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑关系'**
  String get relationGraphEdit;

  /// No description provided for @relationGraphMinCharacters.
  ///
  /// In zh, this message translates to:
  /// **'至少需要两个角色卡才能绘制关系图'**
  String get relationGraphMinCharacters;

  /// No description provided for @relationGraphCharacterA.
  ///
  /// In zh, this message translates to:
  /// **'角色 A'**
  String get relationGraphCharacterA;

  /// No description provided for @relationGraphCharacterB.
  ///
  /// In zh, this message translates to:
  /// **'角色 B'**
  String get relationGraphCharacterB;

  /// No description provided for @relationGraphLabelField.
  ///
  /// In zh, this message translates to:
  /// **'关系（如：师徒、宿敌）'**
  String get relationGraphLabelField;

  /// No description provided for @relationGraphSelectTwo.
  ///
  /// In zh, this message translates to:
  /// **'请选择两个不同的角色'**
  String get relationGraphSelectTwo;

  /// No description provided for @importPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入文稿'**
  String get importPageTitle;

  /// No description provided for @importPagePickFile.
  ///
  /// In zh, this message translates to:
  /// **'选择文稿文件（txt / docx / md / epub）'**
  String get importPagePickFile;

  /// No description provided for @importPageRepickFile.
  ///
  /// In zh, this message translates to:
  /// **'重新选择文件'**
  String get importPageRepickFile;

  /// No description provided for @importPageConfirmButton.
  ///
  /// In zh, this message translates to:
  /// **'确认导入 {count} 章'**
  String importPageConfirmButton(int count);

  /// No description provided for @importPageFileTooLarge.
  ///
  /// In zh, this message translates to:
  /// **'文件超过 10MB 上限，请先在电脑上拆分后再导入'**
  String get importPageFileTooLarge;

  /// No description provided for @importPageNoContent.
  ///
  /// In zh, this message translates to:
  /// **'没有解析到正文内容，请确认文件格式'**
  String get importPageNoContent;

  /// No description provided for @importPageParseFailed.
  ///
  /// In zh, this message translates to:
  /// **'解析失败：{detail}'**
  String importPageParseFailed(String detail);

  /// No description provided for @importPageFailed.
  ///
  /// In zh, this message translates to:
  /// **'导入失败：{detail}'**
  String importPageFailed(String detail);

  /// No description provided for @importPageDialogEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'存在空章节'**
  String get importPageDialogEmptyTitle;

  /// No description provided for @importPageDialogEmptyBody.
  ///
  /// In zh, this message translates to:
  /// **'有 {count} 章没有正文。保留这些空章节吗？'**
  String importPageDialogEmptyBody(int count);

  /// No description provided for @importPageKeepAll.
  ///
  /// In zh, this message translates to:
  /// **'全部保留'**
  String get importPageKeepAll;

  /// No description provided for @importPageDropEmpty.
  ///
  /// In zh, this message translates to:
  /// **'丢弃空章节'**
  String get importPageDropEmpty;

  /// No description provided for @importPageNoImportable.
  ///
  /// In zh, this message translates to:
  /// **'没有可导入的章节'**
  String get importPageNoImportable;

  /// No description provided for @importPagePickHintTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入旧稿'**
  String get importPagePickHintTitle;

  /// No description provided for @importPagePickHintBody.
  ///
  /// In zh, this message translates to:
  /// **'支持 txt（UTF-8 / GBK）、docx、Markdown（.md）与 EPUB。导入后按「第 X 章」等标题自动分章，可在下一步预览并调整。'**
  String get importPagePickHintBody;

  /// No description provided for @importPageFileSummary.
  ///
  /// In zh, this message translates to:
  /// **'编码 {encoding} · {count} 章 · 共 {words} 字'**
  String importPageFileSummary(String encoding, int count, int words);

  /// No description provided for @importPageMergeIntoPrevious.
  ///
  /// In zh, this message translates to:
  /// **'并入上一章'**
  String get importPageMergeIntoPrevious;

  /// No description provided for @exportActionsFormatTxt.
  ///
  /// In zh, this message translates to:
  /// **'纯文本（.txt）'**
  String get exportActionsFormatTxt;

  /// No description provided for @exportActionsFormatMarkdown.
  ///
  /// In zh, this message translates to:
  /// **'Markdown（.md）'**
  String get exportActionsFormatMarkdown;

  /// No description provided for @exportActionsFormatDocx.
  ///
  /// In zh, this message translates to:
  /// **'Word 文档（.docx）'**
  String get exportActionsFormatDocx;

  /// No description provided for @exportActionsFormatEpub.
  ///
  /// In zh, this message translates to:
  /// **'EPUB 电子书（.epub）'**
  String get exportActionsFormatEpub;

  /// No description provided for @exportActionsChapterTitle.
  ///
  /// In zh, this message translates to:
  /// **'导出本章'**
  String get exportActionsChapterTitle;

  /// No description provided for @exportActionsShareChapterTitle.
  ///
  /// In zh, this message translates to:
  /// **'导出章节'**
  String get exportActionsShareChapterTitle;

  /// No description provided for @exportActionsExportWorkTitle.
  ///
  /// In zh, this message translates to:
  /// **'导出作品'**
  String get exportActionsExportWorkTitle;

  /// No description provided for @exportActionsNoChapters.
  ///
  /// In zh, this message translates to:
  /// **'这部作品还没有章节，暂无可导出的内容'**
  String get exportActionsNoChapters;

  /// No description provided for @exportActionsShareFailed.
  ///
  /// In zh, this message translates to:
  /// **'导出失败：{detail}'**
  String exportActionsShareFailed(String detail);

  /// No description provided for @settingsSectionSecurity.
  ///
  /// In zh, this message translates to:
  /// **'安全'**
  String get settingsSectionSecurity;

  /// No description provided for @settingsAppLock.
  ///
  /// In zh, this message translates to:
  /// **'应用锁'**
  String get settingsAppLock;

  /// No description provided for @settingsAppLockSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'启动或回到前台时验证指纹 / 面容 / 锁屏密码'**
  String get settingsAppLockSubtitle;

  /// No description provided for @settingsAppLockUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'设备未设置锁屏或生物识别，无法启用应用锁'**
  String get settingsAppLockUnavailable;

  /// No description provided for @settingsAppLockDenied.
  ///
  /// In zh, this message translates to:
  /// **'验证未通过，应用锁设置未变更'**
  String get settingsAppLockDenied;

  /// No description provided for @settingsAppLockEnabled.
  ///
  /// In zh, this message translates to:
  /// **'应用锁已开启'**
  String get settingsAppLockEnabled;

  /// No description provided for @settingsAppLockDisabled.
  ///
  /// In zh, this message translates to:
  /// **'应用锁已关闭'**
  String get settingsAppLockDisabled;

  /// No description provided for @settingsAppLockAuthReason.
  ///
  /// In zh, this message translates to:
  /// **'验证身份以修改应用锁'**
  String get settingsAppLockAuthReason;

  /// No description provided for @appLockTitle.
  ///
  /// In zh, this message translates to:
  /// **'应用已锁定'**
  String get appLockTitle;

  /// No description provided for @appLockMessage.
  ///
  /// In zh, this message translates to:
  /// **'验证身份后继续写作'**
  String get appLockMessage;

  /// No description provided for @appLockReason.
  ///
  /// In zh, this message translates to:
  /// **'解锁 NovelPhone'**
  String get appLockReason;

  /// No description provided for @appLockUnlock.
  ///
  /// In zh, this message translates to:
  /// **'解锁'**
  String get appLockUnlock;

  /// No description provided for @appLockFailed.
  ///
  /// In zh, this message translates to:
  /// **'验证未通过，请重试'**
  String get appLockFailed;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get settingsSectionAbout;

  /// No description provided for @settingsAbout.
  ///
  /// In zh, this message translates to:
  /// **'关于 NovelPhone'**
  String get settingsAbout;

  /// No description provided for @settingsAboutSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'版本、隐私说明与开源许可'**
  String get settingsAboutSubtitle;

  /// No description provided for @aboutTagline.
  ///
  /// In zh, this message translates to:
  /// **'本地优先的手机端 AI 小说写作工具'**
  String get aboutTagline;

  /// No description provided for @aboutVersion.
  ///
  /// In zh, this message translates to:
  /// **'版本 {version}'**
  String aboutVersion(String version);

  /// No description provided for @aboutPrivacyTitle.
  ///
  /// In zh, this message translates to:
  /// **'隐私说明'**
  String get aboutPrivacyTitle;

  /// No description provided for @aboutPrivacyNoAccount.
  ///
  /// In zh, this message translates to:
  /// **'默认不收集任何数据：无账号、无广告、无遥测。'**
  String get aboutPrivacyNoAccount;

  /// No description provided for @aboutPrivacyLocal.
  ///
  /// In zh, this message translates to:
  /// **'作品正文、设定、角色与写作统计全部保存在设备本地，离线可用。'**
  String get aboutPrivacyLocal;

  /// No description provided for @aboutPrivacyKey.
  ///
  /// In zh, this message translates to:
  /// **'API Key 与云备份凭证存放在系统安全区（keychain / keystore），不入数据库、不随备份导出。'**
  String get aboutPrivacyKey;

  /// No description provided for @aboutPrivacyNetwork.
  ///
  /// In zh, this message translates to:
  /// **'联网仅发生在你主动使用 AI、MCP 工具服务或云备份时，直连你自行配置的服务商，不经过任何中转服务器。'**
  String get aboutPrivacyNetwork;

  /// No description provided for @aboutPrivacyOffline.
  ///
  /// In zh, this message translates to:
  /// **'本地规则引擎的 AI 感检查完全离线，绝不联网扫描你的正文。'**
  String get aboutPrivacyOffline;

  /// No description provided for @aboutPrivacyErase.
  ///
  /// In zh, this message translates to:
  /// **'卸载应用即同时清除本地数据与安全区中的凭证。'**
  String get aboutPrivacyErase;

  /// No description provided for @aboutPrivacyPolicyLink.
  ///
  /// In zh, this message translates to:
  /// **'查看完整隐私政策（浏览器打开）'**
  String get aboutPrivacyPolicyLink;

  /// No description provided for @aboutPrivacyLinkFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法打开浏览器，请稍后重试。'**
  String get aboutPrivacyLinkFailed;

  /// No description provided for @aboutLicenses.
  ///
  /// In zh, this message translates to:
  /// **'开源许可'**
  String get aboutLicenses;

  /// No description provided for @aboutLicensesSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'NovelPhone 使用以下第三方开源组件，保留其原始许可。'**
  String get aboutLicensesSubtitle;

  /// No description provided for @aboutLicensesAction.
  ///
  /// In zh, this message translates to:
  /// **'查看许可清单'**
  String get aboutLicensesAction;

  /// No description provided for @plotPlanTitle.
  ///
  /// In zh, this message translates to:
  /// **'剧情推演'**
  String get plotPlanTitle;

  /// No description provided for @plotPlanIntro.
  ///
  /// In zh, this message translates to:
  /// **'基于已有章纲、角色与最近正文，推演后续走向与分章建议；满意的条目可存入灵感箱或转为章纲。'**
  String get plotPlanIntro;

  /// No description provided for @plotPlanDirection.
  ///
  /// In zh, this message translates to:
  /// **'希望的方向（可选）'**
  String get plotPlanDirection;

  /// No description provided for @plotPlanDirectionHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：让女主主动摊牌，但暂时不要揭露身世'**
  String get plotPlanDirectionHint;

  /// No description provided for @plotPlanStart.
  ///
  /// In zh, this message translates to:
  /// **'开始推演'**
  String get plotPlanStart;

  /// No description provided for @plotPlanRunning.
  ///
  /// In zh, this message translates to:
  /// **'正在推演剧情…'**
  String get plotPlanRunning;

  /// No description provided for @plotPlanRegenerate.
  ///
  /// In zh, this message translates to:
  /// **'重新推演'**
  String get plotPlanRegenerate;

  /// No description provided for @plotPlanDirections.
  ///
  /// In zh, this message translates to:
  /// **'剧情走向'**
  String get plotPlanDirections;

  /// No description provided for @plotPlanChapters.
  ///
  /// In zh, this message translates to:
  /// **'分章建议'**
  String get plotPlanChapters;

  /// No description provided for @plotPlanHook.
  ///
  /// In zh, this message translates to:
  /// **'看点与风险'**
  String get plotPlanHook;

  /// No description provided for @plotPlanSaveInspiration.
  ///
  /// In zh, this message translates to:
  /// **'存入灵感箱'**
  String get plotPlanSaveInspiration;

  /// No description provided for @plotPlanSaved.
  ///
  /// In zh, this message translates to:
  /// **'已存入灵感箱'**
  String get plotPlanSaved;

  /// No description provided for @plotPlanToOutline.
  ///
  /// In zh, this message translates to:
  /// **'转为章纲'**
  String get plotPlanToOutline;

  /// No description provided for @plotPlanOutlineSaved.
  ///
  /// In zh, this message translates to:
  /// **'已写入章纲'**
  String get plotPlanOutlineSaved;

  /// No description provided for @plotPlanParseFailed.
  ///
  /// In zh, this message translates to:
  /// **'AI 返回的不是结构化结果，已按原文展示。'**
  String get plotPlanParseFailed;

  /// No description provided for @plotPlanFailed.
  ///
  /// In zh, this message translates to:
  /// **'推演失败：{message}'**
  String plotPlanFailed(String message);

  /// No description provided for @batchSummaryTitle.
  ///
  /// In zh, this message translates to:
  /// **'批量生成摘要'**
  String get batchSummaryTitle;

  /// No description provided for @batchSummaryIntro.
  ///
  /// In zh, this message translates to:
  /// **'为缺少摘要或正文已更新的章节依次生成前情摘要，结果直接写回章节。'**
  String get batchSummaryIntro;

  /// No description provided for @batchSummaryStart.
  ///
  /// In zh, this message translates to:
  /// **'生成缺失摘要（{count}）'**
  String batchSummaryStart(int count);

  /// No description provided for @batchSummaryAll.
  ///
  /// In zh, this message translates to:
  /// **'全部重新生成'**
  String get batchSummaryAll;

  /// No description provided for @batchSummaryRunning.
  ///
  /// In zh, this message translates to:
  /// **'正在生成第 {current}/{total} 章…'**
  String batchSummaryRunning(int current, int total);

  /// No description provided for @batchSummaryStopping.
  ///
  /// In zh, this message translates to:
  /// **'将在当前章节完成后停止…'**
  String get batchSummaryStopping;

  /// No description provided for @batchSummaryCancel.
  ///
  /// In zh, this message translates to:
  /// **'停止'**
  String get batchSummaryCancel;

  /// No description provided for @batchSummaryEmpty.
  ///
  /// In zh, this message translates to:
  /// **'所有章节摘要都是最新的。'**
  String get batchSummaryEmpty;

  /// No description provided for @batchSummaryMissing.
  ///
  /// In zh, this message translates to:
  /// **'缺少摘要'**
  String get batchSummaryMissing;

  /// No description provided for @batchSummaryStale.
  ///
  /// In zh, this message translates to:
  /// **'正文已更新'**
  String get batchSummaryStale;

  /// No description provided for @batchSummaryCurrent.
  ///
  /// In zh, this message translates to:
  /// **'摘要已是最新'**
  String get batchSummaryCurrent;

  /// No description provided for @batchSummaryDone.
  ///
  /// In zh, this message translates to:
  /// **'已生成 {count} 章摘要'**
  String batchSummaryDone(int count);

  /// No description provided for @batchSummaryFailed.
  ///
  /// In zh, this message translates to:
  /// **'生成失败：{message}'**
  String batchSummaryFailed(String message);

  /// No description provided for @batchSummaryResult.
  ///
  /// In zh, this message translates to:
  /// **'生成结果'**
  String get batchSummaryResult;

  /// No description provided for @batchSummaryEmptyResult.
  ///
  /// In zh, this message translates to:
  /// **'AI 未返回内容'**
  String get batchSummaryEmptyResult;

  /// No description provided for @chatTitle.
  ///
  /// In zh, this message translates to:
  /// **'作品问答'**
  String get chatTitle;

  /// No description provided for @chatIntro.
  ///
  /// In zh, this message translates to:
  /// **'基于作品设定、章纲与正文回答你的问题；需要细节时会自动检索相关章节。'**
  String get chatIntro;

  /// No description provided for @chatEmpty.
  ///
  /// In zh, this message translates to:
  /// **'和 AI 聊聊这部作品'**
  String get chatEmpty;

  /// No description provided for @chatInputHint.
  ///
  /// In zh, this message translates to:
  /// **'输入问题…'**
  String get chatInputHint;

  /// No description provided for @chatSend.
  ///
  /// In zh, this message translates to:
  /// **'发送'**
  String get chatSend;

  /// No description provided for @chatStop.
  ///
  /// In zh, this message translates to:
  /// **'停止'**
  String get chatStop;

  /// No description provided for @chatThinking.
  ///
  /// In zh, this message translates to:
  /// **'正在思考…'**
  String get chatThinking;

  /// No description provided for @chatNoReply.
  ///
  /// In zh, this message translates to:
  /// **'（没有返回内容）'**
  String get chatNoReply;

  /// No description provided for @chatClearTitle.
  ///
  /// In zh, this message translates to:
  /// **'清空对话'**
  String get chatClearTitle;

  /// No description provided for @chatClearBody.
  ///
  /// In zh, this message translates to:
  /// **'将删除这部作品的问答记录，不影响作品内容。是否继续？'**
  String get chatClearBody;

  /// No description provided for @chatClearAction.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get chatClearAction;

  /// No description provided for @chatContextTitle.
  ///
  /// In zh, this message translates to:
  /// **'上下文详情'**
  String get chatContextTitle;

  /// No description provided for @chatContextUsage.
  ///
  /// In zh, this message translates to:
  /// **'已注入约 {estimated} / {budget} token'**
  String chatContextUsage(int estimated, int budget);

  /// No description provided for @chatSuggestionGoal.
  ///
  /// In zh, this message translates to:
  /// **'主角目前的目标是什么？'**
  String get chatSuggestionGoal;

  /// No description provided for @chatSuggestionForeshadow.
  ///
  /// In zh, this message translates to:
  /// **'哪些伏笔还没回收？'**
  String get chatSuggestionForeshadow;

  /// No description provided for @chatSuggestionRelationship.
  ///
  /// In zh, this message translates to:
  /// **'梳理主要人物关系'**
  String get chatSuggestionRelationship;

  /// No description provided for @editorContinuityStop.
  ///
  /// In zh, this message translates to:
  /// **'停止'**
  String get editorContinuityStop;

  /// No description provided for @editorContinuityStopped.
  ///
  /// In zh, this message translates to:
  /// **'已停止生成，以下是已生成的内容。'**
  String get editorContinuityStopped;

  /// No description provided for @editorContinuityStoppedEmpty.
  ///
  /// In zh, this message translates to:
  /// **'已停止，尚未收到内容。'**
  String get editorContinuityStoppedEmpty;

  /// No description provided for @continuityScanTitle.
  ///
  /// In zh, this message translates to:
  /// **'全书一致性体检'**
  String get continuityScanTitle;

  /// No description provided for @continuityScanIntro.
  ///
  /// In zh, this message translates to:
  /// **'逐章检查正文与角色卡、设定集、章纲、前情是否冲突。全书按顺序执行，避免并发触发服务商限流；可随时停止并保留已完成的结果。'**
  String get continuityScanIntro;

  /// No description provided for @continuityScanEmpty.
  ///
  /// In zh, this message translates to:
  /// **'没有可检查的章节，请先写正文。'**
  String get continuityScanEmpty;

  /// No description provided for @continuityScanStart.
  ///
  /// In zh, this message translates to:
  /// **'开始全书体检'**
  String get continuityScanStart;

  /// No description provided for @continuityScanRerun.
  ///
  /// In zh, this message translates to:
  /// **'重新体检'**
  String get continuityScanRerun;

  /// No description provided for @continuityScanRunning.
  ///
  /// In zh, this message translates to:
  /// **'正在检查第 {current} / {total} 章…'**
  String continuityScanRunning(int current, int total);

  /// No description provided for @continuityScanStopping.
  ///
  /// In zh, this message translates to:
  /// **'当前章完成后停止…'**
  String get continuityScanStopping;

  /// No description provided for @continuityScanCancel.
  ///
  /// In zh, this message translates to:
  /// **'停止体检'**
  String get continuityScanCancel;

  /// No description provided for @continuityScanResult.
  ///
  /// In zh, this message translates to:
  /// **'检查结果'**
  String get continuityScanResult;

  /// No description provided for @continuityScanProgress.
  ///
  /// In zh, this message translates to:
  /// **'已完成 {done} / {total} 章'**
  String continuityScanProgress(int done, int total);

  /// No description provided for @continuityScanNoIssues.
  ///
  /// In zh, this message translates to:
  /// **'未发现冲突'**
  String get continuityScanNoIssues;

  /// No description provided for @continuityScanHasIssues.
  ///
  /// In zh, this message translates to:
  /// **'发现疑似冲突，点击查看'**
  String get continuityScanHasIssues;

  /// No description provided for @continuityScanChapterFailed.
  ///
  /// In zh, this message translates to:
  /// **'本章检查失败'**
  String get continuityScanChapterFailed;

  /// No description provided for @continuityScanFailedLine.
  ///
  /// In zh, this message translates to:
  /// **'检查失败：{message}'**
  String continuityScanFailedLine(String message);

  /// No description provided for @continuityScanCopyAll.
  ///
  /// In zh, this message translates to:
  /// **'复制全部结果'**
  String get continuityScanCopyAll;

  /// No description provided for @continuityScanCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制到剪贴板'**
  String get continuityScanCopied;

  /// No description provided for @aiTaskStyle.
  ///
  /// In zh, this message translates to:
  /// **'AI 文风提取'**
  String get aiTaskStyle;

  /// No description provided for @aiTaskExtract.
  ///
  /// In zh, this message translates to:
  /// **'AI 设定补全'**
  String get aiTaskExtract;

  /// No description provided for @aiTaskPlan.
  ///
  /// In zh, this message translates to:
  /// **'AI 剧情推演'**
  String get aiTaskPlan;

  /// No description provided for @aiTaskChat.
  ///
  /// In zh, this message translates to:
  /// **'AI 作品问答'**
  String get aiTaskChat;

  /// No description provided for @aiTaskStoryState.
  ///
  /// In zh, this message translates to:
  /// **'AI 状态提取'**
  String get aiTaskStoryState;

  /// No description provided for @tokenStatsEstimatedCost.
  ///
  /// In zh, this message translates to:
  /// **'预计费用'**
  String get tokenStatsEstimatedCost;

  /// No description provided for @tokenStatsCostValue.
  ///
  /// In zh, this message translates to:
  /// **'¥{amount}'**
  String tokenStatsCostValue(String amount);

  /// No description provided for @tokenStatsCostHint.
  ///
  /// In zh, this message translates to:
  /// **'在模型组中填写每百万 token 单价后，可在这里估算费用。'**
  String get tokenStatsCostHint;

  /// No description provided for @tokenStatsCostPartial.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个模型未填写单价，未计入费用。'**
  String tokenStatsCostPartial(int count);

  /// No description provided for @tokenStatsMonthly.
  ///
  /// In zh, this message translates to:
  /// **'本月预算'**
  String get tokenStatsMonthly;

  /// No description provided for @tokenStatsBudgetUnset.
  ///
  /// In zh, this message translates to:
  /// **'未设置月度预算'**
  String get tokenStatsBudgetUnset;

  /// No description provided for @tokenStatsBudgetSet.
  ///
  /// In zh, this message translates to:
  /// **'设置月度预算'**
  String get tokenStatsBudgetSet;

  /// No description provided for @tokenStatsBudgetEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑预算'**
  String get tokenStatsBudgetEdit;

  /// No description provided for @tokenStatsBudgetUsage.
  ///
  /// In zh, this message translates to:
  /// **'本月已用 ¥{used} / 预算 ¥{budget}'**
  String tokenStatsBudgetUsage(String used, String budget);

  /// No description provided for @tokenStatsBudgetUsedOnly.
  ///
  /// In zh, this message translates to:
  /// **'本月已用 ¥{used}'**
  String tokenStatsBudgetUsedOnly(String used);

  /// No description provided for @tokenStatsBudgetPercent.
  ///
  /// In zh, this message translates to:
  /// **'已用 {percent}%'**
  String tokenStatsBudgetPercent(String percent);

  /// No description provided for @tokenStatsBudgetExceeded.
  ///
  /// In zh, this message translates to:
  /// **'本月预算已用完，继续调用将超出预算。'**
  String get tokenStatsBudgetExceeded;

  /// No description provided for @tokenStatsBudgetWarning.
  ///
  /// In zh, this message translates to:
  /// **'本月预算已用超过 80%。'**
  String get tokenStatsBudgetWarning;

  /// No description provided for @tokenStatsBudgetNoPrice.
  ///
  /// In zh, this message translates to:
  /// **'模型未填写单价，无法估算当月花费。'**
  String get tokenStatsBudgetNoPrice;

  /// No description provided for @tokenStatsBudgetDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'月度 AI 预算'**
  String get tokenStatsBudgetDialogTitle;

  /// No description provided for @tokenStatsBudgetDialogBody.
  ///
  /// In zh, this message translates to:
  /// **'按自然月统计 AI 调用费用；留空或 0 表示不限制。'**
  String get tokenStatsBudgetDialogBody;

  /// No description provided for @tokenStatsBudgetField.
  ///
  /// In zh, this message translates to:
  /// **'预算金额（元）'**
  String get tokenStatsBudgetField;

  /// No description provided for @tokenStatsBudgetInvalid.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效的金额'**
  String get tokenStatsBudgetInvalid;

  /// No description provided for @tokenStatsBudgetSaved.
  ///
  /// In zh, this message translates to:
  /// **'月度预算已更新'**
  String get tokenStatsBudgetSaved;

  /// No description provided for @modelGroupsPriceLine.
  ///
  /// In zh, this message translates to:
  /// **'¥{input} / ¥{output} 每百万 token'**
  String modelGroupsPriceLine(String input, String output);

  /// No description provided for @modelGroupsNoPrice.
  ///
  /// In zh, this message translates to:
  /// **'未填单价'**
  String get modelGroupsNoPrice;

  /// No description provided for @settingsScreenProtection.
  ///
  /// In zh, this message translates to:
  /// **'截屏保护'**
  String get settingsScreenProtection;

  /// No description provided for @settingsScreenProtectionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'阻止截屏、录屏与后台缩略图泄露正文'**
  String get settingsScreenProtectionSubtitle;

  /// No description provided for @settingsScreenProtectionEnabled.
  ///
  /// In zh, this message translates to:
  /// **'截屏保护已开启'**
  String get settingsScreenProtectionEnabled;

  /// No description provided for @settingsScreenProtectionDisabled.
  ///
  /// In zh, this message translates to:
  /// **'截屏保护已关闭'**
  String get settingsScreenProtectionDisabled;

  /// No description provided for @settingsBackupEncryption.
  ///
  /// In zh, this message translates to:
  /// **'备份加密'**
  String get settingsBackupEncryption;

  /// No description provided for @settingsBackupEncryptionOff.
  ///
  /// In zh, this message translates to:
  /// **'未开启：备份文件为明文 zip'**
  String get settingsBackupEncryptionOff;

  /// No description provided for @settingsBackupEncryptionOn.
  ///
  /// In zh, this message translates to:
  /// **'已开启：导出与云备份使用 AES-256-GCM 加密'**
  String get settingsBackupEncryptionOn;

  /// No description provided for @settingsBackupEncryptionEnabled.
  ///
  /// In zh, this message translates to:
  /// **'备份加密已开启'**
  String get settingsBackupEncryptionEnabled;

  /// No description provided for @settingsBackupEncryptionDisabled.
  ///
  /// In zh, this message translates to:
  /// **'备份加密已关闭'**
  String get settingsBackupEncryptionDisabled;

  /// No description provided for @settingsBackupEncryptionDisableTitle.
  ///
  /// In zh, this message translates to:
  /// **'关闭备份加密？'**
  String get settingsBackupEncryptionDisableTitle;

  /// No description provided for @settingsBackupEncryptionDisableBody.
  ///
  /// In zh, this message translates to:
  /// **'已加密的旧备份仍需原密码恢复；之后的新备份将以明文保存。'**
  String get settingsBackupEncryptionDisableBody;

  /// No description provided for @settingsBackupEncryptionDisableAction.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get settingsBackupEncryptionDisableAction;

  /// No description provided for @backupEncryptMissingPassphrase.
  ///
  /// In zh, this message translates to:
  /// **'未找到备份密码，请先在设置中重新设置'**
  String get backupEncryptMissingPassphrase;

  /// No description provided for @backupPassphraseSetTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置备份密码'**
  String get backupPassphraseSetTitle;

  /// No description provided for @backupPassphraseSetBody.
  ///
  /// In zh, this message translates to:
  /// **'密码至少 {count} 位。忘记密码将无法恢复此后的加密备份，请妥善保管。'**
  String backupPassphraseSetBody(int count);

  /// No description provided for @backupPassphraseLabel.
  ///
  /// In zh, this message translates to:
  /// **'备份密码'**
  String get backupPassphraseLabel;

  /// No description provided for @backupPassphraseConfirmLabel.
  ///
  /// In zh, this message translates to:
  /// **'再次输入密码'**
  String get backupPassphraseConfirmLabel;

  /// No description provided for @backupPassphraseTooShort.
  ///
  /// In zh, this message translates to:
  /// **'密码至少 {count} 位'**
  String backupPassphraseTooShort(int count);

  /// No description provided for @backupPassphraseMismatch.
  ///
  /// In zh, this message translates to:
  /// **'两次输入的密码不一致'**
  String get backupPassphraseMismatch;

  /// No description provided for @backupPassphraseRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入备份密码'**
  String get backupPassphraseRequired;

  /// No description provided for @backupPassphrasePromptTitle.
  ///
  /// In zh, this message translates to:
  /// **'输入备份密码'**
  String get backupPassphrasePromptTitle;

  /// No description provided for @backupPassphrasePromptBody.
  ///
  /// In zh, this message translates to:
  /// **'该备份文件已加密，请输入导出时设置的密码。'**
  String get backupPassphrasePromptBody;

  /// No description provided for @backupPassphraseUnlock.
  ///
  /// In zh, this message translates to:
  /// **'解密恢复'**
  String get backupPassphraseUnlock;

  /// No description provided for @backupErrorDecryptionFailed.
  ///
  /// In zh, this message translates to:
  /// **'密码错误或备份文件已损坏，无法解密'**
  String get backupErrorDecryptionFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
