import '../utils/time_utils.dart';

/// 时间段选择处理器
/// 
/// 负责处理时间段选择的逻辑：
/// - 判断15分钟段是否被选中
/// - 计算选择范围
class TimeSelectionHandler {
  // 私有构造函数，防止实例化
  TimeSelectionHandler._();

  /// 判断某个15分钟段是否被选中
  /// 
  /// [quarterIndex] 15分钟段索引（0-95）
  /// [selectedStartQuarter] 选中的开始15分钟段
  /// [selectedEndQuarter] 选中的结束15分钟段
  /// 
  /// 返回是否被选中
  static bool isQuarterSelected({
    required int quarterIndex,
    required int? selectedStartQuarter,
    required int? selectedEndQuarter,
  }) {
    if (selectedStartQuarter == null || selectedEndQuarter == null) return false;
    return quarterIndex >= selectedStartQuarter && quarterIndex <= selectedEndQuarter;
  }

  /// 判断某个15分钟段在特定列是否被选中（用于周视图）
  /// 
  /// [quarterIndex] 15分钟段索引（0-95）
  /// [column] 列索引（0-6）
  /// [selectedStartQuarter] 选中的开始15分钟段
  /// [selectedEndQuarter] 选中的结束15分钟段
  /// [selectedColumn] 选中的列
  /// 
  /// 返回是否被选中
  static bool isQuarterSelectedInColumn({
    required int quarterIndex,
    required int column,
    required int? selectedStartQuarter,
    required int? selectedEndQuarter,
    required int? selectedColumn,
  }) {
    if (selectedStartQuarter == null || 
        selectedEndQuarter == null || 
        selectedColumn == null) {
      return false;
    }
    
    if (selectedColumn != column) return false;
    
    return quarterIndex >= selectedStartQuarter && quarterIndex <= selectedEndQuarter;
  }

  /// 计算选择范围
  /// 
  /// [initialQuarter] 初始点击的15分钟段
  /// [currentQuarter] 当前拖拽到的15分钟段
  /// 
  /// 返回 (开始, 结束) 的元组
  static ({int start, int end}) calculateSelectionRange({
    required int initialQuarter,
    required int currentQuarter,
  }) {
    // 总是以初始点为基准，确保开始时间 <= 结束时间
    if (currentQuarter >= initialQuarter) {
      // 向下拖拽：从初始位置到当前位置
      return (start: initialQuarter, end: currentQuarter);
    } else {
      // 向上拖拽：从当前位置到初始位置
      return (start: currentQuarter, end: initialQuarter);
    }
  }

  /// 从选中的15分钟段创建时间范围
  /// 
  /// [date] 日期
  /// [startQuarter] 开始的15分钟段
  /// [endQuarter] 结束的15分钟段（包含）
  /// 
  /// 返回 (开始时间, 结束时间) 的元组
  /// 注意：结束时间是 endQuarter + 1 的开始时间
  static ({DateTime start, DateTime end}) createTimeRange({
    required DateTime date,
    required int startQuarter,
    required int endQuarter,
  }) {
    final startTimeOfDay = TimeUtils.quarterToTimeOfDay(startQuarter);
    // 结束时间为选中结束时间段的下一个15分钟
    final endTimeOfDay = TimeUtils.quarterToTimeOfDay(endQuarter + 1);
    
    final startTime = DateTime(
      date.year,
      date.month,
      date.day,
      startTimeOfDay.hour,
      startTimeOfDay.minute,
    );
    
    final endTime = DateTime(
      date.year,
      date.month,
      date.day,
      endTimeOfDay.hour,
      endTimeOfDay.minute,
    );
    
    return (start: startTime, end: endTime);
  }

  /// 验证选择范围是否有效
  /// 
  /// [startQuarter] 开始的15分钟段
  /// [endQuarter] 结束的15分钟段
  /// 
  /// 返回是否有效
  static bool isValidSelection({
    required int? startQuarter,
    required int? endQuarter,
  }) {
    if (startQuarter == null || endQuarter == null) return false;
    return startQuarter <= endQuarter;
  }

  /// 清空选择状态
  /// 
  /// 返回重置后的状态值
  static ({
    int? startQuarter,
    int? endQuarter,
    int? initialQuarter,
    int? selectedColumn,
  }) clearSelection() {
    return (
      startQuarter: null,
      endQuarter: null,
      initialQuarter: null,
      selectedColumn: null,
    );
  }
}

