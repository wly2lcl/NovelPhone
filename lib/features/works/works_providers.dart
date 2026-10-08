import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/data_providers.dart';
import '../../data/db.dart';

/// 作品列表（响应式：数据库变化自动刷新）。
final worksProvider = StreamProvider<List<Work>>(
  (ref) => ref.watch(workRepositoryProvider).watchWorks(),
);