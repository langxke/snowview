import 'package:flutter/material.dart';
import '../../../../data/models/checklist_task_hive.dart';
import '../../../../data/models/task_category_hive.dart';
import '../utils/task_utils.dart';

/// 单个任务条目组件
class TaskItem extends StatelessWidget {
  final ChecklistTaskHive task;
  final TaskCategoryHive? category;
  final bool isSelected;
  final bool isCompleted;
  final VoidCallback onTap;
  final VoidCallback onToggleCompletion;

  const TaskItem({
    super.key,
    required this.task,
    this.category,
    required this.isSelected,
    required this.isCompleted,
    required this.onTap,
    required this.onToggleCompletion,
  });

  @override
  Widget build(BuildContext context) {
    final categoryColor = category?.color ?? Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
            : null,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: categoryColor,
            width: 3,
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Checkbox
                Checkbox(
                  value: task.isCompleted,
                  onChanged: (_) => onToggleCompletion(),
                ),
                
                const SizedBox(width: 8),
                
                // 任务内容
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 标题
                      Text(
                        task.title,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        style: isCompleted
                            ? TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.5),
                              )
                            : Theme.of(context).textTheme.bodyLarge,
                      ),
                      
                      // 子步骤进度
                      if (task.subTasks.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.checklist_outlined,
                              size: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              TaskUtils.formatSubTaskProgress(
                                task.completedSubTasksCount,
                                task.totalSubTasksCount,
                              ),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.6),
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                
                // 截止日期标签
                if (task.dueDate != null) ...[
                  const SizedBox(width: 8),
                  _buildDueDateChip(context, task.dueDate!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDueDateChip(BuildContext context, DateTime dueDate) {
    final isOverdue = TaskUtils.isOverdue(dueDate);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isOverdue
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today,
            size: 12,
            color: isOverdue
                ? Theme.of(context).colorScheme.onErrorContainer
                : Theme.of(context).colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            TaskUtils.formatDueDate(dueDate),
            style: TextStyle(
              fontSize: 11,
              color: isOverdue
                  ? Theme.of(context).colorScheme.onErrorContainer
                  : Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

