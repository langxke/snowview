// 任务数据模型
class TaskModel {
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
  
  const TaskModel({
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
  
  factory TaskModel.fromMap(Map<String, dynamic> map) {
    return TaskModel(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      priority: map['priority'] ?? 1,
      category: map['category'],
      estimatedDuration: map['estimated_duration'],
      actualDuration: map['actual_duration'],
      status: map['status'] ?? 'pending',
      parentTaskId: map['parent_task_id'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'priority': priority,
      'category': category,
      'estimated_duration': estimatedDuration,
      'actual_duration': actualDuration,
      'status': status,
      'parent_task_id': parentTaskId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}


