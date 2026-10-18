import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/core/ai/empty_output_retry.dart';

void main() {
  test('重试上限翻倍，并以 16384 与上下文窗口封顶', () {
    expect(nextRetryMaxTokens(maxTokens: 4096, contextWindow: 32000), 8192);
    expect(nextRetryMaxTokens(maxTokens: 12000, contextWindow: 32000), 16384);
    expect(nextRetryMaxTokens(maxTokens: 8192, contextWindow: 12000), 12000);
    expect(nextRetryMaxTokens(maxTokens: 16384, contextWindow: 32000), isNull);
    expect(nextRetryMaxTokens(maxTokens: 1024, contextWindow: 0), 2048);
    expect(nextRetryMaxTokens(maxTokens: 0, contextWindow: 4096), 2048);
  });
}
