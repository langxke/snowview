## 目标
- 月视图彻底取消“循环任务 start/end + repeat 在客户端展开”的机制，让 AI 直接给出具体日期（单天或日期数组），从而具备更高的安排自由度。
- 备注（description）仅作为参考偏好：在可行情况下尽量满足，但不要求绝对优先。
- 当 AI 输出 JSON 解析失败（或不符合 schema）时，自动带错误信息重试；最大重试次数可在设置中配置，默认 3；超过次数则停止，并把失败信息写到对应视图的“i”提示里。

## 一、月视图：协议改造（取消客户端 repeat 展开）
### 1) AI 输入保持，但不再让 repeat 绑定语义
- 仍然把任务的 `description`、`repeat` 等字段传给 AI（repeat 仅是一个“参考提示”，不再在客户端执行任何展开语义）。

### 2) AI 输出 schema 改为“单天 / 日期数组”两种方式（二选一）
- 只在 prompt 里提供下面两种 assignment（不提 start/end，也不提客户端展开规则）：
  - 单天：`{ taskId, date: "YYYY-MM-DD" }`
  - 多天：`{ taskId, dates: ["YYYY-MM-DD", ...] }`
- 允许同一个 taskId 在 assignments 中出现多次（例如一次 date + 一次 dates，或多条 date）。
- 备注规则：用自然语言描述为“尽可能参考 description 中的偏好/频率/具体日期，但如与时间范围、任务分散策略冲突可折中，并在 reasoning 用通俗语言说明”。

### 3) 客户端解析逻辑替换
- 对 AI 结果做三步处理：
  1) JSON 提取 + jsonDecode
  2) schema 校验（必须包含 reasoning + schedule.assignments；每条 assignment 必须满足 date/dates 之一）
  3) 归一化为 `(taskId, date)` 列表并做：allowedIds 过滤、range 裁剪、(taskId,date) 去重、单任务次数上限保护
- 写入 DailyPlan 与 meta：
  - 2 个及以上日期：写 `aiDueDates=[...]`
  - 仅 1 个日期：写 `aiDueDate=...`
  - 与 repeat 是否为 weekly/daily 无关（因为已取消客户端展开）。

## 二、JSON 解析/校验失败重试机制（核心新需求）
### 1) 触发条件
- 不仅包含 jsonDecode 抛错，也包含“能解析但不符合 schema”的情况（例如缺少 schedule.assignments、assignment 既无 date 也无 dates、日期格式不对等）。

### 2) 重试策略
- 每次失败都会把以下信息重新发给 AI：
  - 需要的 schema（只包含 date/dates 两种）
  - 上一次 AI 原始输出（或截断片段）
  - 本次解析/校验错误信息（例如 `FormatException: ...` 或具体缺失字段说明）
  - 明确要求“只输出纯 JSON，且严格匹配 schema”
- 重试次数 = 设置项 `最大重试次数`（默认 3）。
- 达到上限仍失败：停止尝试，不写入 DailyPlan，改为把错误结果写入对应视图的 reasoning 存储，供“i”图标展示。

### 3) 失败信息写入“i”图标内容
- 月视图：写入 `ai_reasoning_latest_month`（由 [MonthAiScheduler.getReasoning](file:///d:/Projects/SnowView/lib/presentation/screens/schedule/month_ai_scheduler.dart#L43-L68) + [schedule_screen.dart](file:///d:/Projects/SnowView/lib/presentation/screens/schedule_screen.dart#L69-L88) 展示）。
- 日/周视图：同理写入 `ai_reasoning_latest_day/week`（由 [DayWeekAiScheduler.getReasoning](file:///d:/Projects/SnowView/lib/presentation/screens/schedule/day_week_ai_scheduler.dart#L305-L332) 展示）。
- 写入内容建议包含：失败次数、最后一次错误摘要、最后一次原始输出的截断（避免存超大字符串）。

## 三、设置页新增配置：最大重试次数（默认 3）
### 1) 数据模型
- 扩展 [AIConfigHive](file:///d:/Projects/SnowView/lib/data/models/ai_config_hive.dart) 增加一个 int 字段（例如 `maxJsonParseRetries`），默认值 3。
- 同步更新 Hive adapter 生成文件（`ai_config_hive.g.dart`）与仓库中保存/读取逻辑（[AIConfigRepository](file:///d:/Projects/SnowView/lib/data/repositories/ai_config_repository.dart)）。

### 2) Settings UI
- 在 [settings_screen.dart](file:///d:/Projects/SnowView/lib/presentation/screens/settings_screen.dart) “高级设置”里新增一个控件（Slider 或下拉）：
  - 展示当前值
  - 允许设置范围（建议 0~5 或 1~5）
  - 保存时写入 AIConfigHive
  - 加载时回填

## 四、附带稳定性修复（建议同 PR 一起做）
- 修复 [task_item.dart](file:///d:/Projects/SnowView/lib/presentation/screens/tasks/widgets/task_item.dart) 的 `_saveTaskMeta` 覆盖写问题：改为 merge 写入，避免把 `aiDueDate/aiDueDates` 等 AI 安排元数据抹掉。

## 五、验证计划
- 单元测试：
  - 月视图：date/dates 两种输出均能正确归一化、去重、裁剪。
  - 重试机制：mock AIService 第 1/2 次返回坏 JSON，第 3 次返回合格 JSON；验证最终成功写入；以及超过上限时 reasoning 存入错误信息。
  - 设置项：保存/加载 `maxJsonParseRetries` 正常。
- 手动回归：
  - 用“穿搭&发型”备注“每周大概三次”，执行月视图 AI 安排，观察落在多天。
  - 构造故意输出非 JSON（通过临时替换模型/提示词或 mock）验证重试与 i 图标错误提示。

如果你认可这个计划，我会进入行动模式开始实现，并在实现后用测试与实际跑一遍月视图 AI 安排做验收。