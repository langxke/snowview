import 'package:hive/hive.dart';
import '../data/models/calendar_event_hive.dart';
import '../presentation/screens/schedule/models.dart' as schedule;

class CalendarDatabaseService {
  static const String _boxName = 'calendar_events';
  
  // 获取数据库实例
  Box<CalendarEventHive> get _box => Hive.box<CalendarEventHive>(_boxName);
  
  // 添加活动
  Future<void> addEvent(CalendarEventHive event) async {
    await _box.put(event.id, event);
  }
  
  // 从CalendarEvent添加活动（兼容现有代码）
  Future<String> addEventFromCalendarEvent(schedule.CalendarEvent event) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final hiveEvent = CalendarEventHive.fromCalendarEvent(event, id: id);
    await _box.put(hiveEvent.id, hiveEvent);
    return id;
  }
  
  // 更新活动
  Future<void> updateEvent(CalendarEventHive event) async {
    await _box.put(event.id, event);
  }
  
  // 更新活动（通过ID和CalendarEvent）
  Future<void> updateEventById(String id, schedule.CalendarEvent event) async {
    final hiveEvent = CalendarEventHive.fromCalendarEvent(event, id: id);
    await _box.put(id, hiveEvent);
  }
  
  // 删除活动
  Future<void> deleteEvent(String eventId) async {
    await _box.delete(eventId);
  }
  
  // 删除活动（通过CalendarEvent对象）
  Future<void> deleteEventByCalendarEvent(schedule.CalendarEvent event) async {
    // 通过匹配属性找到对应的Hive事件
    final hiveEvent = _box.values.firstWhere(
      (e) => e.title == event.title && 
             e.start == event.start && 
             e.end == event.end &&
             e.description == event.description,
      orElse: () => throw Exception('Event not found'),
    );
    await _box.delete(hiveEvent.id);
  }
  
  // 获取所有活动
  List<CalendarEventHive> getAllEvents() {
    return _box.values.toList();
  }
  
  // 获取所有活动（返回CalendarEvent列表，兼容现有代码）
  List<schedule.CalendarEvent> getAllCalendarEvents() {
    return _box.values.map((e) => e.toCalendarEvent()).toList();
  }
  
  // 获取指定日期的活动
  List<CalendarEventHive> getEventsForDate(DateTime date) {
    return _box.values.where((event) => event.intersects(date)).toList();
  }
  
  // 获取指定日期的活动（返回CalendarEvent列表）
  List<schedule.CalendarEvent> getCalendarEventsForDate(DateTime date) {
    return _box.values
        .where((event) => event.intersects(date))
        .map((e) => e.toCalendarEvent())
        .toList();
  }
  
  // 获取指定日期范围的活动
  List<CalendarEventHive> getEventsInRange(DateTime start, DateTime end) {
    return _box.values.where((event) {
      return event.start.isBefore(end.add(Duration(days: 1))) &&
             event.end.isAfter(start.subtract(Duration(days: 1)));
    }).toList();
  }
  
  // 获取指定日期范围的活动（返回CalendarEvent列表）
  List<schedule.CalendarEvent> getCalendarEventsInRange(DateTime start, DateTime end) {
    return _box.values
        .where((event) {
          return event.start.isBefore(end.add(Duration(days: 1))) &&
                 event.end.isAfter(start.subtract(Duration(days: 1)));
        })
        .map((e) => e.toCalendarEvent())
        .toList();
  }
  
  // 根据ID获取活动
  CalendarEventHive? getEventById(String id) {
    return _box.get(id);
  }
  
  // 根据ID获取活动（返回CalendarEvent）
  schedule.CalendarEvent? getCalendarEventById(String id) {
    final hiveEvent = _box.get(id);
    return hiveEvent?.toCalendarEvent();
  }
  
  // 查找CalendarEvent对应的ID
  String? findEventId(schedule.CalendarEvent event) {
    try {
      final hiveEvent = _box.values.firstWhere(
        (e) => e.title == event.title && 
               e.start == event.start && 
               e.end == event.end &&
               e.description == event.description,
      );
      return hiveEvent.id;
    } catch (e) {
      return null;
    }
  }
  
  // 清空所有数据
  Future<void> clearAllEvents() async {
    await _box.clear();
  }
  
  // 获取活动总数
  int get eventCount => _box.length;
  
  // 监听数据变化
  Stream<BoxEvent> watchEvents() {
    return _box.watch();
  }
  
  // 批量添加活动
  Future<void> addMultipleEvents(List<CalendarEventHive> events) async {
    final Map<String, CalendarEventHive> eventMap = {};
    for (final event in events) {
      eventMap[event.id] = event;
    }
    await _box.putAll(eventMap);
  }
  
  // 批量删除活动
  Future<void> deleteMultipleEvents(List<String> eventIds) async {
    await _box.deleteAll(eventIds);
  }

  // 搜索活动（按标题）
  List<CalendarEventHive> searchEventsByTitle(String query) {
    final lowerQuery = query.toLowerCase();
    return _box.values
        .where((event) => event.title.toLowerCase().contains(lowerQuery))
        .toList();
  }
  
  // 搜索活动（按标题，返回CalendarEvent列表）
  List<schedule.CalendarEvent> searchCalendarEventsByTitle(String query) {
    final lowerQuery = query.toLowerCase();
    return _box.values
        .where((event) => event.title.toLowerCase().contains(lowerQuery))
        .map((e) => e.toCalendarEvent())
        .toList();
  }
  
  // 获取今天的活动数量
  int getTodayEventCount() {
    final today = DateTime.now();
    return getEventsForDate(today).length;
  }
  
  // 获取本周的活动数量
  int getThisWeekEventCount() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(Duration(days: 6));
    return getEventsInRange(startOfWeek, endOfWeek).length;
  }
  
  // 数据库状态检查
  bool get isBoxOpen => Hive.isBoxOpen(_boxName);
  
  // 关闭数据库
  Future<void> closeBox() async {
    if (isBoxOpen) {
      await _box.close();
    }
  }
  
  // 压缩数据库
  Future<void> compactBox() async {
    await _box.compact();
  }
}