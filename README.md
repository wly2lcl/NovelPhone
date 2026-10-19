# NovelPhone

简体中文 | [English](README.en.md)

[![CI](https://github.com/wly2lcl/NovelPhone/actions/workflows/ci.yml/badge.svg)](https://github.com/wly2lcl/NovelPhone/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
![Flutter](https://img.shields.io/badge/Flutter-3.44.3-02569B?logo=flutter&logoColor=white)

**本地优先的手机端 AI 小说写作工具**：作品正文、设定、角色与统计全部保存在设备本地；AI 是按需介入的写作伙伴，通过你自己配置的模型服务商直连完成，不经过任何中转服务器。

两条设计主线：

- **数据归你**——SQLite 本地存储、API Key 存系统安全区、备份导出到本地文件或你自己的对象存储；
- **治理「AI 味」**——内置规则引擎与可选 LLM 深检标记套话、重复句式等问题，支持定位与一键替换；AI 续写默认并发生成多个候选，供你对照挑选。

当前状态：MVP 功能范围（78 / 78）已收口，此后 29 项增强（ENH-01~29，含全 App 简体中文 / English 双语 UI、MCP OAuth 2.1 PKCE 与技能 front matter 导入、无障碍语义、应用图标 / 启动闪屏品牌化、发布产物交付，以及回收站、MCP 调用审计、备份校验预览、技能导出、文风档案、AI 设定补全、剧情推演、作品问答、全书一致性体检与稳定性增强；ENH-24 补齐 Markdown / EPUB 导入、推演转章纲、角色关系抽取、批量摘要、月度 AI 预算与发布收口；ENH-25 新增推理模型空正文自动提高输出上限重试与系统生物识别 / 设备凭证应用锁；ENH-26 新增截屏 / 最近任务缩略图保护与可选密码加密备份；ENH-27 新增 AI 结果分段采纳、结果内多轮修改与本地写作偏好注入；ENH-28 补齐 AI 结果插入空行分隔、作者协作偏好可视化管理与结果内修订版本切换 / 对比；ENH-29 新增段落级未采纳原因、任务感知的采纳样本排序、修订 / 关闭时的用量状态一致性、修订快捷指令与改写原文对比）全部落地；Android release 签名、AAB / 分 ABI APK 产物与 GitHub Actions CI（含 iOS 无签名构建 job 与 release 产物归档）就绪，iOS 无签名 release 构建通过，500 个自动化用例通过，真机验收记录见 [docs/TODO.md](docs/TODO.md)。ENH-23 的文风档案、AI 设定补全与剧情推演已于 2026-10-18 经 `deepseek-v4-flash` / `agnes-3.0-flash` 两个真实模型通道复验（竖屏对比截图见下）。

## 截图

| 作品列表 | 卷与章节 | 写作编辑器 |
|:---:|:---:|:---:|
| ![作品列表](docs/images/works-list.png) | ![卷与章节](docs/images/chapters.png) | ![写作编辑器](docs/images/editor.png) |

| AI 感检查 | AI 续写（3 个候选） |
|:---:|:---:|
| ![AI 感检查](docs/images/ai-check.png) | ![AI 续写](docs/images/ai-continue.png) |

**ENH-23 真实模型验收（竖屏截图对比，左为使用前 / 右为 AI 结果）**

| 文风档案（DeepSeek V4） | AI 设定补全（Agnes 3.0） |
|:---:|:---:|
| ![文风档案](docs/images/enh23-style-compare.png) | ![AI 设定补全](docs/images/enh23-extract-compare.png) |

| 剧情推演（DeepSeek V4） |
|:---:|
| ![剧情推演](docs/images/enh23-plan-compare.png) |

## 功能特性

### 写作与作品管理

- 多作品管理：封面配色、字数与最近编辑时间一览；全局搜索跨作品检索章节标题与正文，命中高亮并可跳转编辑器定位
- 分卷 / 章节结构：卷上移 / 下移 / 重命名 / 删除，卷内新建章节；章节重命名、上移 / 下移、移动到其他卷与删除
- 回收站：删除作品 / 章节只打删除标记，30 天内可在设置 →「回收站」恢复或永久删除；每次启动与打开回收站时自动清理过期条目
- 导入 txt / docx / Markdown / EPUB：自动探测编码（UTF-8 / GBK）、按「第X章」规则分章预览、「并入上一章」合并、单文件 10MB 上限；EPUB 按 OPF spine 顺序读取章节并跳过目录页，Markdown 按标题分章
- 编辑器：自动保存与「已保存」指示、专注模式（隐藏工具栏、光标行居中）、写作外观（夜间纸张 / 正文字号 / 行距）
- 查找、段落移动、撤销 / 重做（100 步与累计 200 万字符双上限）
- 全书查找替换：输入关键词即预览全书命中章节与片段，确认后一次性替换；受影响章节自动留存快照，可在版本历史中回滚
- 章节快照（版本历史）：创建 / 预览 / 恢复 / 删除，可与当前文本对比（段落级差异高亮、改动计数、长未改动段折叠），随备份往返
- 导出：单章 txt / markdown，整作 Word（.docx）与 EPUB 3

### 故事资产

- 角色卡：标签与描述，参与 AI 上下文组装
- 设定集：世界观 / 地点 / 道具分类条目
- 章纲：按章维护，可被 AI 扩写
- 人物关系图：环形绘制角色关系连线，可增删改

### AI 写作伙伴

- **AI 续写**：默认并发生成 3 个候选（温度微调制造差异）、篇幅滑杆、生成方向、插入光标处；生成前可展开「AI 看到的上下文」核对估算 token 与预算
- **AI 灵感**：桥段点子流式生成，自动注入前文摘要与本章章纲
- **AI 改写**：选中段落后按润色 / 扩写 / 缩写 / 改语气 + 补充指令改写，替换原文走编辑器撤销栈
- **AI 结果协作**：续写 / 改写结果可**逐段勾选并直接编辑**后写入（改写会标出与原文不同的段落，未勾选的段落不写入）；也可输入修改意见让 AI 在**当前草稿**上继续修改，而不是整篇重新生成；放弃结果时可记录「太像 AI / 角色出戏 / 节奏拖沓 / 设定不符 / 其他」，原因计数与最近采纳片段只存本机，并在后续生成时作为「作者协作偏好」注入上下文。ENH-28 起：插入光标处自动补空行分隔（不再与正文粘连）；作品菜单可查看 / 开关 / 清空协作偏好（永久删除作品时一并清理）；结果面板保留最近 5 版修订，可切换「原稿 / 修订 N」并与上一版对比。ENH-29 起：分段采纳时若有未勾选段落，可补充未采纳原因并与放弃原因合并计入偏好；关闭 / X 放弃同样询问原因；修订失败保留旧结果且不丢用量记录；结果面板提供「更具体 / 更紧凑 / 加强对话 / 换个结尾 / 去 AI 味」快捷修订，改写模式还可一键「对比原文」
- **AI 逐章摘要 + 本卷前情回顾**：滚动摘要解决长篇上下文「遗忘」；摘要可查看 / 手动编辑，过期时提示重新生成；新增批量生成页，一次为「缺少摘要 / 正文已更新」的章节顺序生成，可中途停止
- **AI 章纲扩写**：一句梗概扩写为分场大纲写回本章章纲
- **推演转章纲**：剧情推演的分章建议可一键写入章纲（标题匹配已有章节时写回该章，否则作为未关联章节的梗概）
- **AI 设定一致性检查**：结合本章正文、角色卡、设定集与章纲，一次性输出人物 / 设定 / 时间线冲突报告与修改建议；结果可回看，不写入正文
- **全书一致性体检**：逐章扫描整部作品，按章展开冲突明细；生成过程流式可见，可随时停止并保留已生成的部分报告
- **文风档案**：从样章提取叙事视角、语感、句长与遣词偏好并保存到作品，写作与问答时自动注入上下文
- **AI 设定补全**：从章节正文抽取角色、设定条目与角色关系，预览合并结果并自动去重，一键写入角色卡、设定集与关系图；无法对应到已有或新建角色的关系会给出跳过原因
- **剧情推演**：结合既有设定、章纲与最新进度给出多条走向与分章建议，可一键存入灵感箱或转为章纲
- **作品问答**：针对整部作品的多轮对话，本地检索章节、角色、设定与章纲后作答；对话按作品持久化（保留最近 40 轮），可查看本轮注入的上下文并清空
- **AI 感检查**：约 200 条词库规则引擎（套话 + 句式重复率 + 标点密度）与可选 LLM 深检两层级联；面板支持范围统计、类型筛选、就地高亮定位、一键替换、忽略与批量忽略同类、处置率计数；单章与整作检查均不冻结界面
- **空正文自动重试**：推理型模型把输出预算耗在推理阶段、没有可见正文时，自动把输出上限翻倍并重试一次（以模型上下文窗口与 16384 为上限）；仍无正文才提示失败，每次尝试的 Token 用量分别计入统计

### 模型与开放能力

- 模型组：支持 OpenAI 兼容 / Anthropic / Responses 三类端点协议，多组管理、启用开关、baseUrl 与模型列表、每任务生成参数
- 任务与模型映射：续写 / 灵感 / 改写 / 感检查 / 摘要 / 章纲扩写 / 本卷回顾 / 设定一致性检查分别指定模型组，未配置时引导至设置页；一致性检查未配置时依次回退 AI 感检查组与续写组
- 出网稳健性：429 / 5xx 在首个文本增量前指数退避自动重试，内容过滤等错误分类给出可读提示；连接 30 秒、流式空闲 90 秒超时，避免请求无限挂起
- MCP 工具服务：接入远程 Streamable HTTP server，把其工具提供给 AI 调用；认证支持自定义请求头与 **OAuth 2.1 PKCE**（授权在系统浏览器完成、loopback 回调换令牌，支持动态客户端注册与 refresh_token 自动续期，令牌只存本机安全区）；「MCP 调用审计」本地记录最近 100 次远程工具调用（工具名、参数 / 结果摘要、耗时、成功标记），可展开查看与清空，不联网、不含认证信息
- 自定义技能：附加指令文本 + 工具白名单，注入续写与灵感编排；支持按 Anthropic SKILL.md 约定从文件 / 粘贴导入 **front matter**（name / description / allowed-tools / parameters / enabled，预览确认后落库），并可把技能导出为 Markdown 文件经系统分享面板发送

### 界面与体验

- 界面语言：简体中文 / English 双语，默认跟随系统，可在设置 → 写作 → 语言内切换（即时生效并持久化）；AI 提示词与中文域数据保持中文
- 全 App 深色模式：跟随系统 / 浅色 / 深色三态，暖色纸质调色板亮暗两套随主题切换
- 品牌化外观：钢笔笔尖主题应用图标与暖色启动闪屏；「关于」页展示版本号、隐私说明要点与开源许可清单
- 无障碍：开关 / 色块 / 弹层菜单带语义标签，仅长按可达的操作（作品卡、章节行）暴露为屏幕阅读器自定义动作，图表提供摘要描述，滑杆与标签合并播报
- 应用锁：可选开启（默认关闭），启动与从后台返回时用系统生物识别或锁屏密码 / 图案解锁；开启与关闭都需要先通过系统验证，锁定期间仅遮挡界面、不销毁导航树，解锁后仍停留在原编辑位置；设备未设置安全锁屏时给出明确提示，不降级为明文保护
- 截屏保护：可选开启（默认关闭）——Android 通过 `FLAG_SECURE` 阻止截屏 / 录屏，并让最近任务中的应用缩略图显示为空白；iOS 在应用退到后台时立即覆盖不透明遮罩，避免切换器快照泄露正文（系统不提供阻止前台截屏的公开 API，此限制已在界面与文档中说明）

### 数据、统计与隐私

- 备份到文件：整库 zip（`data.json` + `manifest.json` + 每作品 markdown），恢复前展示导出时间、数据版本、作品 / 章 / 角色数量并校验 **SHA-256**（旧版无清单的备份会明确提示「未包含校验信息」）；恢复时可「合并为新增作品」或「覆盖并清空本地」
- 备份密码加密：可选开启（默认关闭）——导出与云备份统一封装为 `.npbak`（`NPBK` v1 信封：PBKDF2-HMAC-SHA256 21 万次派生 + AES-256-GCM 认证加密），密码只存设备安全存储、不随备份导出；开启后密码缺失即中止导出，绝不静默回退明文；恢复同时支持加密 `.npbak` 与旧版明文 `.zip`，密码错误或密文被篡改统一提示「密码错误或备份文件已损坏」
- 云备份：用户自带的 S3 兼容对象存储（AWS S3 / 阿里云 OSS / 七牛 Kodo / 腾讯 COS / 华为 OBS），SigV4 直签、默认关闭，支持手动与按间隔自动备份；开启备份加密时云端对象同样为 `.npbak` 密文，自动备份在密码缺失时跳过且不发起网络请求
- 写作统计：每日字数目标进度、连续写作天数、番茄钟、近 7 / 30 天字数趋势图与近一年写作热力图
- Token 与采纳统计：按「任务 · 模型」分组，记录生成次数、token 用量与采纳率 / 忽略率；模型组可填每百万 token 输入 / 输出价格，统计页据此估算费用（人民币）；可设置**月度 AI 预算**，达到 80% 提示、100% 红色告警（仅提示，不阻断调用）
- 发布资料：独立的 [隐私政策](docs/PRIVACY.md)（中英双语）与 [发布说明](docs/RELEASE.md)（构建命令、Google Play 商品信息、Data safety 表单口径、iOS 阻塞项）；「关于」页可直接打开隐私政策外链
- 隐私：API Key 存系统安全存储（keychain / keystore），不入库、不随备份导出；AI 功能首次联网前展示告知门控；忽略原因与最近采纳片段按作品只存本机设置、不随备份导出，仅在生成时随上下文发送给你配置的模型服务商，详情见 [docs/COMPLIANCE.md](docs/COMPLIANCE.md)

## 技术栈

| 层 | 选型 |
|---|---|
| UI / 状态 | Flutter 3.44 · Riverpod · go_router |
| 数据 | Drift（SQLite，schema v12，含完整迁移链） |
| 安全存储 | flutter_secure_storage（keychain / keystore） |
| 应用锁 | local_auth（系统生物识别 / 设备凭证，Android FlutterFragmentActivity + USE_BIOMETRIC，iOS Face ID 用途说明） |
| 隐私保护 | Android `FLAG_SECURE`（MethodChannel 控制，同时遮挡最近任务缩略图）；iOS 退后台遮罩；备份加密使用 cryptography（PBKDF2-HMAC-SHA256 210,000 次 + AES-256-GCM） |
| 网络 | http（SSE 流式解析）、crypto（云备份 SigV4 直签） |
| AI 互操作 | 三类端点协议适配、mcp_dart（远程 MCP）、自定义技能编排 |
| 平台 | 单代码库交付 iOS / Android；当前以 Android 为主要交付与真机验收目标（iOS 已通过无签名 release 构建验证） |

无服务端组件：应用离线可用，联网仅发生在你主动使用 AI 或云备份时，且直连你自己配置的服务商。

## 快速开始

环境要求：

- Flutter 3.44.x（CI 基线 3.44.3）/ Dart ^3.12.2
- Android SDK（构建 Android 安装包）
- Xcode 27+（构建 iOS 包，可选；无需 CocoaPods）

```bash
flutter pub get
flutter run     # 连接 Android 设备或模拟器运行
```

构建发布产物（需先配置签名：在 `android/key.properties` 指向你的 keystore；两者均不入库，请务必离线备份）：

```bash
# AAB：Google Play 上架格式（首次上传必需）
flutter build appbundle --release

# 分 ABI APK：侧载 / 直接分发推荐（arm64-v8a / armeabi-v7a / x86_64 各一个）
flutter build apk --release --split-per-abi

# 通用 APK：单包兼容所有设备，体积较大
flutter build apk --release
```

产物路径：APK 在 `build/app/outputs/flutter-apk/`，AAB 在 `build/app/outputs/bundle/release/`。

iOS 构建（需 Xcode 27+；Flutter 3.44 走 Swift Package Manager，不依赖 CocoaPods；未配置签名证书时用 `--no-codesign` 验证编译）：

```bash
flutter build ios --no-codesign --release
```

修改 Drift 表结构后重新生成数据层代码：

```bash
dart run build_runner build --delete-conflicting-outputs
```

## 测试与 CI

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test    # 500 个用例：数据层 / 编辑器控制器 / AI 客户端与编排 / 空正文重试 / 分段采纳与偏好注入 / 段落负反馈与快捷修订 / 插入分隔与修订历史 / 应用锁与截屏保护 / 备份加密（NPBK / 错误密码 / 篡改检测）/ 文风与结构化输出 / 作品问答与检索 / 导入解析（txt / Markdown / EPUB）/ MCP OAuth、审计与技能导入导出 / 检查引擎 / 页面 widget
```

GitHub Actions（[ci.yml](.github/workflows/ci.yml)）在 push 与 PR 上执行上述三项检查，并在 `macos-latest` 上额外执行 iOS 无签名 release 构建（`flutter build ios --release --no-codesign`）以尽早发现 iOS 工程 / 插件集成问题；`main` push 或手动触发时还会用临时 keystore 构建 AAB 与分 ABI APK 并归档 14 天（仅供构建验证，正式上架需用离线发布证书重建，见 [docs/RELEASE.md](docs/RELEASE.md)）。

开发辅助工具：[tool/fake_llm_server.dart](tool/fake_llm_server.dart) 在本机回环模拟 Chat Completions / Messages 的正常流与 429 / 5xx / 内容过滤场景，并提供文风 / 设定抽取 / 剧情推演的 JSON 场景（`/openai-style`、`/openai-extract`、`/openai-plan`）与首次空正文、之后正常的 `/openai-empty-first`（记录两次请求的 `max_tokens`，用于验证自动加倍重试）、`/openai-enh27`（多段落续写，带修订要求的请求返回不同草稿，用于验证分段采纳与结果内继续修改）、`/openai-enh29-revise-fail`（首次请求返回正常草稿，修订请求固定 500，用于验证修订失败保留旧结果且可继续采纳）；流式分片即时 flush，可观察增量输出与「停止保留部分结果」（`GET /stats` 观测请求计数；`/openai-tool` 场景优先选 MCP 工具先发 `tool_calls`、收到工具结果后再输出文本，可贯通 MCP 调用与审计），配合 `adb reverse` 可在真机验证 AI 错误与重试路径，无需真实 API Key；[tool/fake_mcp_oauth_server.dart](tool/fake_mcp_oauth_server.dart) 模拟带 OAuth 2.1 PKCE 授权服务器（含动态注册、S256 校验、refresh_token）的 MCP server 与 echo 工具，用于验证完整授权链路。

## 文档

| 文档 | 内容 |
|---|---|
| [docs/PRD.md](docs/PRD.md) | 产品定位、功能范围与验收标准 |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | 技术选型、分层模块、数据模型与 AI 层设计 |
| [docs/TODO.md](docs/TODO.md) | 任务清单、进度跟踪与真机验收记录（M1-M4 + ENH-01~26） |
| [docs/RELEASE.md](docs/RELEASE.md) | 发布命令、商店资料、Data safety 口径与已知限制 |
| [docs/PRIVACY.md](docs/PRIVACY.md) | 对外隐私政策（中英双语，商店与应用内共用） |
| [docs/COMPLIANCE.md](docs/COMPLIANCE.md) | 隐私政策、数据安全说明与上架资料要点 |

## 许可证

[Apache License 2.0](LICENSE)
