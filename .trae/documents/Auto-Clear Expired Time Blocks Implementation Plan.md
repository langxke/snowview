# 实施方案：基于持久化索引的高性能清理

## 1. 目标
通过在数据库服务层维护一个持久化的“未完成事件ID索引”，实现 O(M) 复杂度的快速读取和清理，彻底避免全量数据扫描。

## 2. 代码变更

### A. 修改 `lib/services/calendar_database_service.dart`
1.  **引入索引存储**:
    *   在 `init()` 或构造中打开一个新的 Box `calendar_indexes`。
    *   Key: `unfinished_ids` -> Value: `List<String>`.
2.  **拦截 CRUD 操作**:
    *   `addEvent`: 若 `!isCompleted`，更新索引。
    *   `updateEvent`: 根据 `isCompleted` 变化更新索引。
    *   `deleteEvent`: 从索引移除 ID。
3.  **新增查询方法**:
    *   `List<CalendarEventHive> getUnfinishedEvents()`: 读取索引 ID -> 批量 fetch 对象。
4.  **自动迁移**:
    *   首次运行时，若索引为空但有数据，执行全量扫描重建索引。

### B. 修改 `lib/presentation/widgets/schedule_monitor.dart`
1.  **定时器逻辑**:
    *   调用 `databaseService.getUnfinishedEvents()`。
    *   筛选 `end < now` 的事件。
    *   执行清理 (删除事件 + 重置任务)。

## 3. 验证计划
1.  **迁移测试**: 手动添加几个未完成事件，重启 App，确认索引被正确建立。
2.  **功能测试**: 确认过期事件被自动清理，且索引同步更新。
3.  **性能观察**: 确认定时器触发时无明显 CPU/IO 波动。
