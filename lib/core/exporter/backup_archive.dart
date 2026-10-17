import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

import '../../data/repositories/backup_repository.dart';
import 'share_export.dart';
import 'text_exporter.dart';

/// 备份 zip 内的数据文件名。
const String kBackupDataEntry = 'data.json';

/// 备份 zip 内的校验清单元数据名（ENH-22）。
const String kBackupManifestEntry = 'manifest.json';

/// 组装整库备份 zip（M2-10）：`data.json`（全部表数据，供恢复）
/// + `manifest.json`（SHA-256 校验信息）
/// + `works/*.md`（各作品 markdown 全文，供人工查阅）。
Uint8List buildBackupZip({
  required Map<String, dynamic> data,
  required Map<String, String> workMarkdowns,
}) {
  final dataBytes = utf8.encode(jsonEncode(data));
  final manifest = <String, dynamic>{
    'format': kBackupFormat,
    'version': kBackupFormatVersion,
    'schemaVersion': data['schemaVersion'],
    'exportedAt': data['exportedAt'],
    'dataEntry': kBackupDataEntry,
    'dataSize': dataBytes.length,
    'dataSha256': sha256.convert(dataBytes).toString(),
  };
  final archive = Archive()
    ..add(ArchiveFile(kBackupDataEntry, dataBytes.length, dataBytes))
    ..add(ArchiveFile.string(kBackupManifestEntry, jsonEncode(manifest)));
  for (final entry in workMarkdowns.entries) {
    archive.add(ArchiveFile.string(entry.key, entry.value));
  }
  return ZipEncoder().encodeBytes(archive);
}

/// 恢复前预览所需的备份元信息（ENH-22）。
class BackupPreview {
  const BackupPreview({
    required this.checksumVerified,
    this.exportedAt,
    this.schemaVersion,
    this.works = 0,
    this.chapters = 0,
    this.characters = 0,
  });

  /// 是否包含 manifest 且 SHA-256 校验通过；旧版备份无 manifest 为 false。
  final bool checksumVerified;
  final DateTime? exportedAt;
  final int? schemaVersion;
  final int works;
  final int chapters;
  final int characters;

  factory BackupPreview.fromData(
    Map<String, dynamic> data, {
    required bool checksumVerified,
  }) {
    final tables = data['tables'];
    final tableMap = tables is Map ? tables : const <String, dynamic>{};
    int count(String name) {
      final rows = tableMap[name];
      return rows is List ? rows.length : 0;
    }

    final rawExportedAt = data['exportedAt'];
    final rawSchemaVersion = data['schemaVersion'];
    return BackupPreview(
      checksumVerified: checksumVerified,
      exportedAt: rawExportedAt is String
          ? DateTime.tryParse(rawExportedAt)
          : null,
      schemaVersion: rawSchemaVersion is int ? rawSchemaVersion : null,
      works: count('works'),
      chapters: count('chapters'),
      characters: count('characters'),
    );
  }
}

/// 解析后的备份：数据与校验状态（ENH-22）。
class ParsedBackup {
  const ParsedBackup({required this.data, required this.preview});

  final Map<String, dynamic> data;
  final BackupPreview preview;
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
/// 含 manifest 时校验 SHA-256；旧版备份无 manifest 仍可恢复。
Map<String, dynamic> parseBackupZip(Uint8List bytes) =>
    inspectBackupZip(bytes).data;

/// 解析备份 zip 并校验完整性（ENH-22）：恢复前预览使用。
ParsedBackup inspectBackupZip(Uint8List bytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } on Exception {
    throw const BackupException(BackupErrorKind.invalidZip, '文件不是有效的 zip 备份');
  }
  ArchiveFile? dataEntry;
  ArchiveFile? manifestEntry;
  for (final file in archive.files) {
    if (!file.isFile) continue;
    if (file.name == kBackupDataEntry) dataEntry = file;
    if (file.name == kBackupManifestEntry) manifestEntry = file;
  }
  final raw = dataEntry?.readBytes();
  if (raw == null) {
    throw const BackupException(
      BackupErrorKind.missingDataEntry,
      '备份文件缺少 $kBackupDataEntry',
      detail: kBackupDataEntry,
    );
  }
  final checksumVerified = manifestEntry == null
      ? false
      : _verifyChecksum(manifestEntry, raw);
  final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(raw));
  } on FormatException {
    throw const BackupException(BackupErrorKind.decodeFailed, '备份内容解析失败');
  }
  if (decoded is! Map) {
    throw const BackupException(BackupErrorKind.invalidFormat, '备份内容格式不正确');
  }
  final result = decoded.cast<String, dynamic>();
  if (result['format'] != kBackupFormat) {
    throw const BackupException(
      BackupErrorKind.wrongFormat,
      '不是 NovelPhone 的备份文件',
    );
  }
  return ParsedBackup(
    data: result,
    preview: BackupPreview.fromData(result, checksumVerified: checksumVerified),
  );
}

/// 校验 manifest 中的 SHA-256；清单损坏或摘要不匹配都视为文件损坏。
bool _verifyChecksum(ArchiveFile manifestEntry, List<int> dataBytes) {
  Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(manifestEntry.readBytes() ?? const []));
  } on FormatException {
    decoded = null;
  }
  final expected = decoded is Map ? decoded['dataSha256'] : null;
  if (expected is! String || expected.isEmpty) {
    throw const BackupException(
      BackupErrorKind.checksumMismatch,
      '备份文件校验失败，内容可能已损坏',
    );
  }
  final actual = sha256.convert(dataBytes).toString();
  if (actual != expected.toLowerCase()) {
    throw const BackupException(
      BackupErrorKind.checksumMismatch,
      '备份文件校验失败，内容可能已损坏',
    );
  }
  return true;
}

/// [parseBackupZip] 的异步版本（ENH-15）：解压 + utf8 解码 + jsonDecode 是恢复
/// 整库备份的主要 CPU 开销，放到独立 isolate 执行，避免恢复大备份时卡住 UI。
/// 入参 Uint8List 与返回的 JSON Map 均为可跨 isolate 的纯数据；
/// [FormatException] 会被原样抛回调用方。
Future<Map<String, dynamic>> parseBackupZipAsync(Uint8List bytes) async {
  return (await inspectBackupZipAsync(bytes)).data;
}

/// [inspectBackupZip] 的异步版本（ENH-22）：连带校验与预览信息一起返回。
Future<ParsedBackup> inspectBackupZipAsync(Uint8List bytes) {
  return Isolate.run(() => inspectBackupZip(bytes));
}
