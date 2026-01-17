import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'schedule/models.dart';
import 'schedule/widgets.dart';
import 'schedule/day_view.dart';
import 'schedule/week_view.dart';
import 'schedule/month_view.dart';
import 'schedule/month_ai_scheduler.dart';
import 'schedule/day_week_ai_scheduler.dart';
import '../../services/calendar_database_service.dart';
import '../providers/schedule_provider.dart';
import '../providers/task_list_provider.dart';
import '../providers/navigation_provider.dart';
import 'tasks/widgets/task_list_panel.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  CalendarView _view = CalendarView.month;
  late int _year;
  late int _month; // 1-12
  DateTime _selected = DateTime.now();
  CalendarEvent? _selectedEvent;
  bool _isResizingChecklist = false;
  double? _dragWidth;
  double _resizeStartWidth = 0;
  double _resizeStartGlobalX = 0;

  // 数据库服务
  final CalendarDatabaseService _dbService = CalendarDatabaseService();

  static const int _yearRange = 10; // 当前年 ±10 年

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 月视图网格实际显示的范围（包含上月月末/下月月初）。
  /// 返回的 end 是“开区间”，可直接用于 getEventsInRange(start, end)。
  ({DateTime start, DateTime end}) _monthGridRange({required int year, required int month}) {
    final firstOfMonth = DateTime(year, month, 1);
    final firstWeekdayMonFirst = ((firstOfMonth.weekday + 6) % 7); // 以周一为 0
    final startDate = _dateOnly(firstOfMonth.subtract(Duration(days: firstWeekdayMonFirst)));
    const columns = 7;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final weeksNeeded = ((firstWeekdayMonFirst + daysInMonth + columns - 1) ~/ columns);
    final totalCells = weeksNeeded * columns;
    final endExclusive = startDate.add(Duration(days: totalCells));
    return (start: startDate, end: endExclusive);
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
  }

  // 获取包含任务会话的事件列表
  List<CalendarEvent> _getAllEvents(BuildContext context) {
    final scheduleProvider = context.watch<ScheduleProvider>();

    // 根据当前视图获取对应的事件
    switch (_view) {
      case CalendarView.day:
        return scheduleProvider.getEventsForDate(_selected);
      case CalendarView.week:
        final selectedDay = DateTime(_selected.year, _selected.month, _selected.day);
        final weekStart = selectedDay.subtract(Duration(days: selectedDay.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 7));
        return scheduleProvider.getEventsInRange(weekStart, weekEnd);
      case CalendarView.month:
        final range = _monthGridRange(year: _year, month: _month);
        return scheduleProvider.getEventsInRange(range.start, range.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final navigationProvider = context.watch<NavigationProvider>();
    final leftPanelWidth = _dragWidth ?? navigationProvider.calendarChecklistWidth;
    final showChecklist = navigationProvider.isCalendarChecklistExpanded;
    return Row(
      children: [
        AnimatedContainer(
          duration: _isResizingChecklist
              ? Duration.zero
              : const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: showChecklist ? leftPanelWidth : 0,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              minWidth: 0,
              maxWidth: leftPanelWidth,
              child: SizedBox(
                width: leftPanelWidth,
                child: TaskListPanel(),
              ),
            ),
          ),
        ),
        if (showChecklist)
          _MouseResizeHandle(
            onDragStart: (d) {
              _resizeStartWidth = navigationProvider.calendarChecklistWidth;
              _resizeStartGlobalX = d.globalPosition.dx;
              setState(() {
                _isResizingChecklist = true;
                _dragWidth = _resizeStartWidth;
              });
            },
            onDragUpdate: (d) {
              final dx = d.globalPosition.dx - _resizeStartGlobalX;
              final raw = _resizeStartWidth + dx;
              final maxByWindow = MediaQuery.of(context).size.width * 0.6;
              final maxWidth = maxByWindow < NavigationProvider.calendarChecklistMaxWidth
                  ? maxByWindow
                  : NavigationProvider.calendarChecklistMaxWidth;
              final clamped = raw.clamp(
                NavigationProvider.calendarChecklistMinWidth,
                maxWidth,
              );
              setState(() {
                _dragWidth = clamped.toDouble();
              });
            },
            onDragEnd: (_) {
              final finalWidth = _dragWidth;
              if (finalWidth != null) {
                navigationProvider.setCalendarChecklistWidth(finalWidth);
              }
              setState(() {
                _dragWidth = null;
                _isResizingChecklist = false;
              });
            },
          ),
        Expanded(
          child: Column(
            children: [
              _buildHeader(context),
              const Divider(height: 1),
              Expanded(child: _buildMainCalendarArea(context)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final years = List<int>.generate(
      _yearRange * 2 + 1,
      (i) => DateTime.now().year - _yearRange + i,
    );

    final months = List<int>.generate(12, (i) => i + 1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: '上一月',
            icon: const Icon(Icons.chevron_left),
            onPressed: _prevMonth,
          ),
          DropdownButton<int>(
            value: _year,
            items: years
                .map((y) => DropdownMenuItem<int>(value: y, child: Text('$y 年')))
                .toList(),
            onChanged: (v) => setState(() => _year = v ?? _year),
          ),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: _month,
            items: months
                .map((m) => DropdownMenuItem<int>(value: m, child: Text('$m 月')))
                .toList(),
            onChanged: (v) => setState(() => _month = v ?? _month),
          ),
          IconButton(
            tooltip: '下一月',
            icon: const Icon(Icons.chevron_right),
            onPressed: _nextMonth,
          ),
          const Spacer(),
          if (_view == CalendarView.month) ...[
            TextButton.icon(
              icon: const Icon(Icons.auto_awesome),
              label: const Text('AI智能安排'),
              onPressed: _onMonthAiSmartSchedule,
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('清空安排'),
              onPressed: _onMonthClearSchedule,
            ),
            const SizedBox(width: 12),
          ] else if (_view == CalendarView.day) ...[
            TextButton.icon(
              icon: const Icon(Icons.auto_awesome),
              label: const Text('AI智能安排'),
              onPressed: _onDayAiSmartSchedule,
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('清空安排'),
              onPressed: _onDayClearSchedule,
            ),
            const SizedBox(width: 12),
          ] else if (_view == CalendarView.week) ...[
            TextButton.icon(
              icon: const Icon(Icons.auto_awesome),
              label: const Text('AI智能安排'),
              onPressed: _onWeekAiSmartSchedule,
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('清空安排'),
              onPressed: _onWeekClearSchedule,
            ),
            const SizedBox(width: 12),
          ],
          ToggleButtons(
            isSelected: [
              _view == CalendarView.day,
              _view == CalendarView.week,
              _view == CalendarView.month,
            ],
            onPressed: (i) {
              setState(() {
                switch (i) {
                  case 0:
                    _view = CalendarView.day;
                    break;
                  case 1:
                    _view = CalendarView.week;
                    break;
                  case 2:
                    _view = CalendarView.month;
                    break;
                }
              });
            },
            children: const [
              Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('日')),
              Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('周')),
              Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('月')),
            ],
          ),
          const SizedBox(width: 12),
          TextButton.icon(
            icon: const Icon(Icons.today_outlined),
            label: const Text('今日'),
            onPressed: _goToday,
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: _stepTooltip(false),
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _stepView(-1),
          ),
          IconButton(
            tooltip: _stepTooltip(true),
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _stepView(1),
          ),
        ],
      ),
    );
  }

  // 主区域：根据模式切换
  Widget _buildMainCalendarArea(BuildContext context) {
    final allEvents = _getAllEvents(context);

    switch (_view) {
      case CalendarView.day:
        return DayView(
          date: _selected,
          events: allEvents,
          onAddEvent: _addEvent,
          onUpdateEvent: _updateEvent,
          onDeleteEvent: _deleteEvent,
          onSelectEvent: (event) => setState(() => _selectedEvent = event),
          onClearSelection: () => setState(() => _selectedEvent = null),
        );
      case CalendarView.month:
        final taskListProvider = context.watch<TaskListProvider>();
        final gridRange = _monthGridRange(year: _year, month: _month);
        return FutureBuilder<Map<String, List<String>>>(
          future: () async {
            final prefs = await SharedPreferences.getInstance();
            final Map<String, List<String>> todosByDate = {};

            final Map<String, Set<String>> scheduledTaskIdsByDate = <String, Set<String>>{};
            final gridStart = gridRange.start;
            final gridEndExclusive = gridRange.end;
            for (final e in allEvents) {
              if (e.allDay) continue;
              final taskId = _tryExtractTaskIdFromDescription(e.description);
              if (taskId == null || taskId.trim().isEmpty) continue;
              var day = _dateOnly(e.start);
              var last = _dateOnly(e.end);
              if (last.isBefore(day)) continue;
              if (day.isBefore(gridStart)) day = gridStart;
              final gridLast = _dateOnly(gridEndExclusive.subtract(const Duration(days: 1)));
              if (last.isAfter(gridLast)) last = gridLast;
              for (DateTime d = day; !d.isAfter(last); d = d.add(const Duration(days: 1))) {
                final key = _dateKey(d);
                (scheduledTaskIdsByDate[key] ??= <String>{}).add(taskId);
              }
            }

            for (final t in taskListProvider.tasks) {
              if (t.isCompleted) continue;

              // 1) 普通任务：使用 dueDate（单日期）
              final due = t.dueDate;
              if (due != null) {
                final dueDay = _dateOnly(due);
                if (!dueDay.isBefore(gridRange.start) && dueDay.isBefore(gridRange.end)) {
                  final key = _dateKey(dueDay);
                  if (scheduledTaskIdsByDate[key]?.contains(t.id) != true) {
                    (todosByDate[key] ??= <String>[]).add(t.title);
                  }
                }
              }

              // 2) 循环任务：AI 可能写入多个日期到 task_meta aiDueDates
              final raw = prefs.getString('task_meta_v1_${t.id}');
              if (raw == null || raw.trim().isEmpty) continue;
              try {
                final decoded = jsonDecode(raw);
                if (decoded is! Map) continue;
                final v = decoded['aiDueDates'];
                if (v is! List) continue;
                for (final item in v) {
                  final parsed = DateTime.tryParse(item.toString());
                  if (parsed == null) continue;
                  final day = _dateOnly(parsed);
                  if (day.isBefore(gridRange.start) || !day.isBefore(gridRange.end)) continue;
                  final key = _dateKey(day);
                  if (scheduledTaskIdsByDate[key]?.contains(t.id) == true) continue;
                  (todosByDate[key] ??= <String>[]).add(t.title);
                }
              } catch (_) {
                continue;
              }
            }

            return todosByDate;
          }(),
          builder: (context, snapshot) {
            final todosByDate = snapshot.data ?? const <String, List<String>>{};
            return MonthView(
              year: _year,
              month: _month,
              events: allEvents,
              todosByDate: todosByDate,
              onAddEvent: _openAddEventDialog,
            );
          },
        );
      case CalendarView.week:
        return WeekView(
          centerDate: _selected,
          events: allEvents,
          onAddEvent: _addEvent,
          onUpdateEvent: _updateEvent,
          onDeleteEvent: _deleteEvent,
          onSelectEvent: (event) => setState(() => _selectedEvent = event),
          onClearSelection: () => setState(() => _selectedEvent = null),
        );
    }
  }

  String? _tryExtractTaskIdFromDescription(String description) {
    final text = description.trim();
    const prefix = 'AI安排:';
    if (!text.startsWith(prefix)) return null;
    final rest = text.substring(prefix.length).trim();
    return rest.isEmpty ? null : rest;
  }

  String _dateKey(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  void _goToday() {
    final now = DateTime.now();
    setState(() {
      _selected = DateTime(now.year, now.month, now.day);
      _year = now.year;
      _month = now.month;
    });
  }

  // 添加活动
  Future<void> _addEvent(CalendarEvent event) async {
    await _dbService.addEventFromCalendarEvent(event);
    if (mounted) {
      context.read<ScheduleProvider>().refresh();
    }
  }

  // 更新活动
  Future<void> _updateEvent(CalendarEvent oldEvent, CalendarEvent newEvent) async {
    final eventId = _dbService.findEventId(oldEvent);
    if (eventId != null) {
      await _dbService.updateEventById(eventId, newEvent);
      setState(() {
        if (_selectedEvent?.id == oldEvent.id) {
          _selectedEvent = newEvent;
        }
      });

      if (mounted) {
        context.read<ScheduleProvider>().refresh();
      }
    }
  }

  // 删除活动
  Future<void> _deleteEvent(CalendarEvent event) async {
    try {
      await _dbService.deleteEventByCalendarEvent(event);
      if (_selectedEvent == event) {
        _selectedEvent = null;
      }

      if (mounted) {
        context.read<ScheduleProvider>().refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  Future<void> _onMonthAiSmartSchedule() async {
    await MonthAiScheduler.runSmartSchedule(context, year: _year, month: _month);
  }

  Future<void> _onMonthClearSchedule() async {
    await MonthAiScheduler.runClearSchedule(context, year: _year, month: _month);
  }

  Future<void> _onDayAiSmartSchedule() async {
    await DayWeekAiScheduler.runDaySmartSchedule(context, day: _selected);
  }

  Future<void> _onDayClearSchedule() async {
    await DayWeekAiScheduler.runDayClearSchedule(context, day: _selected);
  }

  Future<void> _onWeekAiSmartSchedule() async {
    await DayWeekAiScheduler.runWeekSmartSchedule(context, centerDate: _selected);
  }

  Future<void> _onWeekClearSchedule() async {
    await DayWeekAiScheduler.runWeekClearSchedule(context, centerDate: _selected);
  }

  String _stepTooltip(bool next) {
    switch (_view) {
      case CalendarView.day:
        return next ? '下一天' : '前一天';
      case CalendarView.week:
        return next ? '下一周' : '上一周';
      case CalendarView.month:
        return next ? '下一月' : '上一月';
    }
  }

  void _stepView(int delta) {
    setState(() {
      if (_view == CalendarView.day) {
        _selected = DateTime(_selected.year, _selected.month, _selected.day + delta);
        _year = _selected.year;
        _month = _selected.month;
      } else if (_view == CalendarView.week) {
        _selected = DateTime(_selected.year, _selected.month, _selected.day + 7 * delta);
        _year = _selected.year;
        _month = _selected.month;
      } else {
        final newMonth = _month + delta;
        final newYear = _year + ((newMonth - 1) ~/ 12);
        final monthNorm = ((newMonth - 1) % 12) + 1;
        final days = DateTime(newYear, monthNorm + 1, 0).day;
        final safeDay = math.min(_selected.day, days);
        _year = newYear;
        _month = monthNorm;
        _selected = DateTime(_year, _month, safeDay);
      }
    });
  }

  void _prevMonth() {
    setState(() {
      if (_month == 1) {
        _month = 12;
        _year -= 1;
      } else {
        _month -= 1;
      }
      final days = DateTime(_year, _month + 1, 0).day;
      final safeDay = math.min(_selected.day, days);
      _selected = DateTime(_year, _month, safeDay);
    });
  }

  void _nextMonth() {
    setState(() {
      if (_month == 12) {
        _month = 1;
        _year += 1;
      } else {
        _month += 1;
      }
      final days = DateTime(_year, _month + 1, 0).day;
      final safeDay = math.min(_selected.day, days);
      _selected = DateTime(_year, _month, safeDay);
    });
  }

  Future<void> _openAddEventDialog(DateTime start, DateTime end) async {
    final event = await showDialog<CalendarEvent>(
      context: context,
      builder: (context) => AddEventDialog(startDate: start, endDate: end),
    );

    if (event != null) {
      await _addEvent(event);
    }
  }
}

class _MouseResizeHandle extends StatelessWidget {
  final ValueChanged<DragStartDetails>? onDragStart;
  final ValueChanged<DragUpdateDetails>? onDragUpdate;

  final ValueChanged<DragEndDetails>? onDragEnd;

  const _MouseResizeHandle({
    this.onDragStart,
    this.onDragUpdate,

    this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (d) => onDragStart?.call(d),
        onHorizontalDragUpdate: (d) => onDragUpdate?.call(d),
        onHorizontalDragEnd: (d) => onDragEnd?.call(d),
        child: SizedBox(
          width: 8,
          child: Center(
            child: VerticalDivider(
              width: 1,
              thickness: 1,
              color: Theme.of(context).dividerColor,
            ),
          ),
        ),
      ),
    );
  }
}