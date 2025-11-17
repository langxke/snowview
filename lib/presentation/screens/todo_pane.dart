import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';

class TodoPane extends StatefulWidget {
  const TodoPane({super.key});

  @override
  State<TodoPane> createState() => _TodoPaneState();
}

class _TodoPaneState extends State<TodoPane> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<TaskProvider>();
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: tasks.items.length,
            itemBuilder: (context, index) {
              final t = tasks.items[index];
              return CheckboxListTile(
                value: t.completed,
                onChanged: (_) => tasks.toggle(index),
                title: Text(t.title),
                secondary: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => tasks.removeAt(index),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: '输入待办内容，回车添加…',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (v) {
                    if (v.trim().isEmpty) return;
                    tasks.addTodo(v.trim());
                    _controller.clear();
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final v = _controller.text.trim();
                  if (v.isEmpty) return;
                  tasks.addTodo(v);
                  _controller.clear();
                },
                child: const Text('添加'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


