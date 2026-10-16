import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/core/exporter/backup_archive.dart';
import 'package:novelphone/data/db.dart';
import 'package:novelphone/data/repositories/backup_repository.dart';
import 'package:novelphone/data/repositories/chapter_repository.dart';
import 'package:novelphone/data/repositories/work_repository.dart';

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

  test('整库备份在 isolate 内组装 zip，产物可解析（ENH-14）', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final works = WorkRepository(db);
    final chapters = ChapterRepository(db);
    final workId = await works.createWork(title: '长夜行');
    final chapterId = await chapters.createChapter(
      workId: workId,
      title: '第一章',
    );
    await chapters.saveChapter(
      chapterId: chapterId,
      title: '第一章',
      content: '雨下了一整夜。',
    );

    final bytes = await exportBackupZipBytes(BackupRepository(db));

    final parsed = parseBackupZip(bytes);
    expect(parsed['format'], kBackupFormat);
    expect((parsed['tables'] as Map)['chapters'], hasLength(1));

    // ENH-15：markdown 全文拼接也移入 isolate，条目名与内容都应在产物里。
    final archive = ZipDecoder().decodeBytes(bytes);
    final entry = archive.files.firstWhere(
      (f) => f.name == 'works/长夜行.md',
      orElse: () => throw StateError('缺少 markdown 条目'),
    );
    expect(utf8.decode(entry.readBytes()!), contains('雨下了一整夜。'));
  });

  test('备份 zip 在 isolate 内解析，产物与原数据一致（ENH-15）', () async {
    final bytes = buildBackupZip(
      data: data,
      workMarkdowns: <String, String>{'works/长夜行.md': '# 第一章\n'},
    );

    final parsed = await parseBackupZipAsync(bytes);

    expect(parsed['format'], kBackupFormat);
    expect(parsed['schemaVersion'], 1);
  });

  test('isolate 解析把格式错误原样抛回调用方（ENH-15）', () async {
    final bytes = ZipEncoder().encodeBytes(
      Archive()..add(ArchiveFile.string('works/长夜行.md', '# 第一章\n')),
    );

    await expectLater(
      parseBackupZipAsync(bytes),
      throwsA(isA<FormatException>()),
    );
  });
}
