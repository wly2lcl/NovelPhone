/// 单个 AI 候选的修订版本（ENH-27.3）。
class RevisionDraft {
  const RevisionDraft({required this.text, this.instruction = ''});

  final String text;
  final String instruction;
}

/// 结果内修订历史：保留最近 [maxVersions] 版，支持切换与和上一版对比。
class AiRevisionHistory {
  AiRevisionHistory({this.maxVersions = 5});

  final int maxVersions;
  final List<RevisionDraft> _versions = <RevisionDraft>[];
  int _selected = -1;

  List<RevisionDraft> get versions =>
      List<RevisionDraft>.unmodifiable(_versions);

  int get length => _versions.length;

  int get selectedIndex => _selected;

  bool get canCompare => _selected > 0 && _selected < _versions.length;

  RevisionDraft? get selected => _selected >= 0 && _selected < _versions.length
      ? _versions[_selected]
      : null;

  RevisionDraft? get previous => canCompare ? _versions[_selected - 1] : null;

  /// 记录一版完成的草稿；与上一版完全相同则不重复入栈。
  void record(String text, {String instruction = ''}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (_versions.isNotEmpty && _versions.last.text == trimmed) {
      _selected = _versions.length - 1;
      return;
    }
    _versions.add(RevisionDraft(text: trimmed, instruction: instruction));
    while (_versions.length > maxVersions) {
      _versions.removeAt(0);
    }
    _selected = _versions.length - 1;
  }

  /// 把作者对当前版本的直接编辑写回历史，避免切换版本时丢失。
  void updateSelected(String text) {
    final current = selected;
    final trimmed = text.trim();
    if (current == null || trimmed.isEmpty) return;
    _versions[_selected] = RevisionDraft(
      text: trimmed,
      instruction: current.instruction,
    );
  }

  /// 切换到指定版本，返回该版文本；下标越界返回 null。
  String? select(int index) {
    if (index < 0 || index >= _versions.length) return null;
    _selected = index;
    return _versions[index].text;
  }

  void clear() {
    _versions.clear();
    _selected = -1;
  }
}
