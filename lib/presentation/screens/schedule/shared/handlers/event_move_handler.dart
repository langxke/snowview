import '../../models.dart';
import '../utils/constants.dart';

/// 事件移动的计算结果
class MoveResult {
  /// 新的开始时间
  final DateTime newStart;
  
  /// 新的结束时间
  final DateTime newEnd;
  
  /// 是否超过了移动阈值
  final bool hasMoved;
  
  /// 目标日期（可能与原日期不同，用于跨天移动）
  final DateTime? targetDate;

  const MoveResult({
    required this.newStart,
    required this.newEnd,
    required this.hasMoved,
    this.targetDate,
  });
}

/// 事件移动处理器基类
/// 
/// 负责处理事件移动的计算逻辑：
/// - 时长保持
/// - 边界限制
/// - 移动阈值检测
abstract class EventMoveHandler {
  /// 计算移动后的新时间
  /// 
  /// [originalStartTime] 原始开始时间
  /// [originalEndTime] 原始结束时间
  /// [totalDeltaY] Y轴总移动距离
  /// [boundaryDate] 边界日期
  /// [previouslyMoved] 之前是否已经移动过
  /// 
  /// 返回计算后的结果
  MoveResult calculateMove({
    required DateTime originalStartTime,
    required DateTime originalEndTime,
    required double totalDeltaY,
    required DateTime boundaryDate,
    required bool previouslyMoved,
  });

  /// 检查是否超过了移动阈值
  /// 
  /// [deltaY] Y轴移动距离
  /// [previouslyMoved] 之前是否已经移动过
  /// 
  /// 返回是否应标记为已移动
  bool checkMovementThreshold(double deltaY, bool previouslyMoved) {
    if (previouslyMoved) return true;
    return deltaY.abs() > CalendarConstants.movementThresholdY;
  }

  /// 应用边界限制
  /// 
  /// [start] 开始时间
  /// [end] 结束时间
  /// [boundaryDate] 边界日期
  /// 
  /// 返回限制后的时间
  ({DateTime start, DateTime end}) applyBoundaries({
    required DateTime start,
    required DateTime end,
    required DateTime boundaryDate,
  }) {
    final dayStart = DateTime(boundaryDate.year, boundaryDate.month, boundaryDate.day, 0, 0);
    final dayEnd = DateTime(boundaryDate.year, boundaryDate.month, boundaryDate.day, 23, 59);
    final duration = end.difference(start);
    
    var newStart = start;
    var newEnd = end;
    
    // 限制开始时间不早于00:00
    if (newStart.isBefore(dayStart)) {
      newStart = dayStart;
      newEnd = newStart.add(duration);
    }
    
    // 限制结束时间不晚于23:59
    if (newEnd.isAfter(dayEnd)) {
      newEnd = dayEnd;
      newStart = newEnd.subtract(duration);
      
      // 如果活动时长太长，开始时间会早于00:00，则调整为最大可能的时长
      if (newStart.isBefore(dayStart)) {
        newStart = dayStart;
        newEnd = dayEnd;
      }
    }
    
    return (start: newStart, end: newEnd);
  }
}

/// 日视图事件移动处理器
/// 
/// 只处理单列内的垂直移动
class DayEventMoveHandler extends EventMoveHandler {
  @override
  MoveResult calculateMove({
    required DateTime originalStartTime,
    required DateTime originalEndTime,
    required double totalDeltaY,
    required DateTime boundaryDate,
    required bool previouslyMoved,
  }) {
    // 计算拖拽的15分钟段数
    final deltaQuarters = (totalDeltaY / (CalendarConstants.hourRowHeight / 4)).round();
    
    // 计算新的开始和结束时间（保持时长不变）
    final duration = originalEndTime.difference(originalStartTime);
    var newStart = originalStartTime.add(Duration(minutes: deltaQuarters * 15));
    var newEnd = newStart.add(duration);
    
    // 应用边界限制
    final bounded = applyBoundaries(
      start: newStart,
      end: newEnd,
      boundaryDate: boundaryDate,
    );
    newStart = bounded.start;
    newEnd = bounded.end;
    
    // 检查移动阈值
    final hasMoved = checkMovementThreshold(totalDeltaY, previouslyMoved);
    
    return MoveResult(
      newStart: newStart,
      newEnd: newEnd,
      hasMoved: hasMoved,
    );
  }
}

/// 周视图事件移动处理器
/// 
/// 处理跨列移动，支持X轴和Y轴移动
class WeekEventMoveHandler extends EventMoveHandler {
  /// 根据X坐标计算目标列
  /// 
  /// [currentGlobalX] 当前全局X坐标
  /// [stackGlobalX] Stack组件的全局X坐标
  /// [availableWidth] 可用宽度
  /// 
  /// 返回目标列索引（0-6）
  static int calculateTargetColumn({
    required double currentGlobalX,
    required double stackGlobalX,
    required double availableWidth,
  }) {
    // 计算相对于网格左边缘的位置（考虑时间标签宽度）
    final relativeX = currentGlobalX - stackGlobalX - CalendarConstants.gutterWidth;
    
    // 计算列宽度
    final columnWidth = availableWidth / 7;
    
    // 计算目标列（直接基于位置）
    int targetColumn = (relativeX / columnWidth).floor();
    
    return targetColumn.clamp(0, 6);
  }

  @override
  MoveResult calculateMove({
    required DateTime originalStartTime,
    required DateTime originalEndTime,
    required double totalDeltaY,
    required DateTime boundaryDate,
    required bool previouslyMoved,
    double? totalDeltaX,
    List<DateTime>? weekDays,
    int? targetColumnIndex,
  }) {
    // 计算Y轴移动
    final deltaQuarters = (totalDeltaY / (CalendarConstants.hourRowHeight / 4)).round();
    
    // 计算新的开始和结束时间（保持时长不变）
    final duration = originalEndTime.difference(originalStartTime);
    
    // 确定目标日期
    DateTime targetDate = boundaryDate;
    if (weekDays != null && targetColumnIndex != null) {
      targetDate = weekDays[targetColumnIndex];
    }
    
    // 获取原始时间在一天中的时分秒
    final timeOfDay = Duration(
      hours: originalStartTime.hour,
      minutes: originalStartTime.minute,
      seconds: originalStartTime.second,
    );
    
    // 在目标日期上应用时间和Y轴偏移
    var newStart = DateTime(targetDate.year, targetDate.month, targetDate.day)
        .add(timeOfDay)
        .add(Duration(minutes: deltaQuarters * 15));
    var newEnd = newStart.add(duration);
    
    // 应用边界限制
    final bounded = applyBoundaries(
      start: newStart,
      end: newEnd,
      boundaryDate: targetDate,
    );
    newStart = bounded.start;
    newEnd = bounded.end;
    
    // 检查移动阈值（考虑X轴和Y轴）
    bool hasMoved = previouslyMoved;
    if (!hasMoved) {
      final xThreshold = totalDeltaX != null && 
                        totalDeltaX.abs() > CalendarConstants.movementThresholdX;
      final yThreshold = totalDeltaY.abs() > CalendarConstants.movementThresholdY;
      hasMoved = xThreshold || yThreshold;
    }
    
    return MoveResult(
      newStart: newStart,
      newEnd: newEnd,
      hasMoved: hasMoved,
      targetDate: targetDate,
    );
  }
}

/// 事件移动处理器工具方法
class EventMoveHandlerUtils {
  // 私有构造函数，防止实例化
  EventMoveHandlerUtils._();

  /// 检查事件是否真正改变了位置
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

