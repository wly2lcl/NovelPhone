import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 把导入的原始文件复制到应用私有目录留档（PRD 功能 11：导入后保留原始文件备份）。
/// 留档文件不参与写作与 AI，仅供作者回溯原始素材。
Future<String> archiveImportedFile({
  required int workId,
  required String fileName,
  required Uint8List bytes,
}) async {
  final dir = await getApplicationSupportDirectory();
  final target = Directory(p.join(dir.path, 'imports', 'work_$workId'));
  if (!await target.exists()) {
    await target.create(recursive: true);
  }
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final file = File(p.join(target.path, '${stamp}_${_safeFileName(fileName)}'));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

String _safeFileName(String name) {
  final base = p.basename(name).replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  return base.isEmpty ? 'import.txt' : base;
}
