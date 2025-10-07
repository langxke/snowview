/// 任务相关工具类
class TaskUtils {
  /// 格式化截止日期
  static String formatDueDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) return '今天';
    if (dateOnly == tomorrow) return '明天';
    
    final daysDifference = dateOnly.difference(today).inDays;
    if (daysDifference < 0) {
      return '已逾期';
    }
    if (daysDifference < 7) {
      return '${date.month}/${date.day}';
    }
    return '${date.month}月${date.day}日';
  }

  /// 判断日期是否已过期
  static bool isOverdue(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    return dateOnly.isBefore(today);
  }

  /// 格式化子步骤进度
  static String formatSubTaskProgress(int completed, int total) {
    return '$completed/$total 步骤完成';
  }
}

