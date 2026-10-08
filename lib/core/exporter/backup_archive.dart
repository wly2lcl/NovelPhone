import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../data/repositories/backup_repository.dart';

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