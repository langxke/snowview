// 日程实体
class Schedule {
  final int? id;
  final int taskId;
  final DateTime startTime;
  final DateTime endTime;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Schedule({
    this.id,
    required this.taskId,
    required this.startTime,
    required this.endTime,
    this.status = 'scheduled',
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });
}


