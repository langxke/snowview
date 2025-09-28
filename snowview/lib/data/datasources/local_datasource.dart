// 本地数据源抽象定义，仅用于让项目可以通过编译
abstract class LocalDataSource {
  // Focus sessions
  Future<List<Map<String, dynamic>>> getFocusSessions();
  Future<Map<String, dynamic>?> getFocusSessionById(int id);
  Future<int> insertFocusSession(Map<String, dynamic> data);
  Future<void> updateFocusSession(int id, Map<String, dynamic> data);
  Future<void> deleteFocusSession(int id);
  Future<List<Map<String, dynamic>>> getActiveFocusSessions();
  Future<List<Map<String, dynamic>>> getFocusStats();
  Future<Map<String, dynamic>?> getFocusStatsByDate(String date);

  // Schedules
  Future<List<Map<String, dynamic>>> getSchedules();
  Future<Map<String, dynamic>?> getScheduleById(int id);
  Future<int> insertSchedule(Map<String, dynamic> data);
  Future<void> updateSchedule(int id, Map<String, dynamic> data);
  Future<void> deleteSchedule(int id);
  Future<List<Map<String, dynamic>>> getSchedulesByDate(DateTime date);

  // Tasks
  Future<List<Map<String, dynamic>>> getTasks();
  Future<Map<String, dynamic>?> getTaskById(int id);
  Future<int> insertTask(Map<String, dynamic> data);
  Future<void> updateTask(int id, Map<String, dynamic> data);
  Future<void> deleteTask(int id);
  Future<List<Map<String, dynamic>>> getTasksByStatus(String status);
  Future<List<Map<String, dynamic>>> getTasksByCategory(String category);
}


