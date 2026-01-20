import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../../data/models/calendar_event_hive.dart';
import '../screens/schedule/models.dart';
import '../../services/calendar_database_service.dart';

class ScheduleProvider extends ChangeNotifier {
  final CalendarDatabaseService databaseService = CalendarDatabaseService();

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
    
    // 2. 按开始时间排序
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
    
    // 2. 按开始时间排序
    events.sort((a, b) => a.start.compareTo(b.start));
    
    return events;
  }
  
  /// 刷新视图
  void refresh() {
    notifyListeners();
  }
}
