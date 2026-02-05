# 问题原因分析

经过排查代码 `lib/presentation/screens/schedule/day_week_ai_scheduler.dart`，任务被移除的原因如下：

1.  **触发了可用时间范围检查 (`out of availabilityRanges`)**：
    - 日志显示 `drop block ... out of availabilityRanges start=... 22:00:00 end=... 22:30:00`。
    - 代码中 `_blockWithinAnyRange` 方法会检查生成的时间块是否在用户设置的“可用时间段”内。
    - 系统中另一个任务成功安排在 `20:00-22:00`，这暗示您的**可用时间设置（Availability）可能配置为截止到 22:00**。
    - AI 尝试将最后一个任务安排在 `22:00-22:30`，但这超出了配置的截止时间（22:00），因此被系统安全拦截并移除。

2.  **为什么 AI 会排在范围外？**
    - 虽然提示词（Prompt）中包含了 `freeWindows`（空闲窗口，已根据设置截断在 22:00），但提示词中的全局指令 `range` 仍然告诉 AI 规划范围是 `00:00 - 23:59`。
    - 这种不一致（Prompt Inconsistency）导致 AI 产生“幻觉”，误以为可以利用 22:00 之后的时间来填补剩余任务。

# 解决方案

为了减少这种情况再次发生，建议优化传给 AI 的提示词，将指令中的 `range` 范围严格限制在实际的“有效空闲时间范围”内，而不是整天。

## 修改计划

**文件**: `lib/presentation/screens/schedule/day_week_ai_scheduler.dart`

1.  在 `_callTimeBlockSchedulingAI` 方法中，计算 `freeWindowsForAi` 覆盖的**实际起止时间**。
2.  将传给 AI 的 `instruction.range.start` 和 `instruction.range.end` 更新为这个实际起止时间（例如 `... - 22:00`），从而明确告知 AI 画布的物理边界。

这样 AI 就不会尝试在 22:00 以后安排任务了。
