import 'package:hive/hive.dart';

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
  bool isCompleted;             // 是否完成
  
  @HiveField(4)
  DateTime? dueDate;            // 截止日期
  
  @HiveField(5)
  DateTime? remindAt;           // 提醒时间

  @HiveField(6)
  DateTime createdAt;           // 创建时间
  
  @HiveField(7)
  DateTime? completedAt;        // 完成时间
  
  @HiveField(8)
  int order;                    // 排序序号

  @HiveField(9)
  bool isLongTerm;              // 是否长期任务
  
  ChecklistTaskHive({
    required this.id,
    required this.title,
    this.description,
    required this.isCompleted,
    this.dueDate,
    this.remindAt,
    required this.createdAt,
    this.completedAt,
    required this.order,
    this.isLongTerm = false,
  });
  
  // 创建副本
  ChecklistTaskHive copyWith({
    String? id,
    String? title,
    String? description,
    bool? isCompleted,
    Object? dueDate = _undefined,
    Object? remindAt = _undefined,
    DateTime? createdAt,
    Object? completedAt = _undefined,
    int? order,
    bool? isLongTerm,
  }) {
    return ChecklistTaskHive(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      dueDate: dueDate == _undefined ? this.dueDate : dueDate as DateTime?,
      remindAt: remindAt == _undefined ? this.remindAt : remindAt as DateTime?,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt == _undefined ? this.completedAt : completedAt as DateTime?,
      order: order ?? this.order,
      isLongTerm: isLongTerm ?? this.isLongTerm,
    );
  }
  
  @override
  String toString() {
    return 'ChecklistTaskHive{id: $id, title: $title, isCompleted: $isCompleted}';
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
