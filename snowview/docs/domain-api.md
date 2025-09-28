## Domain 模块 API 说明

### domain/entities/task.dart
- 类：`Task`
  - 字段：`id, title, description, priority, category, estimatedDuration, actualDuration, status, parentTaskId, createdAt, updatedAt`

### domain/entities/schedule.dart
- 类：`Schedule`
  - 字段：`id, taskId, startTime, endTime, status, notes, createdAt, updatedAt`

### domain/entities/focus_session.dart
- 类：`FocusSession`
  - 字段：`id, taskId, sessionType, duration, completedDuration, status, startTime, endTime, notes, createdAt`

### domain/repositories/task_repository_interface.dart
- 抽象接口：`TaskRepositoryInterface`
  - `getTasks() -> Future<List<Task>>`
  - `getTaskById(int id) -> Future<Task?>`
  - `createTask(Task task) -> Future<int>`
  - `updateTask(Task task) -> Future<void>`
  - `deleteTask(int id) -> Future<void>`
  - `getTasksByStatus(String status) -> Future<List<Task>>`
  - `getTasksByCategory(String category) -> Future<List<Task>>`

### domain/repositories/schedule_repository_interface.dart
- 抽象接口：`ScheduleRepositoryInterface`
  - `getSchedules() -> Future<List<Schedule>>`
  - `getScheduleById(int id) -> Future<Schedule?>`
  - `createSchedule(Schedule schedule) -> Future<int>`
  - `updateSchedule(Schedule schedule) -> Future<void>`
  - `deleteSchedule(int id) -> Future<void>`
  - `getSchedulesByDate(DateTime date) -> Future<List<Schedule>>`

### domain/repositories/focus_repository_interface.dart
- 抽象接口：`FocusRepositoryInterface`
  - `getFocusSessions() -> Future<List<FocusSession>>`
  - `getFocusSessionById(int id) -> Future<FocusSession?>`
  - `createFocusSession(FocusSession session) -> Future<int>`
  - `updateFocusSession(FocusSession session) -> Future<void>`
  - `deleteFocusSession(int id) -> Future<void>`
  - `getActiveFocusSessions() -> Future<List<FocusSession>>`
  - `getFocusStats() -> Future<List<Map<String, dynamic>>>`
  - `getFocusStatsByDate(String date) -> Future<Map<String, dynamic>?>`

### domain/usecases/create_task_usecase.dart
- 类：`CreateTaskUseCase`
  - 构造：`CreateTaskUseCase(TaskRepositoryInterface repo)`
  - 函数：`execute({required String title, String? description, int priority = 1, String? category, int? estimatedDuration, int? parentTaskId}) -> Future<int>`
    - 说明：根据入参创建 `Task` 并调用仓库保存，返回任务 ID。

### domain/usecases/generate_schedule_usecase.dart
- 类：`GenerateScheduleUseCase`
  - 函数：`generate({required DateTime day, required List<int> taskIds}) -> List<Schedule>`
    - 说明：示例生成给定日期的简单时间片日程。

### domain/usecases/start_focus_session_usecase.dart
- 类：`StartFocusSessionUseCase`
  - 构造：`StartFocusSessionUseCase(FocusRepositoryInterface repo)`
  - 函数：`execute({int? taskId, required String sessionType, required int duration, String? notes}) -> Future<int>`
    - 说明：校验输入与活跃会话，创建并保存专注会话，返回 ID。


