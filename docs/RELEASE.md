# NovelPhone 发布说明（Android / iOS 上架收口）

> 对应 ENH-24 发布收口。本文是发布操作、商店资料与风险状态的单一入口；隐私政策正文见 [PRIVACY.md](./PRIVACY.md)，数据安全与合规口径见 [COMPLIANCE.md](./COMPLIANCE.md)。

## 1. 当前产物状态

| 平台 | 产物 | 状态 |
|---|---|---|
| Android | `app-release.aab`（Google Play） | 可构建，发布签名校验通过 |
| Android | 分 ABI APK（arm64-v8a / armeabi-v7a / x86_64，侧载） | 可构建 |
| Android | 通用 APK（`flutter build apk --release`） | 可构建，仅用于调试 / 内测分发 |
| iOS | `Runner.app`（无签名 `flutter build ios --release --no-codesign`） | 可编译，用于 CI 编译校验 |
| iOS | `.ipa` / App Store 提交 | **阻塞**：缺少 Apple Developer Program 账号、发布证书与 Provisioning Profile |

版本号来源：`pubspec.yaml` 的 `version: 1.0.0+1`（`versionName 1.0.0` / `versionCode 1`）。
应用 ID：`com.novelphone.novelphone`（Android applicationId 与 iOS bundle id 一致）。
最低 / 目标 SDK：minSdk 24 / targetSdk 36（满足 Google Play 现行 targetSdk 要求）。

## 2. 构建命令

### 2.1 本地构建（需要发布签名）

`android/app/build.gradle.kts` 在 release 构建时强制读取 `android/key.properties`，缺失会直接报错。首次构建：

```bash
keytool -genkeypair -v -keystore android/upload-keystore.jks -storetype PKCS12 \
  -keyalg RSA -keysize 2048 -validity 10000 -alias novelphone
```

按以下格式写入 `android/key.properties`（两项均已被 `.gitignore` 忽略，务必离线备份，丢失将无法覆盖升级已发布应用）：

```properties
storePassword=...
keyPassword=...
keyAlias=novelphone
storeFile=upload-keystore.jks
```

```bash
flutter pub get
flutter build appbundle --release        # build/app/outputs/bundle/release/app-release.aab
flutter build apk --release --split-per-abi
# build/app/outputs/flutter-apk/app-{arm64-v8a,armeabi-v7a,x86_64}-release.apk
flutter build apk --release              # 通用 APK，内测/侧载用
```

### 2.2 CI 产物

CI（`.github/workflows/ci.yml`）的 `android-release` job 在 `main` push 或手动 `workflow_dispatch` 时构建：

- 使用 **临时生成的 CI keystore**（仅存在于该次 runner，密码随机），因此 CI 产物的签名与正式发布签名不同，**不能直接上传 Google Play**，用途是验证「release 可构建 + R8 可收缩 + AAB/APK 结构完整」。
- 上传 artifacts（保留 14 天）：
  - `novelphone-aab`：`app-release.aab`
  - `novelphone-apk`：分 ABI 三个 APK

正式上架请在本地或受控构建机用 2.1 的签名重建，并执行 `apksigner verify` / `keytool -printcert -jarfile` 确认证书一致。

### 2.3 iOS

```bash
flutter build ios --release --no-codesign   # CI 已覆盖，可验证 Pod / Xcode 集成
```

解除 IPA 阻塞需要（当前均缺失，属账号与证书前置条件，代码侧无剩余工作）：

1. 加入 Apple Developer Program，创建 App ID（`com.novelphone.novelphone`）并开启所需能力（本应用只用到网络，无推送/健康等敏感能力）。
2. 在 App Store Connect 创建应用记录，准备发布证书与 Provisioning Profile（或在 Xcode 开启自动签名）。
3. `flutter build ipa --release` 后通过 Transporter / Xcode 上传构建。
4. 填写 App Privacy、年龄分级、审核备注（审核员需自备模型 API Key 才能体验 AI；建议提供演示 Key 或说明「AI 功能需自行配置」，并确保未配置时其余功能可完整体验）。

## 3. Google Play 商店资料

### 3.1 商品信息（中文）

- **应用名称**：NovelPhone
- **简短说明（≤80 字）**：本地优先的小说写作工具，AI 辅助灵感与续写，稿子只留在你的设备上。
- **完整说明**：

> NovelPhone 是一款为手机写作设计的小说创作工具：卷 / 章管理、沉浸编辑器、章纲与角色卡、设定集、灵感箱、版本快照与回收站一应俱全，所有稿件默认只保存在本机。
>
> 需要时，你可以接入自己的大模型服务商（OpenAI 兼容 / Anthropic），获得续写、改写、灵感、逐章摘要、设定补全、剧情推演、作品问答与一致性检查；上下文按预算最小化发送，不经过任何中转服务器。
>
> 支持 Markdown / EPUB / txt / docx 导入，txt / docx / markdown / EPUB 导出，整库备份与恢复，自持对象存储云备份，写作统计与热力图。

- **分类**：图书与工具书 / 生产力（建议主分类「图书与工具书」，次分类「生产力」）
- **标签**：小说写作、写作工具、AI 写作、本地优先、隐私
- **联系邮箱**：在 Play Console 填写可长期接收邮件的地址（仓库不写死个人邮箱）
- **隐私政策 URL**：`https://github.com/wly2lcl/NovelPhone/blob/main/docs/PRIVACY.md`
- **应用访问权限**：无需登录，无受限内容；AI 功能需要用户自备第三方模型 Key

### 3.2 图形素材

- 应用图标：512×512 PNG（源图见 `vibe_images/icon_master_1024.png`，不入库）
- 特色图片：1024×500 PNG/JPEG
- 手机截图：至少 2 张，建议 8 张竖屏（1080×1920 或更高；仓库内 `docs/images/` 有功能截图可参考）
- 平板截图：按需（应用未针对平板单独适配，可不上传）

### 3.3 Data safety 表单填写

| 问题 | 填写 |
|---|---|
| Does your app collect or share any of the required user data types? | **No** |
| Is all of the user data collected by your app encrypted in transit? | 不适用（不收集）；用户主动触发的 AI / 云备份请求使用 HTTPS |
| Do you provide a way for users to request that their data is deleted? | 不适用（数据不离开设备）；卸载即删除，应用内可删除作品 / 清空问答历史 / 重置统计 |
| Data linked to the user | 无 |
| Data shared with third parties | 无 |
| 说明备注（如表单允许） | The app has no accounts, ads, analytics or telemetry. AI requests are initiated by the user and sent directly to the user's own model provider with the user's own API key. Optional cloud backup is off by default and goes directly to the user's own storage. |

> 注意口径：Google 的「收集」指传输离开设备。本应用只有在用户主动触发 AI / MCP / 云备份时才发送最小上下文，且接收方由用户自行配置、凭证由用户自持；按当前 Data safety 定义仍填「不收集」。如未来加入任何遥测或账号，需同步修改本表与隐私政策。

### 3.4 内容分级与审核

- 内容分级问卷：无用户生成内容公开分发、无社交、无广告；题材为写作工具，选「Everyone / 3+」。
- 审核备注建议：

> NovelPhone is a local-first writing app. No sign-in is required. All writing features work offline. AI features require the reviewer to configure their own OpenAI-compatible or Anthropic endpoint and API key in Settings → Model Groups; without a key, the app remains fully usable for writing, import/export and backup.

## 4. App Store（iOS）资料

当前无法提交，资料先备齐：

- **App Privacy（营养标签）**：Data Not Collected（与 Android 口径一致）；如审核认为用户自配服务商属于共享，需在审核备注中说明请求由用户主动发起、接收方与凭证均由用户自持。
- **隐私政策 URL**：同上。
- **审核备注**：同 Google Play，并说明 AI 功能需自备 Key。
- **截图**：6.7"/6.5"/5.5" 竖屏各至少 1 张（可按需生成）。
- **出口合规**：使用 HTTPS，属豁免加密，App Store Connect 选择「Exempt」。

## 5. 发布前检查清单

- [ ] `pubspec.yaml` 版本号已递增（`versionName+versionCode`；Android versionCode 必须大于已发布值）
- [ ] `dart format --output=none --set-exit-if-changed lib test` 零改动
- [ ] `flutter analyze` 无问题
- [ ] `flutter test` 全绿
- [ ] `flutter build appbundle --release` 成功，`keytool -printcert -jarfile` 证书为正式发布证书
- [ ] `flutter build apk --release --split-per-abi` 成功，`apksigner verify` 通过
- [ ] 真机安装 release 包：冷启动、作品列表、编辑器、导入导出、备份、AI 未配置提示均正常
- [ ] `docs/PRIVACY.md`、关于页隐私说明、商店 Data safety 三处口径一致
- [ ] 隐私政策 URL 公网可访问，内容含生效日期与联系方式
- [ ] 商店截图 / 图标 / 特色图片已上传且无测试数据、无真实 API Key
- [ ] 若涉及数据库 schema 变更：旧版本覆盖安装后数据完整（迁移测试）
- [ ] 打 tag 并记录构建产物 SHA-256

## 6. 已知限制

- iOS IPA / 上架被 Apple Developer 账号与证书阻塞，见 §2.3。
- CI release 产物使用临时签名，仅供构建验证，不可用于商店上传。
- 应用未做平板 / 横屏专项适配；商店可不提供平板截图。
- 云备份依赖用户自持 S3 兼容存储，首次配置需自行准备 endpoint / bucket / 凭证。
- 推理型模型（实测 `deepseek-v4-flash` / `agnes-3.0-flash`）在输出上限较低（4096）时可能把 completion token 全部用于推理阶段而无可见正文：应用会在记录用量后明确报错「AI 未返回内容，请重试或提高输出上限」，不会展示空白结果；建议为这类模型组调高输出上限（如 8192）或改用非推理模型。该限制取决于模型服务商，不是应用可修复的协议问题。
