// 专注会话数据模型
class FocusSessionModel {
  final int? id;
  final int? taskId;
  final String sessionType;
  final int duration;
  final int completedDuration;
  final String status;
  final DateTime startTime;
  final DateTime? endTime;
  final String? notes;
  final DateTime createdAt;
  
  const FocusSessionModel({
    this.id,
    this.taskId,
    required this.sessionType,
    required this.duration,
    this.completedDuration = 0,
    this.status = 'active',
    required this.startTime,
    this.endTime,
    this.notes,
    required this.createdAt,
  });
  
  // 从Map创建对象
  factory FocusSessionModel.fromMap(Map<String, dynamic> map) {
    return FocusSessionModel(
      id: map['id'],
      taskId: map['task_id'],
      sessionType: map['session_type'],
      duration: map['duration'],
      completedDuration: map['completed_duration'] ?? 0,
      status: map['status'] ?? 'active',
      startTime: DateTime.parse(map['start_time']),
      endTime: map['end_time'] != null ? DateTime.parse(map['end_time']) : null,
      notes: map['notes'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
  
  // 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'session_type': sessionType,
      'duration': duration,
      'completed_duration': completedDuration,
      'status': status,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }
  
  // 复制对象并修改部分属性
  FocusSessionModel copyWith({
    int? id,
    int? taskId,
    String? sessionType,
    int? duration,
    int? completedDuration,
    String? status,
    DateTime? startTime,
    DateTime? endTime,
    String? notes,
    DateTime? createdAt,
  }) {
    return FocusSessionModel(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      sessionType: sessionType ?? this.sessionType,
      duration: duration ?? this.duration,
      completedDuration: completedDuration ?? this.completedDuration,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
  
  // 获取剩余时间（分钟）
  int get remainingMinutes {
    return duration - completedDuration;
  }
  
  // 获取完成百分比
  double get completionPercentage {
    if (duration == 0) return 0.0;
    return (completedDuration / duration).clamp(0.0, 1.0);
  }
  
  // 检查是否已完成
  bool get isCompleted {
    return status == 'completed' || completedDuration >= duration;
  }
  
  // 检查是否正在进行
  bool get isActive {
    return status == 'active';
  }
  
  // 检查是否已暂停
  bool get isPaused {
    return status == 'paused';
  }
  
  @override
  String toString() {
    return 'FocusSessionModel(id: $id, sessionType: $sessionType, duration: $duration, status: $status)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FocusSessionModel && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
}


