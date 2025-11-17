import 'package:hive/hive.dart';
import 'package:flutter/material.dart';

part 'task_category_hive.g.dart';

/// 任务类别数据模型（Hive）
@HiveType(typeId: 1)
class TaskCategoryHive extends HiveObject {
  @HiveField(0)
  String id;                    // 唯一标识
  
  @HiveField(1)
  String name;                  // 类别名称（如：工作、学习、生活）
  
  @HiveField(2)
  int colorValue;               // 主题色（存储Color.value）
  
  @HiveField(3)
  int order;                    // 排序序号
  
  TaskCategoryHive({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.order,
  });
  
  // 获取Color对象
  Color get color => Color(colorValue);
  
  // 设置Color对象
  set color(Color color) => colorValue = color.value;
  
  // 创建副本
  TaskCategoryHive copyWith({
    String? id,
    String? name,
    Color? color,
    int? order,
  }) {
    return TaskCategoryHive(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: color?.value ?? this.colorValue,
      order: order ?? this.order,
    );
  }
  
  @override
  String toString() {
    return 'TaskCategoryHive{id: $id, name: $name, order: $order}';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TaskCategoryHive && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
}

