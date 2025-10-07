import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/task_list_provider.dart';

/// 右侧任务详情面板
class TaskDetailPanel extends StatefulWidget {
  const TaskDetailPanel({super.key});

  @override
  State<TaskDetailPanel> createState() => _TaskDetailPanelState();
}

class _TaskDetailPanelState extends State<TaskDetailPanel> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  String? _currentTaskId;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _updateControllersIfNeeded(dynamic task) {
    // 如果任务切换了，更新 controllers
    if (task?.id != _currentTaskId) {
      _currentTaskId = task?.id;
      _titleController.text = task?.title ?? '';
      _descriptionController.text = task?.description ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskListProvider>(
      builder: (context, provider, child) {
        final task = provider.selectedTask;
        if (task == null) return const SizedBox.shrink();

        // 更新 controllers（仅在任务切换时）
        _updateControllersIfNeeded(task);

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              left: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              // 头部 - 与TaskListPanel的头部高度对齐
              Container(
                height: 61, // 固定高度与任务列表头部一致
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                    Expanded(
                      child: Text(
                        '任务详情',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => provider.selectTask(null),
                      tooltip: '关闭',
                    ),
                  ],
                ),
              ),

              // 详情内容
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // 标题
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: '任务标题',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        if (value.trim().isNotEmpty) {
                          provider.updateTask(id: task.id, title: value.trim());
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    // 备注
                    TextField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: '备注',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 5,
                      onChanged: (value) {
                        provider.updateTask(id: task.id, description: value);
                      },
                    ),

                    const SizedBox(height: 16),

                    // 子步骤
                    Text(
                      '子步骤',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    if (task.subTasks.isEmpty)
                      const Text('暂无子步骤')
                    else
                      ...task.subTasks.map((subTask) => CheckboxListTile(
                        value: subTask.isCompleted,
                        onChanged: (_) => provider.toggleSubTask(task.id, subTask.id),
                        title: Text(
                          subTask.title,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        secondary: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: () => provider.deleteSubTask(task.id, subTask.id),
                        ),
                        contentPadding: EdgeInsets.zero,
                      )),

                    TextButton.icon(
                      onPressed: () {
                        _showAddSubTaskDialog(provider, task.id);
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('添加子步骤'),
                    ),

                    const SizedBox(height: 16),

                    // 截止日期
                    ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: const Text('截止日期'),
                      subtitle: Text(task.dueDate != null 
                          ? _formatDate(task.dueDate!)
                          : '未设置'),
                      trailing: task.dueDate != null
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => provider.updateTask(
                                id: task.id,
                                clearDueDate: true,
                              ),
                            )
                          : null,
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: task.dueDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          provider.updateTask(id: task.id, dueDate: date);
                        }
                      },
                      contentPadding: EdgeInsets.zero,
                    ),

                    const Divider(),

                    // 提醒时间
                    ListTile(
                      leading: const Icon(Icons.notifications_outlined),
                      title: const Text('提醒时间'),
                      subtitle: Text(task.remindAt != null 
                          ? _formatDateTime(task.remindAt!)
                          : '未设置'),
                      trailing: task.remindAt != null
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => provider.updateTask(
                                id: task.id,
                                clearRemindAt: true,
                              ),
                            )
                          : null,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('提醒功能即将实现')),
                        );
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),

              // 底部操作按钮
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).dividerColor,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showDeleteConfirmDialog(provider, task),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('删除任务'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          provider.toggleTaskCompletion(task.id);
                        },
                        icon: Icon(task.isCompleted 
                            ? Icons.restart_alt 
                            : Icons.check),
                        label: Text(task.isCompleted ? '重新打开' : '标记完成'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }

  String _formatDateTime(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showDeleteConfirmDialog(TaskListProvider provider, dynamic task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除任务"${task.title}"吗？\n此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              provider.deleteTask(task.id);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showAddSubTaskDialog(TaskListProvider provider, String taskId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加子步骤'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '输入步骤标题',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              provider.addSubTask(taskId, value.trim());
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                provider.addSubTask(taskId, controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }
}
