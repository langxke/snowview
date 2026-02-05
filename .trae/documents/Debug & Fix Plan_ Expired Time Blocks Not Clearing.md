# 还原方案：移除自动清除过期时间块功能

## 1. 目标
响应用户需求，彻底移除最近添加的自动清除过期时间块的相关代码，停止对日历数据的自动删除行为。

## 2. 具体步骤

### A. 入口文件清理 (`lib/main.dart`)
*   **操作**: 删除 `await Hive.openBox('calendar_indexes');` 行。
*   **原因**: 不再需要存储未完成事件的索引数据。

### B. 数据库服务还原 (`lib/services/calendar_database_service.dart`)
*   **操作**:
    1.  删除 `_indexBoxName` 和 `_unfinishedIdsKey` 常量定义。
    2.  删除 `_indexBox` getter。
    3.  删除 `_updateUnfinishedIndex`、`getUnfinishedEvents`、`_ensureIndexInitialized`、`_cleanStaleIndex` 等所有索引维护方法。
    4.  修改 `addEvent`、`updateEvent`、`deleteEvent` 及其变体方法，**移除**其中调用的 `await _updateUnfinishedIndex(...)` 代码。
*   **结果**: 数据库服务将恢复到仅负责基本的增删改查，不再有额外的索引开销。

### C. 调度监控器还原 (`lib/presentation/widgets/schedule_monitor.dart`)
*   **操作**:
    1.  删除 `_cleanupExpiredEvents` 方法体（该方法用于执行具体的删除和重置操作）。
    2.  在 `initState` 的 `Timer.periodic` 回调中，**移除** `_cleanupExpiredEvents()` 调用。
    3.  在 `_performCleanupOnce` 中，**移除** `await _cleanupExpiredEvents()` 调用。
    4.  在 `debugTriggerCleanup` 中，**移除**相关调用。
*   **结果**: 定时器将只负责原本的“任务结束提醒”和“弹窗超时检查”，不再触碰用户的历史数据。

## 3. 预期结果
执行完毕后，App 将不再自动清除已过期的未完成时间块，所有历史记录将保留在日历上，完全符合“不自动清除数据”的要求。
