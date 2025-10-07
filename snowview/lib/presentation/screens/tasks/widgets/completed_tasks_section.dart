import 'package:flutter/material.dart';
import '../../../../data/models/checklist_task_hive.dart';
import '../../../../data/models/task_category_hive.dart';
import 'task_item.dart';

/// 已完成任务折叠区域
class CompletedTasksSection extends StatelessWidget {
  final List<ChecklistTaskHive> completedTasks;
  final List<TaskCategoryHive> categories;
  final String? selectedTaskId;
  final bool isExpanded;
  final Function(String taskId) onTaskTap;
  final Function(String taskId) onToggleCompletion;
  final VoidCallback onToggleExpanded;

  const CompletedTasksSection({
    super.key,
    required this.completedTasks,
    required this.categories,
    this.selectedTaskId,
    required this.isExpanded,
    required this.onTaskTap,
    required this.onToggleCompletion,
    required this.onToggleExpanded,
  });

  @override
  Widget build(BuildContext context) {
    if (completedTasks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(top: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).dividerColor,
          width: 1,
        ),
      ),
      child: ExpansionTile(
        leading: Icon(
          Icons.check_circle_outline,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          '已完成',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        subtitle: Text(
          '${completedTasks.length} 个任务',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
        ),
        initiallyExpanded: isExpanded,
        onExpansionChanged: (_) => onToggleExpanded(),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: completedTasks.map((task) {
                final category = categories.firstWhere(
                  (c) => c.id == task.categoryId,
                  orElse: () => categories.first,
                );

                return TaskItem(
                  task: task,
                  category: category,
                  isSelected: selectedTaskId == task.id,
                  isCompleted: true,
                  onTap: () => onTaskTap(task.id),
                  onToggleCompletion: () => onToggleCompletion(task.id),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

