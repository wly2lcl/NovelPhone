/// 推理型模型可能把输出预算全部耗在推理阶段，最终没有任何可见正文。
/// 首次空正文时把输出上限翻倍重试一次；已无处可提则返回 null。
int? nextRetryMaxTokens({required int maxTokens, required int contextWindow}) {
  const hardCap = 16384;
  final contextCap = contextWindow > 0 ? contextWindow : hardCap;
  final cap = contextCap < hardCap ? contextCap : hardCap;
  final current = maxTokens > 0 ? maxTokens : 1024;
  final raised = current * 2;
  final next = raised > cap ? cap : raised;
  return next > current ? next : null;
}
