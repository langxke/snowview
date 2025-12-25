import 'package:flutter/material.dart';
import '../../../../data/models/checklist_task_hive.dart';
import 'task_item.dart';

/// 已完成任务折叠区域
class CompletedTasksSection extends StatelessWidget {
  final List<ChecklistTaskHive> completedTasks;
  final String? selectedTaskId;
  final bool isExpanded;
  final Function(String taskId) onTaskTap;
  final void Function(String taskId, TapDownDetails details)? onTaskSecondaryTapDown;
  final Function(String taskId) onToggleCompletion;
  final VoidCallback onToggleExpanded;

  const CompletedTasksSection({
    super.key,
    required this.completedTasks,
    required this.selectedTaskId,
    required this.isExpanded,
    required this.onTaskTap,
    this.onTaskSecondaryTapDown,
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
                return TaskItem(
                  task: task,
                  isSelected: selectedTaskId == task.id,
                  isCompleted: true,
                  onTap: () => onTaskTap(task.id),
                  onSecondaryTapDown: onTaskSecondaryTapDown != null
                      ? (details) => onTaskSecondaryTapDown!(task.id, details)
                      : null,
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

