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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: widget.hintText ?? '添加任务',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
                  child: Text(
                    '+',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleSubmit(),
            ),
          ),
        ],
      ),
    );
  }
}

