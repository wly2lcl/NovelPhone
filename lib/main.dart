import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/startup_maintenance.dart';
import 'features/settings/cloud_backup_auto.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      // 启动维护 + 云备份自动调度（B-08）：冷启动与回到前台时检查是否到期。
      child: StartupMaintenance(
        child: CloudBackupAutoRunner(child: NovelPhoneApp()),
      ),
    ),
  );
}
