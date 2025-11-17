## Services 模块 API 说明

### services/database_service.dart
- 抽象类：`DatabaseService`
  - `init() -> Future<void>` — 初始化数据库。

### services/ai_service.dart
- 抽象类：`AIService`
  - `generateTasksByGoal(String goalText) -> Future<List<Map<String, dynamic>>>` — 基于目标文本生成任务结构。

### services/schedule_service.dart
- 抽象类：`ScheduleService`
  - `generateDailyPlan({required DateTime day, required List<int> taskIds}) -> List<Schedule>` — 生成日程计划。

### services/focus_service.dart
- 抽象类：`FocusService`
  - `startPomodoro({required Duration work, required Duration rest}) -> Stream<Duration>` — 启动番茄时钟，流式输出剩余时间等。
  - `stop() -> void` — 停止计时。

### services/storage_service.dart
- 抽象类：`StorageService`
  - `readText(String path) -> Future<String>` — 读取文本文件。
  - `writeText(String path, String content) -> Future<void>` — 写入文本文件。

### services/notification_service.dart
- 类：`NotificationService`
  - 单例：`factory NotificationService()`
  - 函数：
    - `initialize() -> Future<void>` — 初始化通知插件。
    - `showImmediate({required int id, required String title, required String body}) -> Future<void>` — 立即显示通知。


