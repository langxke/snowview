import 'package:hive/hive.dart';
import 'package:flutter/material.dart';
import '../../presentation/screens/schedule/models.dart' as schedule;

part 'calendar_event_hive.g.dart'; // 生成的适配器文件

@HiveType(typeId: 0)
class CalendarEventHive extends HiveObject {
  @HiveField(0)
  String id;              // 唯一标识符
  
  @HiveField(1)
  String title;           // 活动标题
  
  @HiveField(2)
  String description;     // 活动描述
  
  @HiveField(3)
  bool allDay;           // 是否全天活动
  
  @HiveField(4)
  DateTime start;        // 开始时间
  
  @HiveField(5)
  DateTime end;          // 结束时间
  
  @HiveField(6)
  int colorValue;        // 颜色值 (Color.value)
  
  CalendarEventHive({
    required this.id,
    required this.title,
    required this.description,
    required this.allDay,
    required this.start,
    required this.end,
    required this.colorValue,
  });
  
  // 获取Color对象
  Color get color => Color(colorValue);
  
  // 设置Color对象
  set color(Color color) => colorValue = color.value;
  
  // 兼容现有代码的intersects方法
  bool intersects(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    return !(d.isBefore(s) || d.isAfter(e));
  }
  
  // 创建副本方法
  CalendarEventHive copyWith({
    String? id,
    String? title,
    String? description,
    bool? allDay,
    DateTime? start,
    DateTime? end,
    Color? color,
  }) {
    return CalendarEventHive(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      allDay: allDay ?? this.allDay,
      start: start ?? this.start,
      end: end ?? this.end,
      colorValue: color?.value ?? this.colorValue,
    );
  }
  
  // 转换为现有的CalendarEvent类型（用于兼容现有代码）
  schedule.CalendarEvent toCalendarEvent() {
    return schedule.CalendarEvent(
      id: id,  // ✅ 保持相同的ID
      title: title,
      allDay: allDay,
      description: description,
      color: color,
      start: start,
      end: end,
      isTaskSession: false,  // ✅ 标记为日历事件
      taskSessionId: null,   // ✅ 不是工作会话
    );
  }
  
  // 从现有的CalendarEvent创建（用于兼容现有代码）
  static CalendarEventHive fromCalendarEvent(schedule.CalendarEvent event, {String? id}) {
    return CalendarEventHive(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: event.title,
      description: event.description,
      allDay: event.allDay,
      start: event.start,
      end: event.end,
      colorValue: event.color.value,
    );
  }
  
  @override
  String toString() {
    return 'CalendarEventHive{id: $id, title: $title, start: $start, end: $end, allDay: $allDay}';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CalendarEventHive && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
}

