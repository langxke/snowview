// 任务实体
class Task {
  final int? id;
  final String title;
  final String? description;
  final int priority;
  final String? category;
  final int? estimatedDuration;
  final int? actualDuration;
  final String status;
  final int? parentTaskId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Task({
    this.id,
    required this.title,
    this.description,
    this.priority = 1,
    this.category,
    this.estimatedDuration,
    this.actualDuration,
    this.status = 'pending',
    this.parentTaskId,
    required this.createdAt,
    required this.updatedAt,
  });
}


