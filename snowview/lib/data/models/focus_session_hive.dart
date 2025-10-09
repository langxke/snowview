import 'package:hive/hive.dart';

part 'focus_session_hive.g.dart';

/// 专注会话数据模型（Hive）
/// TypeId: 5
@HiveType(typeId: 5)
class FocusSessionHive extends HiveObject {
  @HiveField(0)
  String id;                          // 唯一标识

  @HiveField(1)
  String? taskId;                     // 关联任务ID（可选）

  @HiveField(2)
  String? workSessionId;              // 关联工作会话ID（可选）

  @HiveField(3)
  String sessionType;                 // 会话类型：pomodoro/custom/break

  @HiveField(4)
  int plannedDuration;                // 计划时长（秒）

  @HiveField(5)
  int actualDuration;                 // 实际时长（秒）

  @HiveField(6)
  String status;                      // 状态：active/completed/paused/cancelled

  @HiveField(7)
  DateTime startTime;                 // 开始时间

  @HiveField(8)
  DateTime? endTime;                  // 结束时间（可为空表示未结束）

  @HiveField(9)
  String? note;                       // 备注

  @HiveField(10)
  bool isBreak;                       // 是否为休息时间

  @HiveField(11)
  List<DateTime> pauseTimestamps;     // 暂停时间戳列表

  @HiveField(12)
  DateTime createdAt;                 // 创建时间

  FocusSessionHive({
    required this.id,
    this.taskId,
    this.workSessionId,
    required this.sessionType,
    required this.plannedDuration,
    required this.actualDuration,
    required this.status,
    required this.startTime,
    this.endTime,
    this.note,
    required this.isBreak,
    required this.pauseTimestamps,
    required this.createdAt,
  });

  // === 计算属性 ===

  /// 剩余秒数
  int get remainingSeconds {
    if (status == 'completed' || status == 'cancelled') return 0;
    final elapsed = DateTime.now().difference(startTime).inSeconds;
    final remaining = plannedDuration - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  /// 是否已完成
  bool get isCompleted => status == 'completed';

  /// 是否已取消
  bool get isCancelled => status == 'cancelled';

  /// 是否暂停中
  bool get isPaused => status == 'paused';

  /// 是否进行中
  bool get isActive => status == 'active';

  /// 进度百分比（0.0-1.0）
  double get progress {
    if (plannedDuration == 0) return 0.0;
    final elapsed = actualDuration;
    final p = elapsed / plannedDuration;
    return p > 1.0 ? 1.0 : (p < 0.0 ? 0.0 : p);
  }

  // === 复制方法（使用哨兵值处理可选字段） ===

  FocusSessionHive copyWith({
    String? id,
    Object? taskId = _undefined,
    Object? workSessionId = _undefined,
    String? sessionType,
    int? plannedDuration,
    int? actualDuration,
    String? status,
    DateTime? startTime,
    Object? endTime = _undefined,
    Object? note = _undefined,
    bool? isBreak,
    List<DateTime>? pauseTimestamps,
    DateTime? createdAt,
  }) {
    return FocusSessionHive(
      id: id ?? this.id,
      taskId: taskId == _undefined ? this.taskId : taskId as String?,
      workSessionId: workSessionId == _undefined 
          ? this.workSessionId 
          : workSessionId as String?,
      sessionType: sessionType ?? this.sessionType,
      plannedDuration: plannedDuration ?? this.plannedDuration,
      actualDuration: actualDuration ?? this.actualDuration,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime == _undefined ? this.endTime : endTime as DateTime?,
      note: note == _undefined ? this.note : note as String?,
      isBreak: isBreak ?? this.isBreak,
      pauseTimestamps: pauseTimestamps ?? this.pauseTimestamps,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'FocusSessionHive{id: $id, sessionType: $sessionType, status: $status, plannedDuration: $plannedDuration}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FocusSessionHive && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// 用于区分"未传值"和"传null"的哨兵值
const Object _undefined = Object();

