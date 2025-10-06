import 'package:flutter/material.dart';
import 'constants.dart';

/// 时间相关工具类
class TimeUtils {
  // 私有构造函数，防止实例化
  TimeUtils._();
  
  /// 格式化时间显示（HH:mm格式）
  /// 
  /// 例如：formatTime(TimeOfDay(hour: 9, minute: 30)) => "09:30"
  static String formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
  
  /// 生成小时标签（HH:00格式）
  /// 
  /// 例如：hourLabel(9) => "09:00"
  static String hourLabel(int hour) {
    return '${hour.toString().padLeft(2, '0')}:00';
  }
  
  /// 根据Y坐标计算15分钟段索引（0-95）
  /// 
  /// [y] Y坐标位置
  /// 返回值范围：0-95（24小时 * 4个15分钟段）
  static int getQuarterFromY(double y) {
    final quarter = (y / (CalendarConstants.hourRowHeight / 4)).floor();
    return quarter.clamp(0, CalendarConstants.totalQuarters - 1);
  }
  
  /// 将15分钟段索引转换为TimeOfDay
  /// 
  /// [quarter] 15分钟段索引（0-95）
  /// 例如：quarterToTimeOfDay(6) => TimeOfDay(hour: 1, minute: 30)
  static TimeOfDay quarterToTimeOfDay(int quarter) {
    final hour = quarter ~/ 4;
    final minute = (quarter % 4) * 15;
    return TimeOfDay(hour: hour, minute: minute);
  }
  
  /// 计算事件在时间轴上的Y坐标
  /// 
  /// [dateTime] 事件的时间
  /// 返回从00:00开始计算的Y坐标
  static double timeToY(DateTime dateTime) {
    final minutes = dateTime.hour * 60 + dateTime.minute;
    return (minutes / 15) * (CalendarConstants.hourRowHeight / 4);
  }
  
  /// 根据分钟数计算Y坐标
  /// 
  /// [minutes] 从00:00开始的分钟数
  static double minutesToY(int minutes) {
    return (minutes / 15) * (CalendarConstants.hourRowHeight / 4);
  }
  
  /// 根据Y坐标计算分钟数
  /// 
  /// [y] Y坐标位置
  static int yToMinutes(double y) {
    return ((y / (CalendarConstants.hourRowHeight / 4)) * 15).round();
  }
}

