import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models.dart';
import 'time_utils.dart';

/// 事件相关工具类
class EventUtils {
  // 私有构造函数，防止实例化
  EventUtils._();
  
  /// 获取活动的唯一标识
  /// 
  /// [event] 日历事件
  static String getId(CalendarEvent event) {
    return event.id;
  }
  
  /// 复制活动到剪贴板
  /// 
  /// [event] 要复制的日历事件
  /// [context] 用于显示提示消息的BuildContext
  static void copyToClipboard(CalendarEvent event, BuildContext context) {
    final eventText = '${event.title}\n'
        '${TimeUtils.formatTime(TimeOfDay.fromDateTime(event.start))}-'
        '${TimeUtils.formatTime(TimeOfDay.fromDateTime(event.end))}';
    
    Clipboard.setData(ClipboardData(text: eventText));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('活动已复制到剪贴板')),
    );
  }
  
  /// 从剪贴板粘贴活动
  /// 
  /// [context] BuildContext
  /// [date] 目标日期
  /// [selectedStartQuarter] 选中的开始15分钟段（可选）
  /// [selectedEndQuarter] 选中的结束15分钟段（可选）
  /// [onAddEvent] 添加事件的回调
  static Future<void> pasteFromClipboard({
    required BuildContext context,
    required DateTime date,
    int? selectedStartQuarter,
    int? selectedEndQuarter,
    required Function(CalendarEvent) onAddEvent,
  }) async {
    final data = await Clipboard.getData('text/plain');
    
    if (data?.text != null && data!.text!.isNotEmpty) {
      final lines = data.text!.split('\n');
      final title = lines[0].trim();
      
      DateTime startTime;
      DateTime endTime;
      
      if (selectedStartQuarter != null && selectedEndQuarter != null) {
        // 使用选中的时间段
        final startTimeOfDay = TimeUtils.quarterToTimeOfDay(selectedStartQuarter);
        final endTimeOfDay = TimeUtils.quarterToTimeOfDay(selectedEndQuarter + 1);
        
        startTime = DateTime(
          date.year,
          date.month,
          date.day,
          startTimeOfDay.hour,
          startTimeOfDay.minute,
        );
        endTime = DateTime(
          date.year,
          date.month,
          date.day,
          endTimeOfDay.hour,
          endTimeOfDay.minute,
        );
      } else {
        // 默认创建1小时活动，从当前时间开始
        final now = DateTime.now();
        startTime = DateTime(
          date.year,
          date.month,
          date.day,
          now.hour,
          0,
        );
        endTime = startTime.add(const Duration(hours: 1));
      }
      
      final newEvent = CalendarEvent(
        title: title,
        allDay: false,
        description: '',
        color: Colors.blue, // 默认颜色
        start: startTime,
        end: endTime,
        isTaskSession: false,  // ✅ 从剪贴板粘贴的是普通事件
        taskSessionId: null,
      );
      
      onAddEvent(newEvent);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('活动已粘贴')),
        );
      }
    }
  }
  
  /// 创建活动副本
  /// 
  /// [event] 要复制的原始事件
  /// [context] 用于显示提示消息的BuildContext
  /// [onAddEvent] 添加事件的回调
  /// [hourOffset] 时间偏移（小时），默认为1小时
  static void createDuplicate({
    required CalendarEvent event,
    required BuildContext context,
    required Function(CalendarEvent) onAddEvent,
    int hourOffset = 1,
  }) {
    // ✅ 复制事件时不能保留 ID 和工作会话标识（应该创建新事件）
    final newEvent = CalendarEvent(
      // id 会自动生成新的
      title: '${event.title} (副本)',
      allDay: event.allDay,
      description: event.description,
      color: event.color,
      start: event.start.add(Duration(hours: hourOffset)),
      end: event.end.add(Duration(hours: hourOffset)),
      isTaskSession: false,  // 副本总是普通事件
      taskSessionId: null,
    );
    
    onAddEvent(newEvent);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('活动副本已创建')),
    );
  }
  
  /// 更新活动颜色
  /// 
  /// [originalEvent] 原始事件
  /// [newColor] 新颜色
  /// [onUpdateEvent] 更新事件的回调
  /// 返回是否进行了更新
  static bool updateColor({
    required CalendarEvent originalEvent,
    required Color newColor,
    required Function(CalendarEvent, CalendarEvent)? onUpdateEvent,
  }) {
    if (newColor == originalEvent.color || onUpdateEvent == null) {
      return false;
    }
    
    // ✅ 使用 copyWith 保持所有字段
    final updatedEvent = originalEvent.copyWith(color: newColor);
    
    onUpdateEvent(originalEvent, updatedEvent);
    return true;
  }
}

