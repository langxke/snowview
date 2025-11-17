// 任务仓库接口（最小实现以匹配当前仓库实现）
import '../entities/task.dart';

abstract class TaskRepositoryInterface {
  Future<List<Task>> getTasks();
  Future<Task?> getTaskById(int id);
  Future<int> createTask(Task task);
  Future<void> updateTask(Task task);
  Future<void> deleteTask(int id);
  Future<List<Task>> getTasksByStatus(String status);
  Future<List<Task>> getTasksByCategory(String category);
}


