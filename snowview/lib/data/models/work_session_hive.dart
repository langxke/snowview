import 'package:hive/hive.dart';

part 'work_session_hive.g.dart';

/// 工作会话数据模型（Hive）
/// 用于关联任务与日历时间段
@HiveType(typeId: 4)
class WorkSessionHive extends HiveObject {
  @HiveField(0)
  String id;                    // 唯一标识

  @HiveField(1)
  String taskId;                // 关联任务ID（必须）

  @HiveField(2)
  String? subTaskId;            // 关联子步骤ID（可选）

  @HiveField(3)
  DateTime startTime;           // 开始时间

  @HiveField(4)
  DateTime endTime;             // 结束时间

  @HiveField(5)
  String status;                // 状态：planned/completed/cancelled

  @HiveField(6)
  String? note;                 // 备注

  @HiveField(10)
  String? focusSessionId;       // 关联专注会话ID

  @HiveField(11)
  DateTime createdAt;           // 创建时间

  WorkSessionHive({
    required this.id,
    required this.taskId,
    this.subTaskId,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.note,
    this.focusSessionId,
    required this.createdAt,
  });

  // === 计算属性 ===

  /// 计划时长（分钟）
  int get plannedDuration {
    final duration = endTime.difference(startTime);
    return duration.inMinutes;
  }

  /// 是否已完成
  bool get isCompleted => status == 'completed';

  /// 是否已取消
  bool get isCancelled => status == 'cancelled';

  /// 是否计划中
  bool get isPlanned => status == 'planned';

  /// 是否跨天
  bool get isMultiDay {
    final startDate = DateTime(startTime.year, startTime.month, startTime.day);
    final endDate = DateTime(endTime.year, endTime.month, endTime.day);
    return !startDate.isAtSameMomentAs(endDate);
  }

  // === 复制方法（使用哨兵值处理可选字段） ===

  WorkSessionHive copyWith({
    String? id,
    String? taskId,
    Object? subTaskId = _undefined,
    DateTime? startTime,
    DateTime? endTime,
    String? status,
    Object? note = _undefined,
    Object? focusSessionId = _undefined,
    DateTime? createdAt,
  }) {
    return WorkSessionHive(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      subTaskId: subTaskId == _undefined ? this.subTaskId : subTaskId as String?,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      note: note == _undefined ? this.note : note as String?,
      focusSessionId: focusSessionId == _undefined 
          ? this.focusSessionId 
          : focusSessionId as String?,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'WorkSessionHive{id: $id, taskId: $taskId, status: $status, startTime: $startTime, endTime: $endTime}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WorkSessionHive && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// 用于区分"未传值"和"传null"的哨兵值
const Object _undefined = Object();

