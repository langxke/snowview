import 'package:hive/hive.dart';

part 'subtask_hive.g.dart';

/// 子步骤数据模型（Hive）
@HiveType(typeId: 2)
class SubTaskHive extends HiveObject {
  @HiveField(0)
  String id;                    // 唯一标识
  
  @HiveField(1)
  String title;                 // 步骤标题
  
  @HiveField(2)
  bool isCompleted;             // 是否完成
  
  @HiveField(3)
  int order;                    // 排序序号
  
  SubTaskHive({
    required this.id,
    required this.title,
    required this.isCompleted,
    required this.order,
  });
  
  // 创建副本
  SubTaskHive copyWith({
    String? id,
    String? title,
    bool? isCompleted,
    int? order,
  }) {
    return SubTaskHive(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      order: order ?? this.order,
    );
  }
  
  @override
  String toString() {
    return 'SubTaskHive{id: $id, title: $title, isCompleted: $isCompleted}';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SubTaskHive && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
}

