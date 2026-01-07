import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../data/models/checklist_task_hive.dart';
import '../../../providers/task_list_provider.dart';
import 'task_item.dart';
import 'task_quick_add_input.dart';
import 'completed_tasks_section.dart';

enum _TaskContextAction {
  rename,
  scheduleToday,
  markCompleted,
  delete,
}

/// 中间任务列表面板
class TaskListPanel extends StatelessWidget {
  const TaskListPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskListProvider>(
      builder: (context, provider, child) {
        return FutureBuilder<Set<String>>(
          future: provider.getRecurringTaskIds(),
          builder: (context, snapshot) {
            final recurringIds = snapshot.data ?? const <String>{};
            final scheduledTasks = provider.scheduledUncompletedTasks.toList()
              ..sort((a, b) {
                final ar = recurringIds.contains(a.id);
                final br = recurringIds.contains(b.id);
                if (ar != br) return ar ? -1 : 1;
                return (a.dueDate!).compareTo(b.dueDate!);
              });
            final uncompletedTasks = provider.unscheduledUncompletedTasks.toList()
              ..sort((a, b) {
                final ar = recurringIds.contains(a.id);
                final br = recurringIds.contains(b.id);
                if (ar != br) return ar ? -1 : 1;
                return b.createdAt.compareTo(a.createdAt);
              });
            final completedTasks = provider.completedTasks;

            return Column(
              children: [
                // 头部
                _buildHeader(context, uncompletedTasks.length),

                // 任务列表
                Expanded(
                  child: uncompletedTasks.isEmpty && scheduledTasks.isEmpty && completedTasks.isEmpty
                      ? _buildEmptyState(context)
                      : _buildTaskList(context, provider, uncompletedTasks, scheduledTasks, completedTasks),
                ),

                // 底部快速添加
                TaskQuickAddInput(
                  onSubmit: (title) => _handleAddTask(provider, title),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 构建头部
  Widget _buildHeader(BuildContext context, int uncompletedCount) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Flexible(
            child: Text(
              '清单',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$uncompletedCount 个待办',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(77),
          ),
          const SizedBox(height: 24),
          Text(
            '暂无任务',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方输入框添加新任务',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(102),
                ),
          ),
        ],
      ),
    );
  }

  /// 构建任务列表
  Widget _buildTaskList(
    BuildContext context,
    TaskListProvider provider,
    List<dynamic> uncompletedTasks,
    List<dynamic> scheduledTasks,
    List<dynamic> completedTasks,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (uncompletedTasks.isNotEmpty) ...[
          _ScheduledHeader(
            title: '未安排任务',
            count: uncompletedTasks.length,
            expanded: provider.isUnscheduledTasksExpanded,
            onToggle: provider.toggleUnscheduledTasksExpanded,
          ),
          if (provider.isUnscheduledTasksExpanded)
            ...uncompletedTasks.map((task) {
              return TaskItem(
                key: ValueKey(task.id),
                task: task,
                isSelected: provider.selectedTaskId == task.id,
                isCompleted: false,
                onTap: () => provider.toggleNoteEditor(task.id),
                onSecondaryTapDown: (details) => _showTaskContextMenu(
                  context,
                  provider: provider,
                  task: task as ChecklistTaskHive,
                  position: details.globalPosition,
                ),
                onToggleCompletion: () => provider.toggleTaskCompletion(task.id),
              );
            }),
        ],

        if (scheduledTasks.isNotEmpty) ...[
          _ScheduledHeader(
            title: '已安排任务',
            count: scheduledTasks.length,
            expanded: provider.isScheduledTasksExpanded,
            onToggle: provider.toggleScheduledTasksExpanded,
          ),
          if (provider.isScheduledTasksExpanded)
            ...scheduledTasks.map((task) {
              return TaskItem(
                key: ValueKey(task.id),
                task: task,
                isSelected: provider.selectedTaskId == task.id,
                isCompleted: false,
                onTap: () => provider.toggleNoteEditor(task.id),
                onSecondaryTapDown: (details) => _showTaskContextMenu(
                  context,
                  provider: provider,
                  task: task as ChecklistTaskHive,
                  position: details.globalPosition,
                ),
                onToggleCompletion: () => provider.toggleTaskCompletion(task.id),
              );
            }),
        ],

        // 已完成任务折叠区
        CompletedTasksSection(
          completedTasks: completedTasks.cast<ChecklistTaskHive>(),
          selectedTaskId: provider.selectedTaskId,
          isExpanded: provider.isCompletedTasksExpanded,
          onTaskTap: (taskId) => provider.toggleNoteEditor(taskId),
          onTaskSecondaryTapDown: (taskId, details) {
            final task = completedTasks
                .cast<ChecklistTaskHive>()
                .firstWhere((t) => t.id == taskId);
            _showTaskContextMenu(
              context,
              provider: provider,
              task: task,
              position: details.globalPosition,
            );
          },
          onToggleCompletion: (taskId) => provider.toggleTaskCompletion(taskId),
          onToggleExpanded: provider.toggleCompletedTasksExpanded,
        ),
      ],
    );
  }

  Future<void> _showTaskContextMenu(
    BuildContext context, {
    required TaskListProvider provider,
    required ChecklistTaskHive task,
    required Offset position,
  }) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<_TaskContextAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        overlay.size.width - position.dx,
        overlay.size.height - position.dy,
      ),
      items: [
        const PopupMenuItem<_TaskContextAction>(
          value: _TaskContextAction.rename,
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 18),
              SizedBox(width: 8),
              Text('重命名'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<_TaskContextAction>(
          value: _TaskContextAction.scheduleToday,
          child: const Row(
            children: [
              Text('📅  '),
              Text('安排到今天'),
            ],
          ),
        ),
        PopupMenuItem<_TaskContextAction>(
          value: _TaskContextAction.markCompleted,
          enabled: !task.isCompleted,
          child: Row(
            children: [
              const Text('✅  '),
              const Text('标记为完成'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<_TaskContextAction>(
          value: _TaskContextAction.delete,
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18),
              SizedBox(width: 8),
              Text('删除任务'),
            ],
          ),
        ),
      ],
    );

    if (!context.mounted) return;
    if (selected == null) return;

    switch (selected) {
      case _TaskContextAction.rename:
        provider.startRenaming(task.id);
        break;
      case _TaskContextAction.scheduleToday:
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        await provider.updateTask(id: task.id, dueDate: today);
        break;
      case _TaskContextAction.markCompleted:
        await provider.toggleTaskCompletion(task.id);
        break;
      case _TaskContextAction.delete:
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除任务？'),
            content: Text('将删除「${task.title}」'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('删除'),
              ),
            ],
          ),
        );
        if (!context.mounted) return;
        if (confirm == true && context.mounted) {
          await provider.deleteTask(task.id);
        }
        break;
    }
  }

  /// 处理添加任务
  void _handleAddTask(TaskListProvider provider, String title) {
    provider.createTask(
      title: title,
    );
  }
}

class _ScheduledHeader extends StatelessWidget {
  final String title;
  final int count;
  final bool expanded;
  final VoidCallback onToggle;

  const _ScheduledHeader({
    required this.title,
    required this.count,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        );

    final subtitleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
        );

    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(expanded ? Icons.expand_more : Icons.chevron_right, size: 20),
            const SizedBox(width: 6),
            Text(title, style: titleStyle),
            const SizedBox(width: 8),
            Text('$count', style: subtitleStyle),
            const Spacer(),
            Icon(
              Icons.event_available_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
            ),
          ],
        ),
      ),
    );
  }
}
