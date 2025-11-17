/// 日历视图相关常量
class CalendarConstants {
  // 私有构造函数，防止实例化
  CalendarConstants._();
  
  /// 每小时行的高度（像素）
  static const double hourRowHeight = 100.0;
  
  /// 时间标签区域的宽度（像素）
  static const double gutterWidth = 56.0;
  
  /// 日视图中调整手柄的高度（像素）
  static const double resizeHandleHeightDay = 12.0;
  
  /// 周视图中调整手柄的高度（像素）
  static const double resizeHandleHeightWeek = 20.0;
  
  /// 15分钟段的总数（24小时 * 4）
  static const int totalQuarters = 96;
  
  /// 最小活动时长（分钟）
  static const int minEventDurationMinutes = 15;
  
  /// 移动检测阈值 - Y轴（像素）
  static const double movementThresholdY = 5.0;
  
  /// 移动检测阈值 - X轴（像素）
  static const double movementThresholdX = 10.0;
}

