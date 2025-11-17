import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../../data/models/calendar_event_hive.dart';
import '../../data/repositories/work_session_repository.dart';
import '../../data/repositories/task_list_repository.dart';
import '../screens/schedule/models.dart';

class ScheduleProvider extends ChangeNotifier {
  final WorkSessionRepository _sessionRepository = WorkSessionRepository();
  final TaskListRepository _taskRepository = TaskListRepository();
  
  /// 获取指定日期的所有时间块（事件 + 任务会话）
  /// 返回转换为 CalendarEvent 的列表，包含类型标识
  List<CalendarEvent> getEventsForDate(DateTime date) {
    final events = <CalendarEvent>[];
    
    // 1. 获取日历事件
    final eventBox = Hive.box<CalendarEventHive>('calendar_events');
    final calendarEvents = eventBox.values.where((event) => event.intersects(date)).toList();
    
    for (final event in calendarEvents) {
      events.add(event.toCalendarEvent());
    }
    
    // 2. 获取任务会话并转换为 CalendarEvent
    final sessions = _sessionRepository.getSessionsByDate(date);
    
    for (final session in sessions) {
      // 获取关联的任务和类别
      final task = _taskRepository.getTaskById(session.taskId);
      if (task != null) {
        final category = _taskRepository.getCategoryById(task.categoryId);
        if (category != null) {
          // 获取关联的子步骤（如果有）
          final subTask = session.subTaskId != null
              ? task.subTasks.cast<dynamic>().firstWhere(
                  (st) => st.id == session.subTaskId,
                  orElse: () => null,
                )
              : null;
          
          // 转换为 CalendarEvent，标记为工作会话
          events.add(CalendarEvent(
            id: 'ws_${session.id}',  // 使用前缀避免ID冲突
            title: task.title,
            allDay: false,
            description: subTask?.title ?? session.note ?? '',
            color: category.color,
            start: session.startTime,
            end: session.endTime,
            isTaskSession: true,  // ✅ 标记为工作会话
            taskSessionId: session.id,  // ✅ 保存原始会话ID
          ));
        }
      }
    }
    
    // 3. 按开始时间排序
    events.sort((a, b) => a.start.compareTo(b.start));
    
    return events;
  }
  
  /// 获取时间范围内的所有事件（事件 + 任务会话）
  List<CalendarEvent> getEventsInRange(DateTime start, DateTime end) {
    final events = <CalendarEvent>[];
    
    // 1. 获取日历事件
    final eventBox = Hive.box<CalendarEventHive>('calendar_events');
    final calendarEvents = eventBox.values.where((event) {
      // 检查事件是否与时间范围相交
      return event.start.isBefore(end) && event.end.isAfter(start);
    }).toList();
    
    for (final event in calendarEvents) {
      events.add(event.toCalendarEvent());
    }
    
    // 2. 获取任务会话
    final sessions = _sessionRepository.getSessionsInRange(start, end);
    
    for (final session in sessions) {
      // 获取关联的任务和类别
      final task = _taskRepository.getTaskById(session.taskId);
      if (task != null) {
        final category = _taskRepository.getCategoryById(task.categoryId);
        if (category != null) {
          // 获取关联的子步骤（如果有）
          final subTask = session.subTaskId != null
              ? task.subTasks.cast<dynamic>().firstWhere(
                  (st) => st.id == session.subTaskId,
                  orElse: () => null,
                )
              : null;
          
          // 转换为 CalendarEvent，标记为工作会话
          events.add(CalendarEvent(
            id: 'ws_${session.id}',
            title: task.title,
            allDay: false,
            description: subTask?.title ?? session.note ?? '',
            color: category.color,
            start: session.startTime,
            end: session.endTime,
            isTaskSession: true,
            taskSessionId: session.id,
          ));
        }
      }
    }
    
    // 3. 按开始时间排序
    events.sort((a, b) => a.start.compareTo(b.start));
    
    return events;
  }
  
  /// 从会话ID获取完整的TimeBlock（需要关联任务和类别）
  TimeBlock? getTimeBlockFromSession(String sessionId) {
    final session = _sessionRepository.getSessionById(sessionId);
    if (session == null) return null;
    
    final task = _taskRepository.getTaskById(session.taskId);
    if (task == null) return null;
    
    final category = _taskRepository.getCategoryById(task.categoryId);
    if (category == null) return null;
    
    // 获取关联的子步骤（如果有）
    final subTask = session.subTaskId != null
        ? task.subTasks.cast<dynamic>().firstWhere(
            (st) => st.id == session.subTaskId,
            orElse: () => null,
          )
        : null;
    
    return TimeBlock.fromSession(
      session,
      task,
      category,
      subTask: subTask,
    );
  }
  
  /// 刷新视图
  void refresh() {
    notifyListeners();
  }
}
