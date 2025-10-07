import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../data/models/checklist_task_hive.dart';
import '../../../../data/models/task_category_hive.dart';
import '../../../providers/task_list_provider.dart';
import 'task_item.dart';
import 'task_quick_add_input.dart';
import 'completed_tasks_section.dart';

/// 中间任务列表面板
class TaskListPanel extends StatelessWidget {
  const TaskListPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskListProvider>(
      builder: (context, provider, child) {
        final uncompletedTasks = provider.uncompletedTasks;
        final completedTasks = provider.completedTasks;

        // 获取当前类别名称
        String categoryName = '全部';
        if (provider.selectedCategoryId != null &&
            provider.selectedCategoryId != 'all') {
          try {
            final category = provider.categories.firstWhere(
              (c) => c.id == provider.selectedCategoryId,
            );
            categoryName = category.name;
          } catch (e) {
            categoryName = '全部';
          }
        }

        return Column(
          children: [
            // 头部
            _buildHeader(context, categoryName, uncompletedTasks.length),

            // 任务列表
            Expanded(
              child: uncompletedTasks.isEmpty && completedTasks.isEmpty
                  ? _buildEmptyState(context)
                  : _buildTaskList(context, provider, uncompletedTasks, completedTasks),
            ),

            // 底部快速添加
            TaskQuickAddInput(
              onSubmit: (title) => _handleAddTask(provider, title),
            ),
          ],
        );
      },
    );
  }

  /// 构建头部
  Widget _buildHeader(BuildContext context, String categoryName, int uncompletedCount) {
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
              categoryName,
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
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 24),
          Text(
            '暂无任务',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方输入框添加新任务',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
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
    List<dynamic> completedTasks,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 未完成任务列表
        if (uncompletedTasks.isNotEmpty) ...[
          ...uncompletedTasks.map((task) {
            // 查找任务所属类别，如果找不到则返回 null
            TaskCategoryHive? category;
            try {
              category = provider.categories.firstWhere(
                (c) => c.id == task.categoryId,
              );
            } catch (e) {
              // 如果找不到类别，使用 null（TaskItem 会处理）
              category = null;
            }

            return TaskItem(
              key: ValueKey(task.id),
              task: task,
              category: category,
              isSelected: provider.selectedTaskId == task.id,
              isCompleted: false,
              onTap: () => provider.selectTask(task.id),
              onToggleCompletion: () => provider.toggleTaskCompletion(task.id),
            );
          }),
        ],

        // 已完成任务折叠区
        CompletedTasksSection(
          completedTasks: completedTasks.cast<ChecklistTaskHive>(),
          categories: provider.categories,
          selectedTaskId: provider.selectedTaskId,
          isExpanded: provider.isCompletedTasksExpanded,
          onTaskTap: (taskId) => provider.selectTask(taskId),
          onToggleCompletion: (taskId) => provider.toggleTaskCompletion(taskId),
          onToggleExpanded: provider.toggleCompletedTasksExpanded,
        ),
      ],
    );
  }

  /// 处理添加任务
  void _handleAddTask(TaskListProvider provider, String title) {
    // 获取当前选中的类别ID，如果是"全部"则使用第一个类别
    String categoryId = provider.selectedCategoryId ?? 'work';
    if (categoryId == 'all') {
      categoryId = provider.categories.isNotEmpty
          ? provider.categories.first.id
          : 'work';
    }

    provider.createTask(
      title: title,
      categoryId: categoryId,
    );
  }
}
