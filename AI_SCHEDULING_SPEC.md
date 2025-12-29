# AI智能安排 & 清空安排 —— 需求清单与实现步骤

## 1. 背景与目标

在日历视图（月/日/周）提供一个【AI智能安排】入口，用于基于“今日待办/今日任务/清单任务”与“可分配时间段”自动生成安排。

同时提供【清空安排】入口，用于按当前视图范围清除“由 AI 生成的待办与时间安排”，并保证：

- 仅清空 **AI 生成** 内容
- **用户手动创建** 的内容必须保留
- 【清空安排】范围根据视图不同而不同
- AI **不允许凭空产生新的 todo**（仅从既有来源选取/拆分/重排）

本阶段聚焦：需求定义、数据与架构设计、实现步骤拆解；不要求立刻编码。

---

## 2. 术语定义

- **清单任务（Checklist Task）**：任务列表中的长期任务条目（现有 Hive 模型）。
- **今日待办（Daily Todo）**：某一天的待办列表，用于“等待 AI 分配到时间段”或作为执行清单。
- **今日任务（Today Tasks / All-day Tasks）**：某一天的任务集合（可映射为全天事件或独立模型）。
- **时间安排（Scheduled Blocks / Calendar Events）**：落在日/周时间轴上的事件块。
- **AI 生成内容**：由 AI 智能安排创建/写入的 todo 或时间块，必须可与手动创建区分。

---

## 3. 功能范围

### 3.1 月视图

#### 3.1.1 AI智能安排（月视图）

- **入口**：月视图右上角按钮【AI智能安排】。
- **触发范围**：从 **今日** 到 **本月最后一天**。
- **效果**：
  - 调用 AI，为范围内的每一天生成/填充“每日待办”（Daily Todo）。
  - 月历格子中需要展示：
    - 今日任务（Today Tasks）
    - 今日待办（Daily Todos）
  - 两类内容必须以**不同颜色**区分。

#### 3.1.2 清空安排（月视图）

- **入口**：月视图右上角按钮【清空安排】。
- **清空范围**：从 **今日** 到 **本月最后一天**。
- **清空对象**：
  - 该日期范围内所有 `createdBy == ai` 的 Daily Todo
  - 该日期范围内所有 `createdBy == ai` 的时间块事件（如果月视图也可能创建时间块，则同样清空；否则留空）
- **保留对象**：
  - `createdBy == manual` 的 Daily Todo/事件
  - 任何用户手动创建的任务/待办/事件

---

### 3.2 日视图

#### 3.2.1 AI智能安排（日视图）

- **入口**：日视图右上角按钮【AI智能安排】。
- **触发范围**：当前选择的 **单日**。
- **效果**：
  - 调用 AI 将“今日待办 + 清单任务 + 今日任务（如参与）”分配到该日的可分配时间段中，生成时间块事件。
  - 需要遵守：
    - 不覆盖 busy events（已有事件不可冲突）
    - 只能在可分配时间段内生成
    - AI 不凭空创建新 todo：只能使用既有来源（今日待办/今日任务/清单任务）

#### 3.2.2 清空安排（日视图）

- **入口**：日视图右上角按钮【清空安排】。
- **范围**：当前单日。
- **清空对象**：
  - 当天 `createdBy == ai` 的时间块事件
  - 当天 `createdBy == ai` 的 Daily Todo（如果 AI 会填充 daily todo）
- **保留对象**：当天所有 `createdBy == manual` 的内容。

---

### 3.3 周视图

#### 3.3.1 AI智能安排（周视图）

- **入口**：周视图右上角按钮【AI智能安排】。
- **范围**：当前周（weekStart..weekEnd）。
- **效果**：对本周内每天，基于可分配时间段和已占用事件，生成时间块事件。

#### 3.3.2 清空安排（周视图）

- **入口**：周视图右上角按钮【清空安排】。
- **范围**：当前周。
- **清空对象**：
  - 本周内 `createdBy == ai` 的时间块事件
  - 本周内 `createdBy == ai` 的 Daily Todo（如适用）
- **保留对象**：所有手动内容。

---

## 4. 关键约束（必须满足）

### 4.1 AI 不得凭空产生 Todo

- AI 输出必须严格引用输入中的来源项：
  - 今日待办（Daily Todo）
  - 今日任务（Today Tasks / All-day tasks）
  - 清单任务（Checklist Tasks）
- 允许：
  - 将一个来源任务拆分成多个时间块（但仍可追溯到 sourceTaskId/sourceTodoId）
- 不允许：
  - 生成输入中不存在的新标题/新任务作为 todo

### 4.2 清空安排不影响历史

- 月视图清空范围必须是 **今日 -> 月末**，不得破坏过去日期内容。

### 4.3 仅清空 AI 生成内容

- 所有 AI 写入的对象必须带可识别标记。
- 用户手动创建内容必须永远保留。

---

## 5. 数据与标记设计（必须先设计清楚再编码）

### 5.1 统一标记字段

对以下对象统一支持标记：

- Daily Todo（每日待办）
- Calendar Event（时间块事件）

最小字段：

- `createdBy`: `manual | ai`
- `sourceType`: `checklist_task | daily_todo | today_task`
- `sourceId`: String（来源 id：taskId / todoId / eventId）
- `aiMeta`: 可选结构（如 model、runId、生成时间、提示词版本）

说明：

- `createdBy` 用于清空筛选。
- `sourceType/sourceId` 用于追溯来源，支持后续可解释性、避免重复安排。

### 5.2 Daily Todo 的持久化

月视图要显示每日待办，且要可清空某个日期范围的 AI 待办，因此 Daily Todo 建议持久化（Hive）。

建议新建模型（草案）：

- `id: String`
- `date: DateTime`（仅年月日）
- `title: String`
- `status: pending|done`
- `createdBy: manual|ai`
- `sourceType/sourceId`
- `estimatedMinutes: int?`
- `priority: int?`

### 5.3 Calendar Event 的 AI 标记

对 AI 生成的时间块事件写入：

- `createdBy: ai`
- `sourceType/sourceId`

清空时按日期范围 + createdBy 删除。

---

## 6. UI 需求清单

### 6.1 按钮

- 月视图 header：
  - 【AI智能安排】
  - 【清空安排】

- 日/周视图 header：
  - 【AI智能安排】
  - 【清空安排】

### 6.2 交互状态

- AI 调用期间：按钮进入 loading 状态（禁用/显示进度）。
- AI 返回后：必须进入“预览/确认”步骤（建议，但是否强制由后续实现决定）。
- 清空安排：必须二次确认对话框：
  - 明确范围：今日..月末 / 当天 / 本周
  - 明确只清 AI 内容

### 6.3 月历展示

- 日期格子中显示两类列表：
  - 今日任务：颜色 A
  - 今日待办：颜色 B
- 每类最多显示 2-3 项，超出显示 `+n`。

---

## 7. AI 能力拆分与提示词要求（不实现代码，但定义接口）

### 7.1 月视图：填充每日待办（今日->月末）

输入必须包含：

- 日期范围（today..monthEnd）
- 每天现有的：
  - 今日任务
  - 今日待办
  - busy events（可选，用于估算空闲）
  - availability ranges（用于估算空闲）
- 来源池：清单未完成任务

输出必须：

- 仅从来源池中选择任务并分配到每天（可追加策略由 AI 判断“空闲足够才追加”）
- 每个输出项必须带 `sourceType/sourceId`

### 7.2 日/周视图：分配到时间段

输入必须包含：

- 目标日期（day or week range）
- 每天的 availability ranges（来自设置）
- busy events（不可冲突）
- 来源池：今日待办/今日任务/清单任务

输出必须：

- time blocks（start/end/title）
- 每个 block 必须带 `sourceType/sourceId`
- 严禁冲突与越界

---

## 8. 清空安排的行为定义（精确）

### 8.1 清空规则

给定日期范围 [from, to]：

- 删除范围内所有 `createdBy == ai` 的 Daily Todo
- 删除范围内所有 `createdBy == ai` 的 Calendar Event（时间块）

### 8.2 “退回清单”的解释（按你的约束）

由于 AI 不允许产生新的 todo：

- AI 生成的 todo/时间块均来源于清单任务/今日待办/今日任务。
- 清空 AI 内容时，只需删除 AI 生成的 todo/时间块。
- 清单任务天然保留在清单里（未完成），因此“退回清单”等价于：
  - 取消 AI 的安排痕迹
  - 让用户下次再次点击 AI 安排

用户手动创建的待办/任务/时间块不受影响。

---

## 9. 实现步骤（工程拆解）

> 仅列步骤，不写代码实现细节。

### 阶段 0：代码调研与现状梳理

- 确认当前：
  - 月视图/日视图/周视图入口文件、header 构造位置
  - 今日任务/今日待办当前的数据来源（provider/box/内存）
  - CalendarEvent 的持久化方式与模型字段扩展能力

### 阶段 1：建立 Daily Todo 的领域层（若当前缺失）

- 新建 `DailyTodo` 模型（Hive）与 repository/provider：
  - 支持按日期范围查询
  - 支持创建/删除
  - 支持 `createdBy` 标记

### 阶段 2：建立 AI 标记机制

- DailyTodo：新增字段 `createdBy/sourceType/sourceId`
- CalendarEvent：新增字段或 metadata 支持 `createdBy/sourceType/sourceId`

### 阶段 3：月视图 UI

- 在月视图 header 加两个按钮：
  - 【AI智能安排】触发月视图模式
  - 【清空安排】按今日->月末清空 createdBy==ai 的内容
- 月格渲染：
  - 展示今日任务与今日待办
  - 颜色区分

### 阶段 4：月视图 AI 智能安排（仅定义数据流，落地时实现 service/provider）

- Provider：
  - 组装输入上下文
  - 调用 AI service
  - 解析输出
  - 写入 DailyTodo（createdBy=ai）

### 阶段 5：日/周视图 UI + 清空安排

- 日/周视图 header 加按钮：
  - 【AI智能安排】触发时间分配模式
  - 【清空安排】按当天/本周清空 createdBy==ai 的 todo 与时间块

### 阶段 6：日/周视图 AI 分配到时间段

- Provider：
  - 组装 availability + busyEvents + source pool
  - 调用 AI service
  - 解析输出
  - 写入 CalendarEvent（createdBy=ai）

### 阶段 7：验收与边界测试

- 月视图：
  - 生成后只影响 today..monthEnd
  - 清空后只清 AI 内容，手动内容保留
- 日/周视图：
  - 同上
  - 忙碌冲突不产生
  - 时间块均在可分配范围内

---

## 10. 未来可扩展项（不在本阶段）

- 预览/确认 UI（apply 前预览）
- AI 输出 schema 严格校验与错误回退
- “保守/积极”策略切换
- 对同一任务多次安排的去重策略
