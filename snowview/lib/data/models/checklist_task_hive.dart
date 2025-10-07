import 'package:hive/hive.dart';
import 'subtask_hive.dart';

part 'checklist_task_hive.g.dart';

/// 清单任务数据模型（Hive）
@HiveType(typeId: 3)
class ChecklistTaskHive extends HiveObject {
  @HiveField(0)
  String id;                    // 唯一标识
  
  @HiveField(1)
  String title;                 // 标题
  
  @HiveField(2)
  String? description;          // 备注/描述
  
  @HiveField(3)
  String categoryId;            // 所属类别
  
  @HiveField(4)
  bool isCompleted;             // 是否完成
  
  @HiveField(5)
  DateTime? dueDate;            // 截止日期
  
  @HiveField(6)
  DateTime? remindAt;           // 提醒时间
  
  @HiveField(7)
  List<SubTaskHive> subTasks;   // 子步骤列表
  
  @HiveField(8)
  DateTime createdAt;           // 创建时间
  
  @HiveField(9)
  DateTime? completedAt;        // 完成时间
  
  @HiveField(10)
  int order;                    // 排序序号
  
  ChecklistTaskHive({
    required this.id,
    required this.title,
    this.description,
    required this.categoryId,
    required this.isCompleted,
    this.dueDate,
    this.remindAt,
    required this.subTasks,
    required this.createdAt,
    this.completedAt,
    required this.order,
  });
  
  // 获取已完成子步骤数量
  int get completedSubTasksCount => 
      subTasks.where((st) => st.isCompleted).length;
  
  // 获取子步骤总数
  int get totalSubTasksCount => subTasks.length;
  
  // 创建副本
  ChecklistTaskHive copyWith({
    String? id,
    String? title,
    String? description,
    String? categoryId,
    bool? isCompleted,
    Object? dueDate = _undefined,
    Object? remindAt = _undefined,
    List<SubTaskHive>? subTasks,
    DateTime? createdAt,
    Object? completedAt = _undefined,
    int? order,
  }) {
    return ChecklistTaskHive(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      isCompleted: isCompleted ?? this.isCompleted,
      dueDate: dueDate == _undefined ? this.dueDate : dueDate as DateTime?,
      remindAt: remindAt == _undefined ? this.remindAt : remindAt as DateTime?,
      subTasks: subTasks ?? this.subTasks,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt == _undefined ? this.completedAt : completedAt as DateTime?,
      order: order ?? this.order,
    );
  }
  
  @override
  String toString() {
    return 'ChecklistTaskHive{id: $id, title: $title, categoryId: $categoryId, isCompleted: $isCompleted}';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChecklistTaskHive && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
}

// 用于区分"未传值"和"传null"的哨兵值
const Object _undefined = Object();
