import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/checklist_task_hive.dart';
import '../../data/repositories/task_list_repository.dart';

/// 清单任务状态管理Provider
class TaskListProvider extends ChangeNotifier {
  final TaskListRepository _repository;
  
  List<ChecklistTaskHive> _tasks = [];
  String? _selectedTaskId;
  String? _renamingTaskId;
  String? _expandedNoteTaskId;
  bool _isCompletedTasksExpanded = false; // 已完成任务是否展开
  bool _isUnscheduledTasksExpanded = true;
  bool _isScheduledTasksExpanded = true;
  
  TaskListProvider(this._repository) {
    _loadData();
  }
  
  // ==================== Getters ====================
  
  /// 获取所有任务
  List<ChecklistTaskHive> get tasks => _tasks;
  
  /// 获取选中的任务ID
  String? get selectedTaskId => _selectedTaskId;

  /// 当前是否有任务处于“原地重命名”状态
  String? get renamingTaskId => _renamingTaskId;

  /// 当前是否有任务展开了备注编辑
  String? get expandedNoteTaskId => _expandedNoteTaskId;
  
  /// 获取选中的任务
  ChecklistTaskHive? get selectedTask {
    if (_selectedTaskId == null) return null;
    try {
      return _tasks.firstWhere((t) => t.id == _selectedTaskId);
    } catch (e) {
      return null;
    }
  }
  
  /// 获取未完成的任务
  List<ChecklistTaskHive> get uncompletedTasks {
    return _tasks.where((t) => !t.isCompleted).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // 按创建时间倒序
  }

  List<ChecklistTaskHive> get scheduledUncompletedTasks {
    return _tasks
        .where((t) => !t.isCompleted && t.dueDate != null)
        .toList()
      ..sort((a, b) => (a.dueDate!).compareTo(b.dueDate!));
  }

  List<ChecklistTaskHive> get unscheduledUncompletedTasks {
    return _tasks
        .where((t) => !t.isCompleted && t.dueDate == null)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
  
  /// 获取已完成的任务
  List<ChecklistTaskHive> get completedTasks {
    return _tasks.where((t) => t.isCompleted).toList()
      ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!)); // 按完成时间倒序
  }
  
  /// 详情面板是否可见
  bool get isDetailPanelVisible => _selectedTaskId != null;
  
  /// 已完成任务是否展开
  bool get isCompletedTasksExpanded => _isCompletedTasksExpanded;

  bool get isUnscheduledTasksExpanded => _isUnscheduledTasksExpanded;

  bool get isScheduledTasksExpanded => _isScheduledTasksExpanded;
  
  /// 切换已完成任务展开状态
  void toggleCompletedTasksExpanded() {
    _isCompletedTasksExpanded = !_isCompletedTasksExpanded;
    notifyListeners();
  }

  void toggleUnscheduledTasksExpanded() {
    _isUnscheduledTasksExpanded = !_isUnscheduledTasksExpanded;
    notifyListeners();
  }

  void toggleScheduledTasksExpanded() {
    _isScheduledTasksExpanded = !_isScheduledTasksExpanded;
    notifyListeners();
  }

  static const String _taskMetaPrefsPrefix = 'task_meta_v1_';
  static const String _aiScheduledTaskIdsByDatePrefix = 'ai_scheduled_task_ids_v1_';

  Future<bool> isTaskRecurring(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_taskMetaPrefsPrefix$taskId');
    if (raw == null || raw.trim().isEmpty) return false;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return false;
      final rep = decoded['repeat']?.toString();
      return rep != null && rep.trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<Set<String>> getRecurringTaskIds() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = <String>{};
    for (final t in _tasks) {
      final raw = prefs.getString('$_taskMetaPrefsPrefix${t.id}');
      if (raw == null || raw.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) continue;
        final rep = decoded['repeat']?.toString();
        if (rep != null && rep.trim().isNotEmpty && rep.trim() != 'none') {
          ids.add(t.id);
        }
      } catch (_) {
        continue;
      }
    }
    return ids;
  }

  Future<Set<String>> getTimeBlockScheduledTaskIds() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final result = <String>{};
    for (final k in keys) {
      if (!k.startsWith(_aiScheduledTaskIdsByDatePrefix)) continue;
      final ids = prefs.getStringList(k);
      if (ids == null || ids.isEmpty) continue;
      result.addAll(ids);
    }
    return result;
  }
  
  // ==================== 初始化和加载 ====================
  
  /// 加载数据
  Future<void> _loadData() async {
    _tasks = _repository.getAllTasks();
    notifyListeners();
  }
  
  /// 刷新数据
  Future<void> refresh() async {
    await _loadData();
  }
  
  // ==================== 任务管理 ====================
  
  /// 选择任务（打开详情面板）
  void selectTask(String? taskId) {
    _selectedTaskId = taskId;
    if (_renamingTaskId != null && _renamingTaskId != taskId) {
      _renamingTaskId = null;
    }
    if (_expandedNoteTaskId != null && _expandedNoteTaskId != taskId) {
      _expandedNoteTaskId = null;
    }
    notifyListeners();
  }

  /// 开始原地重命名某个任务
  void startRenaming(String taskId) {
    _selectedTaskId = taskId;
    _renamingTaskId = taskId;
    if (_expandedNoteTaskId != null && _expandedNoteTaskId != taskId) {
      _expandedNoteTaskId = null;
    }
    notifyListeners();
  }

  /// 取消原地重命名
  void cancelRenaming() {
    if (_renamingTaskId == null) return;
    _renamingTaskId = null;
    notifyListeners();
  }

  void toggleNoteEditor(String taskId) {
    _selectedTaskId = taskId;
    if (_renamingTaskId != null && _renamingTaskId != taskId) {
      _renamingTaskId = null;
    }
    _expandedNoteTaskId = _expandedNoteTaskId == taskId ? null : taskId;
    notifyListeners();
  }
  
  /// 创建任务
  Future<void> createTask({
    required String title,
  }) async {
    final task = ChecklistTaskHive(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      isCompleted: false,
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
    bool? isLongTerm,
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
      isLongTerm: isLongTerm,
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
    // 删除任务本身
    await _repository.deleteTask(taskId);
    _tasks = _repository.getAllTasks();
    
    // 如果删除的是当前选中的任务，关闭详情面板
    if (_selectedTaskId == taskId) {
      _selectedTaskId = null;
    }
    
    notifyListeners();
  }

  /// 获取所有任务（公开方法）
  List<ChecklistTaskHive> getAllTasks() {
    return _repository.getAllTasks();
  }
  
  /// 根据日期获取任务
  List<ChecklistTaskHive> getTasksByDate(DateTime date) {
    return _repository.getTasksByDate(date);
  }

  /// 获取任务详情
  ChecklistTaskHive? getTaskById(String id) {
    try {
      return _tasks.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }
}

