// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'NovelPhone';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonSettings => 'Settings';

  @override
  String commonCreateFailed(String detail) {
    return 'Failed to create: $detail';
  }

  @override
  String get worksSearchTooltip => 'Search';

  @override
  String get worksNew => 'New work';

  @override
  String worksLoadFailed(String detail) {
    return 'Failed to load works: $detail';
  }

  @override
  String get worksEmptyTitle => 'No works yet';

  @override
  String get worksEmptyHint =>
      'Write the story in your head — start with your first work.';

  @override
  String get worksEmptyCreate => 'Create your first work';

  @override
  String get worksPin => 'Pin to top';

  @override
  String get worksUnpin => 'Unpin';

  @override
  String get worksDelete => 'Delete work';

  @override
  String worksDeleteConfirm(String title) {
    return 'Delete \"$title\"?';
  }

  @override
  String get worksDeleteConfirmBody =>
      'All chapters, character cards, and outlines in this work will be deleted. This cannot be undone.';

  @override
  String worksLastEdited(String time) {
    return 'Last edited $time';
  }

  @override
  String worksLimitReached(int max) {
    return 'At most $max works are allowed';
  }

  @override
  String chapterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapters',
      one: '1 chapter',
    );
    return '$_temp0';
  }

  @override
  String get newWorkTitleRequired => 'Please enter a title';

  @override
  String newWorkTitleMax(int max) {
    return 'Title must be at most $max characters';
  }

  @override
  String get newWorkTitleLabel => 'Title';

  @override
  String get newWorkTitleHint => 'e.g. Long Night';

  @override
  String get newWorkCoverLabel => 'Cover color';

  @override
  String get newWorkCreating => 'Creating…';

  @override
  String get newWorkCreate => 'Create work';

  @override
  String get timeJustNow => 'Just now';

  @override
  String timeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String get timeYesterday => 'Yesterday';

  @override
  String timeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String wordCountExact(String count) {
    return '$count words';
  }

  @override
  String wordCountWan(String value) {
    return '${value}K words';
  }

  @override
  String wordCountK(String value) {
    return '${value}K words';
  }

  @override
  String wordCountM(String value) {
    return '${value}M words';
  }

  @override
  String tokenCountScaled(String value) {
    return '${value}K';
  }

  @override
  String tokenCountMega(String value) {
    return '${value}M';
  }

  @override
  String get commonSave => 'Save';

  @override
  String get commonConfirm => 'OK';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonRename => 'Rename';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonClose => 'Close';

  @override
  String get commonRestore => 'Restore';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonDone => 'Done';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonBack => 'Back';

  @override
  String get commonMore => 'More';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonReset => 'Reset';

  @override
  String get commonUntitledChapter => 'Untitled chapter';

  @override
  String get chapterStatusDraft => 'Draft';

  @override
  String get chapterStatusRevising => 'Revising';

  @override
  String get chapterStatusFinished => 'Final';

  @override
  String get settingTypeWorldview => 'Worldbuilding';

  @override
  String get settingTypeLocation => 'Locations';

  @override
  String get settingTypeItem => 'Items';

  @override
  String get localeSystem => 'System default';

  @override
  String get localeZh => '简体中文';

  @override
  String get localeEn => 'English';

  @override
  String get editorChapterTitleDialog => 'Chapter title';

  @override
  String get editorChapterSummaryTooltip => 'Chapter synopsis';

  @override
  String get editorAiToolsTooltip => 'AI chapter tools';

  @override
  String get editorToolSummarize => 'Generate chapter summary';

  @override
  String get editorToolVolumeSummary => 'Generate volume recap';

  @override
  String get editorToolOutlineExpand => 'Expand chapter outline with AI';

  @override
  String get editorToolEditSummary => 'View/edit chapter summary';

  @override
  String get editorExitFocusMode => 'Exit focus mode';

  @override
  String get editorFocusMode => 'Focus mode';

  @override
  String get editorBodyHint => 'Write your text here…';

  @override
  String get editorSelectRewriteText => 'Select the passage to rewrite first';

  @override
  String get editorNeedOutlineSeed =>
      'Add a one-sentence synopsis via \"Chapter synopsis\" in the top bar first; AI will expand it';

  @override
  String get editorNoEarlierChapters =>
      'No earlier chapters in this volume yet; the volume recap cannot be generated';

  @override
  String get editorNoModelTitle => 'No model configured';

  @override
  String get editorNoModelBody =>
      'Add a model group and fill in the API key in Settings before using AI features.';

  @override
  String get editorLater => 'Later';

  @override
  String get editorGoSettings => 'Go to Settings';

  @override
  String get editorOriginalChanged =>
      'The text has changed; select it again to rewrite';

  @override
  String get editorSummaryTitle => 'Chapter AI summary';

  @override
  String get editorSummaryHint =>
      'AI-generated recap; editable, and used for story continuity in later chapters';

  @override
  String get editorSummaryStale =>
      'The text has changed; the summary may be outdated. Regenerate it.';

  @override
  String get editorSaving => 'Saving';

  @override
  String get editorSaved => 'Saved';

  @override
  String get editorSaveFailed => 'Save failed. Tap to retry';

  @override
  String get editorAiContinue => 'AI continuation';

  @override
  String get editorAiInspire => 'AI ideas';

  @override
  String get editorAiRewrite => 'AI rewrite';

  @override
  String get editorFind => 'Find';

  @override
  String get editorAiCheck => 'AI-flavor';

  @override
  String get editorMoveParagraph => 'Move paragraph';

  @override
  String get editorMoveParagraphUp => 'Move up';

  @override
  String get editorMoveParagraphDown => 'Move down';

  @override
  String get editorUndo => 'Undo';

  @override
  String get editorRedo => 'Redo';

  @override
  String editorChapterWords(String words) {
    return 'Chapter $words';
  }

  @override
  String editorWholeWorkWords(String words) {
    return 'Book $words';
  }

  @override
  String editorLastSaved(String time) {
    return 'Last saved $time';
  }

  @override
  String get aiPanelTitleContinue => 'AI continuation';

  @override
  String get aiPanelTitleInspireIdeas => 'AI ideas · Plot beats';

  @override
  String get aiPanelTitleInspireOpening => 'AI ideas · Opening helper';

  @override
  String get aiPanelTitleRewrite => 'AI rewrite';

  @override
  String get aiPanelTitleSummarize => 'AI chapter summary';

  @override
  String get aiPanelTitleOutlineExpand => 'AI outline expansion';

  @override
  String get aiPanelTitleVolumeSummary => 'AI volume recap';

  @override
  String get aiPanelNewDirection => 'New direction';

  @override
  String get aiPanelDirectionHint =>
      'Add a direction, e.g. have the two face off here';

  @override
  String get aiPanelRegenerate => 'Regenerate';

  @override
  String aiPanelElapsedSeconds(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds',
      one: '1 second',
    );
    return '$_temp0';
  }

  @override
  String get aiPanelCollapse => 'Collapse';

  @override
  String get aiPanelModeIdeas => 'Plot beats';

  @override
  String get aiPanelModeOpening => 'Opening helper';

  @override
  String get aiPanelInstructionHint =>
      'Extra instruction (optional), e.g. make her words colder';

  @override
  String aiPanelLengthLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Length: $count words',
      one: 'Length: 1 word',
    );
    return '$_temp0';
  }

  @override
  String get aiPanelCandidateCount => '3 candidates';

  @override
  String aiPanelVersion(int n) {
    return 'Version $n';
  }

  @override
  String aiPanelContextTitle(int estimated, int budget) {
    return 'Context seen by AI (estimated $estimated / budget $budget tokens)';
  }

  @override
  String get aiPanelTruncated => 'Earlier text omitted';

  @override
  String get aiPanelResultHint =>
      'AI output streams here; edit it before inserting into the text';

  @override
  String get aiPanelNeedsConfig => 'No model or API key configured';

  @override
  String get aiPanelReplaceOriginal => 'Replace original';

  @override
  String get aiPanelSaveSummary => 'Save summary';

  @override
  String get aiPanelSaveToOutline => 'Save to outline';

  @override
  String get aiPanelSaveVolumeSummary => 'Save recap';

  @override
  String get aiPanelInsertAtCursor => 'Insert at cursor';

  @override
  String get aiPanelStop => 'Stop';

  @override
  String get aiPanelSaveToInspiration => 'Save to inspiration box';

  @override
  String get aiPanelDiscard => 'Discard';

  @override
  String get aiPanelSavedToInspiration => 'Saved to inspiration box';

  @override
  String get rewriteIntentPolish => 'Polish';

  @override
  String get rewriteIntentExpand => 'Expand';

  @override
  String get rewriteIntentCondense => 'Condense';

  @override
  String get rewriteIntentTone => 'Adjust tone';

  @override
  String get aiSectionChapterText => 'Chapter text';

  @override
  String get aiSectionTaskMode => 'Task mode';

  @override
  String get aiSectionChapterSynopsis => 'Chapter synopsis';

  @override
  String get aiSectionVolumeMaterial =>
      'Volume material (previous recap + new chapters)';

  @override
  String get aiSectionVolumeOutline => 'Volume outline';

  @override
  String get aiSectionPreviousSummary => 'Previous summary';

  @override
  String get aiSectionCharacters => 'Related character cards';

  @override
  String get aiSectionSettings => 'Worldbuilding';

  @override
  String get aiSectionChapterOutline => 'Chapter outline';

  @override
  String get aiSectionChapterTail => 'Written chapter text (tail)';

  @override
  String get aiSectionRequirements => 'Generation requirements';

  @override
  String get aiSectionUserSkills => 'User skills';

  @override
  String get flavorTitle => 'AI-flavor check';

  @override
  String flavorShownOfTotal(int shown, int total) {
    return 'Showing the first $shown of $total';
  }

  @override
  String flavorIssueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count issues',
      one: '1 issue',
    );
    return '$_temp0';
  }

  @override
  String flavorDeepProgress(int done, int total) {
    return 'Deep check $done/$total';
  }

  @override
  String get flavorScope => 'Scope';

  @override
  String get flavorWholeWork => 'Entire work';

  @override
  String flavorChapterItem(String title, String words) {
    return '$title ($words)';
  }

  @override
  String flavorMetrics(int cliche, String density, String repeat, int dash) {
    return 'Clichés $cliche · density $density/1k chars · pattern repeats $repeat% · dashes/ellipses $dash';
  }

  @override
  String get flavorDeepRunning => 'Deep checking…';

  @override
  String get flavorDeepCheck => 'LLM deep check';

  @override
  String get flavorRecheck => 'Recheck';

  @override
  String get flavorEditInEditor => 'Edit in the editor';

  @override
  String flavorEstimatedTokens(String tokens) {
    return 'Estimated ~$tokens tokens';
  }

  @override
  String flavorMeasuredTokens(String input, String output) {
    return 'Measured input $input + output $output';
  }

  @override
  String get flavorNeedsConfigMessage =>
      'No model configured for the AI-flavor check; deep check is unavailable.';

  @override
  String flavorDeepFailed(String error) {
    return 'Deep check failed (rule results kept): $error';
  }

  @override
  String get flavorRetryDeepCheck => 'Retry deep check';

  @override
  String get flavorFallbackNotice =>
      'The model returned no structured results; raw output:';

  @override
  String get flavorFilterAll => 'All';

  @override
  String get flavorSeverityHigh => 'High';

  @override
  String get flavorSeverityMedium => 'Medium';

  @override
  String get flavorSeverityLow => 'Low';

  @override
  String get flavorTypeCliche => 'Clichés';

  @override
  String get flavorTypeRepetition => 'Sentence repetition';

  @override
  String get flavorTypeTranslationese => 'Translationese';

  @override
  String get flavorTypeOversummary => 'Over-summarizing';

  @override
  String get flavorTypePacing => 'Sluggish pacing';

  @override
  String get flavorEmptyHint => 'No text in this scope; nothing to check';

  @override
  String get flavorCleanHint => 'No obvious AI-flavor issues found';

  @override
  String get flavorDeepBadge => 'Deep check';

  @override
  String get flavorLocateInText => 'Locate in text';

  @override
  String get flavorDeleteWord => 'Delete this word';

  @override
  String flavorReplaceWith(String replacement) {
    return 'Replace with \"$replacement\"';
  }

  @override
  String get flavorIgnoreThis => 'Ignore this one';

  @override
  String flavorIgnoreAllType(String type) {
    return 'Ignore all \"$type\"';
  }

  @override
  String flavorOriginalText(String excerpt) {
    return 'Original: $excerpt';
  }

  @override
  String flavorSuggestion(String suggestion) {
    return 'Suggestion: $suggestion';
  }

  @override
  String get flavorLocate => 'Locate';

  @override
  String get flavorReplace => 'Replace';

  @override
  String get flavorIgnore => 'Ignore';

  @override
  String get flavorDeletedWord => 'Word deleted';

  @override
  String flavorReplacedWith(String replacement) {
    return 'Replaced with \"$replacement\"';
  }

  @override
  String get flavorOriginalChanged =>
      'The text has changed; run the check again';

  @override
  String get snapshotCreated => 'Snapshot created';

  @override
  String get snapshotRestoreVersion => 'Restore this version';

  @override
  String get snapshotRestored => 'Restored to this version';

  @override
  String get snapshotEmptyChapter => '(Empty chapter)';

  @override
  String get snapshotHistoryTitle => 'Version history';

  @override
  String get snapshotCreate => 'Create snapshot';

  @override
  String get snapshotEmptyHint =>
      'No snapshots yet. Tap \"Create snapshot\" while writing to keep a version.';

  @override
  String findReplaceReplacedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Replaced $count occurrences',
      one: 'Replaced 1 occurrence',
    );
    return '$_temp0';
  }

  @override
  String get findReplaceFindHint => 'Find';

  @override
  String get findReplaceCaseSensitive => 'Match case';

  @override
  String findReplaceMatchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count matches',
      one: '1 match',
    );
    return '$_temp0';
  }

  @override
  String get findReplaceReplacementHint => 'Replace with';

  @override
  String get findReplaceReplace => 'Replace';

  @override
  String get findReplaceReplaceAll => 'Replace all';

  @override
  String aiErrorNetwork(String detail) {
    return 'Network request failed: $detail';
  }

  @override
  String aiErrorAuth(int status) {
    return 'Authentication failed ($status): check your API key in Settings';
  }

  @override
  String get aiErrorRateLimit =>
      'Too many requests (429). Please try again later';

  @override
  String aiErrorServer(int status) {
    return 'The model service is temporarily unavailable ($status). Please try again later';
  }

  @override
  String aiErrorContentFilter(String detail) {
    return 'Rejected by the model provider\'s content filter: $detail';
  }

  @override
  String aiErrorBadRequest(int status, String detail) {
    return 'Request failed ($status): $detail';
  }

  @override
  String aiErrorProviderError(String detail) {
    return 'The model service returned an error: $detail';
  }

  @override
  String aiErrorProviderFailed(String detail) {
    return 'The model service returned a failure: $detail';
  }

  @override
  String get aiErrorIncompleteOutput =>
      'Model output was truncated (incomplete). Shorten the context or raise the output limit';

  @override
  String get aiErrorToolLoop => 'AI tool call round limit exceeded, stopped';

  @override
  String get cloudErrorEndpointMissing => 'Please fill in the Endpoint first';

  @override
  String cloudErrorNetwork(String detail) {
    return 'Network request failed: $detail';
  }

  @override
  String get cloudErrorSignatureMismatch =>
      'Signature verification failed (SignatureDoesNotMatch): check that AccessKey / SecretKey, Endpoint and Region match';

  @override
  String get cloudErrorForbidden =>
      'Access denied (403): check the AccessKey / SecretKey and bucket permissions';

  @override
  String get cloudErrorNotFound =>
      'Resource not found (404): check the Endpoint, bucket name and path prefix';

  @override
  String get cloudErrorClockSkew =>
      'Device clock is too far off from the server (RequestTimeTooSkewed): please calibrate the system time';

  @override
  String cloudErrorHttp(int status, String detail) {
    return 'Cloud returned HTTP $status: $detail';
  }

  @override
  String get backupErrorInvalidZip => 'The file is not a valid zip backup';

  @override
  String backupErrorMissingEntry(String entry) {
    return 'The backup file is missing $entry';
  }

  @override
  String get backupErrorDecodeFailed => 'Failed to parse the backup content';

  @override
  String get backupErrorInvalidFormat =>
      'The backup content has an invalid format';

  @override
  String get backupErrorWrongFormat => 'Not a NovelPhone backup file';

  @override
  String get backupErrorNewerVersion =>
      'This backup is from a newer app version. Please update the app first';

  @override
  String get backupErrorIncomplete => 'The backup content is incomplete';

  @override
  String get modelTestOk => 'Connection successful';

  @override
  String modelTestOkDetail(String detail) {
    return 'Connection successful: $detail';
  }

  @override
  String get modelTestMissingModel => 'Please fill in the model name first';

  @override
  String get modelTestMissingKey => 'Please fill in the API Key first';

  @override
  String modelTestFailed(String detail) {
    return 'Connection failed: $detail';
  }

  @override
  String get searchHint => 'Search all works…';

  @override
  String get searchEmptyHint =>
      'Enter a keyword to search chapter titles and text across all works.';

  @override
  String searchFailed(String detail) {
    return 'Search failed: $detail';
  }

  @override
  String searchNoResults(String keyword) {
    return 'No chapters found containing \"$keyword\"';
  }

  @override
  String get statsTitle => 'Writing stats';

  @override
  String get statsTodayTitle => 'Today\'s writing';

  @override
  String get statsSetTarget => 'Set goal';

  @override
  String statsWordsOfGoal(int goal) {
    String _temp0 = intl.Intl.pluralLogic(
      goal,
      locale: localeName,
      other: ' / $goal words',
      one: ' / 1 word',
    );
    return '$_temp0';
  }

  @override
  String statsWordsOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' words',
      one: ' word',
    );
    return '$_temp0';
  }

  @override
  String statsGoalRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count words to go',
      one: '1 word to go',
    );
    return '$_temp0';
  }

  @override
  String get statsGoalReached => 'Today\'s goal reached';

  @override
  String get statsStreakTitle => 'Writing streak';

  @override
  String statsStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get statsStreakKeepGoing => 'Keep it up — don\'t break the streak';

  @override
  String get statsStreakStart => 'Write a little today to start a streak';

  @override
  String get statsPomodoroTitle => 'Pomodoro';

  @override
  String statsPomodoroMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min',
      one: '1 min',
    );
    return '$_temp0';
  }

  @override
  String get statsPomodoroStart => 'Start';

  @override
  String get statsPomodoroPause => 'Pause';

  @override
  String statsPomodoroDoneToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pomodoros done today',
      one: '1 pomodoro done today',
    );
    return '$_temp0';
  }

  @override
  String get statsPomodoroFinished => 'Pomodoro complete — take a break';

  @override
  String get statsDailyTargetTitle => 'Daily word goal';

  @override
  String get statsDailyTargetHint => '0 means no goal';

  @override
  String get statsDailyTargetUnit => 'words';

  @override
  String get statsPomodoroDurationTitle => 'Pomodoro length';

  @override
  String get statsPomodoroDurationHint => '1-120';

  @override
  String get statsPomodoroDurationUnit => 'min';

  @override
  String get appearanceTitle => 'Writing appearance';

  @override
  String get appearanceDarkPaper => 'Night paper';

  @override
  String get appearanceDarkPaperSubtitle =>
      'Dark, eye-friendly background for writing with the lights off';

  @override
  String get appearanceFontSize => 'Body text size';

  @override
  String get appearanceLineHeight => 'Line spacing';

  @override
  String get appearancePreview => 'Preview';

  @override
  String get appearancePreviewText =>
      'The long night was ending. She pushed the window open, and snow whirled into her face.\nOne by one the distant lamps went dark — only the candle on her desk still burned.';

  @override
  String get summaryEditTitle => 'Edit chapter summary';

  @override
  String get summaryEditHint =>
      'Describe what happens in this chapter (0-1000 characters). AI outline expansion also treats this as the one-sentence summary.';

  @override
  String get aiNoticeTitle => 'Before you use AI';

  @override
  String get aiNoticeBody =>
      'Your manuscript text and settings are stored on this device by default. When you use AI features, the app sends the minimal context required by the model provider you configured (current chapter content, outline, related character cards, etc.) directly over the network to that provider. It never passes through NovelPhone\'s servers.\n\nYour API key is stored in the device\'s secure storage and is never uploaded.\n\nBy tapping \"I understand\", you acknowledge and agree to the data transfers described above.';

  @override
  String get aiNoticeConfirm => 'I understand';

  @override
  String get settingsSectionAiModels => 'AI & Models';

  @override
  String get settingsModelGroups => 'Model Groups & API Keys';

  @override
  String get settingsModelGroupsSubtitle =>
      'Manage keys, base URLs, models, and generation settings per provider';

  @override
  String get settingsTaskMapping => 'Task & Model Mapping';

  @override
  String get settingsTaskMappingSubtitle =>
      'Assign model groups for continue writing, inspiration, and AI-flavor checks';

  @override
  String get settingsTokenStats => 'Token & Adoption Stats';

  @override
  String get settingsMcpServers => 'MCP Tool Servers';

  @override
  String get settingsMcpServersSubtitle =>
      'Connect remote MCP servers and expose their tools to the AI';

  @override
  String get settingsSkills => 'Custom Skills';

  @override
  String get settingsSkillsSubtitle =>
      'Extra instructions and tool allowlists injected into continue writing and inspiration';

  @override
  String get settingsSectionWriting => 'Writing';

  @override
  String get settingsAppearance => 'Writing Appearance';

  @override
  String get settingsAppearanceSubtitle =>
      'Night paper, body text size, and line spacing';

  @override
  String get settingsThemeMode => 'Theme';

  @override
  String get themeModeSystem => 'System default';

  @override
  String get themeModeLight => 'Light';

  @override
  String get themeModeDark => 'Dark';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsWritingStats => 'Writing Stats';

  @override
  String get settingsWritingStatsSubtitle =>
      'Daily word goal, writing streak, and pomodoro timer';

  @override
  String get settingsSectionData => 'Data';

  @override
  String get settingsBackupHint =>
      'All work data is stored on this device. Before uninstalling the app or switching devices, back up to a file first, or the data cannot be recovered.';

  @override
  String get settingsBackupToFile => 'Back Up to File';

  @override
  String get settingsBackupToFileSubtitle =>
      'Export all works and text for device migration or safekeeping';

  @override
  String get settingsRestoreFromBackup => 'Restore from Backup';

  @override
  String get settingsRestoreFromBackupSubtitle =>
      'Pick a backup file to merge as a new work or overwrite local data';

  @override
  String get settingsCloudBackup => 'Cloud Backup';

  @override
  String get settingsCloudBackupSubtitle =>
      'Back up to your own object storage (S3 / OSS / COS, etc.), off by default';

  @override
  String get modelGroupsNew => 'New model group';

  @override
  String modelGroupsLoadFailed(String detail) {
    return 'Failed to load: $detail';
  }

  @override
  String get modelGroupsEmptyTitle => 'No model groups yet';

  @override
  String get modelGroupsEmptyHint =>
      'Add a provider and API key before continue writing and inspiration can work';

  @override
  String get modelGroupsOpenAiCompat => 'OpenAI compatible';

  @override
  String get modelGroupsNoModel => 'No models set';

  @override
  String get modelGroupsModelSeparator => ', ';

  @override
  String get modelGroupsNoKey => 'No API key';

  @override
  String get modelGroupsDeleteTitle => 'Delete model group';

  @override
  String modelGroupsDeleteConfirm(String name) {
    return 'Deleting \"$name\" will also remove its API key from this device.';
  }

  @override
  String get modelGroupsDeleted => 'Model group deleted';

  @override
  String get modelEditTitle => 'Edit model group';

  @override
  String get modelEditNameLabel => 'Name';

  @override
  String get modelEditNameHint => 'e.g. DeepSeek Official';

  @override
  String get modelEditNameRequired => 'Please enter a name';

  @override
  String get modelEditProtocolLabel => 'Protocol';

  @override
  String get modelEditBaseUrlHelper =>
      'Must include /v1, e.g. https://api.deepseek.com/v1';

  @override
  String get modelEditBaseUrlRequired => 'Please enter the Base URL';

  @override
  String get modelEditModelsLabel => 'Models';

  @override
  String get modelEditModelsHelper =>
      'One per line; the first line is the default model';

  @override
  String get modelEditModelsRequired => 'Please enter at least one model name';

  @override
  String get modelEditApiKeySaved => 'Saved; leave empty to keep unchanged';

  @override
  String get modelEditApiKeyHint => 'Paste the key provided by your provider';

  @override
  String get modelEditApiKeyHelper =>
      'Stored only in on-device secure storage; not included in backups';

  @override
  String get modelEditTemperature => 'Temperature';

  @override
  String get modelEditMaxTokensLabel => 'Max output tokens';

  @override
  String get modelEditContextWindow => 'Context window';

  @override
  String get modelEditContextWindowHelper => '50% of it is used as the budget';

  @override
  String get modelEditEnabled => 'Enabled';

  @override
  String get modelEditEnabledSubtitle =>
      'Disabled groups are not used by task mapping';

  @override
  String get modelEditTestConnection => 'Test connection';

  @override
  String get modelEditTestNoModel =>
      'Please enter at least one model name first';

  @override
  String get modelEditTestNoApiKey => 'Please enter the API key first';

  @override
  String get modelEditSaved => 'Saved';

  @override
  String taskMapLoadFailed(String detail) {
    return 'Failed to load: $detail';
  }

  @override
  String get taskMapEmptyHint =>
      'Add a model group in \"Model Groups & API Keys\" first';

  @override
  String get taskMapIntro =>
      'Assign a model group to each AI task; if none is assigned, the feature is unavailable.';

  @override
  String get taskMapUnassigned => 'Not assigned';

  @override
  String get aiTaskContinue => 'AI Continue';

  @override
  String get aiTaskInspire => 'AI Inspiration';

  @override
  String get aiTaskRewrite => 'AI Rewrite';

  @override
  String get aiTaskCheck => 'Flavor Check';

  @override
  String get aiTaskSummary => 'Chapter Summary';

  @override
  String get aiTaskOutlineExpand => 'Outline Expand';

  @override
  String get aiTaskVolumeSummary => 'Volume Recap';

  @override
  String get tokenStatsResetTitle => 'Reset stats';

  @override
  String get tokenStatsResetBody =>
      'Clear all generation and adoption records. This cannot be undone.';

  @override
  String tokenStatsLoadFailed(String detail) {
    return 'Failed to load: $detail';
  }

  @override
  String get tokenStatsEmpty => 'No generations yet';

  @override
  String get tokenStatsCalls => 'Generations';

  @override
  String get tokenStatsTotalTokens => 'Total tokens';

  @override
  String get tokenStatsAdoptionRate => 'Adoption rate';

  @override
  String get tokenStatsIgnoreRate => 'Ignore rate';

  @override
  String get tokenStatsCheckHandledRate => 'Check issues handled';

  @override
  String tokenStatsRowCalls(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count runs',
      one: '1 run',
    );
    return '$_temp0';
  }

  @override
  String tokenStatsRowTokens(String prompt, String completion) {
    return 'In $prompt · Out $completion';
  }

  @override
  String tokenStatsRowChars(int output, int adopted) {
    String _temp0 = intl.Intl.pluralLogic(
      output,
      locale: localeName,
      other: 'Generated $output characters',
      one: 'Generated 1 character',
    );
    String _temp1 = intl.Intl.pluralLogic(
      adopted,
      locale: localeName,
      other: 'Adopted $adopted characters',
      one: 'Adopted 1 character',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String tokenStatsRowCounts(int adopted, int ignored) {
    String _temp0 = intl.Intl.pluralLogic(
      adopted,
      locale: localeName,
      other: 'Adopted $adopted times',
      one: 'Adopted 1 time',
    );
    String _temp1 = intl.Intl.pluralLogic(
      ignored,
      locale: localeName,
      other: 'Ignored $ignored times',
      one: 'Ignored 1 time',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get statStatusAdopted => 'Adopted';

  @override
  String get statStatusIgnored => 'Ignored';

  @override
  String get statStatusRegenerated => 'Regenerated';

  @override
  String get statStatusAborted => 'Aborted';

  @override
  String get statStatusPending => 'Pending';

  @override
  String get backupShareTitle => 'NovelPhone Backup';

  @override
  String backupRestoreDone(int works, int chapters, int characters) {
    return 'Restore complete: $works works, $chapters chapters, $characters character cards';
  }

  @override
  String get backupRestoreModeTitle => 'Choose restore mode';

  @override
  String get backupRestoreModeBody =>
      'Merge: import the works in the backup as new works without clearing existing data.\nOverwrite: clear all works on this device first, then restore exactly as in the backup. This cannot be undone.';

  @override
  String get backupRestoreModeMerge => 'Merge';

  @override
  String get backupRestoreModeOverwrite => 'Overwrite';

  @override
  String get cloudSaved => 'Saved';

  @override
  String get cloudTitle => 'Cloud Backup';

  @override
  String get cloudEnable => 'Enable cloud backup';

  @override
  String get cloudEnableSubtitle =>
      'When off, no network access and no cloud requests';

  @override
  String get cloudProviderLabel => 'Provider';

  @override
  String get cloudProviderAwsS3 => 'AWS S3';

  @override
  String get cloudProviderAliyunOss => 'Alibaba Cloud OSS';

  @override
  String get cloudProviderQiniuKodo => 'Qiniu Kodo';

  @override
  String get cloudProviderTencentCos => 'Tencent Cloud COS';

  @override
  String get cloudProviderHuaweiObs => 'Huawei Cloud OBS';

  @override
  String get cloudRegionHintAwsS3 => 'e.g. us-east-1';

  @override
  String get cloudRegionHintAliyunOss => 'e.g. cn-hangzhou';

  @override
  String get cloudRegionHintQiniuKodo => 'e.g. cn-east-1';

  @override
  String get cloudRegionHintTencentCos => 'e.g. ap-guangzhou';

  @override
  String get cloudRegionHintHuaweiObs => 'e.g. cn-north-4';

  @override
  String get cloudEndpointHintAwsS3 =>
      'No bucket name, e.g. s3.us-east-1.amazonaws.com';

  @override
  String get cloudEndpointHintAliyunOss =>
      'No bucket name, e.g. oss-cn-hangzhou.aliyuncs.com';

  @override
  String get cloudEndpointHintQiniuKodo =>
      'No bucket name, e.g. s3-cn-east-1.qiniucs.com';

  @override
  String get cloudEndpointHintTencentCos =>
      'No bucket name, e.g. cos.ap-guangzhou.myqcloud.com';

  @override
  String get cloudEndpointHintHuaweiObs =>
      'No bucket name, e.g. obs.cn-north-4.myhuaweicloud.com';

  @override
  String get cloudRegionRequired => 'Region is required';

  @override
  String get cloudEndpointRequired => 'Endpoint is required';

  @override
  String get cloudBucketRequired => 'Bucket name is required';

  @override
  String get cloudBucketLabel => 'Bucket';

  @override
  String get cloudPrefixLabel => 'Path prefix';

  @override
  String cloudPrefixHelper(String prefix) {
    return 'Default: $prefix';
  }

  @override
  String get cloudKeepCountLabel => 'Backups to keep';

  @override
  String get cloudKeepCountHelper =>
      'The oldest backups are deleted automatically beyond this count; minimum 1';

  @override
  String get cloudKeepCountInvalid => 'Enter an integer no less than 1';

  @override
  String get cloudCredentialsHelper =>
      'Stored only in this device\'s secure storage; never exported with backups';

  @override
  String get cloudSecretHintSaved => 'Saved; leave blank to keep unchanged';

  @override
  String get cloudTestConnection => 'Test connection';

  @override
  String get cloudBackupNow => 'Back up now';

  @override
  String get cloudRefreshRemote => 'Refresh remote backups';

  @override
  String get cloudTestOk => 'Connected: bucket and credentials are usable';

  @override
  String cloudBackupOk(String objectKey, String size) {
    return 'Backup succeeded: $objectKey ($size)';
  }

  @override
  String cloudBackupOkPruned(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count old backups',
      one: '1 old backup',
    );
    return ', pruned $_temp0';
  }

  @override
  String get cloudRemoteEmpty => 'No backups on the remote yet';

  @override
  String cloudRemoteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count backups on the remote',
      one: '1 backup on the remote',
    );
    return '$_temp0';
  }

  @override
  String get cloudNeedEndpointRegionBucket =>
      'Please fill in Endpoint, Region, and Bucket first';

  @override
  String get cloudNeedCredentials =>
      'Please fill in AccessKey and SecretKey first';

  @override
  String get cloudAutoTitle => 'Automatic backup';

  @override
  String get cloudAutoSubtitle =>
      'When enabled, backs up on launch or when returning to the foreground once the selected interval has passed since the last backup';

  @override
  String get cloudIntervalLabel => 'Backup frequency';

  @override
  String get cloudIntervalEvery12h => 'Every 12 hours';

  @override
  String get cloudIntervalDaily => 'Daily';

  @override
  String get cloudIntervalWeekly => 'Weekly';

  @override
  String get cloudRemoteSection => 'Remote backups';

  @override
  String get cloudRemoteTapRefresh =>
      'Tap \"Refresh remote backups\" to view existing backups';

  @override
  String get cloudPrivacyHint =>
      'Cloud backup is off by default and only goes online when you enable and trigger it (including interval-based triggers after automatic backup is turned on). The backup content matches the local zip (including manuscript text, no API keys); AccessKey / SecretKey are stored only in this device\'s secure storage.';

  @override
  String get mcpDeleteTitle => 'Delete MCP server';

  @override
  String mcpDeleteBody(String name) {
    return 'Deleting \"$name\" also removes its auth headers from this device.';
  }

  @override
  String get mcpTitle => 'MCP tool servers';

  @override
  String get mcpAdd => 'Add server';

  @override
  String get mcpAllTools => 'All tools available';

  @override
  String mcpWhitelist(String tools) {
    return 'Whitelist: $tools';
  }

  @override
  String get mcpListSeparator => ', ';

  @override
  String get mcpEmptyTitle => 'No MCP servers yet';

  @override
  String get mcpEmptyHint =>
      'After adding a remote MCP server, its tools can be called by the AI when generating \"Plot Ideas\"';

  @override
  String get mcpSaved => 'Saved';

  @override
  String get mcpEndpointMissing => 'Please fill in the MCP endpoint URL first';

  @override
  String get mcpTestOkNoTools => 'Connected, but the server exposes no tools';

  @override
  String mcpTestOkTools(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tools',
      one: '1 tool',
    );
    return 'Connected, $_temp0: $names';
  }

  @override
  String mcpTestFailed(String detail) {
    return 'Connection failed: $detail';
  }

  @override
  String get mcpNewTitle => 'Add MCP server';

  @override
  String get mcpEditTitle => 'Edit MCP server';

  @override
  String get mcpNameLabel => 'Name';

  @override
  String get mcpNameHint => 'e.g. My local MCP server';

  @override
  String get mcpNameRequired => 'Please fill in the name';

  @override
  String get mcpEndpointLabel => 'MCP endpoint URL';

  @override
  String get mcpEndpointHelper =>
      'Full Streamable HTTP URL, e.g. https://example.com/mcp';

  @override
  String get mcpEndpointRequired => 'Please fill in the endpoint URL';

  @override
  String get mcpEndpointInvalid => 'Enter a full URL starting with http(s)://';

  @override
  String get mcpAuthLabel => 'Auth headers';

  @override
  String get mcpAuthHintSaved => 'Saved; leave blank to keep unchanged';

  @override
  String get mcpAuthHint => 'One per line, e.g. Authorization: Bearer xxx';

  @override
  String get mcpAuthHelper =>
      'Stored only in this device\'s secure storage; never exported with backups';

  @override
  String get mcpToolsLabel => 'Tool whitelist';

  @override
  String get mcpToolsHelper =>
      'One remote tool name per line; leave blank to allow all';

  @override
  String get mcpEnable => 'Enable';

  @override
  String get mcpEnableSubtitle =>
      'When disabled, its tools are not exposed to the AI';

  @override
  String get mcpTestConnection => 'Test connection';

  @override
  String get skillDeleteTitle => 'Delete skill';

  @override
  String skillDeleteBody(String name) {
    return 'Deleting \"$name\" stops its instruction from being injected into AI generation.';
  }

  @override
  String get skillTitle => 'Custom skills';

  @override
  String get skillAdd => 'Add skill';

  @override
  String get skillToolsUnlimited => 'Tools: unrestricted';

  @override
  String skillToolsWhitelist(String tools) {
    return 'Tool whitelist: $tools';
  }

  @override
  String get skillListSeparator => ', ';

  @override
  String get skillEmptyTitle => 'No custom skills yet';

  @override
  String get skillEmptyHint =>
      'Write an extra instruction (e.g. \"use short sentences only\", \"avoid explanatory narration\"); once enabled it is injected into the system prompt for continuation and inspiration generation';

  @override
  String get skillSaved => 'Saved';

  @override
  String get skillNewTitle => 'Add skill';

  @override
  String get skillEditTitle => 'Edit skill';

  @override
  String get skillNameLabel => 'Skill name';

  @override
  String get skillNameHint => 'e.g. Short, hard-boiled sentences';

  @override
  String get skillNameRequired => 'Please fill in the skill name';

  @override
  String get skillInstructionLabel => 'Instruction text';

  @override
  String get skillInstructionHint =>
      'e.g. Use short sentences only, avoid explanatory narration, and write no tone adverbs in dialogue.';

  @override
  String get skillInstructionHelper =>
      'Injected as an extra system instruction for continuation and inspiration generation';

  @override
  String get skillInstructionRequired => 'Please fill in the instruction text';

  @override
  String get skillParamsLabel => 'Parameter template (optional)';

  @override
  String get skillParamsHint => 'One key=value per line, e.g. words=800';

  @override
  String skillParamsHelper(String open, String close) {
    return 'Reference parameters in the instruction as ${open}name$close; replaced with the value on injection';
  }

  @override
  String get skillToolsLabel => 'Tool whitelist (optional)';

  @override
  String get skillToolsHint => 'One tool name per line, e.g. get_chapter';

  @override
  String get skillToolsHelper =>
      'Leave blank for no restriction; built-in tools get_chapter / get_characters / get_outline; MCP tools start with mcp_';

  @override
  String get skillEnable => 'Enable';

  @override
  String get skillEnableSubtitle =>
      'When disabled, it is not injected and does not participate in the tool whitelist';

  @override
  String get workDetailTitleFallback => 'Work';

  @override
  String get workDetailTabChapters => 'Chapters';

  @override
  String get workDetailTabCharacters => 'Characters';

  @override
  String get workDetailTabWorldbuilding => 'Worldbuilding';

  @override
  String get workDetailTabOutline => 'Outline';

  @override
  String get workDetailRunFlavorCheck => 'Run AI-feel check';

  @override
  String get workDetailImportTxtDocx => 'Import txt / docx';

  @override
  String get workDetailInspirationsTitle => 'Inspiration box';

  @override
  String get workDetailAiSettings => 'AI settings';

  @override
  String get workDetailRenameWork => 'Rename work';

  @override
  String workDetailImportedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Imported $count chapters',
      one: 'Imported 1 chapter',
    );
    return '$_temp0';
  }

  @override
  String get workDetailRecordInspiration => 'New inspiration';

  @override
  String get workDetailEditInspiration => 'Edit inspiration';

  @override
  String get workDetailInspirationHint => 'Write something…';

  @override
  String get workDetailInspirationsEmpty => 'The inspiration box is empty';

  @override
  String get workDetailInspirationsEmptyHint =>
      'Jot down scenes, settings, or a line of dialogue. Ideas from AI inspiration are saved here too.';

  @override
  String get workDetailDeleteInspirationConfirm =>
      'Delete this inspiration item?';

  @override
  String get chaptersNewVolume => 'New volume';

  @override
  String get chaptersNewVolumeHint => 'e.g. Volume 2: Rising Wind';

  @override
  String get chaptersCreate => 'Create';

  @override
  String get chaptersEmptyTitle => 'No chapters yet';

  @override
  String get chaptersEmptyHint =>
      'Create a volume below, then start writing your first chapter.';

  @override
  String chaptersVolumeHeader(String volume, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapters',
      one: '1 chapter',
    );
    return '$volume ($_temp0)';
  }

  @override
  String get chaptersVolumeActions => 'Volume actions';

  @override
  String get chaptersRenameVolume => 'Rename volume';

  @override
  String get chaptersVolumeSummaryAction => 'View / edit volume recap';

  @override
  String get chaptersMoveUp => 'Move up';

  @override
  String get chaptersMoveDown => 'Move down';

  @override
  String get chaptersDeleteVolume => 'Delete volume';

  @override
  String get chaptersVolumeSummaryTitle => 'Volume recap';

  @override
  String get chaptersVolumeSummaryHint =>
      'An AI-generated or hand-written recap of this volume, used to keep later chapters consistent';

  @override
  String chaptersDeleteVolumeConfirm(String volume) {
    return 'Delete \"$volume\"?';
  }

  @override
  String get chaptersDeleteVolumeEmptyBody => 'This volume has no chapters.';

  @override
  String chaptersDeleteVolumeBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'All $count chapters in this volume will be deleted too. This cannot be undone.',
      one:
          'The only chapter in this volume will be deleted too. This cannot be undone.',
    );
    return '$_temp0';
  }

  @override
  String get chaptersAddChapterInVolume => 'Add chapter to this volume';

  @override
  String get chaptersRenameChapter => 'Rename chapter';

  @override
  String get chaptersMoveToVolume => 'Move to another volume';

  @override
  String chaptersMarkAs(String status) {
    return 'Mark as $status';
  }

  @override
  String get chaptersDeleteChapter => 'Delete chapter';

  @override
  String get chaptersNoOtherVolume => 'No other volume to move to';

  @override
  String chaptersDeleteChapterConfirm(String title) {
    return 'Delete \"$title\"?';
  }

  @override
  String get chaptersDeleteChapterBody =>
      'The content of this chapter cannot be restored after deletion.';

  @override
  String get outlineOrphanSection => 'Summaries not linked to chapters';

  @override
  String get outlineEmptyEntry => '(Empty summary)';

  @override
  String get outlineEmptyTitle => 'No outline yet';

  @override
  String get outlineEmptyHint =>
      'Create chapters in the \"Chapters\" tab first, then write a one-line summary for each.';

  @override
  String get outlineNoSummary => 'No summary yet';

  @override
  String get charactersNewCard => 'New character card';

  @override
  String get charactersEditCard => 'Edit character card';

  @override
  String get charactersEmptyTitle => 'No character cards yet';

  @override
  String get charactersEmptyHint =>
      'Once you build character profiles, AI continuations and inspiration will automatically include the relevant character settings.';

  @override
  String get charactersIdentityEmpty => 'Identity not set';

  @override
  String get charactersNameLabel => 'Name (required, 1-20 characters)';

  @override
  String get charactersIdentityLabel => 'Identity';

  @override
  String get charactersTagsLabel =>
      'Personality tags (up to 10, separated by spaces or commas)';

  @override
  String get charactersAppearanceLabel => 'Appearance';

  @override
  String get charactersRelationsLabel => 'Relationships';

  @override
  String get charactersArcLabel => 'Character arc';

  @override
  String get charactersNameError => 'Name must be 1-20 characters';

  @override
  String get charactersTagsError => 'At most 10 personality tags';

  @override
  String charactersDeleteConfirm(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get charactersDeleteBody =>
      'This character card cannot be restored after deletion.';

  @override
  String get worldbuildingNewEntry => 'New entry';

  @override
  String get worldbuildingEditEntry => 'Edit entry';

  @override
  String worldbuildingEmptyTitle(String type) {
    return 'No $type yet';
  }

  @override
  String worldbuildingEmptyHint(String type) {
    return 'Save $type details for your work to look them up while writing.';
  }

  @override
  String get worldbuildingNameLabel => 'Name (required, 1-50 characters)';

  @override
  String get worldbuildingContentLabel => 'Content';

  @override
  String get worldbuildingNameError => 'Name must be 1-50 characters';

  @override
  String worldbuildingDeleteConfirm(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get worldbuildingDeleteBody =>
      'This entry cannot be restored after deletion.';

  @override
  String get relationGraphTitle => 'Character relations';

  @override
  String get relationGraphEmpty =>
      'No relations yet. Tap the button in the lower right to add one.';

  @override
  String get relationGraphDeletedCharacter => 'Deleted character';

  @override
  String get relationGraphAdd => 'Add relation';

  @override
  String get relationGraphEdit => 'Edit relation';

  @override
  String get relationGraphMinCharacters =>
      'At least two character cards are needed to draw the relation graph.';

  @override
  String get relationGraphCharacterA => 'Character A';

  @override
  String get relationGraphCharacterB => 'Character B';

  @override
  String get relationGraphLabelField => 'Relation (e.g. mentor, arch-rival)';

  @override
  String get relationGraphSelectTwo => 'Please select two different characters';

  @override
  String get importPageTitle => 'Import manuscript';

  @override
  String get importPagePickFile => 'Choose txt / docx file';

  @override
  String get importPageRepickFile => 'Choose another file';

  @override
  String importPageConfirmButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Import $count chapters',
      one: 'Import 1 chapter',
    );
    return '$_temp0';
  }

  @override
  String get importPageFileTooLarge =>
      'The file exceeds the 10 MB limit. Split it on a computer before importing.';

  @override
  String get importPageNoContent =>
      'No content was found. Please check the file format.';

  @override
  String importPageParseFailed(String detail) {
    return 'Failed to parse: $detail';
  }

  @override
  String importPageFailed(String detail) {
    return 'Import failed: $detail';
  }

  @override
  String get importPageDialogEmptyTitle => 'Empty chapters found';

  @override
  String importPageDialogEmptyBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapters have no content. Keep them?',
      one: '1 chapter has no content. Keep it?',
    );
    return '$_temp0';
  }

  @override
  String get importPageKeepAll => 'Keep all';

  @override
  String get importPageDropEmpty => 'Drop empty chapters';

  @override
  String get importPageNoImportable => 'No chapters to import';

  @override
  String get importPagePickHintTitle => 'Import an old draft';

  @override
  String get importPagePickHintBody =>
      'Supports txt (UTF-8 / GBK) and docx. Chapters are split automatically by headings such as \"Chapter X\", and you can preview and adjust them in the next step.';

  @override
  String importPageFileSummary(String encoding, int count, int words) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Encoding $encoding · $count chapters · $words words in total',
      one: 'Encoding $encoding · 1 chapter · $words words in total',
    );
    return '$_temp0';
  }

  @override
  String get importPageMergeIntoPrevious => 'Merge into previous chapter';

  @override
  String get exportActionsFormatTxt => 'Plain text (.txt)';

  @override
  String get exportActionsFormatMarkdown => 'Markdown (.md)';

  @override
  String get exportActionsFormatDocx => 'Word document (.docx)';

  @override
  String get exportActionsFormatEpub => 'EPUB ebook (.epub)';

  @override
  String get exportActionsChapterTitle => 'Export this chapter';

  @override
  String get exportActionsShareChapterTitle => 'Export chapter';

  @override
  String get exportActionsExportWorkTitle => 'Export work';

  @override
  String get exportActionsNoChapters =>
      'This work has no chapters to export yet.';

  @override
  String exportActionsShareFailed(String detail) {
    return 'Export failed: $detail';
  }
}
