import 'package:flutter/material.dart';
import '../../models.dart';

/// 可编辑的事件标题文本框组件
/// 
/// 用于在右键菜单中快速编辑事件名称
class EventEditableTextField extends StatefulWidget {
  /// 初始文本内容
  final String initialText;
  
  /// 关联的日历事件
  final CalendarEvent event;
  
  /// 事件更新回调
  final Function(CalendarEvent, CalendarEvent)? onUpdateEvent;

  const EventEditableTextField({
    super.key,
    required this.initialText,
    required this.event,
    this.onUpdateEvent,
  });

  @override
  State<EventEditableTextField> createState() => _EventEditableTextFieldState();
}

class _EventEditableTextFieldState extends State<EventEditableTextField> {
  late TextEditingController _controller;
  late CalendarEvent _currentEvent;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _currentEvent = widget.event;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 更新事件标题
  void _updateEvent(String newTitle) {
    if (newTitle.trim().isNotEmpty && newTitle.trim() != _currentEvent.title) {
      // ✅ 使用 copyWith 保持所有字段
      final updatedEvent = _currentEvent.copyWith(title: newTitle.trim());
      
      if (widget.onUpdateEvent != null) {
        widget.onUpdateEvent!(_currentEvent, updatedEvent);
        // 更新当前事件引用
        _currentEvent = updatedEvent;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        hintText: '修改活动名称',
      ),
      onChanged: _updateEvent,
      onSubmitted: (newTitle) {
        Navigator.of(context).pop();
      },
    );
  }
}

