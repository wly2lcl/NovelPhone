import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/ai/insert_separator.dart';
import '../../core/text_search.dart';
import '../../core/word_count.dart';
import '../../data/repositories/chapter_repository.dart';

/// 保存状态指示（PRD 5.3）：保存中 / 已保存 / 失败（可点击重试）。
enum SaveStatus { saving, saved, failed }

/// 编辑器状态：自动保存、会话恢复、独立撤销栈、查找替换、段落移动、字数统计。
class EditorController extends ChangeNotifier {
  EditorController({
    required this.repository,
    required this.workId,
    required this.chapterId,
  });

  /// 单章正文上限（PRD 5.3，超出仅提示不阻断保存，避免丢稿）。
  static const int maxChapterWords = 100000;

  /// 停止输入后自动保存的防抖时长（PRD 5.3）。
  static const Duration autosaveDelay = Duration(seconds: 1);

  /// 撤销栈的快照合并时长：连续输入合并为一次可撤销操作。
  static const Duration historyCoalesceDelay = Duration(milliseconds: 500);

  static const int _maxHistory = 100;

  /// 撤销栈累计正文字符上限（ENH-10）：每步快照保存整章副本，10 万字章节单条约
  /// 20 万字符，仅按条数限制仍可能占用大量内存，故同时限制累计字符数。
  static const int _maxHistoryChars = 2000000;

  /// 撤销栈始终保留的最少步数（ENH-10）：即便超出字符上限也保留最近几步可撤销。
  static const int _minHistoryKeep = 10;

  /// 字数重算防抖（ENH-10）：长章每次按键都全章遍历 rune，改为停顿后再算。
  static const Duration wordCountDebounce = Duration(milliseconds: 120);

  final ChapterRepository repository;
  final int workId;
  final int chapterId;

  final TextEditingController textController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  /// 正文焦点（M4-10：定位时请求焦点，让选中高亮可见并滚动到该处）。
  final FocusNode focusNode = FocusNode();

  bool _loaded = false;
  bool get loaded => _loaded;

  String _title = '';
  String get title => _title;

  /// 最近一次成功落库的标题与正文（ENH-09）：`TextEditingController` 在选区
  /// 变化时也会通知，只挪光标不该被当成正文改动去重写整章，故用它们区分。
  String? _lastSavedText;
  String? _lastSavedTitle;

  SaveStatus _saveStatus = SaveStatus.saved;
  SaveStatus get saveStatus => _saveStatus;

  DateTime? _lastSavedAt;
  DateTime? get lastSavedAt => _lastSavedAt;

  int _chapterWords = 0;
  int get chapterWords => _chapterWords;

  bool get overWordLimit => _chapterWords > maxChapterWords;

  /// 会话恢复用的滚动位置（首帧后由页面消费）。
  int initialScrollOffset = 0;

  Timer? _saveTimer;
  Timer? _historyTimer;
  Timer? _wordTimer;
  bool _dirty = false;
  bool _applyingHistory = false;

  /// dispose 后不再向监听者发通知：离开编辑器时 `flush()` 的保存会晚于 dispose 完成。
  bool _disposed = false;

  final List<_Snapshot> _history = <_Snapshot>[];
  int _historyIndex = -1;

  bool get canUndo => _historyIndex > 0;
  bool get canRedo => _historyIndex >= 0 && _historyIndex < _history.length - 1;

  /// 载入章节正文与上次的光标、滚动位置。
  Future<void> load() async {
    final chapter = await repository.getChapter(chapterId);
    if (chapter == null) return;
    _title = chapter.title;
    textController.text = chapter.content;
    _lastSavedText = chapter.content;
    _lastSavedTitle = chapter.title;
    _chapterWords = chapter.wordCount;
    initialScrollOffset = chapter.scrollOffset;
    final cursor = chapter.cursorOffset.clamp(0, chapter.content.length);
    textController.selection = TextSelection.collapsed(offset: cursor);
    _loaded = true;
    _history.add(_Snapshot(textController.text, cursor));
    _historyIndex = 0;
    textController.addListener(_onTextChanged);
    notifyListeners();
  }

  void _onTextChanged() {
    final text = textController.text;
    // 选区变化也会触发本监听：标题与正文都与已落库内容一致时，只挪了光标，
    // 不重算字数、不标记「保存中」、不排保存（避免每次移光标重写整章）。
    if (text == _lastSavedText && _title == _lastSavedTitle) return;
    // ENH-10：字数改为停顿后重算，避免每次按键都对整章重跑 countWords。
    _wordTimer?.cancel();
    _wordTimer = Timer(wordCountDebounce, _recountWords);
    _dirty = true;
    _saveStatus = SaveStatus.saving;
    _saveTimer?.cancel();
    _saveTimer = Timer(autosaveDelay, _save);
    if (!_applyingHistory) {
      _historyTimer?.cancel();
      _historyTimer = Timer(historyCoalesceDelay, _pushSnapshot);
    }
    notifyListeners();
  }

  /// 停顿后重算字数（ENH-10），仅在真的变了时才通知界面。
  void _recountWords() {
    final words = countWords(textController.text);
    if (words == _chapterWords) return;
    _chapterWords = words;
    if (!_disposed) notifyListeners();
  }

  Future<void> _save() async {
    _saveTimer?.cancel();
    if (!_dirty) return;
    _saveStatus = SaveStatus.saving;
    notifyListeners();
    final text = textController.text;
    try {
      // 正文与标题都没变（多为移动光标 / 改选区）：只落库位置，不重写整章。
      if (text == _lastSavedText && _title == _lastSavedTitle) {
        await repository.saveCursorPosition(
          chapterId: chapterId,
          cursorOffset: _currentCursor,
          scrollOffset: _currentScroll,
        );
      } else {
        await repository.saveChapter(
          chapterId: chapterId,
          title: _title,
          content: text,
          cursorOffset: _currentCursor,
          scrollOffset: _currentScroll,
        );
        _lastSavedText = text;
        _lastSavedTitle = _title;
      }
      _dirty = false;
      _lastSavedAt = DateTime.now();
      _saveStatus = SaveStatus.saved;
    } catch (_) {
      _saveStatus = SaveStatus.failed;
    }
    if (!_disposed) notifyListeners();
  }

  /// 保存失败后的手动重试。
  Future<void> retrySave() => _save();

  /// 离开编辑器前落库：正文（如有改动）+ 光标与滚动位置。
  Future<void> flush() async {
    _historyTimer?.cancel();
    if (_dirty) {
      await _save();
    }
    await repository.saveCursorPosition(
      chapterId: chapterId,
      cursorOffset: _currentCursor,
      scrollOffset: _currentScroll,
    );
  }

  Future<void> renameChapter(String title) async {
    _title = title;
    _dirty = true;
    _saveStatus = SaveStatus.saving;
    notifyListeners();
    await _save();
  }

  int get _currentCursor {
    final offset = textController.selection.baseOffset;
    if (offset >= 0) return offset;
    return textController.text.length;
  }

  int get _currentScroll => scrollController.hasClients
      ? scrollController.offset.round()
      : initialScrollOffset;

  // ---------- 撤销 / 重做（编辑器独立历史栈，与输入法隔离）----------

  void undo() {
    _commitHistoryNow();
    if (_historyIndex <= 0) return;
    _historyIndex--;
    _applySnapshot(_history[_historyIndex]);
  }

  void redo() {
    _commitHistoryNow();
    if (_historyIndex >= _history.length - 1) return;
    _historyIndex++;
    _applySnapshot(_history[_historyIndex]);
  }

  void _pushSnapshot() {
    final snapshot = _Snapshot(textController.text, _currentCursor);
    if (_historyIndex >= 0 &&
        _historyIndex < _history.length &&
        _history[_historyIndex].text == snapshot.text) {
      _history[_historyIndex] = snapshot;
      return;
    }
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(snapshot);
    _trimHistory();
    _historyIndex = _history.length - 1;
  }

  /// 按条数与累计字符数裁剪最旧快照（ENH-10），始终保留最近 [_minHistoryKeep] 步。
  void _trimHistory() {
    var total = 0;
    for (final snapshot in _history) {
      total += snapshot.text.length;
    }
    while (_history.length > _maxHistory ||
        (total > _maxHistoryChars && _history.length > _minHistoryKeep)) {
      total -= _history[0].text.length;
      _history.removeAt(0);
    }
  }

  void _commitHistoryNow() {
    _historyTimer?.cancel();
    _pushSnapshot();
  }

  void _applySnapshot(_Snapshot snapshot) {
    _applyingHistory = true;
    textController.value = TextEditingValue(
      text: snapshot.text,
      selection: TextSelection.collapsed(
        offset: snapshot.cursor.clamp(0, snapshot.text.length),
      ),
    );
    _applyingHistory = false;
    _dirty = true;
    _saveStatus = SaveStatus.saving;
    _saveTimer?.cancel();
    _saveTimer = Timer(autosaveDelay, _save);
    notifyListeners();
  }

  // ---------- 段落移动（PRD 5.3）----------

  /// 光标所在段落上移 / 下移一行段落。
  void moveParagraph({required bool up}) {
    final text = textController.text;
    final offset = textController.selection.baseOffset;
    if (offset < 0) return;
    final lines = text.split('\n');
    final lineIndex = '\n'.allMatches(text.substring(0, offset)).length;
    final target = up ? lineIndex - 1 : lineIndex + 1;
    if (lineIndex < 0 || lineIndex >= lines.length) return;
    if (target < 0 || target >= lines.length) return;

    final swapped = List<String>.of(lines);
    final current = lines[lineIndex];
    swapped[lineIndex] = lines[target];
    swapped[target] = current;

    final shift = up ? -(lines[target].length + 1) : (lines[target].length + 1);
    final newOffset = (offset + shift).clamp(0, swapped.join('\n').length);

    _commitHistoryNow();
    textController.value = TextEditingValue(
      text: swapped.join('\n'),
      selection: TextSelection.collapsed(offset: newOffset),
    );
    _commitHistoryNow();
  }

  // ---------- 查找替换（PRD 5.3）----------

  List<TextMatch> findMatches(String keyword, {bool caseSensitive = false}) =>
      findTextMatches(
        textController.text,
        keyword,
        caseSensitive: caseSensitive,
      );

  int countMatches(String keyword, {bool caseSensitive = false}) =>
      findMatches(keyword, caseSensitive: caseSensitive).length;

  /// 替换光标之后的第一个命中（无光标之后的命中时替换首个）。
  bool replaceNext(
    String keyword,
    String replacement, {
    bool caseSensitive = false,
  }) {
    final matches = findMatches(keyword, caseSensitive: caseSensitive);
    if (matches.isEmpty) return false;
    final cursor = textController.selection.baseOffset;
    final target = matches.firstWhere(
      (m) => cursor < 0 || m.start >= cursor,
      orElse: () => matches.first,
    );
    final text = textController.text;
    final newText = text.replaceRange(target.start, target.end, replacement);
    _commitHistoryNow();
    textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: (target.start + replacement.length).clamp(0, newText.length),
      ),
    );
    _commitHistoryNow();
    return true;
  }

  /// 全部替换，返回替换处数。
  int replaceAll(
    String keyword,
    String replacement, {
    bool caseSensitive = false,
  }) {
    final matches = findMatches(keyword, caseSensitive: caseSensitive);
    if (matches.isEmpty) return 0;
    final text = textController.text;
    final buffer = StringBuffer();
    var last = 0;
    for (final match in matches) {
      buffer.write(text.substring(last, match.start));
      buffer.write(replacement);
      last = match.end;
    }
    buffer.write(text.substring(last));
    final newText = buffer.toString();
    _commitHistoryNow();
    textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: matches.first.start),
    );
    _commitHistoryNow();
    return matches.length;
  }

  // ---------- AI 感检查：定位与替换（M4-10 / M4-11）----------

  /// 定位到指定区间（M4-10）：请求焦点并选中该区间，形成可见高亮。
  void revealRange(int start, int end) {
    final text = textController.text;
    final from = start.clamp(0, text.length);
    final to = end.clamp(from, text.length);
    focusNode.requestFocus();
    _commitHistoryNow();
    textController.selection = TextSelection(
      baseOffset: from,
      extentOffset: to,
    );
    // 选中后不改变正文，历史栈保持原样。
    notifyListeners();
  }

  /// 一键替换指定区间（M4-11）：走编辑器历史栈，可撤销。
  bool replaceRange(int start, int end, String replacement) {
    final text = textController.text;
    if (start < 0 || start > end || end > text.length) return false;
    final newText = text.replaceRange(start, end, replacement);
    _commitHistoryNow();
    textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: (start + replacement.length).clamp(0, newText.length),
      ),
    );
    _commitHistoryNow();
    return true;
  }

  /// 替换选中区间（ENH-04）：原文漂移（区间内文本与 AI 所见不一致）时拒绝，
  /// 命中则转调 [replaceRange]，自动走撤销栈。
  bool replaceSelection({
    required int start,
    required int end,
    required String original,
    required String replacement,
  }) {
    final text = textController.text;
    if (start < 0 || start > end || end > text.length) return false;
    if (text.substring(start, end) != original) return false;
    return replaceRange(start, end, replacement);
  }

  // ---------- AI 产出插入 ----------

  /// 在光标处插入文本（M3-14）：走编辑器历史栈，与手工输入一样可撤销。
  void insertAtCursor(String text) {
    if (text.isEmpty) return;
    final raw = textController.selection.baseOffset;
    final offset = raw >= 0
        ? raw.clamp(0, textController.text.length)
        : textController.text.length;
    // ENH-27.1：按插入点两侧内容补足空行，避免 AI 文本与原文粘连。
    final insertion = composeAiInsertion(
      document: textController.text,
      offset: offset,
      text: text,
    );
    final newText = textController.text.replaceRange(offset, offset, insertion);
    _commitHistoryNow();
    textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: offset + insertion.length),
    );
    _commitHistoryNow();
  }

  // ---------- 版本历史（B-05）----------

  /// 恢复到指定版本：写入标题与正文并立即落库，同时压入历史栈（可撤销）。
  Future<void> restoreVersion({
    required String title,
    required String content,
  }) async {
    _historyTimer?.cancel();
    textController.value = TextEditingValue(
      text: content,
      selection: TextSelection.collapsed(offset: content.length),
    );
    if (title.isNotEmpty) _title = title;
    _pushSnapshot();
    _dirty = true;
    await _save();
  }

  @override
  void dispose() {
    _disposed = true;
    _saveTimer?.cancel();
    _historyTimer?.cancel();
    _wordTimer?.cancel();
    textController.dispose();
    scrollController.dispose();
    focusNode.dispose();
    super.dispose();
  }
}

class _Snapshot {
  _Snapshot(this.text, this.cursor);

  final String text;
  final int cursor;
}
