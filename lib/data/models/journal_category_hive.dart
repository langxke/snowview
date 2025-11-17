import 'package:hive/hive.dart';
import 'package:flutter/material.dart';

part 'journal_category_hive.g.dart';

/// 记录类别数据模型（Hive）
/// TypeId: 8
@HiveType(typeId: 8)
class JournalCategoryHive extends HiveObject {
  @HiveField(0)
  String id;                    // 唯一标识

  @HiveField(1)
  String name;                  // 类别名称（如"日记"、"工作日志"）

  @HiveField(2)
  int colorValue;               // 颜色值

  @HiveField(3)
  int order;                    // 排序序号

  @HiveField(4)
  DateTime createdAt;           // 创建时间

  JournalCategoryHive({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.order,
    required this.createdAt,
  });

  // 获取 Color 对象
  Color get color => Color(colorValue);

  // 设置 Color 对象
  set color(Color color) => colorValue = color.value;

  // 创建副本
  JournalCategoryHive copyWith({
    String? id,
    String? name,
    int? colorValue,
    int? order,
    DateTime? createdAt,
  }) {
    return JournalCategoryHive(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'JournalCategoryHive{id: $id, name: $name}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is JournalCategoryHive && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}


