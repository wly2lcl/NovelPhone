import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/core/exporter/backup_archive.dart';
import 'package:novelphone/data/repositories/backup_repository.dart';

/// M2-10 / M2-11：备份 zip 组装与解析。
void main() {
  final data = <String, dynamic>{
    'format': kBackupFormat,
    'version': kBackupFormatVersion,
    'schemaVersion': 1,
    'tables': <String, dynamic>{'works': <dynamic>[]},
  };

  test('组装后可解析回 data.json', () {
    final bytes = buildBackupZip(
      data: data,
      workMarkdowns: <String, String>{'works/长夜行.md': '# 第一章\n\n正文\n'},
    );

    final parsed = parseBackupZip(bytes);

    expect(parsed['format'], kBackupFormat);
    expect(parsed['tables'], isA<Map>());
  });

  test('缺少 data.json 的 zip 被拒绝', () {
    final bytes = ZipEncoder().encodeBytes(
      Archive()..add(ArchiveFile.string('works/长夜行.md', '# 第一章\n')),
    );

    expect(() => parseBackupZip(bytes), throwsA(isA<FormatException>()));
  });

  test('非 NovelPhone 备份格式被拒绝', () {
    final bytes = buildBackupZip(
      data: <String, dynamic>{'format': 'other', 'tables': <String, dynamic>{}},
      workMarkdowns: const <String, String>{},
    );

    expect(() => parseBackupZip(bytes), throwsA(isA<FormatException>()));
  });
}