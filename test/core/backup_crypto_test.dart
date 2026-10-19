import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/core/exporter/backup_crypto.dart';
import 'package:novelphone/data/repositories/backup_repository.dart';

/// ENH-26：备份密码加密（AES-256-GCM + PBKDF2）。
void main() {
  const passphrase = 'correct horse battery';
  final plain = Uint8List.fromList(
    utf8.encode('{"format":"novelphone-backup","content":"中文正文"}'),
  );

  test('加密往返一致，文件带 NPBK 魔数与版本', () async {
    final encrypted = await encryptBackupBytes(plain, passphrase);

    expect(isEncryptedBackup(encrypted), isTrue);
    expect(encrypted.length, greaterThan(plain.length));
    expect(String.fromCharCodes(encrypted.take(4)), 'NPBK');
    expect(encrypted[4], 1);
    expect(await decryptBackupBytes(encrypted, passphrase), plain);
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('每次加密使用随机 salt / nonce，密文不同', () async {
    final first = await encryptBackupBytes(plain, passphrase);
    final second = await encryptBackupBytes(plain, passphrase);

    expect(first, isNot(second));
    expect(await decryptBackupBytes(first, passphrase), plain);
    expect(await decryptBackupBytes(second, passphrase), plain);
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('密码错误与密文篡改统一报告解密失败', () async {
    final encrypted = await encryptBackupBytes(plain, passphrase);

    await expectLater(
      decryptBackupBytes(encrypted, 'wrong password'),
      throwsA(
        isA<BackupException>().having(
          (e) => e.kind,
          'kind',
          BackupErrorKind.decryptionFailed,
        ),
      ),
    );

    final tampered = Uint8List.fromList(encrypted);
    tampered[tampered.length - 1] ^= 0xFF;
    await expectLater(
      decryptBackupBytes(tampered, passphrase),
      throwsA(
        isA<BackupException>().having(
          (e) => e.kind,
          'kind',
          BackupErrorKind.decryptionFailed,
        ),
      ),
    );
  }, timeout: const Timeout(Duration(seconds: 120)));

  test('密文过短 / 版本不支持 / 非 NPBK 文件被拒绝', () async {
    await expectLater(
      decryptBackupBytes(Uint8List.fromList(<int>[1, 2, 3]), passphrase),
      throwsA(
        isA<BackupException>().having(
          (e) => e.kind,
          'kind',
          BackupErrorKind.wrongFormat,
        ),
      ),
    );

    final short = Uint8List.fromList(<int>[
      ...'NPBK'.codeUnits,
      1,
      ...List<int>.filled(20, 0),
    ]);
    await expectLater(
      decryptBackupBytes(short, passphrase),
      throwsA(
        isA<BackupException>().having(
          (e) => e.kind,
          'kind',
          BackupErrorKind.invalidFormat,
        ),
      ),
    );

    final future = Uint8List.fromList(<int>[
      ...'NPBK'.codeUnits,
      99,
      ...List<int>.filled(60, 0),
    ]);
    await expectLater(
      decryptBackupBytes(future, passphrase),
      throwsA(
        isA<BackupException>().having(
          (e) => e.kind,
          'kind',
          BackupErrorKind.invalidFormat,
        ),
      ),
    );
  });

  test('密码短于下限时拒绝加密', () async {
    await expectLater(encryptBackupBytes(plain, 'short'), throwsArgumentError);
  });

  test('明文 zip 不被识别为加密备份', () {
    expect(
      isEncryptedBackup(Uint8List.fromList(<int>[0x50, 0x4B, 0x03, 0x04])),
      isFalse,
    );
    expect(isEncryptedBackup(Uint8List(0)), isFalse);
  });
}
