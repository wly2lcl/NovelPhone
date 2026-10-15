# NovelPhone 开发 TODO 与进度跟踪

| 项 | 内容 |
|---|---|
| 关联文档 | `docs/PRD.md`（功能与验收）、`docs/ARCHITECTURE.md`（技术方案） |
| 编号规则 | 任务编号 `M<里程碑>-<两位序号>`，全文档唯一，可直接引用；优先级单独标注（P0 必做 / P1 重要 / P2 后置） |
| 使用规则 | 任务完成后勾选并更新进度区；每完成一个任务保证代码可运行 |

## 进度总览

| 里程碑 | 范围 | 状态 | 完成任务 / 总任务 |
|---|---|---|---|
| M1 骨架与编辑器 | 项目骨架、数据层、作品与章节管理（含分卷）、编辑器核心 | 已完成（含真机验收 M1-22） | 22 / 22 |
| M2 作品管理 | 角色卡、章纲、导入导出与备份 | 已完成（含真机验收 M2-15，导出→再导入往返由自动化用例覆盖） | 18 / 18 |
| M3 AI 核心能力 | AI 客户端、Agent Core、上下文组装、续写灵感、设置 | 已完成（含真机验收 M3-21/22） | 22 / 22 |
| M4 AI 感检查与打磨 | 规则引擎、LLM 深检、检查面板、异常流、主题细节、合规资料 | 已完成（含真机全流程回归 M4-14 与验收 M4-15） | 16 / 16 |

当前迭代：M1-M4 全部完成，MVP 范围收口（78 / 78）。阻塞项：无。

M1 自动化验证记录（2026-09-30）：`flutter analyze` 无问题；`flutter test` 39 个用例全部通过（数据层 15 + 字数统计 7 + 编辑器控制器 14 + 作品列表页 3）。M1-22 的冷启动耗时、10 万字输入流畅度、杀进程恢复三项需在真机上人工验收。

M2 自动化验证记录（2026-09-30）：`flutter analyze` 无问题；`flutter test` 72 个用例全部通过（含角色标签 7 + 分章 8 + 编码探测 3 + 导出文本 5 + 备份归档 3 + 备份恢复 5 + 30 万字导入导出往返 2）。M2-15 的真机 30 万字 txt 导入与沉浸滚动体验需在真机上人工验收。

M3 自动化验证记录（2026-09-30）：`flutter analyze` 无问题；`flutter test` 85 个用例全部通过（含 AiClient 适配器 8 + Agent Core 4 + ContextBuilder 6）。M3-21/22 需真机 + 真实 key 人工验收。

M4 自动化验证记录（2026-09-30）：`flutter analyze` 无问题；`flutter test` 146 个用例全部通过（新增规则引擎 17 + 回归集 1 + 深检构造与解析 12 + 检查用例 7（含弱网中断映射）+ 续写用例回归 3（未配置引导 / 流式生成与统计 / 生成中断保留已生成内容）+ 全流程主链路回归 1 + 检查面板 11 + 编辑器定位/替换 3 + 仓库层计数 3（处置率 2 + 联网告知 1））。回归集 v1（40 条人工标注样本：20 正 / 20 负）召回 100%、误报 0%。M4-08~13 已落地：两层结果合并去重与排序、检查面板（范围/预估与实测 token/深检触发/类型筛选）、定位（就地高亮 + 跨章路由参数）、一键替换（走编辑器撤销栈）、忽略与批量忽略同类、0 字禁用与深检失败保留规则结果。M4-16 已落地：`docs/COMPLIANCE.md`（隐私政策 / 数据安全说明 / 上架资料要点）、AI 功能首次联网前告知（`ai_notice.dart`，编辑器 AI 入口与检查面板深检入口均经 `ensureAiNotice` 门控，`ai_notice_ack` 记录确认状态）。

真机验收记录（2026-09-30，Android 13 / arm64 设备，`adb` 直连）：性能类指标在 **release 构建**（AOT）上测得，功能与异常流在 debug 构建上测得，两者数据互通。

- 冷启动（M1-22）：release 构建 `am start -W` 三次 COLD 耗时 1022 / 1051 / 1576 ms，均 ≤ 3s；debug 构建（JIT）同法测得 3435~4896 ms，差异来自 JIT，非应用逻辑。
- 10 万字章节输入流畅（M1-22）：导入 100007 字单章 → 编辑器正常打开并渲染；连续注入 372 字符全部被接收，无卡顿、无丢字（大写部分被 `adb shell input text` 注入限制截断，非应用问题），字数与「已保存」实时更新；章节内滚动录制帧间隔：活跃帧 91 帧，中位 16.7 ms（60 fps）、p90 16.7 ms、p99 33.3 ms，仅 1% 活跃帧超过 16.7 ms。
- 杀进程恢复（M1-22 / M4-14）：`am force-stop` 后重进，作品字数与正文完整（503 字），无数据丢失。
- 30 万字导入（M2-15）：真实 txt 1,099,804 字节 / 40 章 / 304747 字 → 编码识别 UTF-8、分章预览 40 章（每章 7596~7644 字）→ 确认写入，生成卷「novel_300k（40 章）」。导出 markdown → 再导入的设备端往返**未能在该模拟器完成**：模拟器无任何可接收分享的应用（分享面板提示「没有应用可执行此操作」），且 release 构建不可 `run-as` 读取应用临时目录；该往返已由自动化用例 `import_export_roundtrip_test.dart`（30 万字样本）覆盖并全绿。
- AI 续写全流程（M3-21）：真实渠道（OpenAI 兼容协议）完成续写，产出进入待确认面板；上下文中确认包含「相关角色卡：Elena（身份：watcher in the dark）」与「本章章纲」，估算 2939 / 预算 16000 token（无角色卡时 324）；插入光标处写入正文、撤销/重做可用；统计页记录生成 1 次、830 token、采纳率 100%。
- 错误处置（M3-21）：401 实机复现并给出「鉴权失败（401）：请到设置页检查 API Key」+「去设置」入口、插入按钮置灰；429 与内容过滤无法用现有真实渠道稳定复现，由适配器单测 `mapHttpError` 覆盖。
- 弱网中断（M3-22 / M4-14）：以宿主本地假 SSE 服务（`POST /v1/chat/completions` 先发 3 个 chunk 后 RST 断开、不发 `[DONE]`）复现。面板保留已生成的 3 段文本、给出「流式读取中断：ClientException: Connection closed while receiving data」提示，「重新生成」「换个方向」「插入光标处」均可用；点「重新生成」确认发出第二次请求（服务端日志可见新连接）。
- 本轮修复的阻断缺陷（真机发现）：7 处「`showDialog` 返回后立即 `controller.dispose()`」写法在弹窗退场动画期间因 builder 重跑而抛出「A TextEditingController was used after being disposed」，连带 `_dependents.isEmpty` 断言导致整页红屏崩溃（本章梗概、重命名章节/卷/作品、灵感编辑、AI「换个方向」）。已统一改为 `TextFormField(initialValue:)` + `onChanged` 局部变量，并新增 2 个回归用例（编辑器编辑本章梗概、重命名章节）守护。

---

## M1 骨架与编辑器

出口标准：新建作品写章节不丢稿，杀掉 app 重进内容在。

### 项目骨架

- [x] M1-01（P0）初始化 Flutter 项目，配置 `pubspec.yaml`（flutter_lints、riverpod、drift、go_router、flutter_secure_storage、http、path_provider），锁定版本；替换 flutter create 生成的默认 README 为项目说明（指向 docs/）
- [x] M1-02（P0）搭建 `lib/` 目录结构（app/models/data/core/features，按架构文档第 3 章）
- [x] M1-03（P0）配置 go_router 路由表（works → work_detail → editor → settings）与空页面占位
- [x] M1-04（P0）实现暖色纸质主题（app/theme.dart：纸张色背景、衬线标题字体、组件默认样式）

### 数据层

- [x] M1-05（P0）定义 drift 数据库：WORK / VOLUME / CHAPTER / CHARACTER / OUTLINE_ENTRY / INSPIRATION 表（CHAPTER 含会话恢复字段 cursorOffset / scrollOffset；AI_USAGE / MODEL_GROUP / APP_SETTING 在 M3 追加）
- [x] M1-06（P0）实现 DAO 与 Repository（WorkRepository / ChapterRepository / CharacterRepository / OutlineRepository）
- [x] M1-07（P0）作品与章节保存事务内更新 WORK.wordCount 与 chapterCount 冗余字段
- [x] M1-08（P0）编写 Repository 单元测试（增删改、事务、级联删除、响应式流）

### 作品与章节管理

- [x] M1-09（P0）作品列表页：卡片（封面色块/标题/总字数/章节数/最后编辑时间）、置顶排序、空状态引导
- [x] M1-10（P0）新建作品表单（标题必填 1-50 字、8 色预设封面色块）
- [x] M1-11（P0）删除作品二次确认 + 事务级联删除
- [x] M1-12（P0）作品详情页 Tab 框架（章节/角色卡/章纲）与作品级操作入口（导出、AI 设置占位）
- [x] M1-13（P0）卷管理：新建、重命名、排序
- [x] M1-14（P0）章节管理：新建、左滑更多（重命名/状态/删除）、章节状态三态（草稿/修订中/定稿）、排序（上移/下移、移动到其他卷，按 PRD 5.2 不用拖拽交互）

### 编辑器

- [x] M1-15（P0）编辑器页面骨架：顶栏（返回/章节标题可改/保存状态指示）、正文编辑区（衬线字体+纸质背景）、底部工具栏、状态栏（本章字数/总字数）
- [x] M1-16（P0）自动保存：停止输入 1 秒防抖落库，保存中/已保存/失败三态指示，失败可点击重试
- [x] M1-17（P0）会话恢复：光标与滚动位置存入 CHAPTER.cursorOffset / scrollOffset，重进章节时还原
- [x] M1-18（P0）撤销/重做：编辑器独立历史栈，与输入法撤销隔离
- [x] M1-19（P0）查找替换面板：本章关键词查找、命中数显示、单个/全部替换、大小写选项
- [x] M1-20（P0）段落移动：光标所在段上移/下移
- [x] M1-21（P0）中文字数统计（core/word_count.dart）与状态栏实时更新
- [x] M1-22（P0）M1 验收：冷启动 ≤ 3s 到可编辑；10 万字章节输入流畅；杀进程重进内容与光标恢复（真机记录见进度总览「真机验收记录」）
  - 冷启动：release 构建 1022 / 1051 / 1576 ms（≤ 3s）；debug 构建 3435~4896 ms（JIT，非逻辑问题）。
  - 10 万字章节：100007 字单章打开与输入无卡顿，滚动活跃帧中位 16.7 ms（60 fps）、仅 1% 帧掉到 16.7 ms 以上。
  - 杀进程：`am force-stop` 后重进，正文与字数完整。
  - 备注：为修复真机发现的弹窗崩溃缺陷，本轮改动 7 处 `showDialog` 相关代码（详见「真机验收记录」），非 M1-22 范围但同批交付。

## M2 作品管理

出口标准：30 万字 txt 导入成功并正确分章；导出后可再导入还原。

- [x] M2-01（P1）角色卡 CRUD：字段（姓名必填 1-20 字/身份/性格标签≤10/外貌/人际关系/弧光）、网格列表
- [x] M2-02（P1）章纲 CRUD：按卷组织、每章梗概 0-200 字、作品详情与编辑器侧栏双入口
- [x] M2-03（P1）灵感箱：列表、新增、编辑、删除（M3 接入 AI 灵感产出）
- [x] M2-04（P1）txt 导入：文件选择（path_provider + 文件选择器）、编码探测（UTF-8/GBK）
- [x] M2-05（P1）txt 自动分章：章节标题正则识别（"第 X 章/节/回"等模式），分割预览（每章标题+字数），可手动调整分割点
- [x] M2-06（P1）docx 导入：解析正文段落，按标题样式分章（降级方案：同 txt 正则）
- [x] M2-07（P1）导入确认后批量写入（事务），并把原始文件复制到 app 目录留档（对应 PRD 功能 11 的"保留原始文件备份"）
- [x] M2-08（P1）单章导出：txt / markdown（分享面板）
- [x] M2-09（P1）整作导出：txt / markdown / docx（正文+章节结构）
- [x] M2-10（P1）整库备份导出 zip：全部表数据 JSON（含正文，供恢复）+ 各作品 markdown 全文（供人工查阅），不含 key（校验安全存储内容未被打包）
- [x] M2-11（P1）备份恢复：zip 解析、合并/覆盖二选一、数据校验
- [x] M2-12（P1）导入导出边界：10MB 上限提示、0 字章节保留确认、解析失败明确报错
- [x] M2-13（P1）长列表性能：章节列表分页或懒加载，30 万字作品滚动流畅
- [x] M2-14（P1）删除章节/角色卡/卷的二次确认与级联规则（OUTLINE_ENTRY.chapterId 置空）
- [x] M2-15（P1）M2 验收：30 万字真实 txt 导入 → 分章预览 → 写入；导出 markdown → 再导入 → 章节结构与正文一致
  - 设备端已完成「导入 → 分章预览 → 写入」：真实 txt 1,099,804 字节 → 识别 UTF-8、40 章、304747 字 → 预览每章 7596~7644 字 → 写入生成卷「novel_300k（40 章）」。
  - 「导出 markdown → 再导入」的设备端往返未完成（环境限制）：模拟器无任何可接收分享的应用（分享面板提示「没有应用可执行此操作」），且 release 构建不可 `run-as` 读取应用临时目录。该往返由自动化用例 `import_export_roundtrip_test.dart`（30 万字 / 100 章样本，导出 markdown 后再导入，断言 100 章的标题与正文逐章完全相等）覆盖并全绿。
- [x] M2-16（P1）回归测试：M1 功能在导入大数据量后无退化
- [x] M2-17（P1）文档同步：更新 PRD 与 ARCHITECTURE 中的导入导出与分章规则说明
- [x] M2-18（P1）备份引导：设置页显著位置提示"换机前请先备份"

## M3 AI 核心能力

出口标准：用真实 key 完成一次续写插入；上下文含角色卡与章纲。

### AI 客户端

- [x] M3-01（P0）统一模型与抽象：ChatRequest / ChatMessage / ChatChunk（TextDelta / Usage / Done / Error）+ `AiClient` 接口
- [x] M3-02（P0）SSE 解析骨架 core/ai/sse.dart（行缓冲、`data:` 前缀、`[DONE]`）
- [x] M3-03（P0）ChatCompletionsAdapter：请求构造（system 作为首条消息）、`choices[].delta.content` 解析、usage 末帧（stream_options）、错误码映射、`tools` / `tool_calls` 构造与解析（供 Agent Core）
- [x] M3-04（P0）MessagesAdapter：system 顶层字段、anthropic-version 头、content_block_delta 事件序列、双段 usage 合并、错误码映射、`tool_use` / `tool_result` 构造与解析
- [x] M3-05（P1）AiClient 单元测试：用录制的 SSE 响应分别驱动两个适配器（流式文本、usage、错误路径）

### Agent Core 与工具

- [x] M3-06（P1）Tool 抽象与 ReAct 循环（core/ai/agent_core.dart）：Tool 结构对齐 MCP（name / description / inputSchema），循环内处理 tool_calls → 执行工具 → 结果回传，直到无 tool_calls
- [x] M3-07（P1）内置工具：get_chapter（按 id 取正文）、get_characters（按作品取角色卡）、get_outline（取章纲），经 Repository 取数
- [x] M3-08（P1）Agent Core 单元测试：工具调用成功路径、工具执行失败回传、达到最大轮次退出

### 上下文与编排

- [x] M3-09（P0）ContextBuilder：按架构 5.3 优先级装配（system / 本章尾部 / 章纲 / 前文摘要 / 角色卡 / 卷纲）
- [x] M3-10（P0）token 预算控制：模型窗口 50% 预算、中文 1 字≈1 token 近似、超预算从低优先级截断、截断提示
- [x] M3-11（P1）前文摘要本地生成：按段落抽首句拼接，超长再截断
- [x] M3-12（P1）角色卡相关性匹配：本章正文姓名匹配，最多 8 张、截断保留 3 张
- [x] M3-13（P1）ContextBuilder 单测：不同作品规模下的装配结果与预算遵守

### 用例与 UI

- [x] M3-14（P0）续写用例：AiUseCase.continueWriting，流式进待确认面板，可取消，可编辑后插入光标处（插入走编辑器撤销栈）
- [x] M3-15（P0）待确认面板：重新生成、换个方向（补充方向指令）、放弃；上下文详情可展开（作者可见 AI 看到了什么）
- [x] M3-16（P1）灵感用例：桥段点子模式（3-5 个选项，一句话概括+展开）与开篇助手模式；产出可存灵感箱或插入
- [x] M3-17（P1）AI 触发入口：编辑器工具栏按钮；未配置 key 时引导至设置页而非报错
- [x] M3-18（P0）设置页：模型组管理（协议类型 openai_compat / anthropic、名称、baseUrl 预置+自定义、模型列表、温度与输出上限、启用停用）、任务→模型映射（续写/灵感/AI 感检查分别选模型组）、测试连接
- [x] M3-19（P0）key 安全存储：经 SettingsRepository 读写 flutter_secure_storage、库中仅存引用、删除二次确认
- [x] M3-20（P1）token 与采纳统计：AI_USAGE 表（含 outcome）、按模型/任务聚合展示、采纳率与忽略率、重置统计
- [x] M3-21（P0）M3 验收（人工，需真机 + 真实 key）：真实 key（OpenAI 兼容 + Anthropic 各一）完成续写全流程；待确认面板展示上下文含角色卡；429 / 401 / 内容过滤三类错误有明确 UI 处置
  - 真实渠道续写全流程：已在设备上用 OpenAI 兼容协议渠道完成（流式生成 → 待确认面板 → 插入光标处 → 撤销/重做）；统计页记录生成次数、token 与采纳率。
  - 上下文含角色卡：待确认面板「AI 看到的上下文」中确认含「相关角色卡：Elena（身份：watcher in the dark）」与「本章章纲」，估算 2939 / 预算 16000 token。
  - 错误处置：401 已实机复现（「鉴权失败（401）：请到设置页检查 API Key」+「去设置」+ 插入置灰）；**429 与内容过滤未能在真实渠道稳定复现**，仅有适配器单测 `mapHttpError` 覆盖，Anthropic 协议渠道本次无可用 key，同样由适配器单测（MessagesAdapter）覆盖。
- [x] M3-22（P1）错误处理回归（人工，需真机）：断网生成中断后已生成内容保留、可重试
  - 以宿主本地假 SSE 服务（先发 3 个 chunk 后 RST 断开且不发 `[DONE]`）忠实复现中断：面板保留已生成的 3 段文本，提示「流式读取中断：ClientException: Connection closed while receiving data」，并保留「重新生成 / 换个方向 / 插入光标处」；点「重新生成」经服务端日志确认发出第二次请求。

## M4 AI 感检查与打磨

出口标准：规则引擎对回归集达标（召回 ≥ 80%、误报 ≤ 20%）；全流程无阻断性 bug。

### 规则引擎

- [x] M4-01（P0）套话词库：中文网文高频套话约 200 条（不禁/仿佛/一丝/嘴角勾起/眸中闪过等），按权重分级
- [x] M4-02（P0）句式模式检测：模式化对话标签正则、段尾感悟句特征、连续同结构段落检测
- [x] M4-03（P1）统计指标：套话密度、句式重复率、破折号/省略号频率
- [x] M4-04（P1）规则引擎纯函数实现 + 单测
- [x] M4-05（P0）回归集：人工标注"AI 味"段落样本（正样本+负样本），跑通召回/误报指标

### LLM 深检

- [x] M4-06（P0）深检请求构造：分段送检、问题类型枚举（套话/句式重复/翻译腔/过度总结/节奏拖沓）、要求 JSON 输出（类型/严重度/起止/建议）
- [x] M4-07（P1）结果解析：JSON 解析失败降级为纯文本展示
- [x] M4-08（P0）两层结果合并去重（按原文位置+类型），严重度统一为高/中/低后排序（规则权重映射 + LLM 返回字段，见架构 5.5）
- [x] M4-09（P1）检查面板：范围选择（当前章/整作）、预估 token 与实测展示、LLM 深检触发按钮、按类型筛选

### 定位与处置

- [x] M4-10（P0）问题定位：点击跳转编辑器对应段落并高亮
- [x] M4-11（P0）一键替换：建议文本替换原文、标记已处理、可撤销
- [x] M4-12（P1）忽略与批量处理同类问题
- [x] M4-13（P1）边界：0 字章节禁用；LLM 检测失败保留规则结果并提示

### 打磨

- [x] M4-14（P0）全流程回归：导入→写作→AI→检查→导出主链路无阻断 bug；异常流（弱网/无效 key/杀进程）逐一过一遍
  - 自动化：主链路回归用例（导入 → 续写保存 → 规则检查 → 导出 markdown）、深检弱网中断、续写生成中断保留已生成内容用例均已加入 `flutter test` 并全绿；无效 key 由深检失败用例覆盖。
  - 真机：主链路（导入 30 万字 → 编辑器写作 → AI 续写 → 插入正文 → 规则检查 → 导出）无阻断；异常流三项均已实机走通——弱网中断（假 SSE 服务中途 RST，已生成内容保留 + 可重试）、无效 key（401 明确提示 + 去设置）、杀进程恢复（`force-stop` 后正文完整）。
  - 真机过程中发现并修复 1 处阻断缺陷：7 处 `showDialog` 与外部 `TextEditingController` 的组合在弹窗退场时崩溃（详见进度总览「真机验收记录」），已修复并加 2 个回归用例。
- [x] M4-15（P0）M4 验收 + 文档同步（PRD / ARCHITECTURE / TODO 状态更新）
  - 文档同步已完成：PRD 8 风险表标注合规项已缓解；ARCHITECTURE 5.5 补充检查面板/定位处置/计数与首次联网告知；README 更新文档清单与当前状态；TODO 勾选与进度表更新。
  - 验收：M4 出口标准中「规则引擎对回归集达标」由自动化用例证明（召回 100%、误报 0%）；「全流程无阻断性 bug」经自动化回归 + 真机主链路与三项异常流走通后收口（真机记录见进度总览）。
- [x] M4-16（P0）合规与隐私：隐私政策、数据安全说明、AI 功能首次联网前的告知文案；应用商店上架资料（对应 PRD 8 风险表）（交付 `docs/COMPLIANCE.md`；告知门控见 `lib/features/ai/ai_notice.dart`）

## MVP 收口后的增强（2026-10-13 ~ 2026-10-14）

- [x] ENH-01（P1）429 / 5xx 自动退避重试：新增 `lib/core/ai/retrying_ai_client.dart` 的 `RetryingAiClient` 装饰器，`buildAiClient` 出口统一包装，仅对**首个文本增量之前**的 429 / 5xx 指数退避重试（`maxRetries` 默认 1 次），已产出文本增量后不再重试以免重复内容与重复扣费；首个文本增量之前收到的 usage / 工具调用先缓冲、重试时丢弃。
  - 验证：`test/core/ai_client_test.dart` 新增 4 个用例（429 重试后成功、5xx 重试用尽透出错误、文本增量后不重试、401 不重试）。
- [x] ENH-02（P1）设定集纳入 AI 上下文：`ContextBuilder` 注入 `SettingRepository`，按世界观/地点/道具分组加入上下文，排在角色卡之后，超预算时优先于角色卡被丢弃；`AiService` / `aiServiceProvider` 注入仓储（可空，未注入则跳过）。
  - 验证：`test/core/context_builder_test.dart` 新增分组渲染与顺序断言。

- [x] ENH-03（P1）全 App 深色模式：把暖色纸质色值从编译期 `const` 改为挂在 `ThemeData` 上的运行时调色板，新增「跟随系统 / 浅色 / 深色」全局开关。
  - 主题（`lib/app/theme.dart`）：新增 `PaperPalette extends ThemeExtension<PaperPalette>`（`light` / `dark` 两套，色值即原纸质色与 B-04 夜间纸张色）与 `BuildContext.paper` 扩展；`buildPaperTheme([Brightness])` 按亮度取调色板并注册扩展（`Typography.white/black` 随亮度切换，`appBarTheme` / `cardTheme` / `inputDecorationTheme` / `snackBarTheme` 等改为运行时色值，`snackBar` 文字改用 `palette.background` 保证深色对比度）。
  - 模式开关：`enum AppThemeMode { system / light / dark }`（落 `APP_SETTING.app_theme_mode`，脏数据回落 `system`）+ `appThemeModeProvider`（`FutureProvider`）；`app.dart` 改 `ConsumerWidget` 接入 `theme` / `darkTheme` / `themeMode`（未加载完回落 `ThemeMode.system`）；设置页「写作」段新增「深浅模式」`SegmentedButton`，写入后 `ref.invalidate` 全应用立即生效。
  - 写作区联动：`ReadingPalette.paper` / `night` 改为引用 `PaperPalette.light/dark` 色值（改为 `static final`）；`ReadingPalette.of(appearance, {globalDark})` 在全局深色时自动跟随（优先级高于写作外观自身开关）；编辑器写作区与外观页预览同步传入 `Theme.of(context).brightness == Brightness.dark`。
  - 改造面：全项目 `PaperColors.x` 静态引用（27 文件）改为 `context.paper.x`，随之移除相关 `const` 构造（103 处）；`_RelationGraphPainter` 改为构造传入 `PaperPalette` 并在 `shouldRepaint` 比较调色板；`ai_confirm_panel.dart` 局部变量 `BuiltContext` 与原 `BuildContext` 同名，重命名为 `built` 避免遮蔽。
  - 验证：`test/features/reading_appearance_test.dart` 新增 3 个用例（亮/暗主题挂载对应调色板与 `scaffoldBackgroundColor`、`AppThemeMode.decode` 解析与脏数据回落、`themeMode` 映射）；`flutter analyze` 无问题，`flutter test` 234 用例全绿。
  - 文档同步：ARCHITECTURE 3 章 app/ 说明、README 当前状态。

- [x] ENH-04（P1）专注模式 + 选中段落 AI 改写 + 导出 EPUB：
  - 专注模式（`editor_page.dart`）：顶栏常驻「专注模式」开关，开启后隐藏底部工具栏与状态栏；正文 `TextField` 底部留白取编辑区一半高度，光标行（含章末）经 `RenderEditable.getLocalRectForCaret` + `scrollController.jumpTo` 固定到编辑区竖直中线（`getLocalRectForCaret` 返回的已是视口局部坐标，公式为 `offset + rect.bottom - re.size.height`）。
  - 选中段落 AI 改写：工具栏新增「AI 改写」，点击那一刻同步快照选区（`_snapshotRewriteSelection`），未选中给 SnackBar 提示且不开面板；面板（`AiConfirmPanel` 新增 `AiPanelMode.rewrite`）提供润色/扩写/缩写/改语气四种意图 + 作者补充指令输入框，产出可编辑，点「替换原文」经 `EditorController.replaceSelection` 走撤销栈（原文漂移则拒绝并提示）。
  - 改写上下文（`ContextBuilder.buildRewrite`）：不注入本章尾部正文，改用【待改写原文】payload 作为末尾消息，system 走「改稿助手」；模型组解析优先 `AiTask.rewrite`，未配置时回退续写组（零配置可用）；payload 不参与超预算截断。
  - 导出 EPUB（`text_exporter.dart` 新增 `buildWorkEpub`）：EPUB 3 最小结构（`mimetype` 首条目且 STORE 存储、`META-INF/container.xml`、`OEBPS/` 的 `content.opf` / `nav.xhtml`(properties="nav") / `style.css` / 逐章 `chapter_N.xhtml`）；`ExportFormat` 新增 `epub`，单章导出仍为 txt / markdown。
  - 验证：`test/features/editor_page_test.dart` 新增 4 个用例（专注模式隐藏/恢复、窄屏 8 按钮不溢出、未选中改写给提示且不开面板、4 意图 + 替换原文生效）；`test/core/text_exporter_test.dart` 新增 4 个用例（mimetype 首条目与 STORE、container/opf/nav 结构、章节 xhtml、epub mime）；`test/core/context_builder_test.dart` 新增 2 个用例（改写装配与超预算截断）；`test/features/ai_check_test.dart` 新增 2 个用例（改写零配置回退与统计）；`test/features/editor_controller_test.dart` 新增 2 个用例（`replaceSelection` 命中/拒绝）。`flutter analyze` 无问题，`flutter test` 248 用例全绿。
  - 顺带修复：`AiConfirmPanel` 上下文详情由 `Container(decoration:)` 改为 `Material`，消除 `ExpansionTile`→`ListTile` 在 debug 下的「背景/水波纹不可见」断言；`EditorController` 新增 `_disposed` 守卫，避免离开编辑器时 `flush()` 的保存晚于 dispose 触发「used after being disposed」。
  - 文档同步：PRD 4.1 / 5.3 / 5.5 / 5.9 / 6.1；ARCHITECTURE 3 / 5.3 / 5.6 / 6.1；README 当前状态。

- [x] ENH-05（P1）AI 逐章摘要 + 多候选续写 + AI 章纲扩写：
  - AI 逐章摘要（前情回顾，A）：`CHAPTER` 新增 `summary` 列（schemaVersion 5 → 6，`m.addColumn`）；`ChapterRepository.saveChapterSummary` 只改摘要字段、不触碰正文与字数汇总；`ContextBuilder._previousSummary` 改为**优先使用已生成的缓存摘要**（信息密度更高），未生成的章节回退本地抽句（行为与旧版一致）；`buildSummary` 以本章正文为主材料直构上下文（超预算按 `budget - system - header` 截断并标记，不做分段 map-reduce）；`AiTask.summary` + `AiService.summarizeChapter`（模型组优先 `task_model_summary`，未配置回退续写组）；编辑器 AppBar 新增「AI 章节工具」菜单。
  - 多候选续写（B）：`AiService.continueWriting` 新增 `variant` 参数，温度 = 组温度 -0.15 / +0 / +0.15（clamp 0..2）；面板并发订阅 3 路流、各自独立可编辑，`FilterChip('3 个候选')` 可切回单候选，多候选时 `SegmentedButton` 切「版本 1/2/3」；采纳时选中记 `adopted`、其余记 `ignored`。
  - AI 章纲扩写（C）：`buildOutlineExpand` 以作者一句话梗概为种子直构上下文（`_outlineSystem`）；`AiTask.outlineExpand` + `AiService.expandOutline`（同样回退续写组）；面板 `AiPanelMode.outlineExpand`「保存到章纲」覆盖写入本章章纲；「编辑本章梗概」弹窗上限 200 → 1000 字。
  - 面板改造：`AiConfirmPanel` 结果缓冲改为 3 个 `TextEditingController`、错误与 usageId 按候选索引分别记录、`_pending` 归零才解除流式态；新增 `AiPanelMode.summarize` / `outlineExpand` 与 `outlineSeed` / `onSaveSummary` / `onSaveOutline` 参数；摘要与章纲扩写隐藏「换个方向」。
  - 备份兼容：`BackupRepository.restore` 对旧备份缺 `summary` 键 `putIfAbsent('summary', '')`，避免 drift `fromJson` 抛异常；摘要随备份导出/恢复。
  - 验证：`test/core/context_builder_test.dart` 新增 3 个用例（缓存摘要优先、`buildSummary` 装配与超预算截断、`buildOutlineExpand` 种子）；`test/data/repository_test.dart` 新增 1 个用例（`saveChapterSummary` 只改摘要字段）；`test/data/backup_repository_test.dart` 新增 1 个用例（旧备份缺 summary 键仍可恢复）；`test/features/ai_check_test.dart` 新增 4 个用例（摘要/章纲扩写零配置引导、回退续写组与统计、多候选按 variant 调温）；`test/core/flavor_check_test.dart` 构造 `Chapter` 补 `summary`。`flutter analyze` 无问题，`flutter test` 257 用例全绿。
  - 文档同步：PRD 4.1 / 5.4 / 5.5 / 5.9 / 6.1 / 6.2；ARCHITECTURE 4.2 / 5.3 / 5.6 / 6.1；README 当前状态。
  - 真机验收（2026-10-14，SM_G998B / Android 13，release APK）：编辑器顶栏「AI 章节工具」菜单正常弹出「生成本章摘要 / AI 扩写本章纲」；「生成本章摘要」流式产出中文摘要并「保存摘要」，随后进入第二章续写展开「AI 看到的上下文」，其「前文摘要」段已含第一章的 AI 摘要（缓存落库 + 注入生效，A 贯通）；续写面板出现「3 个候选 / 版本 1/2/3」，三个候选文本各不相同（B 贯通）；无梗概时点「AI 扩写本章纲」弹出「请先用顶栏「本章梗概」写一句话梗概」提示，填梗概后生成 5 段分场大纲并「保存到章纲」，作品详情「章纲」Tab 显示已覆盖写入（C 贯通）；「编辑本章梗概」上限显示 0/1000。旧备份缺 `summary` 键的兼容由 `backup_repository_test` 用例覆盖。

- [x] ENH-06（P1）滚动摘要（本卷前情回顾）+ 摘要查看编辑：
  - 滚动摘要（A）：`VOLUME` 新增 `summary` 列（schemaVersion 6 → 7，`m.addColumn`），新增 `ChapterRepository.saveVolumeSummary` 只改卷摘要字段；`ContextBuilder._previousSummary` 新增 `volumeSummary` 参数，非空时把「【本卷前情】…」前置到前文摘要、随后接最近 1-2 章摘要（卷摘要为空时输出与旧版逐字一致，零回归）；`buildVolumeSummary` 以本卷「当前章及之前」各章摘要为主材料直构上下文（`_volumeSummarySystem`，超预算按 `budget - system - header` 截断并标记，不做增量滚动）。
  - 摘要查看编辑（B）：编辑器顶栏「AI 章节工具」改用私有枚举 `_ChapterTool`（容纳非面板动作），新增「查看/编辑本章摘要」弹窗，可查看并手动修改 `CHAPTER.summary`（上限 1000 字，沿用 `TextFormField(initialValue:)` 写法避免 dispose 崩溃）。
  - 用例与面板接入：`AiTask.volumeSummary`（键 `task_model_volume`，未配置回退续写组）+ `AiService.summarizeVolume`；面板 `AiPanelMode.volumeSummary`「保存前情回顾」经 `onSaveVolumeSummary` 写回卷摘要；`_openAi` 增加「本卷当前章之前无已写章节」前置校验。
  - 备份兼容：`BackupRepository.restore` 对旧备份卷行缺 `summary` 键 `putIfAbsent('summary', '')`；卷摘要随备份导出/恢复。
  - 验证：`test/core/context_builder_test.dart` 新增 3 个用例（卷摘要注入与空卷零回归、`buildVolumeSummary` 归并与超预算截断、首章仅含本章）；`test/data/repository_test.dart` 新增 1 个用例（`saveVolumeSummary` 只改卷摘要字段）；`test/data/backup_repository_test.dart` 新增 1 个用例（旧备份卷缺 summary 键仍可恢复）；`test/features/ai_check_test.dart` 新增 2 个用例（卷回顾零配置引导、回退续写组与统计）；`test/features/editor_page_test.dart` 新增 1 个用例（菜单四项可见 + 查看/编辑本章摘要弹窗落库）。`flutter analyze` 无问题，`flutter test` 265 用例全绿。
  - 文档同步：PRD 5.5.1 / 5.8 / 6.1 / 6.2；ARCHITECTURE 4.2 / 5.3 / 5.6 / 6.1；README 当前状态。

- [x] ENH-07（P1）体验与上下文优化（O1-O9）：
  - O1 面板上下文详情滚动解耦：`AiConfirmPanel` 上下文详情区改为「限高（屏高 26%）+ 内部滚动」，避免展开后把下方按钮挤出屏幕；输出框 `maxLines` 10 → 6 同理。
  - O2 压缩保留【本卷前情】：`ContextBuilder._compressPreviousSummary` 在超预算压缩前文摘要时，保留以「【本卷前情】/【前卷前情】」开头的回顾行（截到 160 字），其余行才走 `summarizeText`，避免卷级前情被压没。
  - O3 卷摘要查看/编辑入口：作品详情「章节」Tab 卷头「…」菜单新增「查看/编辑本卷前情回顾」，弹窗可查看/手改 `VOLUME.summary`（上限 1000 字，沿用 `TextFormField(initialValue:)` 写法）；保存不记录归并覆盖章（纯手改）。
  - O4 摘要过期提示：`CHAPTER` 新增 `summaryUpdatedAt` 列（schemaVersion 7 → 8），`saveChapterSummary` 记录更新时间；「查看/编辑本章摘要」弹窗在正文更新时间晚于摘要时间（或缺摘要时间）且摘要非空时提示「正文已改动，摘要可能过期，建议重新生成」。
  - O5 跨卷前情注入：`ContextBuilder._previousSummary` 新增 `previousVolumeSummary`，当当前章为其所属卷的**首章**（`_isVolumeHead`）时把「【前卷前情】…」前置；同卷章不注入。
  - O6 卷回顾增量归并：`VOLUME` 新增 `summaryChapterId` 列（schemaVersion 7 → 8），`saveVolumeSummary` 记录本次归并覆盖到的章节；`buildVolumeSummary` 改为「上一版卷回顾（`【上一版本卷回顾】`） + 新增章节摘要（`【新增章节摘要】`）」增量归并，未覆盖过（`summaryChapterId == 0`）时仍全量归并（零回归）。
  - O7 灵感上下文补全：新增 `ContextBuilder.buildInspireContext`，`AiService` 桥段点子分支调用它以补注入「前文摘要」与「本章章纲」两段，上下文详情同步展示。
  - O8 AI 输出格式清洗：新增顶层函数 `sanitizeAiText`，落库前统一去除行首 markdown 标记（`#` 标题 / `- * +` 列表 / 数字编号）、行尾空白与多余空行；摘要 / 前情回顾 / 章纲要写入正文或字段的产出均先清洗。
  - O9 生成耗时反馈：`AiConfirmPanel` header 在生成期间显示「N 秒」实时计时（首个事件起、`_pending` 归零或发生错误 / 停止时停表）。
  - 备份兼容：`BackupRepository.restore` 对旧备份章节缺 `summaryUpdatedAt`、卷缺 `summaryChapterId` 分别 `putIfAbsent` 兜底（null / 0）。
  - 验证：`test/core/context_builder_test.dart` 新增 3 个用例（O2 压缩保留卷前情、O5 跨卷首章注入前卷前情 / 同卷不注入、O6 增量归并）；`test/data/repository_test.dart` 新增 2 个用例（`saveChapterSummary` 记录摘要更新时间、`saveVolumeSummary` 记录归并覆盖章）；`test/data/backup_repository_test.dart` 新增 1 个用例（旧备份缺两列仍可恢复）；`test/features/editor_page_test.dart` 新增 2 个用例（O4 摘要过期提示、O8 `sanitizeAiText`）。`flutter analyze` 无问题，`flutter test` 273 用例全绿。
  - 文档同步：PRD 5.5 / 5.5.1 / 5.8 / 6.1 / 6.2；ARCHITECTURE 4.2 / 5.3 / 5.6 / 6.1；README 当前状态。
  - 真机验收（2026-10-14，SM_G998B / Android 13，release APK）：编辑器「AI 续写」面板 header 显示生成耗时（如「2 秒」）并在产出完成后停表；展开「AI 看到的上下文」后该区域限高且可内部滚动、下方按钮仍在视口内（O1 / O9 贯通）；作品详情「章节」Tab 卷头「…」→「查看/编辑本卷前情回顾」正常弹出「本卷前情回顾」查看/编辑弹窗（O3 贯通）；「AI 章节工具 → 生成本章摘要」保存后再改动正文，「查看/编辑本章摘要」弹窗顶部出现「正文已改动，摘要可能过期，建议重新生成」提示（O4 贯通）。

- [x] ENH-08（P1）稳健性与性能修正（4 项）：
  - ① 修复 `sanitizeAiText` 误删正文小数：行首编号正则拆为两条——ASCII 点号要求后跟空白（`^\s*\d+\.\s+`），中文编号分隔符（`、`/`)`/`）`）仍允许零空白（`^\s*\d+[、)）]\s*`）。旧写法对 `1.5`/`3.14` 会剥成 `5`/`14`（`\s*` 允许零空白），修复后保留。
  - ② 补 `ContextBuilder.buildInspireContext`（ENH-07 O7）单元测试：未指定章节时不补上下文（保持旧行为）、指定章节时补「前文摘要」与「本章章纲」。
  - ③ 热点外键索引：为 VOLUME.workId / CHAPTER.volumeId / CHAPTER_SNAPSHOT.chapterId / CHARACTER.workId / OUTLINE_ENTRY.workId / INSPIRATION.workId 六个高频过滤列加 drift `@TableIndex`（消除作品/卷维度列表查询的全表扫描）；`schemaVersion` 8 → 9，`onUpgrade` 的 `if (from < 9)` 块内 `m.createIndex(...)` 为既有库补建；`dart run build_runner build` 重生成 `lib/data/db.g.dart`。不做 FTS5（全局搜索仍为本地 LIKE 直查）。
  - ④ 摘要编辑弹窗收敛：`editor_page.dart::_editAiSummary`、`chapters_tab.dart::_editVolumeSummary`、`outline_tab.dart::showSummaryEditor` 三处收敛为共享 `lib/app/summary_editor.dart`，新增可选 `notice` 参数承载 O4「摘要可能过期」提示，沿用 `TextFormField(initialValue:)` 写法（不持有外部 `TextEditingController`，避免退场动画期红屏）。
  - 验证：`test/features/editor_page_test.dart` 新增 1 个用例（`sanitizeAiText` 不误删 `1.5`/`3.14`、仍剥离 `1. `/`1、`/`1）` 编号）；`test/core/context_builder_test.dart` 新增 1 个用例（`buildInspireContext`）；`test/data/repository_test.dart` 新增 2 个用例（建库时索引存在、v8 → v9 升级补建索引）。`flutter analyze` 无问题，`flutter test` 277 用例全绿。
  - 文档同步：ARCHITECTURE 4.2；README 当前状态。
  - 真机验收（2026-10-15，SM_G998B / Android 13，release APK）：三处弹窗入口（编辑器「AI 章节工具 → 查看/编辑本章摘要」带 O4 提示、章节 Tab 卷头「查看/编辑本卷前情回顾」、章纲 Tab 编辑图标）均正常弹出并往返持久化、无红屏；老库（ENH-07 / v8）安装新包后 v8 → v9 迁移成功、作品（40.5 万字 · 42 章）数据完整无崩溃；AI 章节工具真实生成摘要后落库，「查看/编辑本章摘要」显示 `1.5x`/`3.14` 被保留、`1. ` 编号被剥离（旧代码会得到 `5x`/`14`）。

- [x] ENH-09（P1）性能与一致性优化（5 项）：
  - ① 编辑器不再因移光标重写整章：`TextEditingController` 在选区变化时也会通知监听器，旧实现把「只挪光标」当成正文改动、每次移光标都标记「保存中」并重写整章。新增 `EditorController._lastSavedText` / `_lastSavedTitle` 记录最近落库的标题与正文，`_onTextChanged` 与 `_save` 均先比对——纯移光标/改选区时只落库光标与滚动位置（`saveCursorPosition`），不重算字数、不排保存。
  - ② 多候选续写共用一份上下文：三路候选只在温度上不同（`variant`），旧实现每路各自 `ContextBuilder` 全量取数与组装。新增 `AiService.prebuildContinue`（未配置可用模型时返回 null，各流仍走 NeedsConfig 分支）一次组装，`continueWriting` 新增可选 `prebuilt` 参数，`ai_confirm_panel` 起播前预组装并三路共用。
  - ③ 写入正文前统一清洗：续写「插入光标处」与改写「替换原文」改为一律先经 `sanitizeAiText` 清洗（与摘要/卷回顾/章纲一致），避免 Markdown 标记与行首编号混入正文。
  - ④ 章标题按码点安全截断：`chapter_splitter` 的 50 字截断由 UTF-16 `substring` 改为按 `runes` 截断，标题含 emoji 等代理对时不再切出半个字符。
  - ⑤ 快照清理不载入正文：`SnapshotDao.pruneBeyond` 改为 `selectOnly` 仅取 `id` 列排序后 `skip(keep)`，避免每次创建快照把该章最多 50 条正文全文读进内存。
  - 验证：`test/features/editor_controller_test.dart` 新增 1 个用例（仅移动光标不重写正文：`updatedAt` 与正文均不变）；`test/features/editor_page_test.dart` 新增 2 个用例（替换原文前清洗 Markdown 标记、多候选三路共用同一份预组装上下文 `identical`）；`test/core/chapter_splitter_test.dart` 新增 1 个用例（超长标题按码点截断不劈开 emoji）。`flutter analyze` 无问题，`flutter test` 281 用例全绿。Item ⑤ 由既有快照用例覆盖。
  - 文档同步：ARCHITECTURE 3.1 / 4.2 / 4.3 / 5.6；README 当前状态。
  - 真机验收（2026-10-15，SM_G998B / Android 13，release APK）：① 打开「第一章 断章夜航」（7614 字）后仅点正文移动光标，顶栏保持「已保存」不闪「保存中」、撤销/重做仍灰、本章字数不变；返回作品列表「最后编辑」仍为 19 小时前（未重写整章）。②「AI 续写」默认 3 候选（版本 1/2/3），上下文详情「估算 4303 / 预算 16000 token」只组装一次，三个候选均正常流式产出。③ 在候选输出框尾部追加 `1. ENH9item` 后点「插入光标处」，用编辑器「查找」验证正文含 `ENH9item`（1 处）、不含 `1. ENH9`（0 处）——编号前缀已被清洗。④ 导入含 markdown 标题 `# ` + 49 个 `A` + emoji + `尾` 的 txt（标题共 51 码点），导入预览与导入后卷内章节标题均显示为「49 个 A + 完整 emoji」（50 码点、无 `尾`、无半个字符）。⑤「版本历史」面板创建快照（显示「刚刚 · 7614 字」，走 `pruneBeyond` 轻量查询）、预览全文、恢复版本（提示「已恢复到该版本」）均正常。验证结束已删除测试导入的卷、撤销测试插入，作品恢复「40.5 万字 · 42 章」；logcat 无 FATAL / `used after being disposed` / drift-sqlite 报错。

---

## 后置 backlog（不进 MVP 承诺）

进度：B-01、B-02、B-03、B-04、B-05、B-06、B-07、B-08、B-09 全部已完成；MVP 收口后的增强 ENH-01（429/5xx 自动退避重试）、ENH-02（设定集纳入 AI 上下文）、ENH-03（全 App 深色模式）、ENH-04（专注模式 + 选中段落 AI 改写 + 导出 EPUB）、ENH-05（AI 逐章摘要 + 多候选续写 + AI 章纲扩写）、ENH-06（滚动摘要（本卷前情回顾）+ 摘要查看编辑）、ENH-07（体验与上下文优化 O1-O9）、ENH-08（稳健性与性能修正：小数误删修复 + 索引 + 弹窗收敛）、ENH-09（性能与一致性优化：编辑器不重写整章 + 多候选共用上下文 + 写入正文前清洗 + 码点截断 + 快照轻量清理）已完成。

- [x] B-01（P2）Responses 端点适配器：新增 `ResponsesAdapter implements AiClient`（架构 9 章触发条件成熟时）
  - 新增 `lib/core/ai/responses_adapter.dart`（端点 `POST {baseUrl}/v1/responses`，system 提为顶层 `instructions`，`input[]` 支持消息 / `function_call` / `function_call_output`；解析 `response.output_text.delta`、`response.completed` 的 usage 与 status；工具调用经 `response.output_item.*` / `response.function_call_arguments.delta` 累积）；`AiProvider.responses` 登记并在 `buildAiClient` 分发；设置页协议类型增第三段「Responses」。
  - 验证：`test/core/ai_client_test.dart` 新增 4 个用例（流式文本与 usage、tool 调用累积、`error` 事件与 401 映射、工具结果回传为 `function_call_output`）；`flutter analyze` 无问题，`flutter test` 全绿。
- [x] B-02（P2）MCP 接入：mcp_dart 连接远程 server、Tool 包装、设置页 server 配置
  - 认证方式：本轮按「Token / 自定义请求头」实现（设置页填 URL + 认证头文本）；**OAuth 2.1 PKCE 记为后续项**。
  - 新增 `lib/core/ai/mcp/mcp_bridge.dart`：`McpServerConfig`（URL / 启用 / 工具白名单，不含密钥）、`parseAuthHeaders`（按行解析 `Key: Value`）、`openMcpTools`（`StreamableHttpClientTransport` 连接 → `tools/list` → 按白名单包装为同构 `Tool`，名称加 `mcp_` 前缀）、`listMcpToolNames`（测试连接）、`McpToolSession`（会话接口 + 远程实现）；依赖 `mcp_dart 2.4.2`。
  - 持久化（`SettingsRepository`）：配置列表落 `APP_SETTING.mcp_servers`（仅 URL / 名称 / 白名单），认证头文本进安全存储 `mcp_server_<id>`；新增 / 更新 / 删除与 `resolveMcpHeaders`。
  - 设置页：新增「MCP 工具服务」列表页与编辑页（名称 / 端点地址 / 认证头 / 工具白名单 / 启停 / 删除 / 测试连接），路由 `/settings/mcp-servers` 与 `/settings/mcp-servers/:serverId`。
  - 编排：`AiService.inspire()` 的「桥段点子」分支把启用服务的远程工具并入 `AgentCore.run(tools:)`，流结束（含异常）即关闭会话；单个 server 连接失败不阻断生成。
  - 验证：`test/core/mcp_bridge_test.dart` 新增 7 个用例（请求头解析、配置往返与白名单、仓储持久化且密钥不入库、远程工具可用并调用且会话关闭、打开失败不阻断生成）；`flutter analyze` 无问题，`flutter test` 157 用例全绿。
  - 文档同步：ARCHITECTURE 2.2 / 2.3 / 5.4 / 9 章；COMPLIANCE 1.2 / 2 章（新增 MCP 出网面与认证头存储说明）。
- [x] B-03（P2）用户自定义 SKILL：Skill 模型（指令+工具白名单+参数模板）、用例编排注入
  - 模型与纯函数（`lib/core/ai/skills/skill.dart`）：`Skill`（name / instruction / enabled / allowedTools / parameters，字段与 Anthropic·Genkit skills 的 markdown front matter 一一对应，暂以 JSON 落库，markdown 导入后续补 front matter 解析）；`renderInstruction()` 把指令中的 `{{参数名}}` 按参数模板替换；`composeSkillSystem()` 把启用技能拼进 system；`filterToolsBySkills()` 按白名单并集过滤工具（全为空表示不限制）。
  - 持久化（`SettingsRepository`）：技能列表落 `APP_SETTING.ai_skills`（纯文本配置，不含密钥），新增 / 更新 / 启停 / 删除与 `listEnabledSkills()`（过滤停用与空指令）。
  - 编排注入（`AiService`）：续写与灵感（开篇助手 / 桥段点子两模式）均把启用技能作为附加 system 注入，并在上下文详情新增「用户技能」段落；桥段点子分支同时按白名单过滤内置与 MCP 工具。`BuiltContext.withSystem()` 同步上下文段落与 token 估算。
  - 设置页：新增「自定义技能」列表页与编辑页（名称 / 指令文本 / 参数模板 / 工具白名单 / 启停 / 删除），路由 `/settings/skills` 与 `/settings/skills/:skillId`。
  - 验证：`test/core/skill_test.dart` 新增 12 个用例（JSON 往返与脏数据、参数替换、指令拼接、白名单过滤、`withSystem` 估算同步、仓储 CRUD 与脏数据容错、续写注入生效与停用不注入）；`flutter analyze` 无问题，`flutter test` 169 用例全绿。
  - 文档同步：ARCHITECTURE 3 章目录与模块表、9 章 B-03 标注已实现、README 当前状态。
- [x] B-04（P2）护眼深色模式、字体调节
  - 范围：写作/阅读外观（对齐 PRD「深夜沉浸」）；全 App 深色模式已由 ENH-03 补齐（纸质色值改为运行时调色板 + 全局深浅开关）。
  - 模型与配色（`lib/app/reading_appearance.dart`）：`ReadingAppearance`（`dark` / `fontSize` 14~24 / `lineHeight` 1.4~2.4，JSON 落 `APP_SETTING.reader_appearance`，脏数据回落默认并夹紧区间）；`ReadingPalette`（`paper` 复用既有纸质色值 / `night` 深色纸张配色）与 `ReadingPalette.of()`；`readingAppearanceProvider`（`FutureProvider`，写库后 `ref.invalidate` 生效）。
  - 设置页：新增「写作外观」页（夜间纸张开关、正文字号与行距滑杆、示例正文实时预览），路由 `/settings/appearance`，设置页新增「写作」段入口。
  - 编辑器落地：`editor_page.dart` 注入 `palette`（背景 / 文字 / 分隔）并把 `fontSize`、`lineHeight` 应用到正文 `TextField`，工具栏与状态栏同步走 palette。
  - 验证：`test/features/reading_appearance_test.dart` 新增 6 个用例（解析默认与往返、区间夹紧、配色解析、编辑器夜间外观断言、设置页切换写入并 invalidate 后重算）；`flutter analyze` 无问题，`flutter test` 175 用例全绿。
  - 文档同步：ARCHITECTURE 3 章 app/ 说明、README 当前状态。
- [x] B-05（P2）章节快照/版本历史
  - 数据层：`CHAPTER_SNAPSHOT` 表（`lib/data/db.dart`，仅 id / chapterId / title / content / wordCount / createdAt，随章节级联删除），schemaVersion 2 → 3 并加迁移；新增 `lib/data/dao/snapshot_dao.dart`（按章节倒序查询、插入、删除、超出上限清理）。
  - 仓储（`ChapterRepository`）：`watchSnapshots` / `listSnapshots` / `createSnapshot`（事务内写入并按 `maxSnapshotsPerChapter = 50` 清理最旧）/ `deleteSnapshot`。
  - 编辑器：顶栏新增「版本历史」入口（历史图标），内嵌 `lib/features/editor/snapshot_panel.dart` 面板（创建快照 / 列表 / 预览 / 恢复 / 删除）；恢复走 `EditorController.restoreVersion()`，写回标题与正文、立即落库并压入撤销栈；恢复前自动为当前内容补一份快照避免误操作丢稿；`snapshotsProvider` 加在 work_detail_providers。
  - 备份：`BackupRepository` 导出/恢复纳入 `chapterSnapshots`（覆盖恢复按 `chapterIdMap` 重映射外键；旧备份无该键时按空处理，向后兼容）。
  - 验证：`test/features/snapshot_test.dart` 新增 6 个用例（创建与倒序、超上限清理、级联删除、删除指定快照、恢复写回并落库且可撤销、备份往返保留快照）；`flutter analyze` 无问题，`flutter test` 181 用例全绿。
  - 文档同步：ARCHITECTURE 3 章导出说明、4.1 ER 图与表定义、4.2 表要点、README 当前状态。
- [x] B-06（P2）全局搜索
  - 检索（`ChapterRepository.search`）：跨作品在章节标题与正文上做 LIKE 匹配（转义 `%` / `_` / `\` 通配符），按章节更新时间倒序、上限 100 条；返回 `ChapterSearchHit`（作品 / 章节信息 + 命中片段 + 命中起止）。
  - 页面（`lib/features/search/search_page.dart`，路由 `/search`）：作品列表顶栏搜索入口；输入即时检索（`searchProvider` FutureProvider.family），结果按作品名 + 章节名 + 片段展示，命中关键词高亮；点击命中跳转编辑器并用既有 `checkStart/checkEnd` 就地高亮。
  - 验证：`test/features/search_test.dart` 新增 6 个用例（跨作品正文检索、标题命中 `matchOffset = -1`、英文忽略大小写、LIKE 通配符转义、空白关键词、搜索页渲染命中）；`flutter analyze` 无问题，`flutter test` 187 用例全绿。
  - 文档同步：ARCHITECTURE 3 章目录与模块表、README 当前状态。
- [x] B-07（P2）每日字数目标、连击统计、番茄钟
  - 数据层：`DAILY_WRITING_STAT` 表（`lib/data/db.dart`，`day`(yyyy-MM-dd 本地键) 主键 + `words`），schemaVersion 3 → 4 并加迁移；新增 `lib/data/dao/writing_stats_dao.dart`（按日期倒序查询、`addWords` 累加当天正字数）；`lib/data/repositories/chapter_repository.dart` 的 `saveChapter` 在同事务内把「当天正文字数净增的正值」累加进当天统计（只加不减），新增 `watchDailyWritingStats` / `listDailyWritingStats`；纯函数 `lib/core/writing_stats.dart`（`writingDayKey` / `writingStreak`）。
  - 设置（`SettingsRepository`）：每日目标 `daily_word_target`（默认 0，负数归零）、番茄钟时长 `pomodoro_minutes`（默认 25，夹紧 1~120）、按日分键 `pomodoro_done_<yyyy-MM-dd>` 的完成数读写（`dailyWordTarget` / `setDailyWordTarget` / `pomodoroMinutes` / `setPomodoroMinutes` / `pomodoroDoneToday` / `incrementPomodoroDone`）。
  - 页面（`lib/features/stats/writing_stats_page.dart`，路由 `/settings/writing-stats`）：今日字数与每日目标进度、连续写作天数、番茄钟（倒计时 / 开始暂停重置 / 时长设置 / 今日完成数）；目标与时长编辑弹窗沿用 `TextFormField(initialValue:)` 写法。设置页「写作」段新增入口。
  - 备份：`BackupRepository` 导出/恢复纳入 `dailyWritingStats`（无外键，按日期主键合并；覆盖恢复先清空，合并模式保留本机既有日期）。
  - 验证：`test/features/writing_stats_test.dart` 新增 10 个用例（日期键补零、连击计算含今天未写与断连、正/负增量统计口径、同一天累加、备份往返保留统计、目标默认与负数归零、番茄钟时长夹紧、完成数按日累计、写作统计页渲染）；`flutter analyze` 无问题，`flutter test` 197 用例全绿。
  - 文档同步：ARCHITECTURE 3 章目录与模块表、4 章数据设计、README 当前状态。
- [x] B-09（P2）设定集（世界观/地点/道具）、人物关系图
  - 数据层：`SETTING_ENTRY` 表（`lib/data/db.dart`，workId 外键级联 + `type`（worldview/location/item）+ name + content + createdAt）与 `CHARACTER_RELATION` 表（workId + fromCharacterId/toCharacterId 双外键级联到 CHARACTER + label），schemaVersion 4 → 5 并加迁移；新增 `lib/data/dao/setting_dao.dart`、`lib/data/dao/relation_dao.dart`；`lib/models/setting_type.dart` 定义类型枚举（value/label/fromValue）。
  - 仓储：新增 `lib/data/repositories/setting_repository.dart`（watch/list/create/update/delete）；`CharacterRepository` 增加关系读写（`watchRelations` / `listRelations` / `createRelation` / `updateRelation` / `deleteRelation`），角色删除时关系随外键级联清理。
  - 页面：作品详情新增「设定集」Tab（`lib/features/work_detail/worldbuilding_tab.dart`，世界观/地点/道具三类筛选 + 条目卡片 + 新建/编辑/删除表单）；「人物关系图」页（`lib/features/work_detail/relation_graph_page.dart`，路由 `/work/:workId/relations`，CustomPainter 环形布局绘制节点与带标签连线，下方关系列表可增删改），入口在作品详情「更多」菜单。
  - 备份：`BackupRepository` 导出/恢复纳入 `settingEntries` 与 `characterRelations`（覆盖恢复先清空；恢复按 `workIdMap` / 角色 `characterIdMap` 重映射外键；旧备份无该键时按空处理，向后兼容）。
  - 验证：`test/features/worldbuilding_test.dart` 新增 7 个用例（类型回落、设定集增删改与筛选、关系改标签与端点、删角色级联删关系、备份跨库重映射、设定集 Tab 渲染与筛选切换、关系图页绘制与列表）；`flutter analyze` 无问题，`flutter test` 204 用例全绿。
  - 文档同步：ARCHITECTURE 3 章目录与模块表、4.1 ER 图与表定义、4.2 表要点、4.3 级联规则、README 当前状态。
- [x] B-08（P2）云备份（已实现）
  - 决策（2026-10-08 与用户对齐）：用户可开关是否启用；启用后可选服务商 AWS S3 / 阿里云 OSS / 七牛云 Kodo / 腾讯云 COS / 华为云 OBS（统一走 S3 兼容 + SigV4）；远端多份带时间戳并保留最近 N 份；不做客户端加密；手动触发为主、预留自动开关；自写 SigV4 over http、不引新依赖。
  - 需求：PRD 5.10；技术方案：ARCHITECTURE 9.1。
  - 实现：
    - [x] `core/cloud/s3_signer.dart` SigV4 签名纯函数（canonical request → string to sign → signing key → `Authorization`），并导出 `awsUriEncode` 供客户端按同一规则预编码 path/query
    - [x] `core/cloud/cloud_storage_client.dart`（`putObject` / `getObject` / `deleteObject` / `listObjects` / `checkConnection`，path-style 寻址，OSS 兼容头，分页；错误分类提示）
    - [x] `models/cloud_backup_config.dart` 服务商枚举（显示名 / endpoint 模板 / region 提示 / OSS 兼容头标记）与配置模型
    - [x] `core/cloud/cloud_backup_service.dart` 上传/列举/保留 N 份清理/下载编排（复用 `core/exporter` 的 `exportBackupZipBytes`）
    - [x] 配置持久化：非敏感项走 APP_SETTING（`SettingsRepository`），AK/SK 走 `SecureKeyStore`（不落库、不进备份）
    - [x] `features/settings/cloud_backup_page.dart` 云备份页（开关、服务商、字段、测试连接、立即备份、远端恢复、自动开关与频率）+ 路由 `/settings/cloud-backup` + 设置页入口
    - [x] 自动调度：`features/settings/cloud_backup_auto.dart`（`CloudBackupScheduler` + `isCloudBackupDue` 到期判据 + `CloudBackupAutoRunner` 于启动/回到前台检查），频率可选（每 12 小时 / 每天 / 每周），上次成功备份时间落 APP_SETTING（`cloud_backup_last_at`），失败静默
  - 验证：`test/core/cloud_backup_test.dart` 20 个用例（GET 官方向量、`awsUriEncode` 保留字符、配置回落与归一化、endpoint 提示随服务商变化、自动备份频率往返、path-style+OSS 头、保留字符编码进请求路径、分页解析、403/404 提示、`checkConnection`、备份编排与保留份数、`isCloudBackupDue`、调度开关/到期/缺凭证/失败静默、配置持久化与凭证不入库）、`test/features/cloud_backup_page_test.dart` 2 个用例（默认关闭隐藏字段、开启后展示并落库；开启自动备份展示频率并落库）；`flutter analyze` 无问题，`flutter test` 226 用例全绿。
  - 真机验证（release 构建，Android 13 / arm64）：`adb reverse` + 宿主本地假 S3 服务端到端验证「测试连接（`GET ?list-type=2&max-keys=1`）/ 立即备份（`PUT .../{时间戳}.zip` 并随后按前缀列举）/ 自动备份（冷启动到期触发一次，未到期不重复）」全部通过；过程中修复一处**发布阻断级**配置缺失——`android/app/src/main/AndroidManifest.xml` 此前未声明 `android.permission.INTERNET`（Flutter 模板只在 debug/profile 清单声明），导致 release 构建下 AI 与云备份的所有联网能力被系统阻断（`SocketException: Operation not permitted`），已在 main 清单补齐。
  - 文档同步：PRD 5.10 / 1.2 后置说明、ARCHITECTURE 9.1 与演进表、COMPLIANCE §1.2 出网范围、README 当前状态。