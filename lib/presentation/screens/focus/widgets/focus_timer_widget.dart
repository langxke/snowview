import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 专注计时器组件
/// 显示圆形进度条和倒计时
class FocusTimerWidget extends StatelessWidget {
  final int remainingSeconds;
  final double progress;
  final bool isActive;
  final bool isPaused;
  final bool isBreak;  // 是否为休息会话

  const FocusTimerWidget({
    super.key,
    required this.remainingSeconds,
    required this.progress,
    required this.isActive,
    required this.isPaused,
    this.isBreak = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      width: 280,
      height: 280,
      padding: const EdgeInsets.all(20),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 圆形进度指示器
          SizedBox(
            width: 240,
            height: 240,
            child: CustomPaint(
              painter: _CircularProgressPainter(
                progress: progress,
                color: _getProgressColor(context),
                isPaused: isPaused,
              ),
            ),
          ),
          
          // 倒计时显示
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatTime(remainingSeconds),
                style: theme.textTheme.displayLarge?.copyWith(
                  fontSize: 56,
                  fontWeight: FontWeight.w300,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(height: 8),
              if (isActive)
                Text(
                  _getStatusText(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 获取状态文本
  String _getStatusText() {
    if (isPaused) {
      return '暂停中';
    }
    return isBreak ? '休息中' : '专注中';
  }

  /// 格式化时间显示（MM:SS）
  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// 获取进度条颜色
  Color _getProgressColor(BuildContext context) {
    if (isPaused) {
      return Theme.of(context).colorScheme.onSurfaceVariant;
    }
    // 休息时使用不同的颜色
    if (isBreak) {
      return Colors.green;
    }
    return Theme.of(context).colorScheme.primary;
  }
}

/// 圆形进度绘制器
class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isPaused;

  _CircularProgressPainter({
    required this.progress,
    required this.color,
    required this.isPaused,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    // 背景圆环
    final backgroundPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - 4, backgroundPaint);

    // 进度圆环
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 4),
      -math.pi / 2,  // 从顶部开始
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || 
           oldDelegate.color != color || 
           oldDelegate.isPaused != isPaused;
  }
}

