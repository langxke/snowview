import 'package:hive/hive.dart';
import '../models/checklist_task_hive.dart';

/// 清单任务数据仓库
class TaskListRepository {
  static const String _taskBoxName = 'checklist_tasks';
  
  // ==================== 任务相关方法 ====================
  
  /// 获取任务Box
  Box<ChecklistTaskHive> get _taskBox => 
      Hive.box<ChecklistTaskHive>(_taskBoxName);
  
  /// 保存任务
  Future<void> saveTask(ChecklistTaskHive task) async {
    await _taskBox.put(task.id, task);
  }
  
  /// 更新任务
  Future<void> updateTask(ChecklistTaskHive task) async {
    await _taskBox.put(task.id, task);
  }
  
  /// 删除任务
  Future<void> deleteTask(String taskId) async {
    await _taskBox.delete(taskId);
  }
  
  /// 获取所有任务
  List<ChecklistTaskHive> getAllTasks() {
    return _taskBox.values.toList();
  }
  
  /// 根据ID获取任务
  ChecklistTaskHive? getTaskById(String id) {
    return _taskBox.get(id);
  }
  
  /// 根据日期获取任务
  List<ChecklistTaskHive> getTasksByDate(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    return _taskBox.values
        .where((task) {
          if (task.dueDate == null) return false;
          final taskDateOnly = DateTime(
            task.dueDate!.year, 
            task.dueDate!.month, 
            task.dueDate!.day
          );
          return taskDateOnly == dateOnly;
        })
        .toList();
  }
  
  // ==================== 初始化方法 ====================
  
  /// 初始化数据库（打开Boxes）
  static Future<void> init() async {
    await Hive.openBox<ChecklistTaskHive>(_taskBoxName);
  }
  
  /// 关闭数据库
  static Future<void> close() async {
    await Hive.box<ChecklistTaskHive>(_taskBoxName).close();
  }
}

