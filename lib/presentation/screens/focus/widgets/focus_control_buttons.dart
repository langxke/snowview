import 'package:flutter/material.dart';

/// 专注控制按钮组件
class FocusControlButtons extends StatelessWidget {
  final VoidCallback? onStartPomodoro;
  final VoidCallback? onStartCustom;
  final VoidCallback? onStartBreak;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onCancel;
  final bool isActive;
  final bool isPaused;
  final int pomodoroDuration;      // 番茄钟时长（分钟）
  final int shortBreakDuration;    // 短休息时长（分钟）

  const FocusControlButtons({
    super.key,
    this.onStartPomodoro,
    this.onStartCustom,
    this.onStartBreak,
    this.onPause,
    this.onResume,
    this.onCancel,
    required this.isActive,
    required this.isPaused,
    this.pomodoroDuration = 25,
    this.shortBreakDuration = 5,
  });

  @override
  Widget build(BuildContext context) {
    if (!isActive) {
      // 未开始状态：显示开始按钮
      return _buildStartButtons(context);
    } else if (isPaused) {
      // 暂停状态：显示继续和取消按钮
      return _buildPausedButtons(context);
    } else {
      // 进行中状态：显示暂停和取消按钮
      return _buildActiveButtons(context);
    }
  }

  /// 开始按钮（未开始状态）
  Widget _buildStartButtons(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 番茄钟按钮
        SizedBox(
          width: 240,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: onStartPomodoro,
            icon: const Icon(Icons.access_time, size: 20),
            label: Text('开始番茄钟 ($pomodoroDuration分钟)', style: const TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        
        // 自定义时长和休息按钮
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 114,
              height: 40,
              child: OutlinedButton.icon(
                onPressed: onStartCustom,
                icon: const Icon(Icons.timer_outlined, size: 18),
                label: const Text('自定义', style: TextStyle(fontSize: 14)),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 145,
              height: 40,
              child: OutlinedButton.icon(
                onPressed: onStartBreak,
                icon: const Icon(Icons.coffee_outlined, size: 18),
                label: Text('休息 $shortBreakDuration分钟', style: const TextStyle(fontSize: 14)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 进行中按钮
  Widget _buildActiveButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 暂停按钮
        SizedBox(
          width: 114,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: onPause,
            icon: const Icon(Icons.pause, size: 20),
            label: const Text('暂停', style: TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(width: 12),
        
        // 取消按钮
        SizedBox(
          width: 114,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.close, size: 20),
            label: const Text('取消', style: TextStyle(fontSize: 16)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
      ],
    );
  }

  /// 暂停状态按钮
  Widget _buildPausedButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 继续按钮
        SizedBox(
          width: 114,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: onResume,
            icon: const Icon(Icons.play_arrow, size: 20),
            label: const Text('继续', style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        
        // 取消按钮
        SizedBox(
          width: 114,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.close, size: 20),
            label: const Text('取消', style: TextStyle(fontSize: 16)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
      ],
    );
  }
}

