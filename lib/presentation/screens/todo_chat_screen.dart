import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';

class TodoChatScreen extends StatefulWidget {
  const TodoChatScreen({super.key});

  @override
  State<TodoChatScreen> createState() => _TodoChatScreenState();
}

class _TodoChatScreenState extends State<TodoChatScreen> {
  // 左侧区域占比，默认 2/3
  double _leftRatio = 2 / 3;

  static const double _minRatio = 0.3;
  static const double _maxRatio = 0.8;
  static const double _handleWidth = 8.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final total = constraints.maxWidth;
        final leftWidth = (total - _handleWidth) * _leftRatio;
        final rightWidth = total - _handleWidth - leftWidth;
        return Row(
          children: [
            SizedBox(
              width: leftWidth,
              child: const _TodoArea(),
            ),
            _ResizeHandle(
              width: _handleWidth,
              onDragDelta: (dx) {
                setState(() {
                  _leftRatio = (_leftRatio + dx / total).clamp(_minRatio, _maxRatio);
                });
              },
            ),
            SizedBox(
              width: rightWidth,
              child: const _AIChatPanel(),
            ),
          ],
        );
      },
    );
  }
}

class _ResizeHandle extends StatelessWidget {
  final double width;
  final ValueChanged<double> onDragDelta;
  const _ResizeHandle({required this.width, required this.onDragDelta});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) => onDragDelta(d.delta.dx),
        child: SizedBox(
          width: width,
          child: const Center(
            child: VerticalDivider(
              width: 1,
              thickness: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _TodoArea extends StatelessWidget {
  const _TodoArea();

  @override
  Widget build(BuildContext context) {
    return const _TodoPane();
  }
}

class _TodoPane extends StatefulWidget {
  const _TodoPane();
  @override
  State<_TodoPane> createState() => _TodoPaneState();
}

class _TodoPaneState extends State<_TodoPane> {
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

class _AIChatPanel extends StatefulWidget {
  const _AIChatPanel();
  @override
  State<_AIChatPanel> createState() => _AIChatPanelState();
}

class _AIChatPanelState extends State<_AIChatPanel> {
  final List<_Msg> _messages = <_Msg>[];
  final TextEditingController _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('AI 对话', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final m = _messages[index];
              return Align(
                alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: m.isUser ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(m.text),
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
                  controller: _input,
                  decoration: const InputDecoration(
                    hintText: '对AI说点什么…',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _send, child: const Text('发送')),
            ],
          ),
        ),
      ],
    );
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_Msg(text: text, isUser: true));
      _messages.add(_Msg(text: '（示例回复）已收到：$text', isUser: false));
      _input.clear();
    });
  }
}

class _Msg {
  final String text;
  final bool isUser;
  _Msg({required this.text, required this.isUser});
}


