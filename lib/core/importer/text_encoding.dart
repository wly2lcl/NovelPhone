import 'dart:convert';
import 'dart:typed_data';

import 'package:fast_gbk/fast_gbk.dart';

/// 解码结果：正文文本与探测到的编码（展示给作者确认）。
class DecodedText {
  const DecodedText(this.text, this.encoding);

  final String text;
  final String encoding;
}

/// 探测并解码文本字节（M2-04）：优先按 UTF-8 严格校验，失败退到 GBK。
/// 中文 txt 常见的两种编码即为 UTF-8 与 GBK，其余编码不在 MVP 范围内。
DecodedText decodeTextBytes(Uint8List bytes) {
  var data = bytes;
  // 剥离 UTF-8 BOM，避免正文首字符出现 \uFEFF。
  if (data.length >= 3 &&
      data[0] == 0xEF &&
      data[1] == 0xBB &&
      data[2] == 0xBF) {
    data = Uint8List.sublistView(data, 3);
  }
  try {
    return DecodedText(utf8.decode(data, allowMalformed: false), 'UTF-8');
  } on FormatException {
    return DecodedText(gbk.decode(data), 'GBK');
  }
}
