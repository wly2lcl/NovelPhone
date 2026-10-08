import 'dart:convert';

/// 单个 SSE 事件：`data:` 字段拼接后的载荷文本。
class SseEvent {
  const SseEvent(this.data);

  final String data;
}

/// 把响应字节流解析为 SSE `data` 事件流（行缓冲 + `data:` 前缀 + 空行分隔）。
/// Chat Completions / Messages / Responses 三个端点共用该骨架，
/// 仅事件载荷映射不同（ARCHITECTURE 5.1）；`[DONE]` 由各适配器自行判定。
Stream<SseEvent> parseSse(Stream<List<int>> byteStream) async* {
  final lines = byteStream
      .transform(const Utf8Decoder(allowMalformed: true))
      .transform(const LineSplitter());
  final buffer = <String>[];
  await for (final line in lines) {
    if (line.isEmpty) {
      if (buffer.isNotEmpty) {
        yield SseEvent(buffer.join('\n'));
        buffer.clear();
      }
      continue;
    }
    if (line.startsWith(':')) continue; // 注释行 / 心跳
    if (line.startsWith('data:')) {
      buffer.add(line.substring(5).trimLeft());
    }
    // event: / id: / retry: 本轮不使用：Anthropic 的事件类型在 data JSON 的 type 字段内。
  }
  if (buffer.isNotEmpty) yield SseEvent(buffer.join('\n'));
}