import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences
import '../../data/models/daily_plan_hive.dart';
import '../../data/repositories/daily_plan_repository.dart';
import '../../data/repositories/task_list_repository.dart';
import '../../services/calendar_database_service.dart';

import '../../data/models/calendar_event_hive.dart';

class DailyPlanProvider extends ChangeNotifier {
  final DailyPlanRepository _repository;
  final TaskListRepository _taskRepository;
  final CalendarDatabaseService _calendarService;

  DailyPlanProvider(
    this._repository,
    this._taskRepository,
    this._calendarService,
  );

  /// 缓存已加载的计划
  final Map<String, DailyPlanHive> _cache = {};

  /// 获取指定日期的计划（支持懒加载迁移）
  Future<DailyPlanHive> getPlanForDate(DateTime date) async {
    final dateKey = _dateToKey(date);
    
    if (_cache.containsKey(dateKey)) {
      return _cache[dateKey]!;
    }

    var plan = _repository.getPlan(dateKey);
    
    plan ??= await _initializePlanForDate(date, dateKey);

    _cache[dateKey] = plan;
    return plan;
  }

  /// 初始化当天的计划（从现有数据源聚合）
  Future<DailyPlanHive> _initializePlanForDate(DateTime date, String dateKey) async {
    final plan = DailyPlanHive(dateKey: dateKey);
    final prefs = await SharedPreferences.getInstance(); // 获取 SharedPreferences
    
    // 1. 迁移待办任务：查找 dueDate 为当天的任务
    final allTasks = _taskRepository.getAllTasks();
    final todayStart = DateTime(date.year, date.month, date.day);
    final todayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59);

    for (final task in allTasks) {
      if (task.isCompleted) continue; // Skip completed tasks

      // A. 检查物理 dueDate
      if (task.dueDate != null) {
        final d = task.dueDate!.toLocal();
        if (d.year == date.year && d.month == date.month && d.day == date.day) {
          if (!plan.todoTaskIds.contains(task.id)) {
            plan.todoTaskIds.add(task.id);
          }
          continue; // 已添加，跳过后续检查
        }
      }

      // B. 检查 AI 元数据 (task_meta_v1_{id})
      // 这里的逻辑与 MonthAiScheduler 保持一致，用于恢复 AI 安排但无物理 dueDate 的任务
      final raw = prefs.getString('task_meta_v1_${task.id}');
      if (raw != null && raw.trim().isNotEmpty) {
          try {
              final decoded = jsonDecode(raw);
              if (decoded is Map) {
                  // B1. 检查单日安排 (aiDueDate)
                  final aiDue = decoded['aiDueDate'];
                  if (aiDue == dateKey) {
                      if (!plan.todoTaskIds.contains(task.id)) {
                          plan.todoTaskIds.add(task.id);
                      }
                  }

                  // B2. 检查循环任务展开 (aiDueDates)
                  final aiDueDates = decoded['aiDueDates'];
                  if (aiDueDates is List) {
                      for (final dStr in aiDueDates) {
                          // aiDueDates 存储格式通常也是 YYYY-MM-DD
                          // 如果不是标准格式，tryParse 会失败，这里假设是 dateKey 格式
                          if (dStr.toString().startsWith(dateKey)) {
                              if (!plan.todoTaskIds.contains(task.id)) {
                                  plan.todoTaskIds.add(task.id);
                              }
                              break; // 只要有一个命中即可
                          }
                      }
                  }
              }
          } catch (_) {
              // ignore json parse error
          }
      }
    }

    // 2. 迁移时间块：查找当天的日程 (非全天)
    // 迁移逻辑：从旧的 CalendarDatabaseService 读取，然后转换为 DailyPlan 的 embedded events
    final events = _calendarService.getCalendarEventsInRange(todayStart, todayEnd);
    for (final e in events) {
      if (!e.allDay) {
         // 检查是否已存在（根据 ID）
         final exists = plan.scheduledEvents.any((existing) => existing.id == e.id);
         if (!exists) {
           plan.scheduledEvents.add(CalendarEventHive.fromCalendarEvent(e));
         }
      }
    }

    // 3. 全天任务：暂不自动迁移 CalendarEvent(allDay=true) 到 ChecklistTask
    // 保持 allDayTaskIds 为空，用户可手动添加

    await _repository.savePlan(plan);
    return plan;
  }
  
  /// 迁移旧版数据：从 legacyScheduledEventIds 读取并转换为嵌入式对象
  Future<void> _migrateLegacyEvents(DailyPlanHive plan, DateTime date) async {
      // 从旧版 CalendarService 获取当天所有事件（因为旧版 IDs 对应的事件内容只能去 CalendarBox 查）
      // 简单起见，我们重新拉取当天所有事件，并与 ID 匹配（或者直接信任拉取结果）
      final todayStart = DateTime(date.year, date.month, date.day);
      final todayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59);
      final events = _calendarService.getCalendarEventsInRange(todayStart, todayEnd);
      
      for (final e in events) {
          if (!e.allDay) {
               // 只有当 ID 存在于 legacy 列表中时才迁移？
               // 或者更宽容策略：只要是当天的旧数据都迁移进来
               // 这里我们检查 legacyScheduledEventIds 是否包含该 ID
               if (plan.legacyScheduledEventIds!.contains(e.id)) {
                   // 检查是否已存在
                   final exists = plan.scheduledEvents.any((existing) => existing.id == e.id);
                   if (!exists) {
                       plan.scheduledEvents.add(CalendarEventHive.fromCalendarEvent(e));
                   }
               }
          }
      }
      
      // 迁移完成后，清空旧字段以避免重复迁移
      plan.legacyScheduledEventIds = null;
      await plan.save();
  }

  /// 批量获取日期范围内的计划（支持懒加载迁移）
  Future<Map<DateTime, DailyPlanHive>> getPlansForRange(DateTime start, DateTime end) async {
    final result = <DateTime, DailyPlanHive>{};
    
    // 生成日期序列
    final days = <DateTime>[];
    var current = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    
    while (!current.isAfter(endDate)) {
      days.add(current);
      current = current.add(const Duration(days: 1));
    }

    // 批量加载
    for (final date in days) {
      final plan = await getPlanForDate(date);
      result[date] = plan;
    }
    
    return result;
  }

  /// 刷新指定日期（强制重载）
  Future<void> refreshDate(DateTime date) async {
    final dateKey = _dateToKey(date);
    _cache.remove(dateKey);
    await getPlanForDate(date);
    notifyListeners();
  }

  // ================= 操作方法 =================

  /// 添加任务到今日待办
  Future<void> addTodoTask(DateTime date, String taskId) async {
    final plan = await getPlanForDate(date);
    if (!plan.todoTaskIds.contains(taskId)) {
      plan.todoTaskIds.add(taskId);
      await plan.save();
      notifyListeners();
      debugPrint('[DailyPlanProvider] addTodoTask success: date=${_dateToKey(date)} taskId=$taskId');
    } else {
       debugPrint('[DailyPlanProvider] addTodoTask skipped: taskId=$taskId already exists in date=${_dateToKey(date)}');
    }
  }

  /// 移除今日待办
  Future<void> removeTodoTask(DateTime date, String taskId) async {
    final dateKey = _dateToKey(date);
    debugPrint('[DailyPlanProvider] removeTodoTask called: dateKey=$dateKey taskId=$taskId');
    final plan = await getPlanForDate(date);
    debugPrint('[DailyPlanProvider] plan loaded: dateKey=${plan.dateKey} currentTodos=${plan.todoTaskIds}');
    
    if (plan.todoTaskIds.contains(taskId)) {
      plan.todoTaskIds.remove(taskId);
      await plan.save();
      notifyListeners();
      debugPrint('[DailyPlanProvider] removeTodoTask success: date=$dateKey taskId=$taskId remaining=${plan.todoTaskIds.length}');
    } else {
      debugPrint('[DailyPlanProvider] removeTodoTask failed: taskId=$taskId not found in plan for date=$dateKey. currentList=${plan.todoTaskIds}');
    }
  }

  /// 添加任务到今日全天任务
  Future<void> addAllDayTask(DateTime date, String taskId) async {
    final plan = await getPlanForDate(date);
    if (!plan.allDayTaskIds.contains(taskId)) {
      plan.allDayTaskIds.add(taskId);
      await plan.save();
      notifyListeners();
    }
  }

  /// 移除今日全天任务
  Future<void> removeAllDayTask(DateTime date, String taskId) async {
    final plan = await getPlanForDate(date);
    if (plan.allDayTaskIds.remove(taskId)) {
      await plan.save();
      notifyListeners();
    }
  }

  /// 添加时间块记录
  Future<void> addScheduledEvent(DateTime date, CalendarEventHive event) async {
    final plan = await getPlanForDate(date);
    // 检查 ID 是否已存在
    final exists = plan.scheduledEvents.any((e) => e.id == event.id);
    if (!exists) {
      plan.scheduledEvents.add(event);
      await plan.save();
      notifyListeners();
    }
  }

  /// 移除时间块记录
  Future<void> removeScheduledEvent(DateTime date, String eventId) async {
    final plan = await getPlanForDate(date);
    final initialLen = plan.scheduledEvents.length;
    plan.scheduledEvents.removeWhere((e) => e.id == eventId);
    if (plan.scheduledEvents.length != initialLen) {
      await plan.save();
      notifyListeners();
    }
  }

  /// 更新时间块记录
  Future<void> updateScheduledEvent(DateTime date, CalendarEventHive newEvent) async {
      final plan = await getPlanForDate(date);
      final index = plan.scheduledEvents.indexWhere((e) => e.id == newEvent.id);
      
      // 1. 如果在当前日期找到了，直接更新
      if (index != -1) {
          // 检查新日期是否还在当前日期范围内（允许一定容差，但如果跨天太远应迁移）
          final newStart = DateTime(newEvent.start.year, newEvent.start.month, newEvent.start.day);
          final currentDay = DateTime(date.year, date.month, date.day);
          
          if (newStart == currentDay) {
              plan.scheduledEvents[index] = newEvent;
              await plan.save();
              notifyListeners();
              return;
          } else {
              // 日期变了，需要迁移：先删除，再添加到新日期
              plan.scheduledEvents.removeAt(index);
              await plan.save();
              // 添加到新日期
              await addScheduledEvent(newStart, newEvent);
              notifyListeners(); // 两个日期都变了，通知全量刷新可能更安全，或者依赖各 View 的监听
              return;
          }
      }
      
      // 2. 如果没找到（可能是从别的日期拖过来的，或者数据不一致），尝试直接添加到目标日期
      // 但这里我们假设调用者知道 oldDate。如果不知道，可能需要全局搜（效率低）。
      // 暂时假设调用者负责确保 date 是正确的“旧日期”或“新日期”。
      // 如果调用此方法是意图“在 date 这天更新 event”，但 event 不在，那可能需要添加到这天。
      final newStart = DateTime(newEvent.start.year, newEvent.start.month, newEvent.start.day);
      await addScheduledEvent(newStart, newEvent);
  }

  /// 移动任务：待办 <-> 全天
  Future<void> toggleTaskType(DateTime date, String taskId) async {
    final plan = await getPlanForDate(date);
    if (plan.todoTaskIds.contains(taskId)) {
      plan.todoTaskIds.remove(taskId);
      plan.allDayTaskIds.add(taskId);
    } else if (plan.allDayTaskIds.contains(taskId)) {
      plan.allDayTaskIds.remove(taskId);
      plan.todoTaskIds.add(taskId);
    }
    await plan.save();
    notifyListeners();
  }

  String _dateToKey(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
