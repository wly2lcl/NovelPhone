/// AI 网络超时（ENH-23）：连接阶段与流式空闲阶段的默认上限。
library;

const Duration aiConnectTimeout = Duration(seconds: 30);

/// 两段数据之间允许的最长静默时间；心跳帧会重置计时。
const Duration aiStreamIdleTimeout = Duration(seconds: 90);
