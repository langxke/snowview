import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/calendar_database_service.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/task_list_provider.dart';
import '../schedule/day_week_ai_scheduler.dart';
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
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
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
      body: Consumer<ScheduleProvider>(
        builder: (context, scheduleProvider, child) {
          final planned = _findCurrentPlannedEvent(scheduleProvider, _now);
          final isFreeTime = planned == null;
          final plannedTaskId = planned == null ? null : _tryExtractTaskIdFromDescription(planned.description);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  _buildTopTimeStatus(context),
                  Expanded(
                    child: Center(
                      child: isFreeTime ? _buildFreeTimeCore(context) : _buildPlannedTaskCore(context, planned),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 180),
                    child: _buildControls(
                      context,
                      isFreeTime: isFreeTime,
                      plannedTaskId: plannedTaskId,
                      plannedEvent: planned,
                    ),
                  ),
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

  Widget _buildControls(
    BuildContext context, {
    required bool isFreeTime,
    required String? plannedTaskId,
    required CalendarEvent? plannedEvent,
  }) {
    final buttonTextStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        );

    if (isFreeTime) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FilledButton(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              minimumSize: const Size(220, 52),
              textStyle: buttonTextStyle,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('AI 安排稍后接入')),
              );
            },
            child: const Text('让 AI 帮我安排'),
          ),
        ],
      );
    }

    if (plannedEvent == null) {
      return const SizedBox(height: 48);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FilledButton(
          style: FilledButton.styleFrom(textStyle: buttonTextStyle),
          onPressed: () => _handleComplete(context, taskId: plannedTaskId, plannedEvent: plannedEvent),
          child: const Text('完成'),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: () => _handleDoNextTime(context, taskId: plannedTaskId, plannedEvent: plannedEvent),
          child: const Text('下次再做'),
        ),
      ],
    );
  }

  Future<void> _handleComplete(
    BuildContext context, {
    required String? taskId,
    required CalendarEvent plannedEvent,
  }) async {
    try {
      if (taskId != null) {
        final taskProvider = context.read<TaskListProvider>();
        final isRecurring = await taskProvider.isTaskRecurring(taskId);

        // 循环任务：完成仅表示“完成本次时间块/今日这轮”，不把任务本体标记为完成
        if (!isRecurring) {
          await taskProvider.toggleTaskCompletion(taskId);
        }
      }

      // 仅删除当前时间块
      await CalendarDatabaseService().deleteEventByCalendarEvent(plannedEvent);

      // 对于有 taskId 的情况，删除时间块后也清掉该日期的 AI 安排标记，避免任务仍被当作“已安排”
      if (taskId != null) {
        await DayWeekAiScheduler.unmarkAiScheduledTaskForDate(date: plannedEvent.start, taskId: taskId);
      }
      if (!context.mounted) return;
      context.read<ScheduleProvider>().refresh();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败：$e')),
      );
    }
  }

  Future<void> _handleDoNextTime(
    BuildContext context, {
    required String? taskId,
    required CalendarEvent plannedEvent,
  }) async {
    try {
      await CalendarDatabaseService().deleteEventByCalendarEvent(plannedEvent);
      if (taskId != null) {
        await DayWeekAiScheduler.unmarkAiScheduledTaskForDate(date: plannedEvent.start, taskId: taskId);
      }

      if (!context.mounted) return;
      context.read<ScheduleProvider>().refresh();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败：$e')),
      );
    }
  }

  String _formatRange(DateTime start, DateTime end) {
    final s = '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    final e = '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
    return '$s — $e';
  }
}


