import 'package:flutter/material.dart';

/// 快速添加任务输入框
class TaskQuickAddInput extends StatefulWidget {
  final Function(String title) onSubmit;
  final String? hintText;

  const TaskQuickAddInput({
    super.key,
    required this.onSubmit,
    this.hintText,
  });

  @override
  State<TaskQuickAddInput> createState() => _TaskQuickAddInputState();
}

class _TaskQuickAddInputState extends State<TaskQuickAddInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;

    widget.onSubmit(title);
    _controller.clear();
    
    // 保持焦点，方便连续添加
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: widget.hintText ?? '+ 新建任务...',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                prefixIcon: Icon(
                  Icons.add_circle_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleSubmit(),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 48, // 确保与输入框高度一致
            child: FilledButton.icon(
              onPressed: _handleSubmit,
              icon: const Icon(Icons.send, size: 16),
              label: const Text('添加'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

