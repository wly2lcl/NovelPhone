import 'dart:async';

import 'ai_client.dart';

/// 自动重试装饰器（ARCHITECTURE 5.2）：包住任意 [AiClient]，对
/// **尚未产出任何文本增量**即失败的 429（限流）/ 5xx（服务端故障）
/// 做指数退避重试，最多 [maxRetries] 次（默认 1 次，避免弱网重复扣费）。
///
/// 一旦已向调用方吐出过 [ChatTextDelta]，说明模型已开始回答，重试会产生
/// 重复内容，故此时不再重试，直接把错误透出，交由 UI 提供手动重试。
/// 首个文本增量之前的所有 chunk（如 usage / 工具调用）先缓冲，重试时丢弃。
class RetryingAiClient implements AiClient {
  RetryingAiClient(
    this._inner, {
    this.maxRetries = 1,
    this.baseDelay = const Duration(seconds: 1),
  });

  final AiClient _inner;
  final int maxRetries;

  /// 退避基时长，第 n 次重试等待 `baseDelay * n`（1x、2x…）。
  final Duration baseDelay;

  @override
  Stream<ChatChunk> streamChat(ChatRequest req) async* {
    var attempt = 0;
    while (true) {
      final buffered = <ChatChunk>[];
      var committed = false;
      ChatError? error;

      await for (final chunk in _inner.streamChat(req)) {
        if (chunk is ChatError) {
          error = chunk;
          break;
        }
        if (chunk is ChatTextDelta) {
          if (!committed) {
            committed = true;
            for (final pending in buffered) {
              yield pending;
            }
            buffered.clear();
          }
          yield chunk;
        } else if (committed) {
          yield chunk;
        } else {
          buffered.add(chunk);
        }
      }

      if (error == null) {
        // 正常结束：吐出缓冲的 usage / 工具调用等末段内容。
        for (final pending in buffered) {
          yield pending;
        }
        return;
      }

      if (!committed && _retryable(error) && attempt < maxRetries) {
        attempt++;
        await Future<void>.delayed(baseDelay * attempt);
        continue;
      }

      yield error;
      return;
    }
  }

  bool _retryable(ChatError error) =>
      error.kind == AiErrorKind.rateLimit || error.kind == AiErrorKind.server;
}