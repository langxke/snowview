import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/models/openai/openai_models.dart';
import '../../../data/repositories/ai_config_repository.dart';
import '../../../services/ai_service.dart';
import '../../../services/calendar_database_service.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/task_list_provider.dart';
import 'models.dart';

class DayWeekAiScheduler {
  static const String _eventMetaPrefsPrefix = 'event_meta_v1_';
  static const String _eventMetaAiKey = 'ai';
  static const String _scheduledTaskIdsByDatePrefix = 'ai_scheduled_task_ids_v1_';


  // 可分配时间段设置（与 SettingsScreen 保持一致）
  static const String _prefsKeyWeekdayRanges = 'availability_weekday_ranges_v1';
  static const String _prefsKeyWeekendRanges = 'availability_weekend_ranges_v1';
  static const String _prefsKeyWorkdays = 'availability_workdays_v1';

  // 默认值（与 SettingsScreen 初始值保持一致）
  static const List<_TimeRange> _defaultWeekdayRanges = <_TimeRange>[
    _TimeRange(startMinutes: 9 * 60, endMinutes: 12 * 60),
    _TimeRange(startMinutes: 13 * 60, endMinutes: 18 * 60),
  ];
  static const List<_TimeRange> _defaultWeekendRanges = <_TimeRange>[
    _TimeRange(startMinutes: 10 * 60, endMinutes: 12 * 60),
    _TimeRange(startMinutes: 14 * 60, endMinutes: 18 * 60),
  ];
  static const Set<int> _defaultWorkdays = <int>{1, 2, 3, 4, 5};

  static void _logLong(String tag, String message) {
    const chunk = 900;
    if (message.length <= chunk) {
      debugPrint('[$tag] $message');
      return;
    }
    for (int i = 0; i < message.length; i += chunk) {
      final end = (i + chunk < message.length) ? i + chunk : message.length;
      debugPrint('[$tag] ${message.substring(i, end)}');
    }
  }

  static DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _dayEnd(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59);

  static String _dateOnlyKey(DateTime d) {
    final dd = DateTime(d.year, d.month, d.day);
    final mm = dd.month.toString().padLeft(2, '0');
    final day = dd.day.toString().padLeft(2, '0');
    return '${dd.year}-$mm-$day';
  }

  static String _scheduledTaskKeyForDate(DateTime d) => '$_scheduledTaskIdsByDatePrefix${_dateOnlyKey(d)}';

  static List<_TimeRange>? _parseRanges(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      final ranges = <_TimeRange>[];
      for (final item in decoded) {
        if (item is Map) {
          final start = item['startMinutes'];
          final end = item['endMinutes'];
          if (start is int && end is int) {
            final r = _TimeRange(startMinutes: start, endMinutes: end);
            if (r.isValid) ranges.add(r);
          }
        }
      }
      return ranges;
    } catch (_) {
      return null;
    }
  }

  static Set<int>? _parseWorkdays(List<String>? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parsed = <int>{};
    for (final s in raw) {
      final v = int.tryParse(s);
      if (v != null && v >= 1 && v <= 7) parsed.add(v);
    }
    return parsed;
  }

  static Future<({List<_TimeRange> weekday, List<_TimeRange> weekend, Set<int> workdays})> _loadAvailability() async {
    final prefs = await SharedPreferences.getInstance();
    final weekdayRaw = prefs.getString(_prefsKeyWeekdayRanges);
    final weekendRaw = prefs.getString(_prefsKeyWeekendRanges);
    final workdaysRaw = prefs.getStringList(_prefsKeyWorkdays);

    final weekdayParsed = _parseRanges(weekdayRaw);
    final weekendParsed = _parseRanges(weekendRaw);
    final workdaysParsed = _parseWorkdays(workdaysRaw);

    final weekday = weekdayParsed ?? _defaultWeekdayRanges;
    final weekend = weekendParsed ?? _defaultWeekendRanges;
    final workdays = workdaysParsed ?? _defaultWorkdays;

    if (weekdayParsed == null) {
      debugPrint('[DayWeekAiScheduler] availability weekdayRanges parse failed, fallback to default. raw=${weekdayRaw ?? '<null>'}');
    }
    if (weekendParsed == null) {
      debugPrint('[DayWeekAiScheduler] availability weekendRanges parse failed, fallback to default. raw=${weekendRaw ?? '<null>'}');
    }
    if (workdaysParsed == null) {
      debugPrint('[DayWeekAiScheduler] availability workdays parse failed, fallback to default. raw=${workdaysRaw ?? const <String>[]}'.toString());
    }

		debugPrint(
			'[DayWeekAiScheduler] availability loaded '
			'weekday=${weekday.map((e) => '${e.formatStart()}-${e.formatEnd()}').toList(growable: false)} '
			'weekend=${weekend.map((e) => '${e.formatStart()}-${e.formatEnd()}').toList(growable: false)} '
			'workdays=$workdays',
		);
    return (weekday: weekday, weekend: weekend, workdays: workdays);
  }

  static List<_TimeRange> _rangesForDate({required DateTime date, required List<_TimeRange> weekday, required List<_TimeRange> weekend, required Set<int> workdays}) {
    final isWorkday = workdays.contains(date.weekday);
    return isWorkday ? weekday : weekend;
  }

  static DateTime _applyMinutes(DateTime day, int minutes) {
    // Guard against 24:00 (1440) which would otherwise spill to next day.
    // SettingsScreen validation allows endMinutes up to 24*60.
    if (minutes >= 24 * 60) {
      return _dayEnd(day);
    }
    if (minutes <= 0) {
      return DateTime(day.year, day.month, day.day);
    }
    return DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);
  }

  static bool _blockWithinAnyWindow({required DateTime start, required DateTime end, required List<({DateTime start, DateTime end})> windows}) {
    for (final w in windows) {
      if (!start.isBefore(w.start) && !end.isAfter(w.end)) return true;
    }
    return false;
  }

	static bool _blockWithinAnyRange({
		required DateTime start,
		required DateTime end,
		required List<_TimeRange> ranges,
	}) {
		final startM = start.hour * 60 + start.minute;
		final endM = end.hour * 60 + end.minute;
		for (final r in ranges) {
			if (startM >= r.startMinutes && endM <= r.endMinutes) return true;
		}
		return false;
	}

  static List<({DateTime start, DateTime end})> _mergeIntervals(List<({DateTime start, DateTime end})> intervals) {
    if (intervals.isEmpty) return const [];
    final sorted = [...intervals]..sort((a, b) => a.start.compareTo(b.start));
    final merged = <({DateTime start, DateTime end})>[];
    var cur = sorted.first;
    for (int i = 1; i < sorted.length; i++) {
      final next = sorted[i];
      if (!next.start.isAfter(cur.end)) {
        final end = next.end.isAfter(cur.end) ? next.end : cur.end;
        cur = (start: cur.start, end: end);
      } else {
        merged.add(cur);
        cur = next;
      }
    }
    merged.add(cur);
    return merged;
  }

  static List<({DateTime start, DateTime end})> _subtractBusyFromWindow({
    required DateTime windowStart,
    required DateTime windowEnd,
    required List<({DateTime start, DateTime end})> busy,
  }) {
    if (!windowEnd.isAfter(windowStart)) return const [];
    if (busy.isEmpty) return [(start: windowStart, end: windowEnd)];
    final mergedBusy = _mergeIntervals(busy);
    final result = <({DateTime start, DateTime end})>[];
    var cursor = windowStart;
    for (final b in mergedBusy) {
      if (!b.end.isAfter(windowStart)) continue;
      if (!b.start.isBefore(windowEnd)) break;
      final bs = b.start.isBefore(windowStart) ? windowStart : b.start;
      final be = b.end.isAfter(windowEnd) ? windowEnd : b.end;
      if (bs.isAfter(cursor)) {
        result.add((start: cursor, end: bs));
      }
      if (be.isAfter(cursor)) cursor = be;
      if (!windowEnd.isAfter(cursor)) break;
    }
    if (windowEnd.isAfter(cursor)) {
      result.add((start: cursor, end: windowEnd));
    }
    return result.where((w) => w.end.isAfter(w.start)).toList(growable: false);
  }

  static bool _overlapsBusy({required DateTime start, required DateTime end, required List<CalendarEvent> busyEvents}) {
    for (final b in busyEvents) {
      if (b.allDay) continue;
      if (start.isBefore(b.end) && end.isAfter(b.start)) return true;
    }
    return false;
  }

  static Future<Set<String>> getAiScheduledTaskIdsForDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_scheduledTaskKeyForDate(date)) ?? const <String>[];
    return raw.toSet();
  }

  static Future<void> _markTaskScheduledForDate({
    required SharedPreferences prefs,
    required DateTime date,
    required String taskId,
  }) async {
    final key = _scheduledTaskKeyForDate(date);
    final existing = (prefs.getStringList(key) ?? const <String>[]).toSet();
    existing.add(taskId);
    await prefs.setStringList(key, existing.toList());
  }

  static Future<void> _unmarkTaskScheduledForDate({
    required SharedPreferences prefs,
    required DateTime date,
    required String taskId,
  }) async {
    final key = _scheduledTaskKeyForDate(date);
    final existing = (prefs.getStringList(key) ?? const <String>[]).toSet();
    if (!existing.remove(taskId)) return;
    if (existing.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setStringList(key, existing.toList());
    }
  }

  static Future<void> unmarkAiScheduledTaskForDate({
    required DateTime date,
    required String taskId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await _unmarkTaskScheduledForDate(prefs: prefs, date: date, taskId: taskId);
  }

  static Future<void> runDaySmartSchedule(BuildContext context, {required DateTime day}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(day.year, day.month, day.day);
    final rangeStart = targetDay == today ? now : _dayStart(day);
    final rangeEnd = _dayEnd(day);
    await _runSmartSchedule(context, rangeStart: rangeStart, rangeEnd: rangeEnd, scopeLabel: '当天');
  }

  static Future<void> runWeekSmartSchedule(BuildContext context, {required DateTime centerDate}) async {
    final now = DateTime.now();
    final today = _dayStart(DateTime(now.year, now.month, now.day));
    final centerDay = _dayStart(centerDate);

    // 本周定义：从“今天/所选日期（取较晚者）”开始，到该周周日结束；
    // 且如果 start 是今天，则从当前时间开始（避免安排到今天已经过去的时间）。
    final weekStartMon = _dayStart(centerDay.subtract(Duration(days: centerDay.weekday - 1)));
    final weekEndSun = _dayEnd(weekStartMon.add(const Duration(days: 6)));
    final startDay = centerDay.isAfter(today) ? centerDay : today;
    final start = startDay == today ? now : startDay;

    if (start.isAfter(weekEndSun)) {
      // 当天已超过本周范围（极端情况：start 在下周），退化为当天
      await _runSmartSchedule(context, rangeStart: start, rangeEnd: _dayEnd(start), scopeLabel: '本周');
      return;
    }

    await _runSmartSchedule(context, rangeStart: start, rangeEnd: weekEndSun, scopeLabel: '本周');
  }

  static Future<void> runDayClearSchedule(BuildContext context, {required DateTime day}) async {
    final rangeStart = _dayStart(day);
    final rangeEnd = _dayEnd(day);
    await _runClearSchedule(context, rangeStart: rangeStart, rangeEnd: rangeEnd, scopeLabel: '当天');
  }

  static Future<void> runWeekClearSchedule(BuildContext context, {required DateTime centerDate}) async {
    final now = DateTime.now();
    final today = _dayStart(DateTime(now.year, now.month, now.day));
    final centerDay = _dayStart(centerDate);

    final weekStartMon = _dayStart(centerDay.subtract(Duration(days: centerDay.weekday - 1)));
    final weekEndSun = _dayEnd(weekStartMon.add(const Duration(days: 6)));
    final start = centerDay.isAfter(today) ? centerDay : today;

    if (start.isAfter(weekEndSun)) {
      await _runClearSchedule(context, rangeStart: start, rangeEnd: _dayEnd(start), scopeLabel: '本周');
      return;
    }

    await _runClearSchedule(context, rangeStart: start, rangeEnd: weekEndSun, scopeLabel: '本周');
  }

  static Future<void> _runSmartSchedule(
    BuildContext context, {
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required String scopeLabel,
  }) async {
    final aiService = AIService(AIConfigRepository());
    if (!aiService.hasValidConfig) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI 未配置或配置无效，请先在设置中配置 AI 连接')),
      );
      return;
    }

    final taskProvider = context.read<TaskListProvider>();
    final prefs = await SharedPreferences.getInstance();

    int getTaskPriority(dynamic t) {
      // 尝试从 SharedPreferences 读取 meta (与 _callTimeBlockSchedulingAI 保持一致)
      final raw = prefs.getString('task_meta_v1_${t.id}');
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map && decoded['priority'] is int) {
            return decoded['priority'];
          }
        } catch (_) {}
      }
      // 如果没有 meta，尝试读取对象上的 priority 属性，默认为 0 (低)
      // 假设 Task 对象有 priority 字段，且 2=High, 1=Medium, 0=Low
      try {
        return (t as dynamic).priority ?? 0;
      } catch (_) {
        return 0;
      }
    }

    // Helper: 判断任务是否为循环任务
    // 循环任务的 repeat 规则存储在 SharedPreferences 中
    bool isRecurringTask(dynamic t) {
      final raw = prefs.getString('task_meta_v1_${t.id}');
      if (raw == null || raw.trim().isEmpty) return false;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) return false;
        final rep = decoded['repeat']?.toString();
        return rep != null && rep.isNotEmpty && rep != 'none';
      } catch (_) {
        return false;
      }
    }

    final allTasks = taskProvider.tasks.where((t) => !t.isCompleted).toList();

    // 1. 包含过期任务：只要截止日期不晚于 rangeEnd (且未完成)，都应纳入调度
    // 原逻辑 !due.isBefore(rangeStart) 会导致昨天截止的任务被丢弃，现已修正。
    // 【修正】：对于循环任务，如果已过期且未完成，应予以排除，防止堆积。
    final datedTasks = allTasks.where((t) {
      final due = (t as dynamic).dueDate as DateTime?;
      if (due == null) return false;
      
      // 如果截止日期在范围之后，肯定不选
      if (due.isAfter(rangeEnd)) return false;

      // 如果截止日期在 rangeStart 之前（即已过期）
      if (due.isBefore(rangeStart)) {
        // 如果是循环任务，则跳过（不处理过期循环任务）
        if (isRecurringTask(t)) return false;
      }
      
      return true;
    }).toList();

    // 2. 无截止日任务
    final noDateTasks = allTasks.where((t) => (t as dynamic).dueDate == null).toList();

    // 3. 排序：优先级(高->低) > 截止日期(早->晚)
    datedTasks.sort((a, b) {
      final pA = getTaskPriority(a);
      final pB = getTaskPriority(b);
      if (pA != pB) return pB.compareTo(pA); // Descending (2 > 1 > 0)
      final dueA = (a as dynamic).dueDate as DateTime;
      final dueB = (b as dynamic).dueDate as DateTime;
      return dueA.compareTo(dueB); // Ascending
    });

    noDateTasks.sort((a, b) {
      final pA = getTaskPriority(a);
      final pB = getTaskPriority(b);
      return pB.compareTo(pA);
    });

    // 4. 合并与截断 (Top 50)
    final sourceTasks = <dynamic>[...datedTasks, ...noDateTasks];
    if (sourceTasks.length > 50) {
      sourceTasks.length = 50;
    }

    if (sourceTasks.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('没有可用于时间分配的任务（$scopeLabel 内无待办，且清单里也没有未安排任务）')),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI智能安排'),
        content: Text('将为 $scopeLabel 生成时间块，并从“未安排任务”中选择任务填充（不会创建新任务）。是否继续？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('开始')),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;

    final scheduleProvider = context.read<ScheduleProvider>();
    final busyEvents = scheduleProvider.getEventsInRange(rangeStart, rangeEnd)
        .where((e) => !e.allDay)
        .toList(growable: false);

    final closeLoading = _showBlockingLoading(context, 'AI 正在生成时间安排…');
    try {
      debugPrint('[DayWeekAiScheduler] smartSchedule start scope=$scopeLabel rangeStart=$rangeStart rangeEnd=$rangeEnd');
      final plan = await _callTimeBlockSchedulingAI(
        aiService: aiService,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        busyEvents: busyEvents,
        candidates: sourceTasks,
      ).timeout(const Duration(seconds: 90));

      debugPrint('[DayWeekAiScheduler] smartSchedule plan size=${plan.length}');

      final db = CalendarDatabaseService();
      final prefs = await SharedPreferences.getInstance();

      int created = 0;
      for (int i = 0; i < plan.length; i++) {
        final block = plan[i];
        debugPrint(
          '[DayWeekAiScheduler] createEvent[$i/${plan.length}] taskId=${block.taskId} start=${block.start.toIso8601String()} end=${block.end.toIso8601String()}',
        );
        final event = CalendarEvent(
          title: block.title,
          allDay: false,
          description: block.description,
          color: Colors.blue,
          start: block.start,
          end: block.end,
        );
        final id = await db.addEventFromCalendarEvent(event).timeout(const Duration(seconds: 10));
        await _writeEventMetaAi(prefs: prefs, eventId: id).timeout(const Duration(seconds: 5));
        await _markTaskScheduledForDate(prefs: prefs, date: block.start, taskId: block.taskId).timeout(const Duration(seconds: 5));
        created++;
        await Future<void>.delayed(Duration.zero);
      }

      debugPrint('[DayWeekAiScheduler] smartSchedule created=$created');

      if (!context.mounted) return;
      scheduleProvider.refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI 已生成 $created 个时间块')),
      );
    } catch (e) {
      debugPrint('[DayWeekAiScheduler] smartSchedule error=$e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI 安排失败：$e')),
      );
    } finally {
      closeLoading();
    }
  }

  static Future<void> _runClearSchedule(
    BuildContext context, {
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required String scopeLabel,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空安排'),
        content: Text('将清空 $scopeLabel 范围内由 AI 创建的时间块，手动添加的日程不会受影响。是否继续？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('清空')),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;

    final closeLoading = _showBlockingLoading(context, '正在清空 AI 时间块…');
    try {
      debugPrint('[DayWeekAiScheduler] clearSchedule start scope=$scopeLabel rangeStart=$rangeStart rangeEnd=$rangeEnd');
      final cleared = await _clearAiEventsInRange(rangeStart: rangeStart, rangeEnd: rangeEnd)
          .timeout(const Duration(seconds: 90));
      debugPrint('[DayWeekAiScheduler] clearSchedule cleared=$cleared');
      if (!context.mounted) return;
      context.read<ScheduleProvider>().refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已清空 $cleared 个 AI 时间块')),
      );
    } catch (e) {
      debugPrint('[DayWeekAiScheduler] clearSchedule error=$e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('清空失败：$e')),
      );
    } finally {
      closeLoading();
    }
  }

  static Future<int> _clearAiEventsInRange({required DateTime rangeStart, required DateTime rangeEnd}) async {
    final db = CalendarDatabaseService();
    final prefs = await SharedPreferences.getInstance();

    final events = db.getCalendarEventsInRange(rangeStart, rangeEnd);
    debugPrint('[DayWeekAiScheduler] clearAiEventsInRange eventsInRange=${events.length}');
    int cleared = 0;
    for (int i = 0; i < events.length; i++) {
      final e = events[i];
      final isAi = _readEventMetaAi(prefs: prefs, eventId: e.id);
      if (!isAi) continue;
      debugPrint(
        '[DayWeekAiScheduler] deleteAiEvent[$i/${events.length}] eventId=${e.id} start=${e.start.toIso8601String()} end=${e.end.toIso8601String()}',
      );
      await db.deleteEvent(e.id).timeout(const Duration(seconds: 10));
      await _clearEventMetaAi(prefs: prefs, eventId: e.id).timeout(const Duration(seconds: 5));

      final taskId = _tryExtractTaskIdFromDescription(e.description);
      if (taskId != null && taskId.isNotEmpty) {
        await _unmarkTaskScheduledForDate(prefs: prefs, date: e.start, taskId: taskId).timeout(const Duration(seconds: 5));
      }
      cleared++;
      await Future<void>.delayed(Duration.zero);
    }
    return cleared;
  }

  static String? _tryExtractTaskIdFromDescription(String description) {
    final text = description.trim();
    const prefix = 'AI安排:';
    if (!text.startsWith(prefix)) return null;
    final rest = text.substring(prefix.length).trim();
    return rest.isEmpty ? null : rest;
  }

  static Future<void> _writeEventMetaAi({required SharedPreferences prefs, required String eventId}) async {
    final key = '$_eventMetaPrefsPrefix$eventId';
    await prefs.setString(key, jsonEncode({_eventMetaAiKey: true}));
  }

  static bool _readEventMetaAi({required SharedPreferences prefs, required String eventId}) {
    final raw = prefs.getString('$_eventMetaPrefsPrefix$eventId');
    if (raw == null || raw.trim().isEmpty) return false;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return false;
      return decoded[_eventMetaAiKey] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _clearEventMetaAi({required SharedPreferences prefs, required String eventId}) async {
    await prefs.remove('$_eventMetaPrefsPrefix$eventId');
  }

  static Future<List<_TimeBlockPlan>> _callTimeBlockSchedulingAI({
    required AIService aiService,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required List<CalendarEvent> busyEvents,
    required List<dynamic> candidates,
  }) async {
    final availability = await _loadAvailability();

    final prefs = await SharedPreferences.getInstance();

    Map<String, dynamic>? readTaskMeta(String taskId) {
      final raw = prefs.getString('task_meta_v1_$taskId');
      if (raw == null || raw.trim().isEmpty) return null;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) return null;
        return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return null;
      }
    }

    final taskItems = candidates.map((t) {
      final dyn = t as dynamic;
      final meta = readTaskMeta(dyn.id.toString());
      return {
        'id': dyn.id,
        'title': dyn.title,
        if (dyn.description != null) 'description': dyn.description, // 备注（给 AI 看）
        if (meta?['estimatedMinutes'] != null) 'estimatedMinutes': meta?['estimatedMinutes'],
        if (meta?['priority'] != null) 'priority': meta?['priority'],
        if (meta?['repeat'] != null) 'repeat': meta?['repeat'],
        if (dyn.remindAt != null) 'remindAt': (dyn.remindAt as DateTime).toIso8601String(),
      };
    }).toList();

    final busy = busyEvents.map((e) {
      return {
        'title': e.title,
        'start': e.start.toIso8601String(),
        'end': e.end.toIso8601String(),
        'allDay': e.allDay,
      };
    }).toList();

    // 先按“可分配时间段 + busyEvents + rangeStart/rangeEnd”计算每天空闲时间段（不跨天），交给 AI 填充。
    final freeWindowsByDayKey = <String, List<({DateTime start, DateTime end})>>{};
    final freeWindowsForAi = <Map<String, dynamic>>[];

    for (DateTime day = _dayStart(rangeStart); !day.isAfter(_dayStart(rangeEnd)); day = day.add(const Duration(days: 1))) {
      final dayKey = _dateOnlyKey(day);
      final ranges = _rangesForDate(
        date: day,
        weekday: availability.weekday,
        weekend: availability.weekend,
        workdays: availability.workdays,
      );

      final dayBusy = <({DateTime start, DateTime end})>[];
      for (final b in busyEvents) {
        if (b.allDay) continue;
        if (DateTime(b.start.year, b.start.month, b.start.day) != day && DateTime(b.end.year, b.end.month, b.end.day) != day) {
          // 快速过滤：既不是当天开始也不是当天结束的事件，后面仍会通过 overlap 校验挡住；这里先略过
        }
        final start = b.start;
        final end = b.end;
        if (!end.isAfter(start)) continue;
        // 裁剪到当天边界
        final ds = _dayStart(day);
        final de = _dayEnd(day);
        final cs = start.isBefore(ds) ? ds : start;
        final ce = end.isAfter(de) ? de : end;
        if (ce.isAfter(cs)) {
          dayBusy.add((start: cs, end: ce));
        }
      }

      final dayFree = <({DateTime start, DateTime end})>[];
      for (final r in ranges) {
        var ws = _applyMinutes(day, r.startMinutes);
        var we = _applyMinutes(day, r.endMinutes);
        if (ws.isBefore(rangeStart)) ws = rangeStart;
        if (we.isAfter(rangeEnd)) we = rangeEnd;
        if (!we.isAfter(ws)) continue;

        final busyOverlappingWindow = dayBusy
            .where((b) => b.start.isBefore(we) && b.end.isAfter(ws))
            .map((b) => (
                  start: b.start.isBefore(ws) ? ws : b.start,
                  end: b.end.isAfter(we) ? we : b.end,
                ))
            .toList(growable: false);

        dayFree.addAll(_subtractBusyFromWindow(windowStart: ws, windowEnd: we, busy: busyOverlappingWindow));
      }

      final mergedFree = _mergeIntervals(dayFree);
      freeWindowsByDayKey[dayKey] = mergedFree;

      freeWindowsForAi.add({
        'date': dayKey,
        'free': mergedFree
            .map((w) => {
                  'start': w.start.toIso8601String(),
                  'end': w.end.toIso8601String(),
                })
            .toList(),
      });
    }

    final systemPrompt =
        '你是一个严格的“日历时间块排期引擎（Time-Block Scheduling Engine）”。\n'
        '你要把任务安排到具体的时间段中，并生成日程块。\n'
        '你的目标是：在不违反规则的前提下，最大化利用 freeWindows（空闲时间），实现紧凑安排（Tight Scheduling）。\n'
        '不要预留缓冲空隙（除非无任务可排），尽可能填满所有空闲时间。\n'
        '\n'
        '## 核心策略（Core Strategy）\n'
        '1. **要事优先**：严格遵守任务优先级。高优先级任务必须优先安排，且应分配到精力最好的时段。\n'
        '2. **90分钟法则**：单个时间块的最长持续时间不得超过 90 分钟。\n'
        '   - 如果任务预估耗时 > 90 分钟，必须将其拆分为多个时间块。\n'
        '3. **穿插调度 (Interleaving)**：\n'
        '   - 当长任务被拆分时（如 A1, A2），尽量在它们之间插入一个短任务或不同类型的任务（如 B），形成 A -> B -> A 的模式，以缓解疲劳。\n'
        '   - 避免连续安排超过 3 小时的同一任务（即避免 A -> A -> A）。\n'
        '4. **紧凑排列**：不要在时间块之间人为制造空隙。End(Block N) 应等于 Start(Block N+1)。\n'
        '\n'
        '## 关键规则（必须遵守）\n'
        '1) 你不能创建新的任务，只能从 taskPool 中选择 taskId。\n'
        '2) 你必须避开 busyEvents 中的忙碌时间段，不能产生冲突。\n'
        '3) 所有输出的 start/end 必须落在 freeWindows 提供的空闲时间段内。\n'
        '4) 你不能安排跨天时间块（start 与 end 必须在同一天）。\n'
        '5) 每个时间块必须 end > start，且以 15 分钟为粒度；并且每个时间块的时长必须 >= 15 分钟。\n'
        '6) 你必须只输出纯 JSON，不允许输出解释/Markdown/代码块。\n'
        '\n'
        '## 输出 JSON Schema（必须严格匹配）\n'
        '{\n'
        '  "blocks": [\n'
        '    {\n'
        '      "taskId": "<string>",\n'
        '      "title": "<string>",\n'
        '      "start": "<ISO8601>",\n'
        '      "end": "<ISO8601>"\n'
        '    }\n'
        '  ]\n'
        '}';

    final userPrompt = jsonEncode({
      'instruction': {
        'goal': '在 freeWindows 内生成紧凑的时间安排。优先完成高优先级任务；利用穿插策略缓解长任务疲劳；最大化时间利用率。',
        'range': {
          'start': rangeStart.toIso8601String(),
          'end': rangeEnd.toIso8601String(),
        },
        'time_granularity_minutes': 15,
        'planning_strategy': {
          'maximize_total_scheduled_minutes': true,
          'allow_multiple_blocks_per_task': true,
          'max_block_duration_minutes': 90,
          'interleave_long_tasks': true,
          'prefer_tight_scheduling': true,
          'minimize_gaps': true,
          'balance_strategy': 'priority_based',
          'notes': '任务已按优先级和截止日期排序。请优先安排列表靠前的任务。如果任务需时较长，请拆分并尝试穿插其他短任务。'
        }
      },
      'busyEvents': busy,
      'freeWindows': freeWindowsForAi,
      'taskPool': taskItems,
      'output_schema': {
        'blocks': [
          {'taskId': '<string>', 'title': '<string>', 'start': '<ISO8601>', 'end': '<ISO8601>'}
        ]
      }
    });

    _logLong('DayWeekAiScheduler', 'Request userPrompt=$userPrompt');

    final resp = await aiService.chat(
      messages: [OpenAIChatMessage.text(role: OpenAIMessageRole.user, content: userPrompt)],
      systemPrompt: systemPrompt,
      tools: null,
    );

    final msg = resp.choices.isNotEmpty ? resp.choices.first.message : null;
    _logLong('DayWeekAiScheduler', 'AI message.toJson=${jsonEncode(msg?.toJson() ?? {})}');
    final text = msg?.textContent ?? '';
    _logLong('DayWeekAiScheduler', 'AI raw textContent=$text');

    final jsonStr = _extractJsonObject(text);
    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map) throw Exception('AI 输出不是 JSON 对象');
    final blocks = decoded['blocks'];
    if (blocks is! List) throw Exception('AI 输出缺少 blocks');

    final allowedIds = taskItems.map((e) => e['id'].toString()).toSet();
    final usedIntervals = <({DateTime start, DateTime end})>[];
    final allocatedMinutesByTaskId = <String, int>{};
    const maxBlocksPerTask = 8;
    final blocksCountByTaskId = <String, int>{};

    final estMinutesByTaskId = <String, int?>{
      for (final item in taskItems)
        item['id'].toString(): (item['estimatedMinutes'] is int
            ? item['estimatedMinutes'] as int
            : int.tryParse(item['estimatedMinutes']?.toString() ?? '')),
    };

    final result = <_TimeBlockPlan>[];

    // Helper: 强制将 AI 返回的时间视为本地 Wall-Clock Time
    // AI 往往会给时间加上 'Z' 后缀（因为 prompt 要求 ISO8601），但实际上它是基于 prompt 里的本地时间生成的。
    // 如果直接解析为 UTC，会导致时区偏移（例如 UTC+8 会偏 8 小时），从而导致此时间块与 freeWindows（本地时间）对不上。
    DateTime? parseAsLocal(String? s) {
      if (s == null) return null;
      final d = DateTime.tryParse(s);
      if (d == null) return null;
      return DateTime(d.year, d.month, d.day, d.hour, d.minute, d.second, d.millisecond, d.microsecond);
    }

    for (final item in blocks) {
      if (item is! Map) continue;
      final taskId = item['taskId']?.toString();
      final title = item['title']?.toString();
      final startStr = item['start']?.toString();
      final endStr = item['end']?.toString();
      if (taskId == null || title == null || startStr == null || endStr == null) continue;
      if (!allowedIds.contains(taskId)) continue;
      final start = parseAsLocal(startStr);
      final end = parseAsLocal(endStr);
      if (start == null || end == null) continue;
      if (!end.isAfter(start)) continue;

      if (start.isBefore(rangeStart) || end.isAfter(rangeEnd)) {
        debugPrint('[DayWeekAiScheduler] drop block(taskId=$taskId) out of range start=$start end=$end');
        continue;
      }

      if (start.year != end.year || start.month != end.month || start.day != end.day) {
        debugPrint('[DayWeekAiScheduler] drop block(taskId=$taskId) crosses day start=$start end=$end');
        continue;
      }

      final baseRanges = _rangesForDate(
        date: start,
        weekday: availability.weekday,
        weekend: availability.weekend,
        workdays: availability.workdays,
      );
      if (!_blockWithinAnyRange(start: start, end: end, ranges: baseRanges)) {
        debugPrint('[DayWeekAiScheduler] drop block(taskId=$taskId) out of availabilityRanges start=$start end=$end');
        continue;
      }

      final dayKey = _dateOnlyKey(start);
      final dayFree = freeWindowsByDayKey[dayKey] ?? const <({DateTime start, DateTime end})>[];
      if (!_blockWithinAnyWindow(start: start, end: end, windows: dayFree)) {
        debugPrint('[DayWeekAiScheduler] drop block(taskId=$taskId) out of freeWindows start=$start end=$end');
        continue;
      }

      bool overlapNew = false;
      for (final u in usedIntervals) {
        if (start.isBefore(u.end) && end.isAfter(u.start)) {
          overlapNew = true;
          break;
        }
      }
      if (overlapNew) {
        debugPrint('[DayWeekAiScheduler] drop block(taskId=$taskId) overlaps another new block start=$start end=$end');
        continue;
      }

      final blockMinutes = end.difference(start).inMinutes;
      if (blockMinutes < 15) {
        debugPrint('[DayWeekAiScheduler] drop block(taskId=$taskId) too short minutes=$blockMinutes start=$start end=$end');
        continue;
      }
      final currentBlocks = blocksCountByTaskId[taskId] ?? 0;
      if (currentBlocks >= maxBlocksPerTask) {
        debugPrint('[DayWeekAiScheduler] drop block(taskId=$taskId) exceeds maxBlocksPerTask=$maxBlocksPerTask');
        continue;
      }

      final est = estMinutesByTaskId[taskId];
      if (est != null) {
        final already = allocatedMinutesByTaskId[taskId] ?? 0;
        if (already >= est) {
          debugPrint('[DayWeekAiScheduler] drop block(taskId=$taskId) already meets estimatedMinutes=$est');
          continue;
        }
        if (already + blockMinutes > est + 15) {
          debugPrint('[DayWeekAiScheduler] drop block(taskId=$taskId) would exceed estimatedMinutes=$est');
          continue;
        }
      }

      if (_overlapsBusy(start: start, end: end, busyEvents: busyEvents)) {
        debugPrint('[DayWeekAiScheduler] drop block(taskId=$taskId) overlaps busy start=$start end=$end');
        continue;
      }

      // 最后再做一次冲突过滤（防 AI 输出冲突）
      bool conflict = false;
      for (final b in busyEvents) {
        if (b.allDay) continue;
        if (start.isBefore(b.end) && end.isAfter(b.start)) {
          conflict = true;
          break;
        }
      }
      if (conflict) {
        debugPrint('[DayWeekAiScheduler] drop block(taskId=$taskId) conflicts start=$start end=$end');
        continue;
      }

      allocatedMinutesByTaskId[taskId] = (allocatedMinutesByTaskId[taskId] ?? 0) + blockMinutes;
      blocksCountByTaskId[taskId] = currentBlocks + 1;
      usedIntervals.add((start: start, end: end));

      result.add(_TimeBlockPlan(
        taskId: taskId,
        title: title,
        start: start,
        end: end,
      ));
    }

    return result;
  }

  static String _extractJsonObject(String s) {
    var text = s.trim();
    if (text.startsWith('```')) {
      final firstNewline = text.indexOf('\n');
      if (firstNewline != -1) {
        text = text.substring(firstNewline + 1);
      }
      final fenceEnd = text.lastIndexOf('```');
      if (fenceEnd != -1) {
        text = text.substring(0, fenceEnd);
      }
      text = text.trim();
    }

    final objStart = text.indexOf('{');
    final objEnd = text.lastIndexOf('}');
    if (objStart != -1 && objEnd != -1 && objEnd > objStart) {
      return text.substring(objStart, objEnd + 1);
    }

    throw Exception('AI 未返回 JSON');
  }

  static VoidCallback _showBlockingLoading(BuildContext context, String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
    return () {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    };
  }
}

class _TimeBlockPlan {
  final String taskId;
  final String title;
  final DateTime start;
  final DateTime end;

  const _TimeBlockPlan({
    required this.taskId,
    required this.title,
    required this.start,
    required this.end,
  });

  String get description => 'AI安排: $taskId';
}

class _TimeRange {
  final int startMinutes;
  final int endMinutes;

  const _TimeRange({
    required this.startMinutes,
    required this.endMinutes,
  });

  bool get isValid => startMinutes >= 0 && endMinutes <= 24 * 60 && endMinutes > startMinutes;

  String formatStart() => _formatMinutes(startMinutes);

  String formatEnd() => _formatMinutes(endMinutes);

  static String _formatMinutes(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }
}
