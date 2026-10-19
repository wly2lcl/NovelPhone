import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../data/repositories/backup_repository.dart';

/// 加密备份文件扩展名（ENH-26）。
const String kEncryptedBackupExtension = 'npbak';

/// 密码最短长度：太短的密码无法抵抗离线穷举。
const int kMinBackupPassphraseLength = 8;

/// PBKDF2-HMAC-SHA256 迭代次数（OWASP 2023 对 SHA-256 的建议下限）。
const int kBackupKdfIterations = 210000;

const int _magicLength = 4;
const List<int> _magic = <int>[0x4E, 0x50, 0x42, 0x4B]; // "NPBK"
const int _version = 1;
const int _saltLength = 16;
const int _nonceLength = 12;
const int _macLength = 16;
const int _headerLength =
    _magicLength + 1 + _saltLength + _nonceLength + _macLength;

/// 文件是否为 NovelPhone 加密备份（只看魔数，便于选择解密流程）。
bool isEncryptedBackup(List<int> bytes) {
  if (bytes.length < _magicLength) return false;
  for (var i = 0; i < _magicLength; i++) {
    if (bytes[i] != _magic[i]) return false;
  }
  return true;
}

/// 加密备份：`NPBK` + 版本 + salt + nonce + MAC + AES-256-GCM 密文。
/// 密码经 PBKDF2 派生，密码本身不写入文件，也不落库。
Future<Uint8List> encryptBackupBytes(
  Uint8List plainBytes,
  String passphrase,
) async {
  if (passphrase.length < kMinBackupPassphraseLength) {
    throw ArgumentError.value(
      passphrase.length,
      'passphrase',
      '至少 $kMinBackupPassphraseLength 位',
    );
  }
  final random = Random.secure();
  final salt = Uint8List.fromList(
    List<int>.generate(_saltLength, (_) => random.nextInt(256)),
  );
  final nonce = Uint8List.fromList(
    List<int>.generate(_nonceLength, (_) => random.nextInt(256)),
  );
  final key = await _pbkdf2.deriveKeyFromPassword(
    password: passphrase,
    nonce: salt,
  );
  final box = await _aesGcm.encrypt(plainBytes, secretKey: key, nonce: nonce);

  final builder = BytesBuilder(copy: false)
    ..add(_magic)
    ..addByte(_version)
    ..add(salt)
    ..add(box.nonce)
    ..add(box.mac.bytes)
    ..add(box.cipherText);
  return builder.toBytes();
}

/// 解密备份：失败统一抛 [BackupException]（密码错误与内容损坏不可区分，
/// 避免为攻击者提供额外信息）。
Future<Uint8List> decryptBackupBytes(
  Uint8List encrypted,
  String passphrase,
) async {
  if (!isEncryptedBackup(encrypted)) {
    throw const BackupException(
      BackupErrorKind.wrongFormat,
      '不是 NovelPhone 加密备份',
    );
  }
  if (encrypted.length <= _headerLength) {
    throw const BackupException(BackupErrorKind.invalidFormat, '加密备份内容不完整');
  }
  final version = encrypted[_magicLength];
  if (version != _version) {
    throw const BackupException(BackupErrorKind.invalidFormat, '不支持的加密备份版本');
  }
  var offset = _magicLength + 1;
  final salt = Uint8List.sublistView(encrypted, offset, offset + _saltLength);
  offset += _saltLength;
  final nonce = Uint8List.sublistView(encrypted, offset, offset + _nonceLength);
  offset += _nonceLength;
  final mac = Uint8List.sublistView(encrypted, offset, offset + _macLength);
  offset += _macLength;
  final cipherText = Uint8List.sublistView(encrypted, offset);

  final key = await _pbkdf2.deriveKeyFromPassword(
    password: passphrase,
    nonce: salt,
  );
  try {
    final plain = await _aesGcm.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
      secretKey: key,
    );
    return Uint8List.fromList(plain);
  } on SecretBoxAuthenticationError {
    throw const BackupException(
      BackupErrorKind.decryptionFailed,
      '密码错误或备份文件已损坏',
    );
  } on FormatException {
    throw const BackupException(
      BackupErrorKind.decryptionFailed,
      '密码错误或备份文件已损坏',
    );
  }
}

/// 大备份加解密放到 isolate，避免 PBKDF2 与 AES 阻塞 UI。
Future<Uint8List> encryptBackupBytesAsync(
  Uint8List plainBytes,
  String passphrase,
) => Isolate.run(() => encryptBackupBytes(plainBytes, passphrase));

Future<Uint8List> decryptBackupBytesAsync(
  Uint8List encrypted,
  String passphrase,
) => Isolate.run(() => decryptBackupBytes(encrypted, passphrase));

final AesGcm _aesGcm = AesGcm.with256bits();

final Pbkdf2 _pbkdf2 = Pbkdf2.hmacSha256(
  iterations: kBackupKdfIterations,
  bits: 256,
);
