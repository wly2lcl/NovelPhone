# Flutter 引擎与插件以反射方式加载，R8 不得裁剪或重命名。
# 其余插件（share_plus / file_picker / flutter_secure_storage 等）随包携带 consumer rules，
# 无需在此重复声明。变更插件后如出现 release 专属崩溃，优先在此追加 keep。
-keep class io.flutter.** { *; }

# 引擎的 PlayStoreDeferredComponentManager 引用 Play Core（延迟组件，本应用未使用），
# 该依赖不随包分发；R8 full mode 下缺类会使 minifyReleaseWithR8 直接失败。
-dontwarn com.google.android.play.core.**
