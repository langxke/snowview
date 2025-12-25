import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../data/models/checklist_task_hive.dart';
import '../utils/task_utils.dart';
import '../../../providers/task_list_provider.dart';

/// 单个任务条目组件
class TaskItem extends StatefulWidget {
  final ChecklistTaskHive task;
  final bool isSelected;
  final bool isCompleted;
  final VoidCallback onTap;
  final GestureTapDownCallback? onSecondaryTapDown;
  final VoidCallback onToggleCompletion;

  const TaskItem({
    super.key,
    required this.task,
    required this.isSelected,
    required this.isCompleted,
    required this.onTap,
    this.onSecondaryTapDown,
    required this.onToggleCompletion,
  });

  @override
  State<TaskItem> createState() => _TaskItemState();
}

class _TaskItemState extends State<TaskItem> {
  late final TextEditingController _renameController;
  late final FocusNode _renameFocusNode;
  late final TextEditingController _noteController;
  late final FocusNode _noteFocusNode;

  @override
  void initState() {
    super.initState();
    _renameController = TextEditingController();
    _renameFocusNode = FocusNode();
    _renameFocusNode.addListener(() {
      if (!_renameFocusNode.hasFocus) {
        _commitRenameIfNeeded();
      }
    });

    _noteController = TextEditingController();
    _noteFocusNode = FocusNode();
    _noteFocusNode.addListener(() {
      if (!_noteFocusNode.hasFocus) {
        _commitNoteIfNeeded();
      }
    });
  }

  @override
  void dispose() {
    _renameController.dispose();
    _renameFocusNode.dispose();
    _noteController.dispose();
    _noteFocusNode.dispose();
    super.dispose();
  }

  Future<void> _commitRenameIfNeeded() async {
    final provider = context.read<TaskListProvider>();
    if (provider.renamingTaskId != widget.task.id) return;

    final newTitle = _renameController.text.trim();
    final oldTitle = widget.task.title;

    if (newTitle.isEmpty || newTitle == oldTitle) {
      provider.cancelRenaming();
      return;
    }

    await provider.updateTask(id: widget.task.id, title: newTitle);
    if (!mounted) return;
    provider.cancelRenaming();
  }

  Future<void> _commitNoteIfNeeded() async {
    final provider = context.read<TaskListProvider>();
    if (provider.expandedNoteTaskId != widget.task.id) return;

    final newDesc = _noteController.text.trimRight();
    final oldDesc = (widget.task.description ?? '').trimRight();

    if (newDesc == oldDesc) return;
    await provider.updateTask(id: widget.task.id, description: newDesc);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskListProvider>();
    final isRenaming = provider.renamingTaskId == widget.task.id;
    final isNoteExpanded = provider.expandedNoteTaskId == widget.task.id;
    final accentColor = Theme.of(context).colorScheme.primary;

    if (isNoteExpanded && !isRenaming) {
      final text = widget.task.description ?? '';
      if (_noteController.text != text) {
        _noteController.text = text;
        _noteController.selection = TextSelection.fromPosition(
          TextPosition(offset: _noteController.text.length),
        );
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && isNoteExpanded && !isRenaming) {
          _noteFocusNode.requestFocus();
        }
      });
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: widget.isSelected
            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
            : null,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: accentColor,
            width: 3,
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: isRenaming ? null : widget.onTap,
          onSecondaryTapDown: widget.onSecondaryTapDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Checkbox
                    Checkbox(
                      value: widget.task.isCompleted,
                      onChanged: (_) => widget.onToggleCompletion(),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // 任务内容
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 标题
                          if (isRenaming)
                            RawKeyboardListener(
                              focusNode: FocusNode(),
                              onKey: (event) {
                                if (event is RawKeyDownEvent &&
                                    event.logicalKey == LogicalKeyboardKey.escape) {
                                  provider.cancelRenaming();
                                }
                              },
                              child: TextField(
                                controller: _renameController..text = widget.task.title,
                                focusNode: _renameFocusNode,
                                autofocus: true,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                style: Theme.of(context).textTheme.bodyLarge,
                                textInputAction: TextInputAction.done,
                                onTap: () {
                                  _renameController.selection = TextSelection(
                                    baseOffset: 0,
                                    extentOffset: _renameController.text.length,
                                  );
                                },
                                onSubmitted: (_) => _commitRenameIfNeeded(),
                              ),
                            )
                          else
                            Text(
                              widget.task.title,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                              style: widget.isCompleted
                                  ? TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.5),
                                    )
                                  : Theme.of(context).textTheme.bodyLarge,
                            ),
                        ],
                      ),
                    ),
                    
                    // 截止日期标签
                    if (widget.task.dueDate != null) ...[
                      const SizedBox(width: 8),
                      _buildDueDateChip(context, widget.task.dueDate!),
                    ],

                    if (widget.task.isLongTerm) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.autorenew_rounded, size: 18),
                        tooltip: '长期任务',
                        onPressed: null,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                        iconSize: 18,
                      ),
                    ],
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  child: isNoteExpanded && !isRenaming
                      ? Padding(
                          padding: const EdgeInsets.only(top: 6, bottom: 2),
                          child: SizedBox(
                            width: double.infinity,
                            child: TextField(
                              controller: _noteController,
                              focusNode: _noteFocusNode,
                              minLines: 2,
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText: '添加备注',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10,
                                ),
                              ),
                              textInputAction: TextInputAction.newline,
                              onSubmitted: (_) => _commitNoteIfNeeded(),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
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

