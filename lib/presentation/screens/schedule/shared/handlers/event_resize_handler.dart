import '../../models.dart';
import '../utils/constants.dart';

/// 事件调整大小的计算结果
class ResizeResult {
  /// 新的开始时间
  final DateTime newStart;
  
  /// 新的结束时间
  final DateTime newEnd;
  
  /// 是否发生了头尾互换
  final bool wasSwapped;

  const ResizeResult({
    required this.newStart,
    required this.newEnd,
    this.wasSwapped = false,
  });
}

/// 事件调整大小处理器
/// 
/// 负责处理事件调整大小的所有计算逻辑：
/// - 头尾互换
/// - 边界限制
/// - 最小时长保证
class EventResizeHandler {
  // 私有构造函数，防止实例化
  EventResizeHandler._();

  /// 计算调整大小后的新时间
  /// 
  /// [originalStartTime] 原始开始时间（拖拽开始时保存）
  /// [originalEndTime] 原始结束时间（拖拽开始时保存）
  /// [totalDeltaY] 从拖拽开始位置的总Y轴移动距离
  /// [isResizingTop] 是否调整顶部（true=开始时间，false=结束时间）
  /// [boundaryDate] 边界日期（事件应限制在这一天内）
  /// 
  /// 返回计算后的新时间
  static ResizeResult calculateResize({
    required DateTime originalStartTime,
    required DateTime originalEndTime,
    required double totalDeltaY,
    required bool isResizingTop,
    required DateTime boundaryDate,
  }) {
    // 计算拖拽的15分钟段数
    final deltaQuarters = (totalDeltaY / (CalendarConstants.hourRowHeight / 4)).round();
    
    DateTime newStart = originalStartTime;
    DateTime newEnd = originalEndTime;
    bool wasSwapped = false;
    
    // 定义边界：当天的00:00到23:59
    final dayStart = DateTime(boundaryDate.year, boundaryDate.month, boundaryDate.day, 0, 0);
    final dayEnd = DateTime(boundaryDate.year, boundaryDate.month, boundaryDate.day, 23, 59);
    
    // 使用原始时间作为计算基准，避免状态突变
    if (isResizingTop) {
      // 调整开始时间（拖动顶部）
      newStart = originalStartTime.add(Duration(minutes: deltaQuarters * 15));
      
      // 如果新开始时间超过原始结束时间，进行平滑的头尾互换
      if (newStart.isAfter(originalEndTime)) {
        // 计算超出部分，应用到另一端
        final overflowMinutes = newStart.difference(originalEndTime).inMinutes;
        newStart = originalEndTime;
        newEnd = originalEndTime.add(Duration(minutes: overflowMinutes));
        wasSwapped = true;
      } else {
        // 正常拖动，保持结束时间不变
        newEnd = originalEndTime;
      }
    } else {
      // 调整结束时间（拖动底部）
      newEnd = originalEndTime.add(Duration(minutes: deltaQuarters * 15));
      
      // 如果新结束时间早于原始开始时间，进行平滑的头尾互换
      if (newEnd.isBefore(originalStartTime)) {
        // 计算超出部分，应用到另一端
        final overflowMinutes = originalStartTime.difference(newEnd).inMinutes;
        newEnd = originalStartTime;
        newStart = originalStartTime.subtract(Duration(minutes: overflowMinutes));
        wasSwapped = true;
      } else {
        // 正常拖动，保持开始时间不变
        newStart = originalStartTime;
      }
    }
    
    // 应用边界限制
    if (newStart.isBefore(dayStart)) {
      newStart = dayStart;
    }
    if (newEnd.isAfter(dayEnd)) {
      newEnd = dayEnd;
    }
    
    // 确保最小15分钟时长
    final minDuration = Duration(minutes: CalendarConstants.minEventDurationMinutes);
    if (newEnd.difference(newStart) < minDuration) {
      if (isResizingTop) {
        // 如果在拖动顶部，调整开始时间
        newStart = newEnd.subtract(minDuration);
        if (newStart.isBefore(dayStart)) {
          newStart = dayStart;
          newEnd = newStart.add(minDuration);
          // 如果调整后的结束时间超出边界，则限制在边界内
          if (newEnd.isAfter(dayEnd)) {
            newEnd = dayEnd;
            newStart = newEnd.subtract(minDuration);
          }
        }
      } else {
        // 如果在拖动底部，调整结束时间
        newEnd = newStart.add(minDuration);
        if (newEnd.isAfter(dayEnd)) {
          newEnd = dayEnd;
          newStart = newEnd.subtract(minDuration);
          // 如果调整后的开始时间超出边界，则限制在边界内
          if (newStart.isBefore(dayStart)) {
            newStart = dayStart;
            newEnd = newStart.add(minDuration);
          }
        }
      }
    }
    
    return ResizeResult(
      newStart: newStart,
      newEnd: newEnd,
      wasSwapped: wasSwapped,
    );
  }

  /// 验证并修正最终的事件时间
  /// 
  /// [event] 要验证的事件
  /// 返回修正后的事件（如果需要）
  static CalendarEvent validateAndFixEvent(CalendarEvent event) {
    final duration = event.end.difference(event.start);
    
    // 如果时长小于15分钟，进行修正
    if (duration.inMinutes < CalendarConstants.minEventDurationMinutes) {
      return event.copyWith(
        end: event.start.add(Duration(minutes: CalendarConstants.minEventDurationMinutes)),
      );
    }
    
    return event;
  }

  /// 检查事件是否真正改变了
  /// 
  /// [event] 当前事件
  /// [originalStart] 原始开始时间
  /// [originalEnd] 原始结束时间
  /// 
  /// 返回是否发生了真正的改变
  static bool hasChanged(
    CalendarEvent event,
    DateTime originalStart,
    DateTime originalEnd,
  ) {
    return event.start != originalStart || event.end != originalEnd;
  }
}

