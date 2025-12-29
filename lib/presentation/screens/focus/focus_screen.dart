import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/focus_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/task_list_provider.dart';
import '../schedule/models.dart';

/// 专注工具主页面
class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  Timer? _clockTimer;
  DateTime _now = DateTime.now();
  bool _noteExpanded = false;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer2<FocusProvider, ScheduleProvider>(
        builder: (context, focusProvider, scheduleProvider, child) {
          final planned = _findCurrentPlannedEvent(scheduleProvider, _now);

          // 优先：如果正在专注会话，则展示会话内容
          final hasSessionTask = focusProvider.currentSession?.taskId != null;
          final showSessionTask = focusProvider.isActive && hasSessionTask;

          // 否则：如果当前时间命中日程块，则展示该日程块
          final showPlannedTask = !showSessionTask && planned != null;
          final isFreeTime = !showSessionTask && !showPlannedTask;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  _buildTopTimeStatus(context),
                  Expanded(
                    child: Center(
                      child: isFreeTime
                          ? _buildFreeTimeCore(context)
                          : (showSessionTask
                              ? _buildSessionTaskCore(context, focusProvider)
                              : _buildPlannedTaskCore(context, planned!)),
                    ),
                  ),
                  _buildControls(context, focusProvider, isFreeTime: isFreeTime),
                  const SizedBox(height: 16),
                  _buildFooterHints(context, focusProvider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  CalendarEvent? _findCurrentPlannedEvent(ScheduleProvider scheduleProvider, DateTime now) {
    final events = scheduleProvider.getEventsForDate(now);
    // 过滤全天事件，只考虑时间块
    final blocks = events.where((e) => !e.allDay).toList();
    // 找到覆盖当前时间的事件（start <= now < end）
    for (final e in blocks) {
      if (!now.isBefore(e.start) && now.isBefore(e.end)) {
        return e;
      }
    }
    return null;
  }

  Widget _buildTopTimeStatus(BuildContext context) {
    final theme = Theme.of(context);
    final dateText =
        '${_now.year.toString().padLeft(4, '0')} / ${_now.month.toString().padLeft(2, '0')} / ${_now.day.toString().padLeft(2, '0')}';
    final timeText = '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';
    return Align(
      alignment: Alignment.centerLeft,
      child: DefaultTextStyle(
        style: theme.textTheme.bodySmall!.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateText),
            const SizedBox(height: 2),
            Text(timeText),
          ],
        ),
      ),
    );
  }

  Widget _buildFreeTimeCore(BuildContext context) {
    final theme = Theme.of(context);
    final start = DateTime(_now.year, _now.month, _now.day, _now.hour);
    final end = start.add(const Duration(hours: 1));
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('【自由时间】', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        Text(_formatRange(start, end), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 24),
        Text('你当前没有被安排的任务', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildPlannedTaskCore(BuildContext context, CalendarEvent event) {
    final theme = Theme.of(context);
    final taskProvider = context.watch<TaskListProvider>();

    final taskId = _tryExtractTaskIdFromDescription(event.description);
    final task = taskId == null
        ? null
        : taskProvider.tasks.cast<dynamic>().firstWhere(
            (t) => t.id == taskId,
            orElse: () => null,
          );

    final title = task?.title ?? event.title;
    final note = (task?.description ?? '').toString();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _formatRange(event.start, event.end),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 48,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 18),
        if (note.trim().isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _noteExpanded = !_noteExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text(
                  note,
                  maxLines: _noteExpanded ? null : 2,
                  overflow: _noteExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String? _tryExtractTaskIdFromDescription(String description) {
    final text = description.trim();
    const prefix = 'AI安排:';
    if (!text.startsWith(prefix)) return null;
    final rest = text.substring(prefix.length).trim();
    return rest.isEmpty ? null : rest;
  }

  Widget _buildSessionTaskCore(BuildContext context, FocusProvider focusProvider) {
    final theme = Theme.of(context);
    final taskProvider = context.watch<TaskListProvider>();
    final session = focusProvider.currentSession;
    if (session == null) {
      return const SizedBox.shrink();
    }

    final task = taskProvider.tasks.cast<dynamic>().firstWhere(
      (t) => t.id == session.taskId,
      orElse: () => null,
    );

    final start = session.startTime;
    final end = session.startTime.add(Duration(seconds: session.plannedDuration));
    final title = task?.title ?? '当前任务';
    final note = (task?.description ?? '').toString();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _formatRange(start, end),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 48,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 18),
        if (note.trim().isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _noteExpanded = !_noteExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text(
                  note,
                  maxLines: _noteExpanded ? null : 2,
                  overflow: _noteExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildControls(BuildContext context, FocusProvider focusProvider, {required bool isFreeTime}) {
    if (isFreeTime) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FilledButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('AI 安排稍后接入')),
              );
            },
            child: const Text('让 AI 帮我安排'),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('保持空闲')),
              );
            },
            child: const Text('保持空闲'),
          ),
        ],
      );
    }

    final isActive = focusProvider.isActive;
    final isPaused = focusProvider.isPaused;

    final canStart = !isActive;
    final canPause = isActive && !isPaused;
    final canComplete = isActive;
    final canInterrupt = isActive;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FilledButton(
          onPressed: canStart ? () => _handleStart(context, focusProvider) : null,
          child: const Text('开始'),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: canPause ? () => _handlePause(context, focusProvider) : null,
          child: const Text('暂停'),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: canComplete ? () => _handleEarlyComplete(context, focusProvider) : null,
          child: const Text('提前完成'),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: canInterrupt ? () => _handleInterrupted(context, focusProvider) : null,
          child: const Text('被打断'),
        ),
      ],
    );
  }

  Widget _buildFooterHints(BuildContext context, FocusProvider focusProvider) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: DefaultTextStyle(
        style: theme.textTheme.bodySmall!.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('已专注时长：${focusProvider.formattedElapsedTime}'),
            const SizedBox(height: 4),
            const Text('AI 建议：稍后接入（只读占位）'),
          ],
        ),
      ),
    );
  }

  Future<void> _handleStart(BuildContext context, FocusProvider provider) async {
    if (provider.isActive) return;
    try {
      await provider.startCustomSession(60);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('启动失败：${e.toString()}')),
      );
    }
  }

  Future<void> _handlePause(BuildContext context, FocusProvider provider) async {
    final choice = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('你想如何处理暂停？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(0),
            child: const Text('稍后继续'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(1),
            child: const Text('今天不再继续'),
          ),
        ],
      ),
    );

    if (choice == null) return;
    if (choice == 0) {
      await provider.pauseCurrentSession();
      return;
    }
    await provider.cancelCurrentSession();
  }

  Future<void> _handleEarlyComplete(BuildContext context, FocusProvider provider) async {
    final choice = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('该任务是否已完成？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(0),
            child: const Text('否，稍后还需继续'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(1),
            child: const Text('是，任务完成'),
          ),
        ],
      ),
    );

    if (choice == null) return;

    if (choice == 1) {
      final session = provider.currentSession;
      await provider.completeCurrentSession();
      if (!context.mounted) return;
      if (session?.taskId != null) {
        await context.read<TaskListProvider>().toggleTaskCompletion(session!.taskId!);
      }
      return;
    }

    await provider.cancelCurrentSession();
  }

  Future<void> _handleInterrupted(BuildContext context, FocusProvider provider) async {
    final choice = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('发生了什么？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(0),
            child: const Text('临时打断（稍后可补）'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(1),
            child: const Text('今日不可继续'),
          ),
        ],
      ),
    );

    if (choice == null) return;
    await provider.cancelCurrentSession();
  }

  String _formatRange(DateTime start, DateTime end) {
    final s = '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    final e = '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
    return '$s — $e';
  }
}


