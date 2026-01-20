import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
import '../providers/daily_plan_provider.dart'; // Import DailyPlanProvider
import 'tasks/widgets/task_list_panel.dart';

import '../../data/models/calendar_event_hive.dart'; // Add import
import '../../data/models/daily_plan_hive.dart';

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
    // 迁移：使用 DailyPlanProvider 替代 ScheduleProvider 获取事件
    // 注意：这里的 _getAllEvents 必须返回同步数据，但 DailyPlan 可能是异步的
    // 为了兼容现有架构，我们暂时返回空列表，让各子视图 (DayView/MonthView) 自己处理数据获取
    // 或者，我们可以通过 FutureBuilder 在 build 方法中预加载
    // 
    // 目前 DayView/WeekView/MonthView 已经部分重构为从 props 接收 events
    // 为了彻底切换，我们需要在 build 方法中统一获取 DailyPlan 数据
    return []; 
  }

  @override
  Widget build(BuildContext context) {
    final navigationProvider = context.watch<NavigationProvider>();
    final dailyPlanProvider = context.watch<DailyPlanProvider>(); // Watch DailyPlanProvider
    
    // 预加载当前视图所需的 DailyPlan 数据
    // 根据视图类型决定范围
    DateTime start, end;
    switch (_view) {
      case CalendarView.day:
        start = _dateOnly(_selected);
        end = start.add(const Duration(days: 1));
        break;
      case CalendarView.week:
        final selectedDay = _dateOnly(_selected);
        start = selectedDay.subtract(Duration(days: selectedDay.weekday - 1));
        end = start.add(const Duration(days: 7));
        break;
      case CalendarView.month:
        final range = _monthGridRange(year: _year, month: _month);
        start = range.start;
        end = range.end;
        break;
    }

    return FutureBuilder<Map<DateTime, DailyPlanHive>>(
        future: dailyPlanProvider.getPlansForRange(start, end),
        builder: (context, snapshot) {
            final plans = snapshot.data ?? {};
            
            // 将 DailyPlan 中的 embedded events 转换为 CalendarEvent 列表供 UI 使用
            final allEvents = <CalendarEvent>[];
            for (final plan in plans.values) {
                for (final e in plan.scheduledEvents) {
                    allEvents.add(e.toCalendarEvent());
                }
            }
            
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
                      Expanded(child: _buildMainCalendarArea(context, allEvents, plans)), // Pass data
                    ],
                  ),
                ),
              ],
            );
        }
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
  Widget _buildMainCalendarArea(BuildContext context, List<CalendarEvent> allEvents, Map<DateTime, DailyPlanHive> plans) {
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
        // 使用传入的 plans，不再重复调用 provider
        
        // 构造 todosByDate
        final Map<String, List<String>> todosByDate = {};
        plans.forEach((date, plan) {
          final key = _dateKey(date);
          final titles = <String>[];
          
          // 1. 全天任务
          for (final id in plan.allDayTaskIds) {
             final t = taskListProvider.getTaskById(id);
             if (t != null && !t.isCompleted) {
               titles.add(t.title);
             }
          }
          
          // 2. 待办任务
          for (final id in plan.todoTaskIds) {
             final t = taskListProvider.getTaskById(id);
             if (t != null && !t.isCompleted) {
               titles.add(t.title);
             }
          }
          
          if (titles.isNotEmpty) {
            todosByDate[key] = titles;
          }
        });

        return MonthView(
            year: _year,
            month: _month,
            events: allEvents,
            todosByDate: todosByDate,
            onAddEvent: _openAddEventDialog,
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
    // 迁移：使用 DailyPlanProvider 替代 CalendarDatabaseService
    final dailyPlanProvider = context.read<DailyPlanProvider>();
    
    // 需要将 CalendarEvent (UI Model) 转换为 CalendarEventHive (Data Model)
    final hiveEvent = CalendarEventHive(
      id: event.id.isEmpty ? DateTime.now().millisecondsSinceEpoch.toString() : event.id,
      title: event.title,
      description: event.description,
      allDay: event.allDay,
      start: event.start,
      end: event.end,
      colorValue: event.color.value,
      isCompleted: false,
    );
    
    await dailyPlanProvider.addScheduledEvent(event.start, hiveEvent);
    // refresh() is handled by notifyListeners in Provider
  }

  // 更新活动
  Future<void> _updateEvent(CalendarEvent oldEvent, CalendarEvent newEvent) async {
    // 迁移：使用 DailyPlanProvider 替代 CalendarDatabaseService
    final dailyPlanProvider = context.read<DailyPlanProvider>();
    
    final hiveEvent = CalendarEventHive(
      id: newEvent.id,
      title: newEvent.title,
      description: newEvent.description,
      allDay: newEvent.allDay,
      start: newEvent.start,
      end: newEvent.end,
      colorValue: newEvent.color.value,
      isCompleted: false, // 保留状态需优化，暂默认false
    );
    
    // DailyPlanProvider.updateScheduledEvent 会处理跨天迁移
    await dailyPlanProvider.updateScheduledEvent(oldEvent.start, hiveEvent);
    
    setState(() {
      if (_selectedEvent?.id == oldEvent.id) {
        _selectedEvent = newEvent;
      }
    });
  }

  // 删除活动
  Future<void> _deleteEvent(CalendarEvent event) async {
    try {
      // 迁移：使用 DailyPlanProvider 替代 CalendarDatabaseService
      final dailyPlanProvider = context.read<DailyPlanProvider>();
      await dailyPlanProvider.removeScheduledEvent(event.start, event.id);

      if (_selectedEvent == event) {
        _selectedEvent = null;
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