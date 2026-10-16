/// 段落级文本 Diff（快照对比，ENH-18）：公共前后缀裁剪 + LCS 对齐。
library;

import 'dart:typed_data';

enum DiffKind { same, added, removed }

class DiffLine {
  const DiffLine(this.kind, this.text);

  final DiffKind kind;
  final String text;
}

/// 段落级 LCS diff。[oldText] 为快照内容（基线），[newText] 为当前内容：
/// added = 当前新增的段落，removed = 快照中存在但当前已删除的段落。
List<DiffLine> diffParagraphs(String oldText, String newText) {
  final oldLines = oldText.isEmpty ? const <String>[] : oldText.split('\n');
  final newLines = newText.isEmpty ? const <String>[] : newText.split('\n');

  // 裁剪公共前后缀，把 LCS 规模压到实际改动附近。
  var start = 0;
  final maxPrefix = oldLines.length < newLines.length
      ? oldLines.length
      : newLines.length;
  while (start < maxPrefix && oldLines[start] == newLines[start]) {
    start++;
  }
  var endOld = oldLines.length;
  var endNew = newLines.length;
  while (endOld > start &&
      endNew > start &&
      oldLines[endOld - 1] == newLines[endNew - 1]) {
    endOld--;
    endNew--;
  }

  final result = <DiffLine>[];
  for (var i = 0; i < start; i++) {
    result.add(DiffLine(DiffKind.same, oldLines[i]));
  }
  _diffMiddle(
    oldLines.sublist(start, endOld),
    newLines.sublist(start, endNew),
    result,
  );
  for (var i = endOld; i < oldLines.length; i++) {
    result.add(DiffLine(DiffKind.same, oldLines[i]));
  }
  return result;
}

void _diffMiddle(List<String> a, List<String> b, List<DiffLine> out) {
  final n = a.length;
  final m = b.length;
  if (n == 0) {
    for (final line in b) {
      out.add(DiffLine(DiffKind.added, line));
    }
    return;
  }
  if (m == 0) {
    for (final line in a) {
      out.add(DiffLine(DiffKind.removed, line));
    }
    return;
  }
  // 整章重写等极端场景：不做逐行对齐，直接整块删 + 整块增，避免 O(n·m) 爆炸。
  if (n * m > 2000000) {
    for (final line in a) {
      out.add(DiffLine(DiffKind.removed, line));
    }
    for (final line in b) {
      out.add(DiffLine(DiffKind.added, line));
    }
    return;
  }

  final width = m + 1;
  final lcs = Int32List((n + 1) * width);
  for (var i = n - 1; i >= 0; i--) {
    final row = i * width;
    final nextRow = row + width;
    for (var j = m - 1; j >= 0; j--) {
      lcs[row + j] = a[i] == b[j]
          ? lcs[nextRow + j + 1] + 1
          : (lcs[nextRow + j] >= lcs[row + j + 1]
                ? lcs[nextRow + j]
                : lcs[row + j + 1]);
    }
  }

  var i = 0;
  var j = 0;
  while (i < n && j < m) {
    if (a[i] == b[j]) {
      out.add(DiffLine(DiffKind.same, a[i]));
      i++;
      j++;
    } else if (lcs[(i + 1) * width + j] >= lcs[i * width + j + 1]) {
      out.add(DiffLine(DiffKind.removed, a[i]));
      i++;
    } else {
      out.add(DiffLine(DiffKind.added, b[j]));
      j++;
    }
  }
  while (i < n) {
    out.add(DiffLine(DiffKind.removed, a[i]));
    i++;
  }
  while (j < m) {
    out.add(DiffLine(DiffKind.added, b[j]));
    j++;
  }
}
