import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../data/models/task_category_hive.dart';
import '../../data/models/checklist_task_hive.dart';
import '../../data/models/subtask_hive.dart';
import '../../data/models/work_session_hive.dart';
import '../../data/repositories/task_list_repository.dart';
import '../../data/repositories/work_session_repository.dart';

/// 清单任务状态管理Provider
class TaskListProvider extends ChangeNotifier {
  final TaskListRepository _repository;
  final WorkSessionRepository _sessionRepository = WorkSessionRepository();
  
  List<TaskCategoryHive> _categories = [];
  List<ChecklistTaskHive> _tasks = [];
  String? _selectedCategoryId;
  String? _selectedTaskId;
  bool _isCompletedTasksExpanded = false; // 已完成任务是否展开
  
  TaskListProvider(this._repository) {
    _loadData();
  }
  
  // ==================== Getters ====================
  
  /// 获取所有类别
  List<TaskCategoryHive> get categories => _categories;
  
  /// 获取所有任务
  List<ChecklistTaskHive> get tasks => _tasks;
  
  /// 获取选中的类别ID
  String? get selectedCategoryId => _selectedCategoryId;
  
  /// 获取选中的任务ID
  String? get selectedTaskId => _selectedTaskId;
  
  /// 获取选中的任务
  ChecklistTaskHive? get selectedTask {
    if (_selectedTaskId == null) return null;
    try {
      return _tasks.firstWhere((t) => t.id == _selectedTaskId);
    } catch (e) {
      return null;
    }
  }
  
  /// 获取当前显示的任务列表（根据选中的类别筛选）
  List<ChecklistTaskHive> get currentTasks {
    if (_selectedCategoryId == null || _selectedCategoryId == 'all') {
      return _tasks;
    }
    return _tasks.where((t) => t.categoryId == _selectedCategoryId).toList();
  }
  
  /// 获取未完成的任务
  List<ChecklistTaskHive> get uncompletedTasks {
    return currentTasks.where((t) => !t.isCompleted).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // 按创建时间倒序
  }
  
  /// 获取已完成的任务
  List<ChecklistTaskHive> get completedTasks {
    return currentTasks.where((t) => t.isCompleted).toList()
      ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!)); // 按完成时间倒序
  }
  
  /// 详情面板是否可见
  bool get isDetailPanelVisible => _selectedTaskId != null;
  
  /// 已完成任务是否展开
  bool get isCompletedTasksExpanded => _isCompletedTasksExpanded;
  
  /// 切换已完成任务展开状态
  void toggleCompletedTasksExpanded() {
    _isCompletedTasksExpanded = !_isCompletedTasksExpanded;
    notifyListeners();
  }
  
  // ==================== 初始化和加载 ====================
  
  /// 加载数据
  Future<void> _loadData() async {
    _categories = _repository.getCategories();
    _tasks = _repository.getAllTasks();
    
    // 如果是第一次启动，创建默认类别
    if (_categories.isEmpty) {
      await _createDefaultCategories();
    }
    
    // 默认选中"全部"
    _selectedCategoryId = 'all';
    notifyListeners();
  }
  
  /// 创建默认类别
  Future<void> _createDefaultCategories() async {
    final defaultCategories = [
      TaskCategoryHive(
        id: 'work',
        name: '工作',
        colorValue: Colors.blue.value,
        order: 0,
      ),
      TaskCategoryHive(
        id: 'study',
        name: '学习',
        colorValue: Colors.green.value,
        order: 1,
      ),
      TaskCategoryHive(
        id: 'life',
        name: '生活',
        colorValue: Colors.orange.value,
        order: 2,
      ),
    ];
    
    for (var category in defaultCategories) {
      await _repository.saveCategory(category);
    }
    
    _categories = _repository.getCategories();
  }
  
  /// 刷新数据
  Future<void> refresh() async {
    await _loadData();
  }
  
  // ==================== 类别管理 ====================
  
  /// 选择类别
  void selectCategory(String? categoryId) {
    _selectedCategoryId = categoryId;
    _selectedTaskId = null; // 切换类别时关闭详情面板
    notifyListeners();
  }
  
  /// 创建类别
  Future<void> createCategory({
    required String name,
    required Color color,
  }) async {
    final category = TaskCategoryHive(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      colorValue: color.value,
      order: _categories.length,
    );
    
    await _repository.saveCategory(category);
    _categories = _repository.getCategories();
    notifyListeners();
  }
  
  /// 更新类别
  Future<void> updateCategory({
    required String id,
    String? name,
    Color? color,
  }) async {
    final category = _repository.getCategoryById(id);
    if (category == null) return;
    
    final updated = category.copyWith(
      name: name,
      color: color,
    );
    
    await _repository.updateCategory(updated);
    _categories = _repository.getCategories();
    notifyListeners();
  }
  
  /// 删除类别
  Future<void> deleteCategory(String id) async {
    // 检查是否有任务
    final tasksInCategory = _repository.getTasksByCategory(id);
    if (tasksInCategory.isNotEmpty) {
      throw Exception('该类别下还有任务，无法删除');
    }
    
    await _repository.deleteCategory(id);
    _categories = _repository.getCategories();
    
    // 如果删除的是当前选中的类别，切换到"全部"
    if (_selectedCategoryId == id) {
      _selectedCategoryId = 'all';
    }
    
    notifyListeners();
  }
  
  /// 获取类别的未完成任务数量
  int getCategoryTaskCount(String categoryId) {
    return _repository.getUncompletedTaskCount(categoryId);
  }
  
  /// 重新排序类别
  Future<void> reorderCategories(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    
    // 先在内存中更新顺序
    final category = _categories.removeAt(oldIndex);
    _categories.insert(newIndex, category);
    
    // 立即通知UI更新（显示新顺序）
    notifyListeners();
    
    // 然后批量更新数据库（后台保存，不影响UI）
    final updatedCategories = <TaskCategoryHive>[];
    for (int i = 0; i < _categories.length; i++) {
      final updated = _categories[i].copyWith(order: i);
      updatedCategories.add(updated);
      _categories[i] = updated;
    }
    
    // 批量保存到数据库
    for (final category in updatedCategories) {
      await _repository.updateCategory(category);
    }
  }
  
  // ==================== 任务管理 ====================
  
  /// 选择任务（打开详情面板）
  void selectTask(String? taskId) {
    _selectedTaskId = taskId;
    notifyListeners();
  }
  
  /// 创建任务
  Future<void> createTask({
    required String title,
    required String categoryId,
  }) async {
    final task = ChecklistTaskHive(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      categoryId: categoryId,
      isCompleted: false,
      subTasks: [],
      createdAt: DateTime.now(),
      order: _tasks.length,
    );
    
    await _repository.saveTask(task);
    _tasks = _repository.getAllTasks();
    notifyListeners();
  }
  
  /// 更新任务
  Future<void> updateTask({
    required String id,
    String? title,
    String? description,
    DateTime? dueDate,
    DateTime? remindAt,
    bool clearDueDate = false,
    bool clearRemindAt = false,
  }) async {
    final task = _repository.getTaskById(id);
    if (task == null) return;
    
    final updated = task.copyWith(
      title: title,
      description: description,
      dueDate: clearDueDate ? null : (dueDate ?? task.dueDate),
      remindAt: clearRemindAt ? null : (remindAt ?? task.remindAt),
    );
    
    await _repository.updateTask(updated);
    _tasks = _repository.getAllTasks();
    notifyListeners();
  }
  
  /// 切换任务完成状态
  Future<void> toggleTaskCompletion(String taskId) async {
    final task = _repository.getTaskById(taskId);
    if (task == null) return;
    
    final updated = task.copyWith(
      isCompleted: !task.isCompleted,
      completedAt: !task.isCompleted ? DateTime.now() : null,
    );
    
    await _repository.updateTask(updated);
    _tasks = _repository.getAllTasks();
    notifyListeners();
  }
  
  /// 删除任务
  Future<void> deleteTask(String taskId) async {
    // 1. 删除关联的所有工作会话（级联删除）
    await _sessionRepository.deleteSessionsByTaskId(taskId);
    
    // 2. 删除任务本身
    await _repository.deleteTask(taskId);
    _tasks = _repository.getAllTasks();
    
    // 3. 如果删除的是当前选中的任务，关闭详情面板
    if (_selectedTaskId == taskId) {
      _selectedTaskId = null;
    }
    
    notifyListeners();
  }
  
  // ==================== 子步骤管理 ====================
  
  /// 添加子步骤
  Future<void> addSubTask(String taskId, String title) async {
    final task = _repository.getTaskById(taskId);
    if (task == null) return;
    
    final subTask = SubTaskHive(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      isCompleted: false,
      order: task.subTasks.length,
    );
    
    final updatedSubTasks = List<SubTaskHive>.from(task.subTasks)..add(subTask);
    final updated = task.copyWith(subTasks: updatedSubTasks);
    
    await _repository.updateTask(updated);
    _tasks = _repository.getAllTasks();
    notifyListeners();
  }
  
  /// 切换子步骤完成状态
  Future<void> toggleSubTask(String taskId, String subTaskId) async {
    final task = _repository.getTaskById(taskId);
    if (task == null) return;
    
    final updatedSubTasks = task.subTasks.map((st) {
      if (st.id == subTaskId) {
        return st.copyWith(isCompleted: !st.isCompleted);
      }
      return st;
    }).toList();
    
    final updated = task.copyWith(subTasks: updatedSubTasks);
    
    await _repository.updateTask(updated);
    _tasks = _repository.getAllTasks();
    notifyListeners();
  }
  
  /// 删除子步骤
  Future<void> deleteSubTask(String taskId, String subTaskId) async {
    final task = _repository.getTaskById(taskId);
    if (task == null) return;
    
    // 1. 查找关联到此子步骤的会话
    final relatedSessions = _sessionRepository
        .getSessionsByTaskId(taskId)
        .where((s) => s.subTaskId == subTaskId)
        .toList();
    
    // 2. 将会话的子步骤关联改为null（关联到整个任务）
    for (final session in relatedSessions) {
      await _sessionRepository.updateSession(
        session.copyWith(subTaskId: null)
      );
    }
    
    // 3. 删除子步骤
    final updatedSubTasks = task.subTasks
        .where((st) => st.id != subTaskId)
        .toList();
    
    final updated = task.copyWith(subTasks: updatedSubTasks);
    
    await _repository.updateTask(updated);
    _tasks = _repository.getAllTasks();
    notifyListeners();
  }
  
  // ==================== 工作会话管理 ====================
  
  /// 创建工作会话
  Future<void> createWorkSession({
    required String taskId,
    String? subTaskId,
    required DateTime startTime,
    required DateTime endTime,
    String? note,
  }) async {
    final session = WorkSessionHive(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      taskId: taskId,
      subTaskId: subTaskId,
      startTime: startTime,
      endTime: endTime,
      status: 'planned',
      note: note,
      createdAt: DateTime.now(),
    );
    
    await _sessionRepository.saveSession(session);
    notifyListeners();
  }
  
  /// 获取任务的所有会话
  List<WorkSessionHive> getTaskSessions(String taskId) {
    return _sessionRepository.getSessionsByTaskId(taskId);
  }
  
  /// 获取某天的所有会话
  List<WorkSessionHive> getSessionsByDate(DateTime date) {
    return _sessionRepository.getSessionsByDate(date);
  }
  
  /// 更新工作会话
  Future<void> updateWorkSession(WorkSessionHive session) async {
    await _sessionRepository.updateSession(session);
    notifyListeners();
  }
  
  /// 删除工作会话
  Future<void> deleteWorkSession(String sessionId) async {
    await _sessionRepository.deleteSession(sessionId);
    notifyListeners();
  }
  
  // ==================== 会话状态管理 ====================
  
  /// 标记会话为已完成
  Future<void> markSessionAsCompleted(String sessionId) async {
    final session = _sessionRepository.getSessionById(sessionId);
    if (session == null) return;
    
    final updated = session.copyWith(status: 'completed');
    
    await _sessionRepository.updateSession(updated);
    notifyListeners();
  }
  
  /// 取消会话
  Future<void> cancelSession(String sessionId) async {
    final session = _sessionRepository.getSessionById(sessionId);
    if (session == null) return;
    
    final updated = session.copyWith(status: 'cancelled');
    
    await _sessionRepository.updateSession(updated);
    notifyListeners();
  }
  
  // ==================== 与专注功能集成 ====================
  
  /// 从工作会话启动专注功能
  /// 返回创建的专注会话ID（需要与专注功能集成后实现）
  Future<String> startFocusFromSession(WorkSessionHive session) async {
    // TODO: 与专注功能集成
    // 1. 调用专注服务创建专注会话
    // final focusSessionId = await _focusService.startFocus(
    //   taskId: session.taskId,
    //   subTaskId: session.subTaskId,
    //   plannedDuration: session.plannedDuration,
    // );
    
    // 2. 关联工作会话和专注会话
    final focusSessionId = 'temp_focus_${DateTime.now().millisecondsSinceEpoch}';
    final updated = session.copyWith(focusSessionId: focusSessionId);
    await _sessionRepository.updateSession(updated);
    
    notifyListeners();
    return focusSessionId;
  }
  
  /// 专注会话完成后的回调
  /// 自动标记关联的工作会话为已完成
  Future<void> onFocusSessionCompleted(String focusSessionId) async {
    // 查找关联的工作会话
    final sessions = _sessionRepository.getAllSessions();
    final relatedSession = sessions.cast<WorkSessionHive?>().firstWhere(
      (s) => s?.focusSessionId == focusSessionId,
      orElse: () => null,
    );
    
    if (relatedSession != null) {
      // 自动标记工作会话为已完成
      await markSessionAsCompleted(relatedSession.id);
    }
  }
  
  /// 从专注会话获取实际时长
  /// （需要与专注功能集成后实现）
  int getActualDurationFromFocus(String? focusSessionId) {
    if (focusSessionId == null) return 0;
    
    // TODO: 从专注服务获取实际时长
    // final focusSession = _focusService.getSessionById(focusSessionId);
    // return focusSession?.duration ?? 0;
    
    // 临时返回0
    return 0;
  }
  
  // ==================== 工具方法 ====================
  
  /// 检查时间冲突
  bool checkSessionConflict(DateTime start, DateTime end, {String? excludeId}) {
    return _sessionRepository.hasConflict(start, end, excludeSessionId: excludeId);
  }
  
  /// 获取冲突的会话列表
  List<WorkSessionHive> getConflictingSessions(DateTime start, DateTime end, {String? excludeId}) {
    return _sessionRepository.getConflictingSessions(start, end, excludeSessionId: excludeId);
  }
  
  // ==================== 日历集成方法 ====================
  
  /// 根据日期获取任务
  List<ChecklistTaskHive> getTasksByDate(DateTime date) {
    return _repository.getTasksByDate(date);
  }
}

