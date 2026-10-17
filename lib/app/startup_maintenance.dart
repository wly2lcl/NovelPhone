import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data_providers.dart';

/// 启动维护（ENH-22）：清理回收站中超过保留期的内容。
/// 失败时静默，不打断应用启动。
class StartupMaintenance extends ConsumerStatefulWidget {
  const StartupMaintenance({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<StartupMaintenance> createState() => _StartupMaintenanceState();
}

class _StartupMaintenanceState extends ConsumerState<StartupMaintenance> {
  @override
  void initState() {
    super.initState();
    _purgeExpiredTrash();
  }

  Future<void> _purgeExpiredTrash() async {
    try {
      await ref.read(trashRepositoryProvider).purgeExpired();
    } catch (error) {
      debugPrint('Failed to purge expired trash: $error');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
