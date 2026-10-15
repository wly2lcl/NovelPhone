import 'dart:isolate';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../app/theme.dart';
import '../../core/importer/chapter_splitter.dart';
import '../../core/importer/docx_parser.dart';
import '../../core/importer/import_archive.dart';
import '../../core/importer/text_encoding.dart';
import '../../data/data_providers.dart';
import '../../data/repositories/chapter_repository.dart';

/// 导入上限（M2-12）：超过 10MB 的文件提示改用其他方式。
const int kMaxImportBytes = 10 * 1024 * 1024;

/// txt / docx 导入页（PRD 功能 11）：选文件 → 解析分章 → 预览调整 → 确认写入。
class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key, required this.workId});

  final int workId;

  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage> {
  String? _fileName;
  Uint8List? _bytes;
  List<ChapterDraft> _drafts = const <ChapterDraft>[];
  String? _encoding;
  String? _error;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('导入文稿')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          if (_error != null) _ErrorBanner(message: _error!),
          if (_drafts.isEmpty) const _PickHint() else ...<Widget>[
            _FileSummary(
              fileName: _fileName!,
              encoding: _encoding,
              chapterCount: _drafts.length,
              totalWords:
                  _drafts.fold<int>(0, (sum, d) => sum + d.wordCount),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _drafts.length; i++)
              _DraftTile(
                index: i,
                draft: _drafts[i],
                onMerge: i == 0
                    ? null
                    : () => setState(() {
                          _drafts = mergeWithPrevious(_drafts, i);
                        }),
              ),
          ],
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pickFile,
            icon: const Icon(Icons.folder_open),
            label: Text(_drafts.isEmpty ? '选择 txt / docx 文件' : '重新选择文件'),
          ),
          if (_drafts.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _confirmImport,
              icon: const Icon(Icons.download_done),
              label: Text('确认导入 ${_drafts.length} 章'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const <String>['txt', 'docx'],
      );
      if (file == null) return;
      final fileName = file.name;
      final bytes = await file.readAsBytes();
      if (bytes.length > kMaxImportBytes) {
        setState(() =>
            _error = '文件超过 10MB 上限，请先在电脑上拆分后再导入');
        return;
      }
      final parsed = await parseImportFileAsync(fileName, bytes);
      setState(() {
        _fileName = fileName;
        _bytes = bytes;
        _drafts = parsed.drafts;
        _encoding = parsed.encoding;
        if (_drafts.isEmpty) _error = '没有解析到正文内容，请确认文件格式';
      });
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '解析失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmImport() async {
    var drafts = _drafts;
    final emptyCount = drafts.where((d) => d.wordCount == 0).length;
    if (emptyCount > 0) {
      final keep = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('存在空章节'),
          content: Text('有 $emptyCount 章没有正文。保留这些空章节吗？'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('全部保留'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('丢弃空章节'),
            ),
          ],
        ),
      );
      if (keep == null) return;
      if (!keep) {
        drafts = drafts.where((d) => d.wordCount > 0).toList(growable: false);
      }
    }
    if (drafts.isEmpty) {
      setState(() => _error = '没有可导入的章节');
      return;
    }

    setState(() => _busy = true);
    final volumeName = p.basenameWithoutExtension(_fileName!);
    final count = await ref.read(chapterRepositoryProvider).importChapters(
          workId: widget.workId,
          volumeName: volumeName,
          drafts: drafts
              .map((d) =>
                  ChapterImportDraft(title: d.title, content: d.content))
              .toList(growable: false),
        );
    // 原始文件留档失败不阻断导入结果。
    try {
      await archiveImportedFile(
        workId: widget.workId,
        fileName: _fileName!,
        bytes: _bytes!,
      );
    } catch (_) {
      // 忽略：留档仅作备份用途。
    }
    if (!mounted) return;
    Navigator.of(context).pop(count);
  }
}

/// 在独立 isolate 中解析导入文件（ENH-12）：只接受可安全跨 isolate 传递的
/// String / Uint8List 参数，调用方无法把平台对象（如文件选择器返回值）带进闭包
/// ——否则会抛「Illegal argument in isolate message: object is unsendable」。
@visibleForTesting
Future<ParseResult> parseImportFileAsync(String fileName, Uint8List bytes) =>
    Isolate.run(() => parseImportFile(fileName, bytes));

/// 解析导入文件（ENH-12）：编码探测 / 正则分章 / docx 解析都是同步整文计算，
/// 10MB 上限内的文件会把 UI 线程卡住，放到独立 isolate 执行。
@visibleForTesting
ParseResult parseImportFile(String fileName, Uint8List bytes) {
  final fallbackTitle = p.basenameWithoutExtension(fileName);
  if (fileName.toLowerCase().endsWith('.docx')) {
    return ParseResult(
      drafts: parseDocx(bytes, fallbackTitle: fallbackTitle),
      encoding: 'docx',
    );
  }
  final decoded = decodeTextBytes(bytes);
  return ParseResult(
    drafts: splitIntoChapters(decoded.text, fallbackTitle: fallbackTitle),
    encoding: decoded.encoding,
  );
}

/// 解析结果（ENH-12：解析函数与 isolate 一起使用，故为公开类型以便单测覆盖）。
class ParseResult {
  const ParseResult({required this.drafts, required this.encoding});

  final List<ChapterDraft> drafts;
  final String encoding;
}

class _PickHint extends StatelessWidget {
  const _PickHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: <Widget>[
          Icon(Icons.upload_file_outlined,
              size: 64, color: context.paper.inkSoft),
          const SizedBox(height: 12),
          Text('导入旧稿', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            '支持 txt（UTF-8 / GBK）与 docx。导入后按「第 X 章」等标题自动分章，'
            '可在下一步预览并调整。',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.paper.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFB3261E).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.error_outline, color: Color(0xFFB3261E), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: Color(0xFFB3261E), fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _FileSummary extends StatelessWidget {
  const _FileSummary({
    required this.fileName,
    required this.encoding,
    required this.chapterCount,
    required this.totalWords,
  });

  final String fileName;
  final String? encoding;
  final int chapterCount;
  final int totalWords;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(Icons.description_outlined,
            color: context.paper.accent),
        title: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '编码 $encoding · $chapterCount 章 · 共 $totalWords 字',
          style: TextStyle(color: context.paper.inkSoft, fontSize: 13),
        ),
      ),
    );
  }
}

class _DraftTile extends StatelessWidget {
  const _DraftTile({
    required this.index,
    required this.draft,
    required this.onMerge,
  });

  final int index;
  final ChapterDraft draft;
  final VoidCallback? onMerge;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Text('${index + 1}',
          style: TextStyle(color: context.paper.inkSoft)),
      title: Text(
        draft.title.isEmpty ? '未命名章节' : draft.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text('${draft.wordCount} 字',
          style: TextStyle(color: context.paper.inkSoft, fontSize: 12)),
      trailing: onMerge == null
          ? null
          : TextButton(
              onPressed: onMerge,
              child: const Text('并入上一章'),
            ),
    );
  }
}