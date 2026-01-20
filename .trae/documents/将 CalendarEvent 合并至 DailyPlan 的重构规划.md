# 重构计划：CalendarEvent 完整合并至 DailyPlan (嵌入式存储)

用户建议将 `CalendarEvent` 完整合并到 `DailyPlan` 中，而非仅存储 ID 引用。

经过评估，对于 **CalendarEvent (时间块)** 这一特定实体，采用 **嵌入式存储 (Embedding)** 是可行的，且确实能简化管理。

## 核心理由与差异分析

* **ChecklistTask (任务)**: 必须用引用。因为任务是全局的，可能今天没做完推迟到明天，或者在“所有任务”列表里被修改。任务是独立于日期的实体。

* **CalendarEvent (时间块)**: **可以嵌入**。时间块本质上是依附于特定日期的时间段。一个“今天下午2点到3点的会议”强绑定于“今天”。它通常不会像任务那样在日期之间频繁流转。如果需要改期，本质上是销毁旧时间块、创建新时间块。

## 方案详情

### 1. 数据模型变更 (Breaking Change)

修改 `DailyPlanHive`，不再存储 ID 列表，而是直接存储事件对象列表。

* **DailyPlanHive**:

  * 移除: `@HiveField(3) List<String> scheduledEventIds`

  * 新增: `@HiveField(3) List<CalendarEventHive> scheduledEvents`

* **CalendarEventHive**:

  * 保留 `id` 字段（用于 UI 唯一标识）。

  * 这个类将作为 `DailyPlanHive` 的子对象存储，不再需要独立的 Box (`calendar_events`)。

### 2. 数据迁移 (Data Migration)

这是一个破坏性变更，需要处理旧数据。

* **迁移逻辑**:

  * 启动时检查 `calendar_events` Box 是否有数据。

  * 如果有，遍历所有旧事件，根据日期将它们**移动**到对应日期的 `DailyPlan` 对象的 `scheduledEvents` 列表中。

  * 清空并弃用 `calendar_events` Box。

### 3. Provider 重构 (DailyPlanProvider)

`DailyPlanProvider` 将成为时间块的唯一管理者。

* **读取**: 直接返回 `plan.scheduledEvents`。无需二次查询，性能提升，无“僵尸引用”风险。

* **写入 (Add)**: `plan.scheduledEvents.add(newEvent); plan.save();`

* **更新 (Update)**:

  * 在 `plan.scheduledEvents` 列表中找到对象并修改。

  * **特殊情况**: 如果修改了日期（跨天），则从 `Day A` 的列表移除，添加到 `Day B` 的列表。

* **删除 (Delete)**: `plan.scheduledEvents.removeWhere(...)`。

### 4. 废弃 CalendarDatabaseService

原有的 `CalendarDatabaseService` 将被废弃或重写为 `DailyPlanProvider` 的内部辅助类。

### 5. UI 适配

* **DayView / WeekView**: 直接消费 `DailyPlan` 中的事件列表。

* **ScheduleMonitor**: 监控逻辑直接检查 `DailyPlan`。

## 优势总结

1. **原子性**: 每日的计划和它的时间块是一个整体，存取更原子化。
2. **检索简单**: “获取今天的日程” = “读取今天的 Plan”，无需 Join。
3. **无遗漏**: 不会出现“ID 在 Plan 里但 Event 被删了”或“Event 在库里但没关联到 Plan”的数据不一致。

## 风险

* **跨天事件**: 不允许跨天。

如果您确认采用此方案，我将开始执行数据模型变更和迁移逻辑。
