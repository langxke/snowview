import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _renamePreparedForCurrentSession = false;

  bool _showMoreSettings = false;
  bool _notePreparedForCurrentSession = false;

  int? _estimatedMinutes;
  int? _priority; // 0=低 1=中 2=高
  String? _repeatRule; // none|daily|weekly|monthly|workdays|weekends

  static const String _taskMetaPrefsPrefix = 'task_meta_v1_';

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

    _loadTaskMeta();
  }

  @override
  void didUpdateWidget(covariant TaskItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.id != widget.task.id) {
      _showMoreSettings = false;
      _notePreparedForCurrentSession = false;
      _estimatedMinutes = null;
      _priority = null;
      _repeatRule = null;
      _loadTaskMeta();
    }
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

  Future<void> _loadTaskMeta() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_taskMetaPrefsPrefix${widget.task.id}');
      if (raw == null || raw.trim().isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;

      final est = decoded['estimatedMinutes'];
      final pri = decoded['priority'];
      final rep = decoded['repeat'];

      if (!mounted) return;
      setState(() {
        _estimatedMinutes = est is int ? est : int.tryParse(est?.toString() ?? '');
        _priority = pri is int ? pri : int.tryParse(pri?.toString() ?? '');
        _repeatRule = rep?.toString();
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _saveTaskMeta() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_taskMetaPrefsPrefix${widget.task.id}',
        jsonEncode({
          'estimatedMinutes': _estimatedMinutes,
          'priority': _priority,
          'repeat': _repeatRule,
        }),
      );
    } catch (_) {
      // ignore
    }
  }

  Future<void> _pickDueDate() async {
    final provider = context.read<TaskListProvider>();
    final initial = widget.task.dueDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    await provider.updateTask(id: widget.task.id, dueDate: picked);
  }

  Future<void> _clearDueDate() async {
    final provider = context.read<TaskListProvider>();
    await provider.updateTask(id: widget.task.id, clearDueDate: true);
  }

  void _setEstimatedMinutes(int? minutes) {
    setState(() {
      _estimatedMinutes = minutes;
    });
    _saveTaskMeta();
  }

  void _setPriority(int? priority) {
    setState(() {
      _priority = priority;
    });
    _saveTaskMeta();
  }

  void _setRepeatRule(String? rule) {
    setState(() {
      _repeatRule = rule;
    });
    _saveTaskMeta();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskListProvider>();
    final isRenaming = provider.renamingTaskId == widget.task.id;
    final isNoteExpanded = provider.expandedNoteTaskId == widget.task.id;
    final accentColor = Theme.of(context).colorScheme.primary;

    if (!isRenaming && _renamePreparedForCurrentSession) {
      _renamePreparedForCurrentSession = false;
    }

    if (isRenaming && !_renamePreparedForCurrentSession) {
      final text = widget.task.title;
      _renameController.text = text;
      _renameController.selection = TextSelection(baseOffset: 0, extentOffset: text.length);
      _renamePreparedForCurrentSession = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && provider.renamingTaskId == widget.task.id) {
          _renameFocusNode.requestFocus();
        }
      });
    }

    if (!isNoteExpanded && _showMoreSettings) {
      _showMoreSettings = false;
      _notePreparedForCurrentSession = false;
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
                                controller: _renameController,
                                focusNode: _renameFocusNode,
                                autofocus: true,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                style: Theme.of(context).textTheme.bodyLarge,
                                textInputAction: TextInputAction.done,
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

                    if (_repeatRule != null && _repeatRule!.trim().isNotEmpty && _repeatRule != 'none') ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.autorenew_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
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
                          child: _showMoreSettings
                              ? _buildMoreSettingsPanel(context)
                              : _buildAiSuggestionSummary(context),
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

  Widget _buildAiSuggestionSummary(BuildContext context) {
    final theme = Theme.of(context);
    final dueStr = widget.task.dueDate != null ? TaskUtils.formatDueDate(widget.task.dueDate!) : '未设置';
    final estStr = _estimatedMinutes != null ? '$_estimatedMinutes 分钟' : '未设置';
    final priStr = _formatPriority(_priority);
    final repeatStr = _formatRepeatRule(_repeatRule);
    final noteRaw = (widget.task.description ?? '').trim();
    final noteStr = noteRaw.isEmpty ? '无' : noteRaw;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              '给AI的建议',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildSummaryRow(context, label: '截止日期', value: dueStr),
        const SizedBox(height: 6),
        _buildSummaryRow(context, label: '预估时长', value: estStr),
        const SizedBox(height: 6),
        _buildSummaryRow(context, label: '优先级', value: priStr),
        const SizedBox(height: 6),
        _buildSummaryRow(context, label: '是否循环', value: repeatStr),
        const SizedBox(height: 6),
        _buildSummaryRow(
          context,
          label: '备注',
          value: noteStr,
          maxLines: 1,
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              setState(() {
                _showMoreSettings = true;
              });
            },
            child: const Text('更多设置'),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(
    BuildContext context, {
    required String label,
    required String value,
    int? maxLines,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall,
            maxLines: maxLines,
            overflow: maxLines != null ? TextOverflow.ellipsis : null,
          ),
        ),
      ],
    );
  }

  Widget _buildMoreSettingsPanel(BuildContext context) {
    final text = widget.task.description ?? '';
    if (!_notePreparedForCurrentSession && _noteController.text != text) {
      _noteController.text = text;
      _noteController.selection = TextSelection.fromPosition(
        TextPosition(offset: _noteController.text.length),
      );
      _notePreparedForCurrentSession = true;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _showMoreSettings = false;
                });
              },
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('返回'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: const Size(0, 36),
                alignment: Alignment.centerLeft,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 截止日期
        Row(
          children: [
            const SizedBox(
              width: 80,
              child: Text('截止日期'),
            ),
            Expanded(
              child: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: _pickDueDate,
                    child: Text(widget.task.dueDate != null
                        ? TaskUtils.formatDueDate(widget.task.dueDate!)
                        : '选择日期'),
                  ),
                  if (widget.task.dueDate != null)
                    TextButton(
                      onPressed: _clearDueDate,
                      child: const Text('清除'),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 预估时长
        Row(
          children: [
            const SizedBox(
              width: 80,
              child: Text('预估时长'),
            ),
            Expanded(
              child: DropdownButtonFormField<int?>(
                initialValue: _estimatedMinutes,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem<int?>(value: null, child: Text('未设置')),
                  DropdownMenuItem<int?>(value: 15, child: Text('15 分钟')),
                  DropdownMenuItem<int?>(value: 30, child: Text('30 分钟')),
                  DropdownMenuItem<int?>(value: 45, child: Text('45 分钟')),
                  DropdownMenuItem<int?>(value: 60, child: Text('60 分钟')),
                  DropdownMenuItem<int?>(value: 90, child: Text('90 分钟')),
                  DropdownMenuItem<int?>(value: 120, child: Text('120 分钟')),
                ],
                onChanged: _setEstimatedMinutes,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 优先级
        Row(
          children: [
            const SizedBox(
              width: 80,
              child: Text('优先级'),
            ),
            Expanded(
              child: DropdownButtonFormField<int?>(
                initialValue: _priority,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem<int?>(value: null, child: Text('未设置')),
                  DropdownMenuItem<int?>(value: 0, child: Text('低')),
                  DropdownMenuItem<int?>(value: 1, child: Text('中')),
                  DropdownMenuItem<int?>(value: 2, child: Text('高')),
                ],
                onChanged: _setPriority,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 是否循环
        Row(
          children: [
            const SizedBox(
              width: 80,
              child: Text('是否循环'),
            ),
            Expanded(
              child: DropdownButtonFormField<String?>(
                initialValue: _repeatRule,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem<String?>(value: null, child: Text('不循环')),
                  DropdownMenuItem<String?>(value: 'daily', child: Text('每天')),
                  DropdownMenuItem<String?>(value: 'weekly', child: Text('每周')),
                  DropdownMenuItem<String?>(value: 'monthly', child: Text('每月')),
                  DropdownMenuItem<String?>(value: 'workdays', child: Text('工作日')),
                  DropdownMenuItem<String?>(value: 'weekends', child: Text('周末')),
                ],
                onChanged: _setRepeatRule,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 备注（给 AI 看）
        TextField(
          controller: _noteController,
          focusNode: _noteFocusNode,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: '备注（主要给 AI 看）',
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
      ],
    );
  }

  String _formatPriority(int? p) {
    switch (p) {
      case 0:
        return '低';
      case 1:
        return '中';
      case 2:
        return '高';
      default:
        return '未设置';
    }
  }

  String _formatRepeatRule(String? rule) {
    switch (rule) {
      case 'daily':
        return '每天';
      case 'weekly':
        return '每周';
      case 'monthly':
        return '每月';
      case 'workdays':
        return '工作日';
      case 'weekends':
        return '周末';
      default:
        return '不循环';
    }
  }
}

