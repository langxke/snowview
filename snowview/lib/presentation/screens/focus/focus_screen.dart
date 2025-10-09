import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/focus_provider.dart';
import '../../providers/task_list_provider.dart';
import 'widgets/focus_timer_widget.dart';
import 'widgets/focus_control_buttons.dart';
import 'widgets/focus_stats_card.dart';
import 'widgets/focus_session_list_item.dart';
import 'dialogs/custom_duration_dialog.dart';

/// 专注工具主页面
class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  bool _wasActive = false;
  int _pomodoroDuration = 25;
  int _shortBreakDuration = 5;
  int _longBreakDuration = 15;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// 加载设置
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pomodoroDuration = prefs.getInt('focus_pomodoro_duration') ?? 25;
      _shortBreakDuration = prefs.getInt('focus_short_break_duration') ?? 5;
      _longBreakDuration = prefs.getInt('focus_long_break_duration') ?? 15;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 每次页面可见时重新加载设置
    _loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎯 专注工具'),
        centerTitle: true,
      ),
      body: Consumer<FocusProvider>(
        builder: (context, focusProvider, child) {
          // 检测专注完成（从活动变为不活动）
          if (_wasActive && !focusProvider.isActive) {
            _wasActive = false;
            // 延迟显示完成对话框，避免在 build 中调用
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showCompletionDialog(context);
            });
          } else if (focusProvider.isActive) {
            _wasActive = true;
          }
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // 计时器区域
                FocusTimerWidget(
                  remainingSeconds: focusProvider.remainingSeconds,
                  progress: focusProvider.progress,
                  isActive: focusProvider.isActive,
                  isPaused: focusProvider.isPaused,
                  isBreak: focusProvider.currentSession?.isBreak ?? false,
                ),
                const SizedBox(height: 16),
                
                // 关联任务显示
                if (focusProvider.currentSession?.taskId != null)
                  _buildTaskInfo(context, focusProvider),
                
                const SizedBox(height: 24),
                
                // 控制按钮
                FocusControlButtons(
                  isActive: focusProvider.isActive,
                  isPaused: focusProvider.isPaused,
                  pomodoroDuration: _pomodoroDuration,
                  shortBreakDuration: _shortBreakDuration,
                  onStartPomodoro: () => _startPomodoro(context, focusProvider),
                  onStartCustom: () => _startCustom(context, focusProvider),
                  onStartBreak: () => _startBreak(context, focusProvider),
                  onPause: () => _pause(context, focusProvider),
                  onResume: () => _resume(context, focusProvider),
                  onCancel: () => _cancel(context, focusProvider),
                ),
                
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 24),
                
                // 今日统计
                FocusStatsCard(stats: focusProvider.todayStats),
                
                const SizedBox(height: 24),
                
                // 最近专注
                _buildRecentSessions(context, focusProvider),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 构建任务信息显示
  Widget _buildTaskInfo(BuildContext context, FocusProvider focusProvider) {
    final taskProvider = context.watch<TaskListProvider>();
    final task = taskProvider.tasks.cast<dynamic>().firstWhere(
      (t) => t.id == focusProvider.currentSession?.taskId,
      orElse: () => null,
    );
    
    if (task == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.task_alt,
            size: 16,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 8),
          Text(
            '关联任务：${task.title}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建最近专注列表
  Widget _buildRecentSessions(BuildContext context, FocusProvider focusProvider) {
    final theme = Theme.of(context);
    final sessions = focusProvider.recentSessions;
    
    if (sessions.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.history,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              '最近专注',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // 会话列表
        ...sessions.take(5).map((session) {
          // 获取关联的任务
          final taskProvider = context.watch<TaskListProvider>();
          final task = session.taskId != null
              ? taskProvider.tasks.cast<dynamic>().firstWhere(
                  (t) => t.id == session.taskId,
                  orElse: () => null,
                )
              : null;
          
          return FocusSessionListItem(
            session: session,
            task: task,
          );
        }),
      ],
    );
  }

  // === 操作方法 ===

  /// 开始番茄钟
  Future<void> _startPomodoro(BuildContext context, FocusProvider provider) async {
    // 如果已有活动会话（不应该出现，但做防御性检查）
    if (provider.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已有专注会话进行中')),
      );
      return;
    }
    
    try {
      await provider.startPomodoro();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已开始25分钟番茄钟')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('启动失败：${e.toString()}')),
        );
      }
    }
  }

  /// 开始自定义时长
  Future<void> _startCustom(BuildContext context, FocusProvider provider) async {
    // 检查是否已有活动会话
    if (provider.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已有专注会话进行中')),
      );
      return;
    }
    
    final minutes = await CustomDurationDialog.show(context);
    if (minutes == null) return;
    
    try {
      await provider.startCustomSession(minutes);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已开始${minutes}分钟专注')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('启动失败：${e.toString()}')),
        );
      }
    }
  }

  /// 开始短休息
  Future<void> _startBreak(BuildContext context, FocusProvider provider) async {
    // 检查是否已有活动会话
    if (provider.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已有专注会话进行中')),
      );
      return;
    }
    
    try {
      await provider.startBreak(); // 使用设置中的短休息时长
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已开始短休息 $_shortBreakDuration分钟')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('启动失败：${e.toString()}')),
        );
      }
    }
  }

  /// 开始长休息
  Future<void> _startLongBreak(BuildContext context, FocusProvider provider) async {
    // 检查是否已有活动会话
    if (provider.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已有专注会话进行中')),
      );
      return;
    }
    
    try {
      await provider.startLongBreak(); // 使用设置中的长休息时长
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已开始长休息 $_longBreakDuration分钟')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('启动失败：${e.toString()}')),
        );
      }
    }
  }

  /// 暂停
  Future<void> _pause(BuildContext context, FocusProvider provider) async {
    await provider.pauseCurrentSession();
  }

  /// 恢复
  Future<void> _resume(BuildContext context, FocusProvider provider) async {
    await provider.resumeCurrentSession();
  }

  /// 取消
  Future<void> _cancel(BuildContext context, FocusProvider provider) async {
    // 二次确认
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消专注'),
        content: const Text('确定要取消当前的专注会话吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('继续专注'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认取消'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await provider.cancelCurrentSession();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已取消专注会话')),
        );
      }
    }
  }

  /// 显示专注完成对话框
  void _showCompletionDialog(BuildContext context) {
    final focusProvider = context.read<FocusProvider>();
    final taskProvider = context.read<TaskListProvider>();
    final recentSessions = focusProvider.recentSessions;
    
    // 获取最后完成的会话
    if (recentSessions.isEmpty) return;
    
    final lastSession = recentSessions.first;
    if (!lastSession.isCompleted) return;
    
    final isBreak = lastSession.isBreak;
    final consecutiveCount = focusProvider.consecutivePomodoroCount;
    final shouldSuggestLongBreak = consecutiveCount >= 4;  // 建议长休息的阈值
    
    final task = lastSession.taskId != null
        ? taskProvider.tasks.cast<dynamic>().firstWhere(
            (t) => t.id == lastSession.taskId,
            orElse: () => null,
          )
        : null;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(
          isBreak ? Icons.check_circle : Icons.celebration,
          size: 64,
          color: isBreak ? Colors.green : Theme.of(context).colorScheme.primary,
        ),
        title: Text(isBreak ? '✅ 休息完成！' : '🎉 专注完成！'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 主提示文案
            Text(
              _getCompletionMessage(isBreak, task, shouldSuggestLongBreak),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            
            // 连续番茄钟计数（仅专注完成时显示）
            if (!isBreak && consecutiveCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: shouldSuggestLongBreak 
                      ? Colors.orange.withOpacity(0.1)
                      : Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '🍅 连续完成 $consecutiveCount 个番茄钟',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: shouldSuggestLongBreak ? Colors.orange[700] : null,
                  ),
                ),
              ),
            
            const SizedBox(height: 16),
            
            // 时长卡片
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isBreak 
                    ? Colors.green.withOpacity(0.1)
                    : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isBreak 
                      ? Colors.green.withOpacity(0.3)
                      : Theme.of(context).colorScheme.primary.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.timer,
                    color: isBreak ? Colors.green : Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${lastSession.actualDuration ~/ 60} 分钟',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isBreak ? Colors.green : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (!isBreak) ...[
            // 专注完成后：提供短休息和长休息选项
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('稍后'),
            ),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _startBreak(context, focusProvider);
              },
              icon: const Icon(Icons.coffee_outlined, size: 18),
              label: Text('短休息 $_shortBreakDuration分', style: const TextStyle(fontSize: 14)),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _startLongBreak(context, focusProvider);
              },
              icon: const Icon(Icons.hotel, size: 18),
              label: Text('长休息 $_longBreakDuration分', style: const TextStyle(fontSize: 14)),
              style: shouldSuggestLongBreak 
                  ? FilledButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    )
                  : null,
            ),
          ] else ...[
            // 休息完成后：只需确认
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('继续工作'),
            ),
          ],
        ],
      ),
    );
  }

  /// 获取完成提示文案
  String _getCompletionMessage(bool isBreak, dynamic task, bool shouldSuggestLongBreak) {
    if (isBreak) {
      return '休息时间已结束，精力充沛！\n准备好继续专注工作了吗？';
    }
    
    String baseMessage = task != null
        ? '任务「${task.title}」的专注会话已完成\n做得好！'
        : '恭喜！您已完成一次专注会话\n做得好！';
    
    if (shouldSuggestLongBreak) {
      return '$baseMessage\n\n💡 建议：您已连续工作较久，\n可以考虑长休息深度放松';
    } else {
      return '$baseMessage\n要不要休息一下？';
    }
  }
}


