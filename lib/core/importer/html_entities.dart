/// 解码 HTML / XHTML 中常见的命名实体与数字实体。
String decodeHtmlEntities(String input) {
  const named = <String, String>{
    'amp': '&',
    'lt': '<',
    'gt': '>',
    'quot': '"',
    'apos': "'",
    'nbsp': ' ',
    'mdash': '—',
    'ndash': '–',
    'hellip': '…',
    'ldquo': '“',
    'rdquo': '”',
    'lsquo': '‘',
    'rsquo': '’',
    'middot': '·',
  };
  return input.replaceAllMapped(RegExp(r'&(#x?[0-9a-fA-F]+|[a-zA-Z]+);'), (
    match,
  ) {
    final value = match.group(1)!;
    if (value.startsWith('#x') || value.startsWith('#X')) {
      final code = int.tryParse(value.substring(2), radix: 16);
      return code == null ? match.group(0)! : String.fromCharCode(code);
    }
    if (value.startsWith('#')) {
      final code = int.tryParse(value.substring(1));
      return code == null ? match.group(0)! : String.fromCharCode(code);
    }
    return named[value.toLowerCase()] ?? match.group(0)!;
  });
}
