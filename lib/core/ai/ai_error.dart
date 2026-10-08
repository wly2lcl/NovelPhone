import 'ai_client.dart';

/// HTTP 错误码 → 统一错误类的映射（ARCHITECTURE 5.2），两个适配器共用。
ChatError mapHttpError(int statusCode, String body) {
  if (statusCode == 401 || statusCode == 403) {
    return ChatError(
      kind: AiErrorKind.auth,
      message: '鉴权失败（$statusCode）：请到设置页检查 API Key',
      statusCode: statusCode,
    );
  }
  if (statusCode == 429) {
    return ChatError(
      kind: AiErrorKind.rateLimit,
      message: '请求过于频繁（429），请稍后重试',
      statusCode: statusCode,
    );
  }
  if (statusCode >= 500) {
    return ChatError(
      kind: AiErrorKind.server,
      message: '模型服务暂时不可用（$statusCode），请稍后重试',
      statusCode: statusCode,
    );
  }
  if (statusCode == 400 && _looksLikeContentFilter(body)) {
    return ChatError(
      kind: AiErrorKind.contentFilter,
      message: '内容被模型服务商拒绝：${_snippet(body)}',
      statusCode: statusCode,
    );
  }
  return ChatError(
    kind: AiErrorKind.badRequest,
    message: '请求失败（$statusCode）：${_snippet(body)}',
    statusCode: statusCode,
  );
}

bool _looksLikeContentFilter(String body) {
  final lower = body.toLowerCase();
  return lower.contains('content_filter') ||
      lower.contains('content policy') ||
      lower.contains('content_policy') ||
      lower.contains('safety') ||
      lower.contains('blocked') ||
      lower.contains('refusal');
}

/// 提取服务商返回的可读原因（截断，避免整段 JSON 刷屏）。
String _snippet(String body) {
  final text = body.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.isEmpty) return '无返回内容';
  return text.length > 200 ? '${text.substring(0, 200)}…' : text;
}