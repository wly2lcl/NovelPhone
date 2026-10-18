import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/app_lock_controller.dart';
import '../l10n/l10n.dart';
import 'theme.dart';

/// 应用锁宿主（ENH-25）：启动与回到前台时用系统生物识别 / 设备凭证解锁。
/// 锁定期间保留原导航树，仅以覆盖层遮挡，避免解锁后丢失编辑位置。
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  bool _started = false;
  String _reason = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reason = context.l10n.appLockReason;
    _initialize();
  }

  Future<void> _initialize() async {
    final controller = ref.read(appLockControllerProvider);
    await controller.initialize();
    if (!mounted) return;
    if (controller.locked) {
      FocusManager.instance.primaryFocus?.unfocus();
      WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(appLockControllerProvider);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      controller.onBackground();
      return;
    }
    if (state != AppLifecycleState.resumed) return;
    if (controller.busy) return;
    if (!controller.consumePendingLock()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (!mounted) return;
    await ref.read(appLockControllerProvider).unlock(reason: _reason);
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appLockControllerProvider);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final hidden = !controller.initialized || controller.locked;
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Offstage(
              offstage: hidden,
              child: TickerMode(enabled: !hidden, child: widget.child),
            ),
            if (!controller.initialized) const _LockLoadingScreen(),
            if (controller.initialized && controller.locked)
              AppLockScreen(
                busy: controller.busy,
                failed: controller.lastAuthFailed,
                onUnlock: _unlock,
              ),
          ],
        );
      },
    );
  }
}

class _LockLoadingScreen extends StatelessWidget {
  const _LockLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.paper.background,
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class AppLockScreen extends StatelessWidget {
  const AppLockScreen({
    super.key,
    required this.busy,
    required this.failed,
    required this.onUnlock,
  });

  final bool busy;
  final bool failed;
  final Future<void> Function() onUnlock;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: context.paper.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.lock_outline,
                    size: 56,
                    color: context.paper.accent,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.appLockTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    failed ? l10n.appLockFailed : l10n.appLockMessage,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: failed
                          ? Theme.of(context).colorScheme.error
                          : context.paper.inkSoft,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: busy ? null : () => onUnlock(),
                    icon: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.fingerprint),
                    label: Text(l10n.appLockUnlock),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
