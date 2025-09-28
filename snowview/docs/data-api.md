## Data 模块 API 说明

### data/datasources/local_datasource.dart
- 抽象类：`LocalDataSource`
  - Focus 会话：
    - `getFocusSessions() -> Future<List<Map<String, dynamic>>>`
    - `getFocusSessionById(int id) -> Future<Map<String, dynamic>?>`
    - `insertFocusSession(Map<String, dynamic> data) -> Future<int>`
    - `updateFocusSession(int id, Map<String, dynamic> data) -> Future<void>`
    - `deleteFocusSession(int id) -> Future<void>`
    - `getActiveFocusSessions() -> Future<List<Map<String, dynamic>>>`
    - `getFocusStats() -> Future<List<Map<String, dynamic>>>`
    - `getFocusStatsByDate(String date) -> Future<Map<String, dynamic>?>`
  - Schedules：
    - `getSchedules() -> Future<List<Map<String, dynamic>>>`
    - `getScheduleById(int id) -> Future<Map<String, dynamic>?>`
    - `insertSchedule(Map<String, dynamic> data) -> Future<int>`
    - `updateSchedule(int id, Map<String, dynamic> data) -> Future<void>`
    - `deleteSchedule(int id) -> Future<void>`
    - `getSchedulesByDate(DateTime date) -> Future<List<Map<String, dynamic>>>`
  - Tasks：
    - `getTasks() -> Future<List<Map<String, dynamic>>>`
    - `getTaskById(int id) -> Future<Map<String, dynamic>?>`
    - `insertTask(Map<String, dynamic> data) -> Future<int>`
    - `updateTask(int id, Map<String, dynamic> data) -> Future<void>`
    - `deleteTask(int id) -> Future<void>`
    - `getTasksByStatus(String status) -> Future<List<Map<String, dynamic>>>`
    - `getTasksByCategory(String category) -> Future<List<Map<String, dynamic>>>`

### data/datasources/ai_datasource.dart
- 抽象类：`AIDatasource`
  - `generateTasksByGoal(String goalText) -> Future<List<Map<String, dynamic>>>`
    - 输入：学习目标文本
    - 输出：任务 JSON 列表（标题、描述、优先级、预计时长等字段）

### data/models/task_model.dart
- 类：`TaskModel`
  - 主要字段：`id, title, description, priority, category, estimatedDuration, actualDuration, status, parentTaskId, createdAt, updatedAt`
  - 工厂：`fromMap(Map<String, dynamic>) -> TaskModel`
  - 函数：`toMap() -> Map<String, dynamic>`

### data/models/schedule_model.dart
- 类：`ScheduleModel`
  - 字段：`id, taskId, startTime, endTime, status, notes, createdAt, updatedAt`
  - 工厂：`fromMap(Map<String, dynamic>) -> ScheduleModel`
  - 函数：`toMap() -> Map<String, dynamic>`

### data/models/focus_session_model.dart
- 类：`FocusSessionModel`
  - 字段：`id, taskId, sessionType, duration, completedDuration, status, startTime, endTime, notes, createdAt`
  - 工厂：`fromMap(Map<String, dynamic>) -> FocusSessionModel`
  - 函数：`toMap() -> Map<String, dynamic>`

### data/models/user_preferences_model.dart
- 类：`UserPreferencesModel`
  - 字段：用户工作时间、休息、番茄钟、主题、语言等偏好
  - 工厂：`fromMap(Map<String, dynamic>) -> UserPreferencesModel`
  - 函数：`toMap() -> Map<String, dynamic>`

### data/repositories/task_repository.dart
- 类：`TaskRepository`
  - 依赖：`LocalDataSource`
  - 函数：
    - `getTasks() -> Future<List<Task>>`
    - `getTaskById(int id) -> Future<Task?>`
    - `createTask(Task task) -> Future<int>`
    - `updateTask(Task task) -> Future<void>`
    - `deleteTask(int id) -> Future<void>`
    - `getTasksByStatus(String status) -> Future<List<Task>>`
    - `getTasksByCategory(String category) -> Future<List<Task>>`

### data/repositories/schedule_repository.dart
- 类：`ScheduleRepository`
  - 依赖：`LocalDataSource`
  - 函数：
    - `getSchedules() -> Future<List<Schedule>>`
    - `getScheduleById(int id) -> Future<Schedule?>`
    - `createSchedule(Schedule schedule) -> Future<int>`
    - `updateSchedule(Schedule schedule) -> Future<void>`
    - `deleteSchedule(int id) -> Future<void>`
    - `getSchedulesByDate(DateTime date) -> Future<List<Schedule>>`

### data/repositories/focus_repository.dart
- 类：`FocusRepositoryImpl`
  - 依赖：`LocalDataSource`
  - 函数：
    - `getFocusSessions() -> Future<List<FocusSession>>`
    - `getFocusSessionById(int id) -> Future<FocusSession?>`
    - `createFocusSession(FocusSession session) -> Future<int>`
    - `updateFocusSession(FocusSession session) -> Future<void>`
    - `deleteFocusSession(int id) -> Future<void>`
    - `getActiveFocusSessions() -> Future<List<FocusSession>>`
    - `getFocusStats() -> Future<List<Map<String, dynamic>>>`
    - `getFocusStatsByDate(String date) -> Future<Map<String, dynamic>?>`


