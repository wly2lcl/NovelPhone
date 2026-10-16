# NovelPhone

简体中文 | [English](README.en.md)

[![CI](https://github.com/wly2lcl/NovelPhone/actions/workflows/ci.yml/badge.svg)](https://github.com/wly2lcl/NovelPhone/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
![Flutter](https://img.shields.io/badge/Flutter-3.44.3-02569B?logo=flutter&logoColor=white)

**本地优先的手机端 AI 小说写作工具**：作品正文、设定、角色与统计全部保存在设备本地；AI 是按需介入的写作伙伴，通过你自己配置的模型服务商直连完成，不经过任何中转服务器。

两条设计主线：

- **数据归你**——SQLite 本地存储、API Key 存系统安全区、备份导出到本地文件或你自己的对象存储；
- **治理「AI 味」**——内置规则引擎与可选 LLM 深检标记套话、重复句式等问题，支持定位与一键替换；AI 续写默认并发生成多个候选，供你对照挑选。

当前状态：MVP 功能范围（78 / 78）已收口，此后 17 项增强（ENH-01~17，含全 App 简体中文 / English 双语 UI）全部落地；Android release 签名与 GitHub Actions CI 就绪，314 个自动化用例通过，真机验收记录见 [docs/TODO.md](docs/TODO.md)。

## 截图

| 作品列表 | 卷与章节 | 写作编辑器 |
|:---:|:---:|:---:|
| ![作品列表](docs/images/works-list.png) | ![卷与章节](docs/images/chapters.png) | ![写作编辑器](docs/images/editor.png) |

| AI 感检查 | AI 续写（3 个候选） |
|:---:|:---:|
| ![AI 感检查](docs/images/ai-check.png) | ![AI 续写](docs/images/ai-continue.png) |

## 功能特性

### 写作与作品管理

- 多作品管理：封面配色、字数与最近编辑时间一览；全局搜索跨作品检索章节标题与正文，命中高亮并可跳转编辑器定位
- 分卷 / 章节结构：卷上移 / 下移 / 重命名 / 删除，卷内新建章节；章节重命名、上移 / 下移、移动到其他卷与删除
- 导入 txt / docx：自动探测编码（UTF-8 / GBK）、按「第X章」规则分章预览、「并入上一章」合并、单文件 10MB 上限
- 编辑器：自动保存与「已保存」指示、专注模式（隐藏工具栏、光标行居中）、写作外观（夜间纸张 / 正文字号 / 行距）
- 查找、段落移动、撤销 / 重做（100 步与累计 200 万字符双上限）
- 章节快照（版本历史）：创建 / 预览 / 恢复 / 删除，随备份往返
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
- **AI 逐章摘要 + 本卷前情回顾**：滚动摘要解决长篇上下文「遗忘」；摘要可查看 / 手动编辑，过期时提示重新生成
- **AI 章纲扩写**：一句梗概扩写为分场大纲写回本章章纲
- **AI 感检查**：约 200 条词库规则引擎（套话 + 句式重复率 + 标点密度）与可选 LLM 深检两层级联；面板支持范围统计、类型筛选、就地高亮定位、一键替换、忽略与批量忽略同类、处置率计数；单章与整作检查均不冻结界面

### 模型与开放能力

- 模型组：支持 OpenAI 兼容 / Anthropic / Responses 三类端点协议，多组管理、启用开关、baseUrl 与模型列表、每任务生成参数
- 任务与模型映射：续写 / 灵感 / 改写 / 感检查 / 摘要 / 章纲扩写 / 本卷回顾分别指定模型组，未配置时引导至设置页
- 出网稳健性：429 / 5xx 在首个文本增量前指数退避自动重试，内容过滤等错误分类给出可读提示
- MCP 工具服务：接入远程 Streamable HTTP server，把其工具提供给 AI 调用
- 自定义技能：附加指令文本 + 工具白名单，注入续写与灵感编排

### 界面与体验

- 界面语言：简体中文 / English 双语，默认跟随系统，可在设置 → 写作 → 语言内切换（即时生效并持久化）；AI 提示词与中文域数据保持中文
- 全 App 深色模式：跟随系统 / 浅色 / 深色三态，暖色纸质调色板亮暗两套随主题切换

### 数据、统计与隐私

- 备份到文件：整库 zip（`data.json` + 每作品 markdown），恢复时可「合并为新增作品」或「覆盖并清空本地」
- 云备份：用户自带的 S3 兼容对象存储（AWS S3 / 阿里云 OSS / 七牛 Kodo / 腾讯 COS / 华为 OBS），SigV4 直签、默认关闭，支持手动与按间隔自动备份
- 写作统计：每日字数目标进度、连续写作天数、番茄钟
- Token 与采纳统计：按「任务 · 模型」分组，记录生成次数、token 用量与采纳率 / 忽略率
- 隐私：API Key 存系统安全存储（keychain / keystore），不入库、不随备份导出；AI 功能首次联网前展示告知门控，详情见 [docs/COMPLIANCE.md](docs/COMPLIANCE.md)

## 技术栈

| 层 | 选型 |
|---|---|
| UI / 状态 | Flutter 3.44 · Riverpod · go_router |
| 数据 | Drift（SQLite，schema v10，含完整迁移链） |
| 安全存储 | flutter_secure_storage（keychain / keystore） |
| 网络 | http（SSE 流式解析）、crypto（云备份 SigV4 直签） |
| AI 互操作 | 三类端点协议适配、mcp_dart（远程 MCP）、自定义技能编排 |
| 平台 | 单代码库交付，当前以 Android 为主要交付与真机验收目标 |

无服务端组件：应用离线可用，联网仅发生在你主动使用 AI 或云备份时，且直连你自己配置的服务商。

## 快速开始

环境要求：

- Flutter 3.44.x（CI 基线 3.44.3）/ Dart ^3.12.2
- Android SDK（构建 Android 安装包）

```bash
flutter pub get
flutter run     # 连接 Android 设备或模拟器运行
```

构建 release APK（需先配置签名：在 `android/key.properties` 指向你的 keystore；两者均不入库，请务必离线备份）：

```bash
flutter build apk --release
```

修改 Drift 表结构后重新生成数据层代码：

```bash
dart run build_runner build --delete-conflicting-outputs
```

## 测试与 CI

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test    # 314 个用例：数据层 / 编辑器控制器 / AI 客户端与编排 / 检查引擎 / 页面 widget
```

GitHub Actions（[ci.yml](.github/workflows/ci.yml)）在 push 与 PR 上执行上述三项检查。

开发辅助工具：[tool/fake_llm_server.dart](tool/fake_llm_server.dart) 在本机回环模拟 Chat Completions / Messages 的正常流与 429 / 5xx / 内容过滤场景（`GET /stats` 观测请求计数），配合 `adb reverse` 可在真机验证 AI 错误与重试路径，无需真实 API Key。

## 文档

| 文档 | 内容 |
|---|---|
| [docs/PRD.md](docs/PRD.md) | 产品定位、功能范围与验收标准 |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | 技术选型、分层模块、数据模型与 AI 层设计 |
| [docs/TODO.md](docs/TODO.md) | 任务清单、进度跟踪与真机验收记录（M1-M4 + ENH-01~17） |
| [docs/COMPLIANCE.md](docs/COMPLIANCE.md) | 隐私政策、数据安全说明与上架资料要点 |

## 许可证

[Apache License 2.0](LICENSE)
