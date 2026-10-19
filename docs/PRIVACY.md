# NovelPhone 隐私政策

生效日期：2026-10-19

NovelPhone（以下简称「本应用」）是一款本地优先的手机小说写作工具。本政策说明本应用如何处理你的信息。核心原则：**默认不收集任何数据，创作内容只保存在你的设备上。**

## 1. 我们不收集什么

- 不设账号体系，不要求登录。
- 不接入广告、分析、崩溃上报或遥测 SDK。
- 不上传、不备份你的作品正文、设定、角色卡、章纲、灵感、写作统计到 NovelPhone 的任何服务器（本应用没有中转服务器）。
- 不读取与写作无关的设备信息（通讯录、位置、相册、剪贴板等）。
- 应用锁（可选，默认关闭）只调用系统提供的生物识别 / 设备凭证校验，不读取、不存储、不上传指纹或人脸等生物识别数据。
- 截屏保护（可选，默认关闭）：开启后仅在系统层阻止截屏与最近任务预览（Android `FLAG_SECURE`），iOS 在退后台时以遮罩覆盖系统快照；本应用不采集、不上传屏幕内容。iOS 无公开 API 阻止前台主动截屏，设置页已注明此限制。
- 备份密码加密（可选，默认关闭）：加密完全在本机完成，密码只保存在设备安全存储，不写入备份文件、不上传、不写日志。

## 2. 数据保存在哪里

以下数据仅保存在本机应用私有目录的 SQLite 数据库中：

- 作品、卷、章节正文、章纲、角色卡、角色关系、设定集、灵感箱、写作统计与版本快照；
- 应用设置（模型组名称 / baseUrl / 模型名 / 生成参数、任务映射、界面偏好、月度 AI 预算）；
- 作品问答历史（每部作品最多 40 轮，在本机保存，可随时清空）。

API Key、MCP 认证头、MCP OAuth 令牌、云备份凭证与备份加密密码仅保存在操作系统的安全存储（iOS Keychain / Android Keystore），数据库中只保存引用标识或布尔开关。

应用锁的开关状态保存在本机设置中；解锁所需的指纹 / 人脸模板由操作系统保管，本应用只接收「校验通过 / 未通过」的结果。

## 3. 何时联网

只有你主动触发以下功能时，本应用才会发起网络请求：

1. **AI 功能**（续写、灵感、改写、摘要、设定补全、剧情推演、作品问答、一致性检查等）：本应用会把该次请求所需的最小上下文（当前章节内容、章纲、相关角色卡、前情摘要等）**直接发送给你自行配置的模型服务商**。请求由你提供的 API Key 鉴权。不经过 NovelPhone 的服务器。
2. **MCP 工具服务**（可选）：若你配置了 MCP 服务并触发相关 AI 任务，本应用会直连你配置的 MCP 地址；若使用 OAuth 2.1，则通过系统浏览器在你与授权服务器之间完成授权。
3. **云备份**（可选，默认关闭）：若你开启并触发备份，本应用会把整库备份直接上传到你自行配置的对象存储（S3 兼容）；开启备份密码加密时上传 `.npbak` 密文，否则上传与本地一致的 zip。凭证与加密密码只存本机。

本地规则引擎的「AI 感检查」完全离线，不产生网络请求。

## 4. 第三方

本应用不集成任何第三方广告、统计或数据分析 SDK。你主动发送给模型服务商或对象存储的数据，其处理方式适用对应服务商的隐私政策；请自行确认其条款。

## 5. 数据删除与导出

- 你可以在应用内导出作品（txt / docx / markdown / EPUB）与整库备份（备份不包含 API Key）；整库备份可选择密码加密（`.npbak`，AES-256-GCM），密码由你保管、本应用不提供找回。
- 你可以删除单部作品（进入回收站后可进一步彻底删除）、清空作品问答历史、重置 Token 统计。
- 卸载应用会清除本地数据库与安全存储中的凭证。
- 系统级自动云备份已关闭：Android 声明 `android:allowBackup="false"`，并在 Android 12+ 通过 `dataExtractionRules` 排除 cloud-backup 的全部数据域，作品数据不会进入 Google Drive 等系统云备份；换机设备直传（D2D）保留，数据只在你自己的两台设备间直接迁移。

## 6. 未成年人

本应用是通用写作工具，不面向未成年人专门设计，也不主动收集未成年人个人信息。

## 7. 政策更新与联系方式

本政策更新时会修改本页面的「生效日期」。如有疑问，请通过项目仓库的 Issues 反馈：
<https://github.com/wly2lcl/NovelPhone/issues>

---

# NovelPhone Privacy Policy (English)

Effective date: 2026-10-19

NovelPhone is a local-first novel-writing app. **It collects no data by default; your manuscripts stay on your device.**

- No accounts, ads, analytics, crash reporting or telemetry SDKs.
- The optional app lock (off by default) delegates verification to the OS biometric / device-credential prompt. The app never reads, stores or uploads fingerprint or face data; it only receives a pass/fail result.
- The optional screen protection (off by default) only sets a platform window flag on Android (`FLAG_SECURE`) and overlays an opaque view while the app is backgrounded on iOS, so the system screenshots and task-switcher previews are blocked or masked. The app never captures or uploads screen content. iOS exposes no public API to block a foreground screenshot; the settings screen states this limitation.
- The optional backup passphrase encryption (off by default) runs entirely on-device. The passphrase lives only in the OS secure store; it is never written into the backup file, uploaded or logged.
- Manuscripts, story bible, outlines, inspirations and writing stats are stored only in the app's private SQLite database on your device. API keys, cloud-backup credentials and the optional backup passphrase live in the OS secure store (Keychain / Keystore).
- The app connects to the network only when you actively use AI features, an MCP tool server, or cloud backup. Requests go **directly to the provider you configure**; NovelPhone operates no relay server. The minimum context needed for each request is sent, authenticated with your own key.
- Optional cloud backup is off by default and uploads directly to your own S3-compatible storage. When backup passphrase encryption is enabled, the uploaded file is `.npbak` ciphertext; otherwise it is the same zip as the local backup. Credentials and the passphrase stay on your device.
- You can export works and full-library backups at any time; backups never contain API keys. Encrypted backups (`.npbak`, AES-256-GCM) use a passphrase you keep yourself — there is no recovery mechanism.
- Uninstalling the app removes local data and secure-store credentials. Android auto backup is disabled (`allowBackup="false"` plus `dataExtractionRules` excluding all cloud-backup domains); device-to-device transfer remains available and never goes through the cloud.
- No third-party SDKs are bundled. Data sent to your chosen model provider is governed by that provider's privacy policy.

Contact: <https://github.com/wly2lcl/NovelPhone/issues>
