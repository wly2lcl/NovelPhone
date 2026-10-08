import 'dart:convert';
import 'dart:typed_data';

import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/core/importer/text_encoding.dart';

void main() {
  test('UTF-8 文本按 UTF-8 解码', () {
    final bytes = Uint8List.fromList(utf8.encode('第一章 落雪'));
    final decoded = decodeTextBytes(bytes);
    expect(decoded.encoding, 'UTF-8');
    expect(decoded.text, '第一章 落雪');
  });

  test('剥离 UTF-8 BOM', () {
    final bytes = Uint8List.fromList(<int>[
      0xEF, 0xBB, 0xBF,
      ...utf8.encode('正文'),
    ]);
    final decoded = decodeTextBytes(bytes);
    expect(decoded.text, '正文');
  });

  test('GBK 字节退到 GBK 解码', () {
    final bytes = Uint8List.fromList(gbk.encode('第一章 落雪'));
    final decoded = decodeTextBytes(bytes);
    expect(decoded.encoding, 'GBK');
    expect(decoded.text, '第一章 落雪');
  });
}