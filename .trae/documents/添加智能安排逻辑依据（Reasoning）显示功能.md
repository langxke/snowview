我将分为后端逻辑改造和前端UI实现两部分来完成此任务。

### 1. 后端改造：智能安排逻辑 (DayWeekAiScheduler & MonthAiScheduler)
**目标**：修改 AI 响应结构，增加 `reasoning` 字段，并持久化存储该信息。

**具体修改**：
*   **Prompt 调整**：
    *   在 `DayWeekAiScheduler` 和 `MonthAiScheduler` 中，更新 System Prompt 的 `output_schema`。
    *   新的 JSON 结构：
        ```json
        {
          "reasoning": "简要说明安排依据（例如：优先安排了高优先级的A任务，利用了下午的整块时间...）",
          "schedule": {
            "blocks": [...] // DayWeek 模式
            // 或者
            "assignments": [...] // Month 模式
          }
        }
        ```
*   **解析逻辑更新**：
    *   更新 `_callTimeBlockSchedulingAI` 和 `_callMonthSchedulingAI` 方法，适配新的 JSON 结构。
    *   提取 `reasoning` 字段。
*   **数据存储**：
    *   引入 `SharedPreferences` 存储 Reasoning。
    *   Key 格式：`ai_last_reasoning_{scope}_{date_key}`。
        *   DayWeek Scope: `day` / `week`。
        *   Month Scope: `month`。
    *   新增方法 `_saveReasoning(prefs, scope, dateKey, reasoning)`。

### 2. 前端实现：Info 按钮与 Tooltip (ScheduleScreen)
**目标**：在智能安排按钮左侧添加 Info 按钮，悬停显示对应的 Reasoning。

**具体修改**：
*   **状态管理**：
    *   在 `ScheduleScreen` 中添加 `String? _aiReasoning` 状态。
    *   添加 `_loadReasoning()` 方法，根据当前视图 (`_view`) 和选中日期 (`_selected`/`_year`/`_month`) 从 SharedPreferences 读取对应的 Reasoning。
    *   在 `initState`、`_stepView`、`_prevMonth/nextMonth` 以及视图切换时调用 `_loadReasoning()`。
    *   在执行完智能安排后，调用 `_loadReasoning()` 刷新显示。
*   **UI 组件**：
    *   在 Header Row 中（“AI智能安排”按钮左侧）添加一个新的 Widget。
    *   样式：圆形小按钮（`IconButton` 或 `InkWell` + `Container`），图标为 `Icons.info_outline`。
    *   交互：使用 `Tooltip` 组件包裹按钮。
        *   `message`: `_aiReasoning ?? '暂无本次安排的逻辑依据'`。
        *   设置 Tooltip 的样式（背景色、文字样式、padding 等）以增强可读性。

### 执行计划
1.  **修改 `DayWeekAiScheduler.dart`**：更新 Prompt、解析逻辑、存储 Reasoning。
2.  **修改 `MonthAiScheduler.dart`**：更新 Prompt、解析逻辑、存储 Reasoning。
3.  **修改 `ScheduleScreen.dart`**：添加读取 Reasoning 的逻辑，并在 Header 添加带 Tooltip 的 Info 按钮。

确认后，我将按此计划执行。