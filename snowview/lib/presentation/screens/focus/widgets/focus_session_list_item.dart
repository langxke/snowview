import 'package:flutter/material.dart';
import '../../../../data/models/focus_session_hive.dart';
import '../../../../data/models/checklist_task_hive.dart';

/// 专注会话列表项
class FocusSessionListItem extends StatelessWidget {
  final FocusSessionHive session;
  final ChecklistTaskHive? task;

  const FocusSessionListItem({
    super.key,
    required this.session,
    this.task,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // 状态图标
          _buildStatusIcon(context),
          const SizedBox(width: 12),
          
          // 会话信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 任务名称或会话类型
                Text(
                  task?.title ?? _getSessionTypeLabel(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                
                // 时间信息
                Text(
                  _getTimeInfo(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          
          // 时长显示
          Text(
            _getDurationText(),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建状态图标
  Widget _buildStatusIcon(BuildContext context) {
    IconData iconData;
    Color iconColor;
    
    if (session.isCompleted) {
      iconData = Icons.check_circle;
      iconColor = Colors.green;
    } else if (session.isCancelled) {
      iconData = Icons.cancel;
      iconColor = Colors.grey;
    } else {
      iconData = Icons.radio_button_unchecked;
      iconColor = Theme.of(context).colorScheme.primary;
    }
    
    return Icon(iconData, size: 20, color: iconColor);
  }

  /// 获取会话类型标签
  String _getSessionTypeLabel() {
    if (session.isBreak) {
      return '休息时间';
    }
    switch (session.sessionType) {
      case 'pomodoro':
        return '番茄钟';
      case 'custom':
        return '自定义专注';
      default:
        return '专注会话';
    }
  }

  /// 获取时间信息
  String _getTimeInfo() {
    final time = session.startTime;
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// 获取时长文本
  String _getDurationText() {
    final duration = session.isCompleted 
        ? session.actualDuration 
        : session.plannedDuration;
    
    final minutes = duration ~/ 60;
    return '${minutes}分钟';
  }
}

