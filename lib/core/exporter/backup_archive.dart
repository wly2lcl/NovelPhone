import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../data/repositories/backup_repository.dart';
import 'share_export.dart';
import 'text_exporter.dart';

/// 备份 zip 内的数据文件名。
const String kBackupDataEntry = 'data.json';

/// 组装整库备份 zip（M2-10）：`data.json`（全部表数据，供恢复）
/// + `works/*.md`（各作品 markdown 全文，供人工查阅）。
Uint8List buildBackupZip({
  required Map<String, dynamic> data,
  required Map<String, String> workMarkdowns,
}) {
  final archive = Archive()
    ..add(ArchiveFile.string(kBackupDataEntry, jsonEncode(data)));
  for (final entry in workMarkdowns.entries) {
    archive.add(ArchiveFile.string(entry.key, entry.value));
  }
  return ZipEncoder().encodeBytes(archive);
}

/// 作品正文的纯数据投影（可跨 isolate 传递，避免把 drift 行对象带进 isolate）。
typedef WorkMarkdownSource = ({
  String title,
  List<({String title, String content})> chapters,
});

/// 从仓储读取整库数据并组装备份 zip（B-08：本地导出与云备份共用同一份内容）。
Future<Uint8List> exportBackupZipBytes(BackupRepository repository) async {
  final data = await repository.exportData();
  final bundles = await repository.loadWorkBundles();

  // ENH-15：把作品正文收敛成纯数据记录后，「逐作品 markdown 全文拼接 +
  // jsonEncode + zip 压缩」整体移入 isolate。ENH-14 只移走了后半段，markdown
  // 拼接仍会在主线程把整库正文再扫一遍。
  final works = <WorkMarkdownSource>[
    for (final bundle in bundles)
      (
        title: bundle.title,
        chapters: [
          for (final chapter in bundle.chapters)
            (title: chapter.title, content: chapter.content),
        ],
      ),
  ];
  return Isolate.run(() => _buildBackupZip(data: data, works: works));
}

/// 在 isolate 内完成 markdown 拼接与 zip 组装（顶层函数，入参均为纯数据）。
Uint8List _buildBackupZip({
  required Map<String, dynamic> data,
  required List<WorkMarkdownSource> works,
}) {
  final markdowns = <String, String>{};
  final usedNames = <String>{};
  for (final work in works) {
    final chapters = <ExportChapter>[
      for (final chapter in work.chapters)
        ExportChapter(title: chapter.title, content: chapter.content),
    ];
    var path = 'works/${safeExportFileName(work.title, 'md')}';
    var suffix = 2;
    while (!usedNames.add(path)) {
      path = 'works/${safeExportFileName('${work.title}_$suffix', 'md')}';
      suffix++;
    }
    markdowns[path] = buildWorkMarkdown(chapters);
  }
  return buildBackupZip(data: data, workMarkdowns: markdowns);
}

/// 解析备份 zip，返回 data.json 内容（M2-11 数据校验入口之一）。
Map<String, dynamic> parseBackupZip(Uint8List bytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } on Exception {
    throw const FormatException('文件不是有效的 zip 备份');
  }
  ArchiveFile? dataEntry;
  for (final file in archive.files) {
    if (file.isFile && file.name == kBackupDataEntry) {
      dataEntry = file;
      break;
    }
  }
  final raw = dataEntry?.readBytes();
  if (raw == null) {
    throw const FormatException('备份文件缺少 $kBackupDataEntry');
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(raw));
  } on FormatException {
    throw const FormatException('备份内容解析失败');
  }
  if (decoded is! Map) {
    throw const FormatException('备份内容格式不正确');
  }
  final result = decoded.cast<String, dynamic>();
  if (result['format'] != kBackupFormat) {
    throw const FormatException('不是 NovelPhone 的备份文件');
  }
  return result;
}

/// [parseBackupZip] 的异步版本（ENH-15）：解压 + utf8 解码 + jsonDecode 是恢复
/// 整库备份的主要 CPU 开销，放到独立 isolate 执行，避免恢复大备份时卡住 UI。
/// 入参 Uint8List 与返回的 JSON Map 均为可跨 isolate 的纯数据；
/// [FormatException] 会被原样抛回调用方。
Future<Map<String, dynamic>> parseBackupZipAsync(Uint8List bytes) {
  return Isolate.run(() => parseBackupZip(bytes));
}