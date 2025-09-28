// 专注会话实体
class FocusSession {
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

  const FocusSession({
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
}


