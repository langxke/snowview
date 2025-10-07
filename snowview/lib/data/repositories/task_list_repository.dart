import 'package:hive/hive.dart';
import '../models/task_category_hive.dart';
import '../models/checklist_task_hive.dart';

/// 清单任务数据仓库
class TaskListRepository {
  static const String _categoryBoxName = 'task_categories';
  static const String _taskBoxName = 'checklist_tasks';
  
  // ==================== 类别相关方法 ====================
  
  /// 获取类别Box
  Box<TaskCategoryHive> get _categoryBox => 
      Hive.box<TaskCategoryHive>(_categoryBoxName);
  
  /// 保存类别
  Future<void> saveCategory(TaskCategoryHive category) async {
    await _categoryBox.put(category.id, category);
  }
  
  /// 更新类别
  Future<void> updateCategory(TaskCategoryHive category) async {
    await _categoryBox.put(category.id, category);
  }
  
  /// 删除类别
  Future<void> deleteCategory(String categoryId) async {
    await _categoryBox.delete(categoryId);
  }
  
  /// 获取所有类别
  List<TaskCategoryHive> getCategories() {
    final categories = _categoryBox.values.toList();
    // 按order排序
    categories.sort((a, b) => a.order.compareTo(b.order));
    return categories;
  }
  
  /// 根据ID获取类别
  TaskCategoryHive? getCategoryById(String id) {
    return _categoryBox.get(id);
  }
  
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
  
  /// 根据类别ID获取任务
  List<ChecklistTaskHive> getTasksByCategory(String categoryId) {
    return _taskBox.values
        .where((task) => task.categoryId == categoryId)
        .toList();
  }
  
  /// 根据ID获取任务
  ChecklistTaskHive? getTaskById(String id) {
    return _taskBox.get(id);
  }
  
  /// 获取某个类别的未完成任务数量
  int getUncompletedTaskCount(String categoryId) {
    return _taskBox.values
        .where((task) => 
            task.categoryId == categoryId && !task.isCompleted)
        .length;
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
    await Hive.openBox<TaskCategoryHive>(_categoryBoxName);
    await Hive.openBox<ChecklistTaskHive>(_taskBoxName);
  }
  
  /// 关闭数据库
  static Future<void> close() async {
    await Hive.box<TaskCategoryHive>(_categoryBoxName).close();
    await Hive.box<ChecklistTaskHive>(_taskBoxName).close();
  }
}

