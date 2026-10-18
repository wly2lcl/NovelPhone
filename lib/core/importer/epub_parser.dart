import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import 'chapter_splitter.dart';
import 'html_entities.dart';
import 'text_encoding.dart';

/// EPUB 导入：按 OPF spine 顺序读取 XHTML，提取正文与标题后分章。
/// 目录页（nav）会被跳过；单个 XHTML 内含多个章节标题时继续按标题拆分。
List<ChapterDraft> parseEpub(Uint8List bytes, {String fallbackTitle = ''}) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } on Object {
    throw const FormatException('不是有效的 EPUB 文件');
  }
  final files = <String, ArchiveFile>{};
  for (final file in archive.files) {
    if (file.isFile) files[_normalizePath(file.name)] = file;
  }

  final containerFile = _findFile(files, 'META-INF/container.xml');
  if (containerFile == null) {
    throw const FormatException('不是有效的 EPUB 文件（缺少 META-INF/container.xml）');
  }
  final XmlDocument container;
  try {
    container = XmlDocument.parse(
      decodeTextBytes(containerFile.readBytes()!).text,
    );
  } on Object {
    throw const FormatException('EPUB 容器信息解析失败');
  }
  String? opfPath;
  for (final element in container.descendants.whereType<XmlElement>()) {
    if (element.name.local == 'rootfile') {
      opfPath = element.getAttribute('full-path');
      if (opfPath != null && opfPath.isNotEmpty) break;
    }
  }
  if (opfPath == null || opfPath.isEmpty) {
    throw const FormatException('EPUB 缺少内容清单（OPF）');
  }
  final opfFile = _findFile(files, _normalizePath(opfPath));
  if (opfFile == null) {
    throw const FormatException('EPUB 内容清单不存在');
  }

  final XmlDocument opf;
  try {
    opf = XmlDocument.parse(decodeTextBytes(opfFile.readBytes()!).text);
  } on Object {
    throw const FormatException('EPUB 内容清单解析失败');
  }
  final opfDir = p.posix.dirname(_normalizePath(opfPath));

  final manifest = <String, ({String href, String type, String properties})>{};
  for (final item in opf.descendants.whereType<XmlElement>()) {
    if (item.name.local != 'item') continue;
    final id = item.getAttribute('id');
    final href = item.getAttribute('href');
    if (id == null || href == null || href.isEmpty) continue;
    manifest[id] = (
      href: href,
      type: item.getAttribute('media-type') ?? '',
      properties: item.getAttribute('properties') ?? '',
    );
  }

  final spine = <String>[];
  for (final ref in opf.descendants.whereType<XmlElement>()) {
    if (ref.name.local != 'itemref') continue;
    final idref = ref.getAttribute('idref');
    if (idref != null && manifest.containsKey(idref)) spine.add(idref);
  }
  if (spine.isEmpty) {
    spine.addAll(
      manifest.entries
          .where((entry) => _isHtml(entry.value.href, entry.value.type))
          .map((entry) => entry.key),
    );
  }

  final drafts = <ChapterDraft>[];
  for (final id in spine) {
    final item = manifest[id]!;
    if (item.properties.split(RegExp(r'\s+')).contains('nav')) continue;
    if (!_isHtml(item.href, item.type)) continue;
    final docPath = _resolvePath(opfDir, item.href);
    final docFile = _findFile(files, docPath);
    if (docFile == null) continue;
    final html = decodeTextBytes(docFile.readBytes()!).text;
    drafts.addAll(
      _parseDocument(
        html,
        fallbackTitle: p.posix.basenameWithoutExtension(docPath),
      ),
    );
  }

  return drafts
      .where((draft) => draft.title.isNotEmpty || draft.content.isNotEmpty)
      .toList(growable: false);
}

List<ChapterDraft> _parseDocument(
  String html, {
  required String fallbackTitle,
}) {
  var body = html;
  final bodyMatch = RegExp(
    r'<body[^>]*>([\s\S]*?)</body>',
    caseSensitive: false,
  ).firstMatch(html);
  if (bodyMatch != null) body = bodyMatch.group(1)!;

  final title = _extractHeading(body);
  var text = _htmlToText(body);
  if (title.isNotEmpty) {
    final lines = text.split('\n');
    if (lines.isNotEmpty && _cleanInline(lines.first) == title) {
      lines.removeAt(0);
      text = lines.join('\n').trim();
    }
  }
  if (text.isEmpty) return const <ChapterDraft>[];

  final parts = splitIntoChapters(text);
  if (parts.length > 1 || (parts.length == 1 && parts.first.title.isNotEmpty)) {
    return parts;
  }
  return <ChapterDraft>[
    ChapterDraft(title: _truncateTitle(title), content: text),
  ];
}

String _extractHeading(String body) {
  for (final level in <int>[1, 2, 3]) {
    final match = RegExp(
      '<h$level[^>]*>([\\s\\S]*?)</h$level>',
      caseSensitive: false,
    ).firstMatch(body);
    if (match == null) continue;
    final title = _cleanInline(match.group(1)!);
    if (title.isNotEmpty) return title;
  }
  return '';
}

String _htmlToText(String html) {
  var text = html
      .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '')
      .replaceAll(
        RegExp(
          r'<(script|style|head)[^>]*>[\s\S]*?</\1>',
          caseSensitive: false,
        ),
        '',
      )
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(
        RegExp(
          r'</(?:p|div|h[1-6]|li|tr|section|article|blockquote|pre)>',
          caseSensitive: false,
        ),
        '\n\n',
      )
      .replaceAll(RegExp(r'<[^>]+>'), '');
  text = decodeHtmlEntities(text);
  return _normalize(text);
}

String _cleanInline(String input) => _normalize(
  decodeHtmlEntities(input.replaceAll(RegExp(r'<[^>]+>'), ' ')),
).replaceAll('\n', ' ').trim();

String _normalize(String input) {
  final result = <String>[];
  for (final raw
      in input.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n')) {
    final line = raw.replaceAll(RegExp(r'[ \t\u00a0]+'), ' ').trim();
    if (line.isEmpty) {
      if (result.isNotEmpty && result.last.isNotEmpty) result.add('');
      continue;
    }
    result.add(line);
  }
  return result.join('\n').trim();
}

String _truncateTitle(String title) {
  final runes = title.runes.toList(growable: false);
  if (runes.length <= kMaxChapterTitleLength) return title;
  return String.fromCharCodes(runes.take(kMaxChapterTitleLength));
}

bool _isHtml(String href, String type) {
  final lower = href.toLowerCase();
  return type.toLowerCase().contains('xhtml') ||
      type.toLowerCase().contains('html') ||
      lower.endsWith('.xhtml') ||
      lower.endsWith('.html') ||
      lower.endsWith('.htm');
}

String _resolvePath(String baseDir, String href) {
  var raw = href.split('#').first;
  try {
    raw = Uri.decodeFull(raw);
  } on ArgumentError {
    // 保留原始路径。
  }
  if (raw.startsWith('/')) raw = raw.substring(1);
  return _normalizePath(p.posix.join(baseDir, raw));
}

String _normalizePath(String path) {
  final normalized = p.posix.normalize(path.replaceAll('\\', '/'));
  return normalized.startsWith('./') ? normalized.substring(2) : normalized;
}

ArchiveFile? _findFile(Map<String, ArchiveFile> files, String path) {
  final normalized = _normalizePath(path);
  final exact = files[normalized];
  if (exact != null) return exact;
  final lower = normalized.toLowerCase();
  for (final entry in files.entries) {
    if (entry.key.toLowerCase() == lower) return entry.value;
  }
  return null;
}
