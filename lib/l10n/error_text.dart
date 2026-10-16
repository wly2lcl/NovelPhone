/// 错误文案的「展示时本地化」（构造期 message 保持 zh 原样，展示时按 locale 重组合）。
///
/// 增量改造约定：
/// - 异常 / 错误对象保留既有 message 组合逻辑（zh 逐字一致，既有断言不受影响）；
/// - 新增结构化字段（kind / code / detail），本文件按 kind → code → detail
///   的顺序选择 l10n 文案；
/// - 类型或字段无法识别时回退原始 message / toString（信息不丢）。
library;

import '../core/ai/ai_client.dart';
import '../core/cloud/cloud_storage_client.dart';
import '../data/repositories/backup_repository.dart';
import '../features/ai/ai_service.dart';
import 'l10n.dart';

/// AI 流式错误 → 本地化文案。
String aiErrorText(AppLocalizations l10n, ChatError error) {
  final detail = error.detail;
  final status = error.statusCode;
  switch (error.kind) {
    case AiErrorKind.network:
      // '网络请求失败' 与 '流式读取中断' 共用一个 network 文案（detail 携带原始信息）。
      return detail == null ? error.message : l10n.aiErrorNetwork(detail);
    case AiErrorKind.auth:
      return status == null ? error.message : l10n.aiErrorAuth(status);
    case AiErrorKind.rateLimit:
      return l10n.aiErrorRateLimit;
    case AiErrorKind.contentFilter:
      return detail == null ? error.message : l10n.aiErrorContentFilter(detail);
    case AiErrorKind.badRequest:
      if (error.code == ChatErrorCode.providerError) {
        return detail == null
            ? error.message
            : l10n.aiErrorProviderError(detail);
      }
      if (error.code == ChatErrorCode.incompleteOutput) {
        return l10n.aiErrorIncompleteOutput;
      }
      if (status == null || detail == null) return error.message;
      return l10n.aiErrorBadRequest(status, detail);
    case AiErrorKind.server:
      if (error.code == ChatErrorCode.providerFailed) {
        return detail == null
            ? error.message
            : l10n.aiErrorProviderFailed(detail);
      }
      return status == null ? error.message : l10n.aiErrorServer(status);
    case AiErrorKind.unknown:
      if (error.code == ChatErrorCode.toolLoop) return l10n.aiErrorToolLoop;
      return error.message;
  }
}

/// AI 失败事件（[AiFailed] / [CheckDeepFailed]）→ 本地化文案。
String aiFailureText(
  AppLocalizations l10n, {
  required AiErrorKind kind,
  required String message,
  int? statusCode,
  String? code,
  String? detail,
}) {
  return aiErrorText(
    l10n,
    ChatError(
      kind: kind,
      message: message,
      statusCode: statusCode,
      code: code,
      detail: detail,
    ),
  );
}

/// 云备份存储错误 → 本地化文案。[error] 允许为任意类型（未知类型回退原始文本）；
/// 云端恢复路径可能直接抛备份格式错误（[BackupException]），按备份文案处理。
String cloudErrorText(AppLocalizations l10n, Object error) {
  if (error is BackupException) return backupErrorText(l10n, error);
  if (error is! CloudStorageException) return _fallbackText(error);
  final detail = error.detail;
  final status = error.statusCode;
  switch (error.code) {
    case CloudStorageErrorCode.endpointMissing:
      return l10n.cloudErrorEndpointMissing;
    case CloudStorageErrorCode.network:
      return detail == null ? error.message : l10n.cloudErrorNetwork(detail);
    case CloudStorageErrorCode.signatureMismatch:
      return l10n.cloudErrorSignatureMismatch;
    case CloudStorageErrorCode.forbidden:
      return l10n.cloudErrorForbidden;
    case CloudStorageErrorCode.notFound:
      return l10n.cloudErrorNotFound;
    case CloudStorageErrorCode.clockSkew:
      return l10n.cloudErrorClockSkew;
    case CloudStorageErrorCode.httpError:
      if (status == null || detail == null) return error.message;
      return l10n.cloudErrorHttp(status, detail);
    case CloudStorageErrorCode.unknown:
      return error.message;
  }
}

/// 备份文件 / 恢复错误 → 本地化文案。[error] 允许为任意类型（未知类型回退原始文本）。
String backupErrorText(AppLocalizations l10n, Object error) {
  if (error is! BackupException) return _fallbackText(error);
  final entry = error.detail;
  switch (error.kind) {
    case BackupErrorKind.invalidZip:
      return l10n.backupErrorInvalidZip;
    case BackupErrorKind.missingDataEntry:
      return entry == null
          ? error.message
          : l10n.backupErrorMissingEntry(entry);
    case BackupErrorKind.decodeFailed:
      return l10n.backupErrorDecodeFailed;
    case BackupErrorKind.invalidFormat:
      return l10n.backupErrorInvalidFormat;
    case BackupErrorKind.wrongFormat:
      return l10n.backupErrorWrongFormat;
    case BackupErrorKind.newerVersion:
      return l10n.backupErrorNewerVersion;
    case BackupErrorKind.incomplete:
      return l10n.backupErrorIncomplete;
  }
}

/// 测试连接结果 → 本地化文案。
/// 失败且携带 [TestResult.errorKind] 时与 [aiErrorText] 同源组合，
/// 保证 zh 输出与既有 message 逐字一致。
String testResultText(AppLocalizations l10n, TestResult result) {
  final detail = result.detail;
  final errorKind = result.errorKind;
  switch (result.kind) {
    case TestResultKind.ok:
      return detail == null ? l10n.modelTestOk : l10n.modelTestOkDetail(detail);
    case TestResultKind.missingModel:
      return l10n.modelTestMissingModel;
    case TestResultKind.missingApiKey:
      return l10n.modelTestMissingKey;
    case TestResultKind.failed:
      if (errorKind != null) {
        return aiFailureText(
          l10n,
          kind: errorKind,
          message: result.message,
          statusCode: result.statusCode,
          code: result.code,
          detail: detail,
        );
      }
      return detail == null
          ? l10n.modelTestFailed(result.message)
          : l10n.modelTestFailed(detail);
  }
}

/// 类型 / 字段无法识别时的回退：返回原始文本，保证信息不丢。
String _fallbackText(Object error) {
  if (error is FormatException) {
    return error.message.isEmpty ? error.toString() : error.message;
  }
  return error.toString();
}
