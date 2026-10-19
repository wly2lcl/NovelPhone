import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/security/screen_protection.dart';
import '../data/data_providers.dart';
import '../features/settings/app_lock_controller.dart';

/// 把「截屏保护」设置同步到原生窗口（ENH-26）：
/// 冷启动应用一次，设置页变更后经 Provider 立即生效。
class ScreenProtectionHost extends ConsumerStatefulWidget {
  const ScreenProtectionHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ScreenProtectionHost> createState() =>
      _ScreenProtectionHostState();
}

class _ScreenProtectionHostState extends ConsumerState<ScreenProtectionHost> {
  @override
  void initState() {
    super.initState();
    _applyInitial();
  }

  Future<void> _applyInitial() async {
    final enabled = await ref
        .read(settingsRepositoryProvider)
        .screenProtectionEnabled();
    if (!mounted) return;
    await ScreenProtection.setEnabled(enabled);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(screenProtectionEnabledProvider, (previous, next) {
      final enabled = next.value;
      if (enabled == null || enabled == previous?.value) return;
      ScreenProtection.setEnabled(enabled);
    });
    return widget.child;
  }
}
