import 'package:flutter/material.dart';
import 'models.dart';

class EventSidebar extends StatelessWidget {
  final DateTime selectedDate;
  final CalendarEvent? selectedEvent;
  final VoidCallback? onAddEvent;
  final Function(CalendarEvent)? onEditEvent;
  final Function(CalendarEvent)? onDeleteEvent;
  final VoidCallback? onClearSelection;

  const EventSidebar({
    super.key,
    required this.selectedDate,
    this.selectedEvent,
    this.onAddEvent,
    this.onEditEvent,
    this.onDeleteEvent,
    this.onClearSelection,
  });


  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: selectedEvent != null 
        ? _buildEventEditPanel(context)
        : _buildEmptyPanel(context),
    );
  }

  Widget _buildEmptyPanel(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.event_note_outlined,
          size: 64,
          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
        ),
        const SizedBox(height: 16),
        Text(
          '活动编辑面板',
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '在右侧日历中选择活动\n即可在此处查看和编辑详情',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: onAddEvent,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('新建活动'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildEventEditPanel(BuildContext context) {
    if (selectedEvent == null) return const SizedBox();
    
    final theme = Theme.of(context);
    final event = selectedEvent!;
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部：标题
          Row(
            children: [
              Icon(Icons.edit_note, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                '编辑活动',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // 活动标题编辑区域
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: event.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: event.color.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题和颜色编辑
                Row(
                  children: [
                    // 颜色选择器
                    GestureDetector(
                      onTap: () => _showColorPicker(context, event),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: event.color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.outline.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.palette,
                          size: 14,
                          color: event.color.computeLuminance() > 0.5 
                              ? Colors.black54 
                              : Colors.white70,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 可编辑标题
                    Expanded(
                      child: _EditableTitle(
                        initialTitle: event.title,
                        event: event,
                        onUpdateEvent: onEditEvent,
                        textStyle: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: event.color.computeLuminance() > 0.5 
                              ? Colors.black87 
                              : event.color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 时间显示（暂时保持只读）
                Text(
                  _formatEventTime(event),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // 活动详情
          _buildDetailSection(context, '基本信息', [
            _buildDetailRow(context, Icons.access_time, '开始时间', _formatDateTime(event.start)),
            _buildDetailRow(context, Icons.schedule, '结束时间', _formatDateTime(event.end)),
            _buildDetailRow(context, Icons.timer_outlined, '持续时间', _formatDuration(event)),
          ]),
          
          const SizedBox(height: 20),
          _buildDetailSection(context, '活动描述', [
            _EditableDescription(
              initialDescription: event.description,
              event: event,
              onUpdateEvent: onEditEvent,
            ),
          ]),
          
          const SizedBox(height: 24),
          
          // 操作按钮
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => onDeleteEvent?.call(event),
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('删除活动'),
                  style: FilledButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(BuildContext context, String title, List<Widget> children) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}月${dateTime.day}日 ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  String _formatEventTime(CalendarEvent event) {
    final startTime = '${event.start.hour.toString().padLeft(2, '0')}:${event.start.minute.toString().padLeft(2, '0')}';
    final endTime = '${event.end.hour.toString().padLeft(2, '0')}:${event.end.minute.toString().padLeft(2, '0')}';
    return '$startTime - $endTime';
  }

  String _formatDuration(CalendarEvent event) {
    final duration = event.end.difference(event.start);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return minutes > 0 ? '${hours}小时${minutes}分钟' : '${hours}小时';
    } else {
      return '${minutes}分钟';
    }
  }


  void _showColorPicker(BuildContext context, CalendarEvent event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择颜色'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Colors.red,
            Colors.orange,
            Colors.yellow,
            Colors.green,
            Colors.blue,
            Colors.purple,
            Colors.pink,
            Colors.teal,
            Colors.indigo,
            Colors.brown,
            Colors.grey,
            Colors.blueGrey,
          ].map((color) => GestureDetector(
            onTap: () {
              final updatedEvent = CalendarEvent(
                title: event.title,
                allDay: event.allDay,
                description: event.description,
                color: color,
                start: event.start,
                end: event.end,
              );
              onEditEvent?.call(updatedEvent);
              Navigator.of(context).pop();
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: event.color == color
                  ? Border.all(color: Colors.black, width: 3)
                  : Border.all(color: Colors.grey.shade300),
              ),
            ),
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }
}

// 可编辑标题组件
class _EditableTitle extends StatefulWidget {
  final String initialTitle;
  final CalendarEvent event;
  final Function(CalendarEvent)? onUpdateEvent;
  final TextStyle? textStyle;

  const _EditableTitle({
    required this.initialTitle,
    required this.event,
    this.onUpdateEvent,
    this.textStyle,
  });

  @override
  State<_EditableTitle> createState() => _EditableTitleState();
}

class _EditableTitleState extends State<_EditableTitle> {
  late TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.event.title);
  }

  @override
  void didUpdateWidget(_EditableTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当组件更新时，同步最新的标题内容到控制器
    if (oldWidget.event.title != widget.event.title) {
      _controller.text = widget.event.title;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _saveTitle() {
    if (_controller.text.trim().isEmpty) {
      _controller.text = widget.event.title;
      return;
    }

    // 与当前活动的标题比较，而不是初始标题
    if (_controller.text.trim() != widget.event.title) {
      final updatedEvent = CalendarEvent(
        title: _controller.text.trim(),
        allDay: widget.event.allDay,
        description: widget.event.description,
        color: widget.event.color,
        start: widget.event.start,
        end: widget.event.end,
      );
      widget.onUpdateEvent?.call(updatedEvent);
    }

    setState(() {
      _isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentTitle = widget.event.title;
    
    if (_isEditing) {
      return TextField(
        controller: _controller,
        style: widget.textStyle,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          isDense: true,
        ),
        autofocus: true,
        onSubmitted: (_) => _saveTitle(),
        onTapOutside: (_) => _saveTitle(),
      );
    }

    return GestureDetector(
      onTap: () {
        // 进入编辑模式前，确保控制器包含最新内容
        _controller.text = currentTitle;
        setState(() => _isEditing = true);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          currentTitle,
          style: widget.textStyle,
        ),
      ),
    );
  }
}

// 可编辑描述组件
class _EditableDescription extends StatefulWidget {
  final String initialDescription;
  final CalendarEvent event;
  final Function(CalendarEvent)? onUpdateEvent;

  const _EditableDescription({
    required this.initialDescription,
    required this.event,
    this.onUpdateEvent,
  });

  @override
  State<_EditableDescription> createState() => _EditableDescriptionState();
}

class _EditableDescriptionState extends State<_EditableDescription> {
  late TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.event.description);
  }

  @override
  void didUpdateWidget(_EditableDescription oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当组件更新时，同步最新的描述内容到控制器
    if (oldWidget.event.description != widget.event.description) {
      _controller.text = widget.event.description;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _saveDescription() {
    final newDescription = _controller.text.trim();
    
    // 与当前活动的描述比较，而不是初始描述
    if (newDescription != widget.event.description) {
      final updatedEvent = CalendarEvent(
        title: widget.event.title,
        allDay: widget.event.allDay,
        description: newDescription,
        color: widget.event.color,
        start: widget.event.start,
        end: widget.event.end,
      );
      widget.onUpdateEvent?.call(updatedEvent);
    }

    setState(() {
      _isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentDescription = widget.event.description;
    
    if (_isEditing) {
      return Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.primary),
        ),
        child: TextField(
          controller: _controller,
          maxLines: null,
          minLines: 3,
          style: theme.textTheme.bodyMedium,
          decoration: const InputDecoration(
            hintText: '输入活动描述...',
            border: InputBorder.none,
            contentPadding: EdgeInsets.all(12),
          ),
          autofocus: true,
          onTapOutside: (_) => _saveDescription(),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        // 进入编辑模式前，确保控制器包含最新内容
        _controller.text = currentDescription;
        setState(() => _isEditing = true);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          currentDescription.isNotEmpty 
            ? currentDescription 
            : '点击添加描述...',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: currentDescription.isNotEmpty 
              ? null 
              : theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
            fontStyle: currentDescription.isNotEmpty 
              ? null 
              : FontStyle.italic,
          ),
        ),
      ),
    );
  }
}
