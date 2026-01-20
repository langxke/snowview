import 'package:hive/hive.dart';
import 'calendar_event_hive.dart';

part 'daily_plan_hive.g.dart';

/// 每日计划数据模型 (Hive)
/// 作为“每日视图的唯一真理源”，存储当天的所有安排索引
@HiveType(typeId: 4)
class DailyPlanHive extends HiveObject {
  @HiveField(0)
  String dateKey; // 主键 "yyyy-MM-dd"

  /// 【今日任务 (全天)】：指向 ChecklistTask (原 allDay Events)
  @HiveField(1)
  List<String> allDayTaskIds; 

  /// 【今日待办】：指向 ChecklistTask
  @HiveField(2)
  List<String> todoTaskIds; 

  /// 【时间块 (日程)】：嵌入 CalendarEvent 对象列表
  @HiveField(4)
  List<CalendarEventHive> scheduledEvents; 

  /// 【已废弃】旧版存储 Event ID
  @HiveField(3)
  List<String>? legacyScheduledEventIds;

  DailyPlanHive({
    required this.dateKey,
    List<String>? allDayTaskIds,
    List<String>? todoTaskIds,
    List<CalendarEventHive>? scheduledEvents,
    this.legacyScheduledEventIds,
  }) : 
    allDayTaskIds = allDayTaskIds ?? [],
    todoTaskIds = todoTaskIds ?? [],
    scheduledEvents = scheduledEvents ?? [];

  @override
  String toString() {
    return 'DailyPlanHive{dateKey: $dateKey, allDay: ${allDayTaskIds.length}, todos: ${todoTaskIds.length}, scheduled: ${scheduledEvents.length}, legacyIds: ${legacyScheduledEventIds?.length}}';
  }
}
