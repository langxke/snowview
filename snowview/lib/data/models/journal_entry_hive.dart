import 'package:hive/hive.dart';

part 'journal_entry_hive.g.dart';

/// 记录条目数据模型（Hive）
/// TypeId: 7
@HiveType(typeId: 7)
class JournalEntryHive extends HiveObject {
  @HiveField(0)
  String id;                          // 唯一标识

  @HiveField(1)
  String title;                       // 标题（可选）

  @HiveField(2)
  String content;                     // Markdown 内容

  @HiveField(3)
  String categoryId;                  // 关联类别ID

  @HiveField(4)
  DateTime createdAt;                 // 创建时间

  @HiveField(5)
  DateTime updatedAt;                 // 更新时间

  @HiveField(6)
  List<String> tags;                  // 标签列表

  @HiveField(7)
  String? mood;                       // 心情emoji（可选）

  @HiveField(8)
  List<String> relatedTaskIds;        // 关联任务ID

  @HiveField(9)
  int? dailyFocusMinutes;             // 当日专注时长（自动）

  @HiveField(10)
  bool isPinned;                      // 是否置顶

  JournalEntryHive({
    required this.id,
    required this.title,
    required this.content,
    required this.categoryId,
    required this.createdAt,
    required this.updatedAt,
    required this.tags,
    this.mood,
    required this.relatedTaskIds,
    this.dailyFocusMinutes,
    required this.isPinned,
  });

  // === 计算属性 ===

  /// 显示标题（无标题时用日期）
  String get displayTitle {
    if (title.trim().isNotEmpty) {
      return title;
    }
    // 无标题时使用日期
    return dateFormatted;
  }

  /// 格式化日期
  String get dateFormatted {
    final year = createdAt.year;
    final month = createdAt.month.toString().padLeft(2, '0');
    final day = createdAt.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// 字数统计
  int get wordCount {
    // 移除 Markdown 标记后统计字数
    final plainText = content
        .replaceAll(RegExp(r'[#*`\-\[\]()!]'), '')  // 移除 Markdown 符号
        .replaceAll(RegExp(r'\s+'), ' ')            // 合并空白
        .trim();
    return plainText.length;
  }

  /// 内容摘要（前100字符）
  String get contentSummary {
    final plainText = content
        .replaceAll(RegExp(r'[#*`\-\[\]()!]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (plainText.length <= 100) {
      return plainText;
    }
    return '${plainText.substring(0, 100)}...';
  }

  // === 复制方法（使用哨兵值处理可选字段） ===

  JournalEntryHive copyWith({
    String? id,
    String? title,
    String? content,
    String? categoryId,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tags,
    Object? mood = _undefined,
    List<String>? relatedTaskIds,
    Object? dailyFocusMinutes = _undefined,
    bool? isPinned,
  }) {
    return JournalEntryHive(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      categoryId: categoryId ?? this.categoryId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
      mood: mood == _undefined ? this.mood : mood as String?,
      relatedTaskIds: relatedTaskIds ?? this.relatedTaskIds,
      dailyFocusMinutes: dailyFocusMinutes == _undefined 
          ? this.dailyFocusMinutes 
          : dailyFocusMinutes as int?,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  @override
  String toString() {
    return 'JournalEntryHive{id: $id, title: $title, categoryId: $categoryId, createdAt: $createdAt}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is JournalEntryHive && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// 用于区分"未传值"和"传null"的哨兵值
const Object _undefined = Object();

