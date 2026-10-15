import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/exporter/share_export.dart';
import '../../core/exporter/text_exporter.dart';
import '../../data/data_providers.dart';
import '../../data/db.dart';

/// 导出格式（PRD 功能 12）。
enum ExportFormat { txt, markdown, docx, epub }

extension on ExportFormat {
  String get label => switch (this) {
        ExportFormat.txt => '纯文本（.txt）',
        ExportFormat.markdown => 'Markdown（.md）',
        ExportFormat.docx => 'Word 文档（.docx）',
        ExportFormat.epub => 'EPUB 电子书（.epub）',
      };
}

/// 单章导出（M2-08）：分享 txt 或 markdown。
Future<void> exportChapter(
  BuildContext context,
  WidgetRef ref,
  Chapter chapter,
) async {
  final format = await _pickFormat(
    context,
    const <ExportFormat>[ExportFormat.txt, ExportFormat.markdown],
    title: '导出本章',
  );
  if (format == null) return;
  final draft = ExportChapter(title: chapter.title, content: chapter.content);
  final name = safeExportFileName(
    chapter.title.isEmpty ? '未命名章节' : chapter.title,
    format == ExportFormat.txt ? 'txt' : 'md',
  );
  final bytes = textToBytes(format == ExportFormat.txt
      ? buildChapterText(draft)
      : buildChapterMarkdown(draft));
  if (!context.mounted) return;
  await _share(context, fileName: name, bytes: bytes, title: '导出章节');
}

/// 整作导出（M2-09）：txt / markdown / docx，正文 + 章节结构。
Future<void> exportWork(
  BuildContext context,
  WidgetRef ref,
  int workId,
) async {
  final format = await _pickFormat(context, ExportFormat.values, title: '导出作品');
  if (format == null) return;
  final work = await ref.read(workRepositoryProvider).getWork(workId);
  final chapters =
      await ref.read(chapterRepositoryProvider).watchChapters(workId).first;
  if (!context.mounted) return;
  if (chapters.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('这部作品还没有章节，暂无可导出的内容')),
    );
    return;
  }
  final drafts = <ExportChapter>[
    for (final chapter in chapters)
      ExportChapter(title: chapter.title, content: chapter.content),
  ];
  final title = work?.title ?? '作品';
  final bytes = switch (format) {
    ExportFormat.txt => textToBytes(buildWorkText(drafts)),
    ExportFormat.markdown => textToBytes(buildWorkMarkdown(drafts)),
    // ENH-14：docx / epub 需逐章拼 XML 并 zip 压缩，大作品同步构建会卡住 UI，
    // 移入 isolate 执行（入参为纯数据，可安全跨 isolate）。
    ExportFormat.docx => await Isolate.run(() => buildWorkDocx(drafts)),
    ExportFormat.epub =>
      await Isolate.run(() => buildWorkEpub(drafts, title: title)),
  };
  final extension = switch (format) {
    ExportFormat.txt => 'txt',
    ExportFormat.markdown => 'md',
    ExportFormat.docx => 'docx',
    ExportFormat.epub => 'epub',
  };
  if (!context.mounted) return;
  await _share(
    context,
    fileName: safeExportFileName(title, extension),
    bytes: bytes,
    title: title,
  );
}

Future<ExportFormat?> _pickFormat(
  BuildContext context,
  List<ExportFormat> formats, {
  required String title,
}) {
  return showModalBottomSheet<ExportFormat>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(title,
                  style: Theme.of(sheetContext).textTheme.titleMedium),
            ),
          ),
          for (final format in formats)
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(format.label),
              onTap: () => Navigator.of(sheetContext).pop(format),
            ),
        ],
      ),
    ),
  );
}

Future<void> _share(
  BuildContext context, {
  required String fileName,
  required Uint8List bytes,
  required String title,
}) async {
  try {
    await shareExport(fileName: fileName, bytes: bytes, title: title);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('导出失败：$e')),
    );
  }
}