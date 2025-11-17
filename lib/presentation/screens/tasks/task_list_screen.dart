import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/task_list_provider.dart';
import 'widgets/category_sidebar.dart';
import 'widgets/task_list_panel.dart';
import 'widgets/task_detail_panel.dart';

/// 清单主屏幕（两栏/三栏布局）
class TaskListScreen extends StatelessWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskListProvider>(
      builder: (context, provider, child) {
        return Row(
          children: [
            // 左侧类别栏（固定宽度200px）
            const SizedBox(
              width: 200,
              child: CategorySidebar(),
            ),
            
            // 中间任务列表（自适应）
            const Expanded(
              child: TaskListPanel(),
            ),
            
            // 右侧详情面板（条件显示，固定宽度350px）
            if (provider.isDetailPanelVisible)
              const SizedBox(
                width: 350,
                child: TaskDetailPanel(),
              ),
          ],
        );
      },
    );
  }
}

