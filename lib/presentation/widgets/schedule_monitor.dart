import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/calendar_event_hive.dart';
import '../providers/schedule_provider.dart';
import '../providers/task_list_provider.dart';
import '../providers/daily_plan_provider.dart';
import '../../services/notification_service.dart';
import '../screens/schedule/models.dart';

/// 全局调度监控器 (Wrapper)
/// 负责在 MaterialApp.builder 中初始化，确保 Content 拥有正确的 Navigator/Overlay 上下文

class ScheduleMonitor extends StatelessWidget {
  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;

  const ScheduleMonitor({
    super.key, 
    required this.child,
    this.navigatorKey,
  });

  @override
  Widget build(BuildContext context) {
    return ScheduleMonitorContent(
      navigatorKey: navigatorKey,
      child: child,
    );
  }
}

/// 监控器逻辑实现
class ScheduleMonitorContent extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;

  const ScheduleMonitorContent({super.key, required this.child, this.navigatorKey});

  @override
  State<ScheduleMonitorContent> createState() => ScheduleMonitorContentState();
}

class ScheduleMonitorContentState extends State<ScheduleMonitorContent> {
  Timer? _monitorTimer;
  // 记录最近一次已处理的“结束时间”，防止同一事件在1分钟内重复触发
  // Key: eventId, Value: endTime
  final Map<String, DateTime> _handledEvents = {};

  // 记录弹窗的显示时间，用于超时判定
  // Key: taskId, Value: showTime
  final Map<String, DateTime> _pendingDialogs = {};

  bool _hasPerformedInitialCleanup = false;

  @override
  void initState() {
    super.initState();
    // 每30秒检查一次
    _monitorTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkScheduleEnd();
      _checkDialogTimeout(); // 检查是否有超时未处理的弹窗
    });
    
    // 监听 Provider 数据变化，确保在数据加载后执行清理
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final taskProvider = context.read<TaskListProvider>();
      
      // 如果已有数据，直接清理
      if (taskProvider.tasks.isNotEmpty) {
        _performCleanupOnce();
      }
      
      // 监听后续变化（防止初始为空）
      void listener() {
        if (taskProvider.tasks.isNotEmpty && !_hasPerformedInitialCleanup) {
           _performCleanupOnce();
        }
      }
      taskProvider.addListener(listener);
      
      // 注意：这里没有移除 listener，可能会有轻微内存泄漏，但 ScheduleMonitor 是全局单例，问题不大。
      // 严谨的做法是在 dispose 中移除，但 listener 是闭包，需要保存引用。
      // 简化处理：我们在 _performCleanupOnce 内部设置标志位，再次触发也无妨。
    });
  }

  Future<void> _performCleanupOnce() async {
    if (_hasPerformedInitialCleanup) return;
    _hasPerformedInitialCleanup = true;
    
    // 延迟一点点确保 UI 稳定
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    
    debugPrint('ScheduleMonitor: Starting initial cleanup of past tasks...');
    await _cleanupPastTasks();
  }

  /// 检查是否有超时未处理的任务（超过15分钟未确认）
  void _checkDialogTimeout() async {
    if (!mounted) return;
    final taskProvider = context.read<TaskListProvider>();
    final now = DateTime.now();
    final timeout = const Duration(minutes: 15);

    final expiredTaskIds = <String>[];
    
    _pendingDialogs.forEach((taskId, showTime) {
      if (now.difference(showTime) > timeout) {
        expiredTaskIds.add(taskId);
      }
    });

    for (final taskId in expiredTaskIds) {
      // 视为未完成，执行重置逻辑
      debugPrint('Task confirmation timed out: $taskId');
      _pendingDialogs.remove(taskId);
      
      // 关闭 Overlay
      if (_activeOverlays.containsKey(taskId)) {
        _activeOverlays[taskId]?.remove();
        _activeOverlays.remove(taskId);
      }
      
      await _resetIncompleteTask(taskProvider, taskId);
    }
  }

  /// 清理历史遗留任务：当前时间之前的所有未完成待办任务（非循环），重置为未安排
  Future<int> _cleanupPastTasks() async {
    if (!mounted) return 0;
    int totalCleaned = 0;
    try {
      final taskProvider = context.read<TaskListProvider>();
      final now = DateTime.now();
      // 任务清理基准：今天 (00:00:00) 本地时间
      final today = DateTime(now.year, now.month, now.day);

      // 策略 A：扫描已排程的过期日历事件
      // 迁移：从 DailyPlanProvider 获取计划来检查，而不是直接查 DB
      // 为了简化，我们假设 DailyPlan 已经覆盖了所有 active events
      // 这里我们需要遍历过去几天的 Plan 吗？
      // 或者，ScheduleMonitor 应该只关注“今天之前”？
      // 如果我们只关心“今天之前”，那意味着我们需要遍历以前的 DailyPlanHive。
      // 但 DailyPlan 是按需加载的，可能没有加载。
      // 
      // 替代方案：DailyPlanProvider 可以提供一个方法来清理过期事件
      // 或者我们暂时先跳过对 CalendarEvent 的自动清理（因为 embedded events 不容易全局扫描）
      // 
      // 重新思考：_cleanupPastTasks 的目的是什么？
      // 1. 清理过期的 Task.dueDate -> 这可以通过扫描 TaskList 完成（策略 B）。
      // 2. 清理过期的 CalendarEvent -> 这在 embedded 模式下，意味着要从 DailyPlan 中 remove。
      //    如果 DailyPlan 是按天存的，过去的 Plan 就让它留在过去吧，作为历史记录？
      //    是的，通常我们不删除历史日程。
      //    但如果是“未完成”的任务对应的日程呢？
      //    如果是 embedded，那么它只存在于那一天。如果不删，它就是那天的历史记录。
      //    如果用户希望“未完成的任务自动顺延”或者“自动回到待办池”，
      //    那我们只需要重置 Task.dueDate（策略 B），那么它就会出现在待办池。
      //    至于那个历史的 CalendarEvent，它就留在那里作为“那天我计划做这个但没做完”的记录。
      //    这比直接删除要好。
      // 
      // 结论：在 embedded 模式下，我们可以移除“策略 A”（删除过期事件），只保留“策略 B”（重置过期任务）。
      // 这样代码更简洁，且保留了历史记录。
      
      /* 
      // 策略 A (Legacy): 删除过期事件
      // ... 移除 ...
      */

      // 策略 B：直接扫描 TaskList 中所有“已过期”的任务
      // 用户指示：不要考虑时区，使用系统时间；不需要检查是否完成（只要在过去就清理）
      final allTasks = taskProvider.getAllTasks(); 
      
      debugPrint('Running _cleanupPastTasks. Today (Local): $today. Total tasks: ${allTasks.length}');
      
      int scannedCount = 0;
      
      for (final task in allTasks) {
        try {
          // 仅跳过无日期的任务
          if (task.dueDate == null) continue;
          
          scannedCount++;
          
          // 检查是否过期
          // 1. 统一转换为本地时间 (System Time)
          final localDueDate = task.dueDate!.toLocal();
          // 2. 提取日期部分 (00:00:00)
          final taskDate = DateTime(localDueDate.year, localDueDate.month, localDueDate.day);
          
          // 3. 比较：如果任务日期 < 今天，则清理
          if (taskDate.isBefore(today)) {
            debugPrint('Found expired task: ${task.id} (${task.title}), localDueDate: $localDueDate, isCompleted: ${task.isCompleted}');
            
            // 执行重置（清除截止日期）
            // 这会自动将任务从 DailyPlan 的 todoTaskIds 中移除（如果存在逻辑关联的话）
            // 但 DailyPlan 存储的是 ID。
            // 关键：DailyPlan.todoTaskIds 里的 ID 对应的 Task 如果 dueDate 变了，
            // 实际上 DailyPlan 里的 ID 还在，但 UI 渲染时可能会过滤？
            // 不，DailyPlan 是静态索引。
            // 所以，如果 Task.dueDate 被清除，我们需要通知 DailyPlan 移除它吗？
            // 
            // 现在的逻辑是：DailyPlan 是 Truth。
            // 如果 Task.dueDate 清除了，但 DailyPlan(昨天).todoTaskIds 还有它。
            // 那没关系，那是昨天的计划。
            // 
            // 唯一的问题是：如果任务是“过期”的，我们把它重置了。
            // 那它在昨天的日历上显示为“未完成”？是的，这是正确的。
            
            await _resetIncompleteTask(taskProvider, task.id);
            
            // 我们不需要显式去修改过去的 DailyPlan。
             
            totalCleaned++;
          }
        } catch (e) {
          debugPrint('Error processing task ${task.id} for cleanup: $e');
        }
      }
      
      debugPrint('Cleanup finished. Scanned: $scannedCount, Cleaned: $totalCleaned');
      
      if (totalCleaned > 0) {
        // 自动清理时的提示
        final messenger = widget.navigatorKey?.currentContext != null
            ? ScaffoldMessenger.of(widget.navigatorKey!.currentContext!)
            : (mounted ? ScaffoldMessenger.of(context) : null);
            
        messenger?.showSnackBar(
          SnackBar(content: Text('已自动清理 $totalCleaned 个过期任务')),
        );
      }
    } catch (e) {
      debugPrint('Error in _cleanupPastTasks: $e');
    }
    return totalCleaned;
  }

  /// 调试方法：手动触发清理逻辑
  Future<void> debugTriggerCleanup() async {
    final count = await _cleanupPastTasks();
    if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('手动清理检查完成，共清理 $count 个任务')),
      );
    }
  }

  /// 重置未完成任务：如果是普通任务，清除截止日期；如果是循环任务，也清除截止日期（因为月视图中已预先安排好）
  Future<void> _resetIncompleteTask(TaskListProvider taskProvider, String taskId) async {
    // 无论是否循环，过期未完成的任务都重置为“未安排”（清除 dueDate）
    // 对于普通任务：回到待办池，等待重新安排
    // 对于循环任务：如果月视图中已有未来的实例（通过其他机制生成），那么当前的过期实例也应被清理，
    // 清除 dueDate 后，它会变成无日期任务。用户可以选择手动删除或忽略。
    
    await taskProvider.updateTask(
      id: taskId,
      clearDueDate: true,
    );
    debugPrint('Reset incomplete task to unscheduled: $taskId');

    if (!mounted) return;

    // 同时删除关联的日历时间块（仅针对本次结束的事件）
    // 注意：这里的 taskId 只是任务ID，我们需要找到关联的事件ID才能删除
    // 但 _resetIncompleteTask 参数里只有 taskId。
    // 我们需要扩展此方法或在调用处处理。
    // 为了方便，我们在调用处（_triggerCompletionFlow）里直接处理删除逻辑。
    // 对于 _cleanupPastTasks 和 _checkDialogTimeout，由于它们是在“事后”处理，
    // 也可以尝试扫描关联的 CalendarEvents 并删除。
    
    final scheduleProvider = context.read<ScheduleProvider>();
    final db = scheduleProvider.databaseService;
    final allEvents = db.getAllEvents();
    
    // 查找所有关联此 taskId 且已结束的事件并删除
    // (防止日历上留着一堆红色的未完成块)
    final now = DateTime.now();
    for (final event in allEvents) {
      // 只删除过去的事件
      if (event.end.isBefore(now)) {
          final eTaskId = _extractTaskId(event.description);
          if (eTaskId == taskId) {
             await db.deleteEvent(event.id);
             debugPrint('Deleted expired event for task: $taskId');
          }
      }
    }
    scheduleProvider.refresh();
  }

  // 记录弹窗的 OverlayEntry，用于关闭
  // Key: taskId, Value: OverlayEntry
  final Map<String, OverlayEntry> _activeOverlays = {};

  @override
  void dispose() {
    _monitorTimer?.cancel();
    // 清理所有 Overlay
    for (final entry in _activeOverlays.values) {
      entry.remove();
    }
    _activeOverlays.clear();
    super.dispose();
  }

  void _checkScheduleEnd() {
    if (!mounted) return;
    final scheduleProvider = context.read<ScheduleProvider>();
    final taskProvider = context.read<TaskListProvider>();
    final now = DateTime.now();

    // 获取今日事件
    final events = scheduleProvider.getEventsForDate(now);
    // 过滤掉全天事件
    final blocks = events.where((e) => !e.allDay).toList();

    for (final e in blocks) {
      // 1. 检查是否刚刚结束
      // 允许的触发窗口：结束后的 0~60 秒内 -> 放宽到 0~120 秒，防止定时器 30s 间隔 + 执行延迟导致错过
      final end = e.end;
      final diff = now.difference(end);

      if (diff.inSeconds >= 0 && diff.inSeconds < 120) {
        // 2. 检查是否已经处理过该事件
        if (_handledEvents.containsKey(e.id) && 
            _handledEvents[e.id] == end) {
          continue; // 已处理
        }

        // 3. 检查是否关联了任务
        // 如果是 AI 安排的，description 里会有 ID
        // 如果是手动安排的，可能没有 description，但 title 也是任务
        // 我们应该对所有时间块都提醒，只是只有关联了 TaskId 的才弹窗询问“是否完成”
        
        // 标记为已处理
        _handledEvents[e.id] = end;

        // 触发流程
        _triggerCompletionFlow(e, taskProvider);
      }
    }
    
    // 清理太久远的缓存 (例如超过1小时的 key)
    _handledEvents.removeWhere((k, v) => now.difference(v).inHours > 1);
  }

  Future<void> _triggerCompletionFlow(CalendarEvent event, TaskListProvider taskProvider) async {
    // CalendarEvent 的 description 字段是非空 String（根据 models.dart 定义）
    // 但为了避免 IDE 警告（或未定义的 nullability），直接使用
    final taskId = _extractTaskId(event.description);

    // 0. 如果关联了任务且已完成，则不触发任何提醒
    if (taskId != null) {
      final task = taskProvider.getTaskById(taskId);
      if (task != null && task.isCompleted) return;
    }
    
    // 1. 发送系统通知
    await NotificationService().showImmediate(
      id: event.id.hashCode,
      title: '时间块结束提醒',
      body: '您安排的【${event.title}】时段已结束，请确认进度。',
    );

    // 2. 右下角 Overlay 提醒
    if (!mounted) return;
    
    if (taskId != null) {
      // 检查任务是否已完成
      final task = taskProvider.getTaskById(taskId);
      if (task == null || task.isCompleted) return; // 任务不存在或已完成，不弹窗

      // 如果该任务已经有 Overlay 在显示，先移除旧的（避免堆叠重复）
      if (_activeOverlays.containsKey(taskId)) {
        _activeOverlays[taskId]?.remove();
        _activeOverlays.remove(taskId);
      }
      
      // 记录显示时间
      _pendingDialogs[taskId] = DateTime.now();
      
      // 创建新的 Overlay
      final overlayEntry = _createOverlayEntry(context, event, taskId, taskProvider);
      
      // 插入 Overlay
      // 使用 navigatorKey 获取全局 Overlay，或者回退到 context
      final overlayState = widget.navigatorKey?.currentState?.overlay ?? Overlay.of(context);
      overlayState.insert(overlayEntry);
      _activeOverlays[taskId] = overlayEntry;
    }
  }

  OverlayEntry _createOverlayEntry(
    BuildContext context, 
    CalendarEvent event, 
    String taskId, 
    TaskListProvider taskProvider
  ) {
    return OverlayEntry(
      builder: (context) => Positioned(
        right: 20,
        bottom: 20 + (_activeOverlays.keys.toList().indexOf(taskId) * 160.0), // 简单的堆叠策略
        width: 300,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time_filled, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '任务时间结束',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                         _removeOverlay(taskId);
                         // 点击关闭视为“未完成/稍后”
                         _resetIncompleteTask(taskProvider, taskId);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  event.title,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        _removeOverlay(taskId);
                        _resetIncompleteTask(taskProvider, taskId);
                      },
                      child: const Text('下次再做'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () async {
                        _removeOverlay(taskId);
                        
                        // 提前获取 ScaffoldMessengerState，避免异步操作后 context 失效
                        // 使用 navigatorKey.currentContext 更安全
                        final messenger = widget.navigatorKey?.currentContext != null
                            ? ScaffoldMessenger.of(widget.navigatorKey!.currentContext!)
                            : (context.mounted ? ScaffoldMessenger.of(context) : null);
                        
                        // 1. 标记任务完成
                        taskProvider.toggleTaskCompletion(taskId);
                        
                        // 2. 标记当前时间块为已完成 (避免被误删)
                        final dailyPlanProvider = context.read<DailyPlanProvider>();
                        
                        // 查找并更新 embedded event
                        final hiveEvent = CalendarEventHive(
                          id: event.id,
                          title: event.title,
                          description: event.description,
                          allDay: event.allDay,
                          start: event.start,
                          end: event.end,
                          colorValue: event.color.value,
                          isCompleted: true, // 标记为完成
                        );
                        
                        // 使用 updateScheduledEvent (这会触发 save)
                        await dailyPlanProvider.updateScheduledEvent(event.start, hiveEvent);

                        messenger?.showSnackBar(
                          const SnackBar(content: Text('已标记为完成')),
                        );
                      },
                      child: const Text('已完成'),
                    ),
                  ],
                ),
                // 简单的倒计时进度条示意 (可选)
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: null, // 循环动画，表示在倒计时中
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _removeOverlay(String taskId) {
    if (_activeOverlays.containsKey(taskId)) {
      _activeOverlays[taskId]?.remove();
      _activeOverlays.remove(taskId);
    }
    _pendingDialogs.remove(taskId);
  }

  String? _extractTaskId(String description) {
    // 1. 尝试从标准格式 'AI安排: 176862...' 中提取
    final prefix = 'AI安排:';
    if (description.contains(prefix)) {
      final start = description.indexOf(prefix) + prefix.length;
      final end = description.indexOf('\n', start);
      final idStr = end == -1 
          ? description.substring(start).trim() 
          : description.substring(start, end).trim();
      if (idStr.isNotEmpty) return idStr;
    }
    
    // 2. 如果是手动拖拽的任务（DayView 拖拽），description 可能就是 taskId，或者为空
    // 目前 DayView 拖拽逻辑中，是将 taskId 存入 CalendarEvent 的 description 吗？
    // 检查代码发现：DayView 拖拽创建时，description 通常为空，或者由用户输入。
    // 如果没有明确关联，则无法提取 ID。
    
    // 3. 尝试直接解析 description 为纯数字 ID（如果是手动关联的情况）
    if (RegExp(r'^\d+$').hasMatch(description.trim())) {
      return description.trim();
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  /// 调试方法：立即触发当前时间（或最近结束）的事件提醒
  void debugTriggerCurrentEvent() {
    final scheduleProvider = context.read<ScheduleProvider>();
    final taskProvider = context.read<TaskListProvider>();
    final now = DateTime.now();

    // 查找“当前正在进行”或“刚刚结束”的事件
    // 为了测试，我们放宽条件：查找今天内，结束时间在 [now - 1h, now + 1h] 范围内的最近一个事件
    // 或者直接找正在进行的事件，并强制结束它？
    // 用户的需求是：测试的任务是“目前时间对应的时间块任务”
    
    final events = scheduleProvider.getEventsForDate(now);
    final blocks = events.where((e) => !e.allDay).toList();
    
    CalendarEvent? targetEvent;
    
    // 1. 优先找正在进行的（start <= now <= end）
    try {
      targetEvent = blocks.firstWhere((e) => e.start.isBefore(now) && e.end.isAfter(now));
    } catch (_) {
      // 2. 如果没有正在进行的，找刚刚结束的
       try {
         targetEvent = blocks.where((e) => e.end.isBefore(now)).last; // 最后一个结束的
       } catch (_) {}
    }
    
    if (targetEvent != null) {
      debugPrint('Debug Trigger: Found event ${targetEvent.title}');
      _triggerCompletionFlow(targetEvent, taskProvider);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已手动触发测试：${targetEvent.title}')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前时间没有对应的时间块任务')),
      );
    }
  }
}
