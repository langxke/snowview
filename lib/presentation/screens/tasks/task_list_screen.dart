import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/task_list_provider.dart';
import 'widgets/task_list_panel.dart';

/// 清单主屏幕（两栏/三栏布局）
class TaskListScreen extends StatelessWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskListProvider>(
      builder: (context, provider, child) {
        return Row(
          children: [
            // 中间任务列表（自适应）
            const Expanded(
              child: TaskListPanel(),
            ),
          ],
        );
      },
    );
  }
}

