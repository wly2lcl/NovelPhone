import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 导出文件名的安全化处理（去掉路径分隔符与非法字符）。
String safeExportFileName(String base, String extension) {
  final cleaned = base.replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
  final name = cleaned.isEmpty ? 'novelphone' : cleaned;
  return '$name.$extension';
}

/// 按扩展名推断 MIME 类型（分享面板用于让接收方正确识别）。
String mimeTypeForFileName(String fileName) {
  switch (p.extension(fileName).toLowerCase()) {
    case '.txt':
      return 'text/plain';
    case '.md':
      return 'text/markdown';
    case '.docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    case '.epub':
      return 'application/epub+zip';
    case '.zip':
      return 'application/zip';
    default:
      return 'application/octet-stream';
  }
}

/// 把导出内容写入临时文件并唤起系统分享面板（M2-08 / M2-09 / M2-10）。
Future<void> shareExport({
  required String fileName,
  required Uint8List bytes,
  String? title,
}) async {
  final dir = await getTemporaryDirectory();
  final file = File(p.join(dir.path, fileName));
  await file.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(
    ShareParams(
      files: <XFile>[XFile(file.path, mimeType: mimeTypeForFileName(fileName))],
      title: title,
    ),
  );
}
