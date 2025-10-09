import 'package:hive/hive.dart';
import 'focus_session_hive.dart';

part 'focus_daily_stats_hive.g.dart';

/// 每日专注统计数据模型（Hive）
/// TypeId: 6
@HiveType(typeId: 6)
class FocusDailyStatsHive extends HiveObject {
  @HiveField(0)
  String id;                          // 唯一标识（日期字符串，如"2025-10-08"）

  @HiveField(1)
  DateTime date;                      // 统计日期

  @HiveField(2)
  int totalFocusSeconds;              // 总专注时长（秒）

  @HiveField(3)
  int completedSessionCount;          // 完成的专注会话数

  @HiveField(4)
  int pomodoroCount;                  // 完成的番茄钟数量

  @HiveField(5)
  int totalBreakSeconds;              // 总休息时长（秒）

  @HiveField(6)
  List<String> focusedTaskIds;        // 专注过的任务ID列表

  @HiveField(7)
  DateTime createdAt;                 // 创建时间

  @HiveField(8)
  DateTime updatedAt;                 // 更新时间

  FocusDailyStatsHive({
    required this.id,
    required this.date,
    required this.totalFocusSeconds,
    required this.completedSessionCount,
    required this.pomodoroCount,
    required this.totalBreakSeconds,
    required this.focusedTaskIds,
    required this.createdAt,
    required this.updatedAt,
  });

  // === 计算属性 ===

  /// 格式化总时长（如"2h 35m"）
  String get totalFocusTimeFormatted {
    if (totalFocusSeconds == 0) return '0m';
    
    final hours = totalFocusSeconds ~/ 3600;
    final minutes = (totalFocusSeconds % 3600) ~/ 60;
    
    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${minutes}m';
    }
  }

  /// 平均会话时长（分钟）
  double get averageSessionDuration {
    if (completedSessionCount == 0) return 0.0;
    return (totalFocusSeconds / 60) / completedSessionCount;
  }

  // === 添加会话方法 ===

  /// 添加一个专注会话到统计中
  void addSession(FocusSessionHive session) {
    if (!session.isCompleted) return;
    
    // 累加时长
    if (session.isBreak) {
      totalBreakSeconds += session.actualDuration;
    } else {
      totalFocusSeconds += session.actualDuration;
    }
    
    // 累加会话数
    completedSessionCount++;
    
    // 如果是番茄钟，累加番茄钟数
    if (session.sessionType == 'pomodoro') {
      pomodoroCount++;
    }
    
    // 添加任务ID（如果有且未添加过）
    if (session.taskId != null && !focusedTaskIds.contains(session.taskId)) {
      focusedTaskIds.add(session.taskId!);
    }
    
    // 更新时间
    updatedAt = DateTime.now();
  }

  // === 复制方法 ===

  FocusDailyStatsHive copyWith({
    String? id,
    DateTime? date,
    int? totalFocusSeconds,
    int? completedSessionCount,
    int? pomodoroCount,
    int? totalBreakSeconds,
    List<String>? focusedTaskIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FocusDailyStatsHive(
      id: id ?? this.id,
      date: date ?? this.date,
      totalFocusSeconds: totalFocusSeconds ?? this.totalFocusSeconds,
      completedSessionCount: completedSessionCount ?? this.completedSessionCount,
      pomodoroCount: pomodoroCount ?? this.pomodoroCount,
      totalBreakSeconds: totalBreakSeconds ?? this.totalBreakSeconds,
      focusedTaskIds: focusedTaskIds ?? this.focusedTaskIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'FocusDailyStatsHive{id: $id, date: $date, totalFocusSeconds: $totalFocusSeconds, completedSessions: $completedSessionCount}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FocusDailyStatsHive && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

