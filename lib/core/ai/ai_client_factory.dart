import 'package:http/http.dart' as http;

import 'ai_client.dart';
import 'chat_completions_adapter.dart';
import 'messages_adapter.dart';
import 'responses_adapter.dart';
import 'retrying_ai_client.dart';

/// 协议类型（与 MODEL_GROUP.provider 的取值对应，ARCHITECTURE 5.1）。
class AiProvider {
  const AiProvider._();

  static const String openaiCompat = 'openai_compat';
  static const String anthropic = 'anthropic';
  static const String responses = 'responses';
}

/// 由一个模型组（协议类型 + baseUrl + key）构造对应的 AiClient 实例。
/// 新增端点只需在此登记，上层用例零改动（ARCHITECTURE 9 章预留）。
/// 返回实例统一包一层 [RetryingAiClient]，对 429 / 5xx 自动退避重试（ARCHITECTURE 5.2）。
AiClient buildAiClient({
  required String provider,
  required String baseUrl,
  required String apiKey,
  http.Client? httpClient,
  int maxRetries = 1,
  Duration baseDelay = const Duration(seconds: 1),
}) {
  final inner = _buildAdapter(
    provider: provider,
    baseUrl: baseUrl,
    apiKey: apiKey,
    httpClient: httpClient,
  );
  return RetryingAiClient(inner, maxRetries: maxRetries, baseDelay: baseDelay);
}

AiClient _buildAdapter({
  required String provider,
  required String baseUrl,
  required String apiKey,
  http.Client? httpClient,
}) {
  if (provider == AiProvider.anthropic) {
    return MessagesAdapter(baseUrl: baseUrl, apiKey: apiKey, client: httpClient);
  }
  if (provider == AiProvider.responses) {
    return ResponsesAdapter(baseUrl: baseUrl, apiKey: apiKey, client: httpClient);
  }
  return ChatCompletionsAdapter(baseUrl: baseUrl, apiKey: apiKey, client: httpClient);
}