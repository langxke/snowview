// 日程数据模型
class ScheduleModel {
  final int? id;
  final int taskId;
  final DateTime startTime;
  final DateTime endTime;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  const ScheduleModel({
    this.id,
    required this.taskId,
    required this.startTime,
    required this.endTime,
    this.status = 'scheduled',
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory ScheduleModel.fromMap(Map<String, dynamic> map) {
    return ScheduleModel(
      id: map['id'],
      taskId: map['task_id'],
      startTime: DateTime.parse(map['start_time']),
      endTime: DateTime.parse(map['end_time']),
      status: map['status'] ?? 'scheduled',
      notes: map['notes'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'status': status,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}


