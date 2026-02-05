import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/date_utils.dart';
import '../../../data/models/openai/openai_models.dart';
import '../../../data/repositories/ai_config_repository.dart';
import '../../../services/ai_service.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/daily_plan_provider.dart';
import '../../../data/models/calendar_event_hive.dart';
import '../../providers/task_list_provider.dart';
import 'models.dart';

class DayWeekAiScheduler {
  // 移除未使用的导入
  // import '../../../services/calendar_database_service.dart';

  static const String _eventMetaPrefsPrefix = 'event_meta_v1_';
  static const String _eventMetaAiKey = 'ai';
  static const String _eventMetaOriginDateKey = 'originDateKey';
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

  static ({DateTime rangeStart, DateTime rangeEnd}) computeWeekRange({
    required DateTime now,
    required DateTime centerDate,
    required bool startFromNowIfToday,
  }) {
    final today = _dayStart(DateTime(now.year, now.month, now.day));
    final centerDay = _dayStart(centerDate);

    final weekStartMon = _dayStart(centerDay.subtract(Duration(days: centerDay.weekday - 1)));
    final weekEndSun = _dayEnd(weekStartMon.add(const Duration(days: 6)));

    final startDay = weekStartMon.isAfter(today) ? weekStartMon : today;
    final start = startDay == today && startFromNowIfToday ? now : startDay;

    return (rangeStart: start, rangeEnd: weekEndSun);
  }

  static String _dateOnlyKey(DateTime d) {
    final dd = DateTime(d.year, d.month, d.day);
    final mm = dd.month.toString().padLeft(2, '0');
    final day = dd.day.toString().padLeft(2, '0');
    return '${dd.year}-$mm-$day';
  }

  static DateTime? _tryParseDateOnlyKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
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

  static Future<void> _saveReasoning({
    required String scopeLabel, // 'day', 'week'
    required String reasoning,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'ai_reasoning_latest_$scopeLabel'; // 固定 Key
    final data = {
      'timestamp': DateTime.now().toIso8601String(),
      'reasoning': reasoning,
    };
    await prefs.setString(key, jsonEncode(data));
  }

  static Future<String?> getReasoning({
    required String scopeLabel,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'ai_reasoning_latest_$scopeLabel';
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    
    try {
      final data = jsonDecode(raw);
      if (data is Map) {
        final tsStr = data['timestamp']?.toString();
        final content = data['reasoning']?.toString();
        if (content == null) return null;
        
        String timeDisplay = '';
        if (tsStr != null) {
          final ts = DateTime.tryParse(tsStr);
          if (ts != null) {
            final local = ts.toLocal();
            timeDisplay = '[生成于 ${local.month}月${local.day}日 ${local.hour.toString().padLeft(2,'0')}:${local.minute.toString().padLeft(2,'0')}]\n';
          }
        }
        return '$timeDisplay$content';
      }
    } catch (_) {}
    return null;
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
    final r = computeWeekRange(now: now, centerDate: centerDate, startFromNowIfToday: true);
    final start = r.rangeStart;
    final weekEndSun = r.rangeEnd;

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
    final r = computeWeekRange(now: now, centerDate: centerDate, startFromNowIfToday: false);
    final start = r.rangeStart;
    final weekEndSun = r.rangeEnd;

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
    final dailyPlanProvider = context.read<DailyPlanProvider>(); // Add DailyPlanProvider
    final busyEvents = scheduleProvider.getEventsInRange(rangeStart, rangeEnd)
        .where((e) => !e.allDay)
        .toList(growable: false);
    final plansInRange = await dailyPlanProvider.getPlansForRange(rangeStart, rangeEnd);
    final todoOwnerDateKeyByTaskId = <String, String>{};
    for (final plan in plansInRange.values) {
      final dateKey = plan.dateKey;
      for (final taskId in plan.todoTaskIds) {
        todoOwnerDateKeyByTaskId.putIfAbsent(taskId, () => dateKey);
      }
    }

    final closeLoading = _showBlockingLoading(context, 'AI 正在生成时间安排…');
    final scopeKey = scopeLabel == '当天' ? 'day' : 'week';
    try {
      debugPrint('[DayWeekAiScheduler] smartSchedule start scope=$scopeLabel rangeStart=$rangeStart rangeEnd=$rangeEnd');
      final plan = await _callTimeBlockSchedulingAI(
        aiService: aiService,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        busyEvents: busyEvents,
        candidates: sourceTasks,
      ).timeout(const Duration(seconds: 90));

      debugPrint('[DayWeekAiScheduler] smartSchedule plan size=${plan.blocks.length}');

      await _saveReasoning(scopeLabel: scopeKey, reasoning: plan.reasoning);

      final prefs = await SharedPreferences.getInstance();

      int created = 0;
      final removedFromTodoTaskIds = <String>{};
      for (int i = 0; i < plan.blocks.length; i++) {
        final block = plan.blocks[i];
        debugPrint(
          '[DayWeekAiScheduler] createEvent[$i/${plan.blocks.length}] taskId=${block.taskId} start=${block.start.toIso8601String()} end=${block.end.toIso8601String()}',
        );
        final originDateKey = todoOwnerDateKeyByTaskId[block.taskId];
        final originDate = originDateKey == null ? null : _tryParseDateOnlyKey(originDateKey);
        
        // 创建 CalendarEventHive 对象（嵌入式）
        final event = CalendarEventHive(
          id: DateTime.now().millisecondsSinceEpoch.toString() + i.toString(), // 临时生成 ID
          title: block.title,
          allDay: false,
          description: block.description,
          colorValue: Colors.blue.value,
          start: block.start,
          end: block.end,
          isCompleted: false,
        );
        
        // 同步更新 DailyPlan：添加嵌入式时间块
        await dailyPlanProvider.addScheduledEvent(block.start, event);

        // 关键修复：任务被安排到时间块后，从今日待办中移除
        debugPrint('[DayWeekAiScheduler] removing todo task: date=${block.start} taskId=${block.taskId}');
        if (removedFromTodoTaskIds.add(block.taskId)) {
          await dailyPlanProvider.removeTodoTask(originDate ?? block.start, block.taskId);
        }
        
        await _writeEventMetaAi(prefs: prefs, eventId: event.id, originDateKey: originDateKey).timeout(const Duration(seconds: 5));
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
      final errText = e.toString();
      if (errText.contains('输出解析失败') || errText.contains('JSON')) {
        await _saveReasoning(scopeLabel: scopeKey, reasoning: 'AI 输出解析失败：$errText');
      }
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
      final cleared = await _clearAiEventsInRange(context, rangeStart: rangeStart, rangeEnd: rangeEnd) // Pass context
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

  static Future<int> _clearAiEventsInRange(
    BuildContext context, { // Add context
    required DateTime rangeStart, 
    required DateTime rangeEnd,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    // 假设 DailyPlanProvider 可用（如果是在 UI 流程中调用）
    // 但这个静态方法可能无法直接访问 Provider，除非传入 Context
    // 为了安全，我们修改签名要求 Context
    DailyPlanProvider? dailyPlanProvider;
    try {
      dailyPlanProvider = context.read<DailyPlanProvider>();
    } catch (_) {
      // ignore
    }
    
    if (dailyPlanProvider == null) return 0;

    // 从 DailyPlan 获取范围内的所有计划，然后筛选出 AI 事件
    final plans = await dailyPlanProvider.getPlansForRange(rangeStart, rangeEnd);
    int cleared = 0;
    
    for (final plan in plans.values) {
        final events = List<CalendarEventHive>.from(plan.scheduledEvents); // 复制一份列表以避免并发修改
        for (final e in events) {
            final meta = _readEventMeta(prefs: prefs, eventId: e.id);
            if (!meta.ai) continue;
            
            // 检查是否在请求的时间范围内 (虽然 getPlansForRange 已经筛选了日期，但 DailyPlan 是按天聚合的)
            if (e.start.isBefore(rangeStart) || e.end.isAfter(rangeEnd)) continue;

            debugPrint(
                '[DayWeekAiScheduler] deleteAiEvent eventId=${e.id} start=${e.start.toIso8601String()} end=${e.end.toIso8601String()}',
            );
            
            // 同步清理 DailyPlan (embedded)
            // 注意：DailyPlanProvider.removeScheduledEvent 需要传入日期
            // 这里我们用 e.start 作为 key
            await dailyPlanProvider.removeScheduledEvent(e.start, e.id);
            
            await _clearEventMetaAi(prefs: prefs, eventId: e.id).timeout(const Duration(seconds: 5));

            final taskId = _tryExtractTaskIdFromDescription(e.description);
            if (taskId != null && taskId.isNotEmpty) {
                await _unmarkTaskScheduledForDate(prefs: prefs, date: e.start, taskId: taskId).timeout(const Duration(seconds: 5));
                
                final restoreDate = meta.originDateKey == null
                    ? _dayStart(e.start)
                    : (_tryParseDateOnlyKey(meta.originDateKey!) ?? _dayStart(e.start));
                await dailyPlanProvider.addTodoTask(restoreDate, taskId);
            }
            cleared++;
            await Future<void>.delayed(Duration.zero);
        }
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

  static Future<void> _writeEventMetaAi({
    required SharedPreferences prefs,
    required String eventId,
    String? originDateKey,
  }) async {
    final key = '$_eventMetaPrefsPrefix$eventId';
    final data = <String, dynamic>{_eventMetaAiKey: true};
    if (originDateKey != null && originDateKey.trim().isNotEmpty) {
      data[_eventMetaOriginDateKey] = originDateKey;
    }
    await prefs.setString(key, jsonEncode(data));
  }

  static ({bool ai, String? originDateKey}) _readEventMeta({
    required SharedPreferences prefs,
    required String eventId,
  }) {
    final raw = prefs.getString('$_eventMetaPrefsPrefix$eventId');
    if (raw == null || raw.trim().isEmpty) return (ai: false, originDateKey: null);
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return (ai: false, originDateKey: null);
      final ai = decoded[_eventMetaAiKey] == true;
      final origin = decoded[_eventMetaOriginDateKey]?.toString();
      return (ai: ai, originDateKey: origin);
    } catch (_) {
      return (ai: false, originDateKey: null);
    }
  }

  @visibleForTesting
  static DateTime? tryParseDateOnlyKeyForTest(String key) => _tryParseDateOnlyKey(key);

  @visibleForTesting
  static Future<void> writeEventMetaAiForTest({
    required SharedPreferences prefs,
    required String eventId,
    String? originDateKey,
  }) =>
      _writeEventMetaAi(prefs: prefs, eventId: eventId, originDateKey: originDateKey);

  @visibleForTesting
  static ({bool ai, String? originDateKey}) readEventMetaForTest({
    required SharedPreferences prefs,
    required String eventId,
  }) =>
      _readEventMeta(prefs: prefs, eventId: eventId);

  @visibleForTesting
  static ({List<Map<String, dynamic>> violations, List<Map<String, dynamic>> normalizedBlocks}) validateAiBlocksForTest({
    required List<dynamic> raw,
    required Set<String> allowedIds,
    required DateTime effectiveStart,
    required DateTime effectiveEnd,
    required Map<String, List<({DateTime start, DateTime end})>> freeWindows,
    required Map<String, List<Map<String, int>>> availabilityRanges,
    required List<CalendarEvent> busy,
  }) {
    String formatTime(DateTime d) {
      final Y = d.year;
      final M = d.month.toString().padLeft(2, '0');
      final D = d.day.toString().padLeft(2, '0');
      final h = d.hour.toString().padLeft(2, '0');
      final m = d.minute.toString().padLeft(2, '0');
      return '$Y-$M-$D $h:$m';
    }

    DateTime? parseAsLocal(String? s) {
      if (s == null) return null;
      final d = DateTime.tryParse(s);
      if (d == null) return null;
      return DateTime(d.year, d.month, d.day, d.hour, d.minute, d.second, d.millisecond, d.microsecond);
    }

    bool withinAnyAvailabilityRange({
      required DateTime start,
      required DateTime end,
      required List<Map<String, int>> ranges,
    }) {
      final startM = start.hour * 60 + start.minute;
      final endM = end.hour * 60 + end.minute;
      for (final r in ranges) {
        final s = r['startMinutes'];
        final e = r['endMinutes'];
        if (s == null || e == null) continue;
        if (startM >= s && endM <= e) return true;
      }
      return false;
    }

    final violations = <Map<String, dynamic>>[];
    final normalized = <Map<String, dynamic>>[];

    for (final item in raw) {
      if (item is! Map) {
        violations.add({'reason': 'invalid_item', 'raw': item.toString()});
        continue;
      }
      final taskId = item['taskId']?.toString().trim();
      final title = item['title']?.toString();
      final startStr = item['start']?.toString();
      final endStr = item['end']?.toString();
      if (taskId == null || taskId.isEmpty || title == null || startStr == null || endStr == null) {
        violations.add({'reason': 'missing_fields', 'taskId': taskId, 'title': title, 'start': startStr, 'end': endStr});
        continue;
      }
      if (!allowedIds.contains(taskId)) {
        violations.add({'reason': 'unknown_task_id', 'taskId': taskId, 'start': startStr, 'end': endStr});
        continue;
      }

      final start = parseAsLocal(startStr);
      final end = parseAsLocal(endStr);
      if (start == null || end == null) {
        violations.add({'reason': 'invalid_datetime', 'taskId': taskId, 'start': startStr, 'end': endStr});
        continue;
      }
      if (!end.isAfter(start)) {
        violations.add({'reason': 'non_positive_duration', 'taskId': taskId, 'start': startStr, 'end': endStr});
        continue;
      }
      if (start.year != end.year || start.month != end.month || start.day != end.day) {
        violations.add({'reason': 'cross_day', 'taskId': taskId, 'start': startStr, 'end': endStr});
        continue;
      }
      if (start.isBefore(effectiveStart) || end.isAfter(effectiveEnd)) {
        violations.add({
          'reason': 'out_of_range',
          'taskId': taskId,
          'start': startStr,
          'end': endStr,
          'rangeStart': formatTime(effectiveStart),
          'rangeEnd': formatTime(effectiveEnd),
        });
        continue;
      }

      final dayKey = _dateOnlyKey(start);
      final ranges = availabilityRanges[dayKey] ?? const <Map<String, int>>[];
      if (ranges.isEmpty || !withinAnyAvailabilityRange(start: start, end: end, ranges: ranges)) {
        violations.add({'reason': 'out_of_availability', 'taskId': taskId, 'start': startStr, 'end': endStr, 'date': dayKey});
        continue;
      }

      final dayFree = freeWindows[dayKey] ?? const <({DateTime start, DateTime end})>[];
      if (!_blockWithinAnyWindow(start: start, end: end, windows: dayFree)) {
        violations.add({'reason': 'out_of_free_windows', 'taskId': taskId, 'start': startStr, 'end': endStr, 'date': dayKey});
        continue;
      }

      final blockMinutes = end.difference(start).inMinutes;
      if (blockMinutes < 15) {
        violations.add({'reason': 'too_short', 'taskId': taskId, 'start': startStr, 'end': endStr, 'minutes': blockMinutes});
        continue;
      }
      if (start.minute % 15 != 0 || end.minute % 15 != 0 || blockMinutes % 15 != 0) {
        violations.add({'reason': 'not_15min_granularity', 'taskId': taskId, 'start': startStr, 'end': endStr});
        continue;
      }

      if (_overlapsBusy(start: start, end: end, busyEvents: busy)) {
        violations.add({'reason': 'overlaps_busy', 'taskId': taskId, 'start': startStr, 'end': endStr});
        continue;
      }

      normalized.add({'taskId': taskId, 'title': title, 'start': start, 'end': end});
    }

    if (violations.isNotEmpty) {
      return (violations: violations, normalizedBlocks: normalized);
    }

    final sorted = [...normalized]..sort((a, b) => (a['start'] as DateTime).compareTo(b['start'] as DateTime));
    for (int i = 0; i < sorted.length - 1; i++) {
      final a = sorted[i];
      final b = sorted[i + 1];
      final aStart = a['start'] as DateTime;
      final aEnd = a['end'] as DateTime;
      final bStart = b['start'] as DateTime;
      final bEnd = b['end'] as DateTime;
      if (bStart.isBefore(aEnd) && bEnd.isAfter(aStart)) {
        violations.add({
          'reason': 'overlaps_another_block',
          'a': {
            'taskId': a['taskId'],
            'start': formatTime(aStart),
            'end': formatTime(aEnd),
          },
          'b': {
            'taskId': b['taskId'],
            'start': formatTime(bStart),
            'end': formatTime(bEnd),
          },
        });
        break;
      }
    }

    return (violations: violations, normalizedBlocks: sorted);
  }

  static Future<void> _clearEventMetaAi({required SharedPreferences prefs, required String eventId}) async {
    await prefs.remove('$_eventMetaPrefsPrefix$eventId');
  }

  static Future<({String reasoning, List<_TimeBlockPlan> blocks})> _callTimeBlockSchedulingAI({
    required AIService aiService,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required List<CalendarEvent> busyEvents,
    required List<dynamic> candidates,
  }) async {
    final normalizedRangeStart = DateUtilsEx.floorToMinute(rangeStart);
    final normalizedRangeEnd = DateUtilsEx.floorToMinute(rangeEnd);

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

    for (DateTime day = _dayStart(normalizedRangeStart); !day.isAfter(_dayStart(normalizedRangeEnd)); day = day.add(const Duration(days: 1))) {
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
        final start = DateUtilsEx.floorToMinute(b.start);
        final end = DateUtilsEx.ceilToMinute(b.end);
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
        if (ws.isBefore(normalizedRangeStart)) ws = normalizedRangeStart;
        if (we.isAfter(normalizedRangeEnd)) we = normalizedRangeEnd;
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

    // Calculate effective range limits from freeWindows to prevent AI from hallucinating blocks outside availability
    DateTime effectiveRangeStart = normalizedRangeStart;
    DateTime effectiveRangeEnd = normalizedRangeEnd;
    
    DateTime? minFreeStart;
    DateTime? maxFreeEnd;

    for (final windows in freeWindowsByDayKey.values) {
      for (final w in windows) {
        if (minFreeStart == null || w.start.isBefore(minFreeStart)) minFreeStart = w.start;
        if (maxFreeEnd == null || w.end.isAfter(maxFreeEnd)) maxFreeEnd = w.end;
      }
    }
    
    // Only tighten the range
    if (minFreeStart != null && minFreeStart.isAfter(effectiveRangeStart)) {
      effectiveRangeStart = minFreeStart;
    }
    if (maxFreeEnd != null && maxFreeEnd.isBefore(effectiveRangeEnd)) {
      effectiveRangeEnd = maxFreeEnd;
    }

    final daysWithFree = freeWindowsByDayKey.entries.where((e) => e.value.isNotEmpty).length;
    final daysTotal = freeWindowsByDayKey.length;
    debugPrint(
      '[DayWeekAiScheduler] freeWindows summary daysWithFree=$daysWithFree/$daysTotal effectiveRangeStart=$effectiveRangeStart effectiveRangeEnd=$effectiveRangeEnd',
    );

    final systemPrompt =
        '你是一个严格的“日历时间块排期引擎（Time-Block Scheduling Engine）”。\n'
        '你要把任务安排到具体的时间段中，并生成日程块。\n'
        '你的目标是：在不违反规则的前提下，最大化利用 freeWindows（空闲时间），实现紧凑安排。\n'
        '不要预留缓冲空隙（除非无任务可排），尽可能填满所有空闲时间。\n'
        '\n'
        '## 核心策略（Core Strategy）\n'
        '1. **深度工作（Deep Work）优先**：\n'
        '   - 尽可能保持任务的连续性。如果一个任务需要 3 小时，请尽量安排一个连续的 3 小时块（或两个 1.5 小时块），而不是切分成多个碎片。\n'
        '   - **严禁**为了“穿插”而人为打断正在进行的任务。同一任务的时间块应紧邻排列。\n'
        '2. **时间块时长**：\n'
        '   - 优先分配 **60分钟** 或 **90分钟** 的长整块。\n'
        '   - 仅当任务剩余预估时间不足 60 分钟，或空闲时间窗口很小时，才分配 30 分钟或 15 分钟的短块。\n'
        '3. **要事优先**：严格遵守任务优先级。高优先级任务必须优先安排在最早、最长的空闲时段。\n'
        '4. **紧凑排列**：End(Block N) 应等于 Start(Block N+1)，中间不留空隙。\n'
        '5. **全范围覆盖**：必须充分利用 range.start 到 range.end 之间的所有可用时间。如果任务足够多，请确保最后一天（如周日）也被安排，不要因为是最后一天就忽略。\n'
        '\n'
        '格式要求：\n'
        '- 所有时间字段请使用 "YYYY-MM-DD HH:mm" 格式（例如 "2026-01-24 09:00"）。\n'
        '- 不要包含秒或毫秒。\n'
        '\n'
        '## 关键规则（必须遵守）\n'
        '1) 你不能创建新的任务，只能从 taskPool 中选择 taskId。\n'
        '2) 你必须避开 busyEvents 中的忙碌时间段，不能产生冲突。\n'
        '3) 所有输出的 start/end 必须落在 freeWindows 提供的空闲时间段内。\n'
        '   并且必须满足：start >= range.start 且 end <= range.end（按分钟比较，包含边界）。\n'
        '4) 你不能安排跨天时间块（start 与 end 必须在同一天）。\n'
        '5) 你输出的所有时间块之间必须两两不重叠（包含不同任务之间也不能重叠）。\n'
        '   若多个任务竞争同一时间段，保留更高优先级/更靠前任务，并把其他任务顺延到后续空闲时间。\n'
        '5) 每个时间块必须 end > start，且以 15 分钟为粒度；并且每个时间块的时长必须 >= 15 分钟。\n'
        '6) taskPool 中的 estimatedMinutes 仅为参考信息，不是硬性上限；允许同一任务在不同日期重复安排。\n'
        '6) 你必须只输出纯 JSON，不允许输出解释/Markdown/代码块。\n'
        '7) blocks 必须按 start 升序输出。\n'
        '\n'
        '## 输出 JSON Schema（必须严格匹配）\n'
        '{\n'
        '  "reasoning": "<在此处简要说明你的安排逻辑。要求：1. 必须使用通俗易懂的语言（如“优先安排了高优先级任务”、“利用了周末的空闲时间”），严禁使用“freeWindows”、“taskPool”等技术术语；2. 语言要简洁明了，让用户一眼就能看懂；3. 解释为什么这样安排，以及是否有任务因为时间不足而被推迟。>",\n'
        '  "schedule": {\n'
        '    "blocks": [\n'
        '      {\n'
        '        "taskId": "<string>",\n'
        '        "title": "<string>",\n'
        '        "start": "YYYY-MM-DD HH:mm",\n'
        '        "end": "YYYY-MM-DD HH:mm"\n'
        '      }\n'
        '    ]\n'
        '  }\n'
        '}';

    String formatTime(DateTime d) {
      final Y = d.year;
      final M = d.month.toString().padLeft(2, '0');
      final D = d.day.toString().padLeft(2, '0');
      final h = d.hour.toString().padLeft(2, '0');
      final m = d.minute.toString().padLeft(2, '0');
      return '$Y-$M-$D $h:$m';
    }

    final userPrompt = jsonEncode({
      'instruction': {
        'goal': '在 freeWindows 内生成紧凑的时间安排。优先完成高优先级任务；最大化时间利用率；尽可能填满所有空闲时间，不要主动留空。',
        'range': {
          'start': formatTime(effectiveRangeStart),
          'end': formatTime(effectiveRangeEnd),
        },
        'time_granularity_minutes': 15,
        'planning_strategy': {
          'maximize_total_scheduled_minutes': true,
          'allow_multiple_blocks_per_task': true,
          'allow_overlaps': false,
          'prefer_tight_scheduling': true,
          'minimize_gaps': true,
          'minimize_fragmentation': true,
          'prefer_longer_blocks': true,
          'balance_strategy': 'priority_based',
          'notes': '任务已按优先级和截止日期排序。请优先安排列表靠前的任务。请尽可能为每个任务分配连续的长整块时间，减少任务切换。'
        }
      },
      'busyEvents': busy.map((e) => {
        ...e,
        'start': formatTime(DateTime.parse(e['start'] as String)),
        'end': formatTime(DateTime.parse(e['end'] as String)),
      }).toList(),
      'freeWindows': freeWindowsForAi.map((day) => {
        'date': day['date'],
        'free': (day['free'] as List).map((w) => {
          'start': formatTime(DateTime.parse(w['start'] as String)),
          'end': formatTime(DateTime.parse(w['end'] as String)),
        }).toList(),
      }).toList(),
      'taskPool': taskItems.map((t) {
        final newItem = Map<String, dynamic>.from(t);
        if (newItem['remindAt'] != null) {
          newItem['remindAt'] = formatTime(DateTime.parse(newItem['remindAt'] as String));
        }
        return newItem;
      }).toList(),
      'output_schema': {
        'reasoning': '<string>',
        'schedule': {
          'blocks': [
            {'taskId': '<string>', 'title': '<string>', 'start': 'YYYY-MM-DD HH:mm', 'end': 'YYYY-MM-DD HH:mm'}
          ]
        }
      }
    });

    _logLong('DayWeekAiScheduler', 'Request userPrompt=$userPrompt');

    int maxJsonParseRetries = 3;
    try {
      maxJsonParseRetries = AIConfigRepository().getConfig()?.maxJsonParseRetries ?? 3;
    } catch (_) {
      maxJsonParseRetries = 3;
    }

    String clip(String s, int maxChars) {
      if (s.length <= maxChars) return s;
      return s.substring(0, maxChars);
    }

    String buildRetryNote({required int attempt, required String error, required String lastRawOutput}) {
      return jsonEncode({
        'instruction': {
          'goal': '上一次输出解析失败，请根据原始输入重新输出符合要求的纯 JSON。',
          'attempt': attempt,
          'previous_error': error,
          'must_follow': [
            '只输出纯 JSON（不要 Markdown/代码块/解释）',
            '严格匹配 output_schema',
            'blocks 必须按 start 升序输出',
          ],
        },
        'previous_output': clip(lastRawOutput, 1200),
      });
    }

    Exception? lastError;
    String lastRawText = '';
    List<dynamic>? blocksRaw;
    String reasoning = '';
    List<Map<String, dynamic>> lastViolations = const [];
    bool lastWasValidationError = false;
    List<_TimeBlockPlan>? parsedBlocks;
    String parsedReasoning = '';

    Map<String, List<Map<String, int>>> buildAvailabilityByDayKey() {
      final out = <String, List<Map<String, int>>>{};
      for (final entry in freeWindowsByDayKey.entries) {
        final day = _tryParseDateOnlyKey(entry.key);
        if (day == null) continue;
        final ranges = _rangesForDate(
          date: day,
          weekday: availability.weekday,
          weekend: availability.weekend,
          workdays: availability.workdays,
        );
        out[entry.key] = ranges
            .map((r) => {
                  'startMinutes': r.startMinutes,
                  'endMinutes': r.endMinutes,
                })
            .toList(growable: false);
      }
      return out;
    }

    final availabilityByDayKey = buildAvailabilityByDayKey();
    final allowedIds = taskItems.map((e) => e['id'].toString()).toSet();

    ({List<Map<String, dynamic>> violations, List<Map<String, dynamic>> normalizedBlocks}) validateAiBlocks({
      required List<dynamic> raw,
      required Set<String> allowedIds,
      required DateTime effectiveStart,
      required DateTime effectiveEnd,
      required Map<String, List<({DateTime start, DateTime end})>> freeWindows,
      required Map<String, List<Map<String, int>>> availabilityRanges,
      required List<CalendarEvent> busy,
    }) {
      DateTime? parseAsLocal(String? s) {
        if (s == null) return null;
        final d = DateTime.tryParse(s);
        if (d == null) return null;
        return DateTime(d.year, d.month, d.day, d.hour, d.minute, d.second, d.millisecond, d.microsecond);
      }

      bool withinAnyAvailabilityRange({
        required DateTime start,
        required DateTime end,
        required List<Map<String, int>> ranges,
      }) {
        final startM = start.hour * 60 + start.minute;
        final endM = end.hour * 60 + end.minute;
        for (final r in ranges) {
          final s = r['startMinutes'];
          final e = r['endMinutes'];
          if (s == null || e == null) continue;
          if (startM >= s && endM <= e) return true;
        }
        return false;
      }

      final violations = <Map<String, dynamic>>[];
      final normalized = <Map<String, dynamic>>[];

      for (final item in raw) {
        if (item is! Map) {
          violations.add({'reason': 'invalid_item', 'raw': item.toString()});
          continue;
        }
        final taskId = item['taskId']?.toString().trim();
        final title = item['title']?.toString();
        final startStr = item['start']?.toString();
        final endStr = item['end']?.toString();
        if (taskId == null || taskId.isEmpty || title == null || startStr == null || endStr == null) {
          violations.add({'reason': 'missing_fields', 'taskId': taskId, 'title': title, 'start': startStr, 'end': endStr});
          continue;
        }
        if (!allowedIds.contains(taskId)) {
          violations.add({'reason': 'unknown_task_id', 'taskId': taskId, 'start': startStr, 'end': endStr});
          continue;
        }

        final start = parseAsLocal(startStr);
        final end = parseAsLocal(endStr);
        if (start == null || end == null) {
          violations.add({'reason': 'invalid_datetime', 'taskId': taskId, 'start': startStr, 'end': endStr});
          continue;
        }
        if (!end.isAfter(start)) {
          violations.add({'reason': 'non_positive_duration', 'taskId': taskId, 'start': startStr, 'end': endStr});
          continue;
        }
        if (start.year != end.year || start.month != end.month || start.day != end.day) {
          violations.add({'reason': 'cross_day', 'taskId': taskId, 'start': startStr, 'end': endStr});
          continue;
        }
        if (start.isBefore(effectiveStart) || end.isAfter(effectiveEnd)) {
          violations.add({
            'reason': 'out_of_range',
            'taskId': taskId,
            'start': startStr,
            'end': endStr,
            'rangeStart': formatTime(effectiveStart),
            'rangeEnd': formatTime(effectiveEnd),
          });
          continue;
        }

        final dayKey = _dateOnlyKey(start);
        final ranges = availabilityRanges[dayKey] ?? const <Map<String, int>>[];
        if (ranges.isEmpty || !withinAnyAvailabilityRange(start: start, end: end, ranges: ranges)) {
          violations.add({'reason': 'out_of_availability', 'taskId': taskId, 'start': startStr, 'end': endStr, 'date': dayKey});
          continue;
        }

        final dayFree = freeWindows[dayKey] ?? const <({DateTime start, DateTime end})>[];
        if (!_blockWithinAnyWindow(start: start, end: end, windows: dayFree)) {
          violations.add({'reason': 'out_of_free_windows', 'taskId': taskId, 'start': startStr, 'end': endStr, 'date': dayKey});
          continue;
        }

        final blockMinutes = end.difference(start).inMinutes;
        if (blockMinutes < 15) {
          violations.add({'reason': 'too_short', 'taskId': taskId, 'start': startStr, 'end': endStr, 'minutes': blockMinutes});
          continue;
        }
        if (start.minute % 15 != 0 || end.minute % 15 != 0 || blockMinutes % 15 != 0) {
          violations.add({'reason': 'not_15min_granularity', 'taskId': taskId, 'start': startStr, 'end': endStr});
          continue;
        }

        if (_overlapsBusy(start: start, end: end, busyEvents: busy)) {
          violations.add({'reason': 'overlaps_busy', 'taskId': taskId, 'start': startStr, 'end': endStr});
          continue;
        }

        normalized.add({'taskId': taskId, 'title': title, 'start': start, 'end': end});
      }

      if (violations.isNotEmpty) {
        return (violations: violations, normalizedBlocks: normalized);
      }

      final sorted = [...normalized]..sort((a, b) => (a['start'] as DateTime).compareTo(b['start'] as DateTime));
      for (int i = 0; i < sorted.length - 1; i++) {
        final a = sorted[i];
        final b = sorted[i + 1];
        final aStart = a['start'] as DateTime;
        final aEnd = a['end'] as DateTime;
        final bStart = b['start'] as DateTime;
        final bEnd = b['end'] as DateTime;
        if (bStart.isBefore(aEnd) && bEnd.isAfter(aStart)) {
          violations.add({
            'reason': 'overlaps_another_block',
            'a': {
              'taskId': a['taskId'],
              'start': formatTime(aStart),
              'end': formatTime(aEnd),
            },
            'b': {
              'taskId': b['taskId'],
              'start': formatTime(bStart),
              'end': formatTime(bEnd),
            },
          });
          break;
        }
      }

      return (violations: violations, normalizedBlocks: sorted);
    }

    for (int attempt = 1; attempt <= maxJsonParseRetries; attempt++) {
      _logLong('DayWeekAiScheduler', 'AI request attempt=$attempt max=$maxJsonParseRetries');
      final messages = <OpenAIChatMessage>[
        if (attempt > 1 && lastWasValidationError)
          OpenAIChatMessage.text(
            role: OpenAIMessageRole.user,
            content: jsonEncode({
              'instruction': {
                'goal': '上一次输出的时间块不满足规则，请修复违规项并重新输出完整的纯 JSON。',
                'attempt': attempt,
                'must_follow': [
                  '只输出纯 JSON（不要 Markdown/代码块/解释）',
                  '严格匹配 output_schema',
                  '所有 start/end 必须落在 freeWindows 内',
                  '不得跨天，不得重叠',
                  '时间粒度为 15 分钟，且单块时长 >= 15 分钟',
                  'blocks 必须按 start 升序输出',
                ],
                'violations': lastViolations.take(20).toList(growable: false),
              },
              'previous_output': clip(lastRawText, 1200),
            }),
          ),
        if (attempt > 1 && !lastWasValidationError)
          OpenAIChatMessage.text(
            role: OpenAIMessageRole.user,
            content: buildRetryNote(attempt: attempt, error: lastError.toString(), lastRawOutput: lastRawText),
          ),
        OpenAIChatMessage.text(role: OpenAIMessageRole.user, content: userPrompt),
      ];

      try {
        final resp = await aiService.chat(
          messages: messages,
          systemPrompt: systemPrompt,
          tools: null,
        );

        final msg = resp.choices.isNotEmpty ? resp.choices.first.message : null;
        _logLong('DayWeekAiScheduler', 'AI message.toJson=${jsonEncode(msg?.toJson() ?? {})}');
        final text = msg?.textContent ?? '';
        lastRawText = text;
        _logLong('DayWeekAiScheduler', 'AI raw textContent=$text');

        final jsonStr = _extractJsonObject(text);
        final decoded = jsonDecode(jsonStr);
        if (decoded is! Map) throw Exception('AI 输出不是 JSON 对象');
        // 兼容旧格式（直接返回 blocks）或新格式（返回 reasoning + schedule）

        if (decoded.containsKey('schedule') && decoded['schedule'] is Map) {
          final schedule = decoded['schedule'];
          final raw = (schedule as Map)['blocks'];
          if (raw is! List) throw Exception('AI 输出 schedule.blocks 不是数组');
          blocksRaw = raw;
          reasoning = decoded['reasoning']?.toString() ?? '无逻辑说明';
        } else if (decoded.containsKey('blocks')) {
          final raw = decoded['blocks'];
          if (raw is! List) throw Exception('AI 输出 blocks 不是数组');
          blocksRaw = raw;
          reasoning = decoded['reasoning']?.toString() ?? '无逻辑说明';
        } else {
          throw Exception('AI 输出缺少 schedule.blocks 或 blocks');
        }

        final validation = validateAiBlocksForTest(
          raw: blocksRaw!,
          allowedIds: allowedIds,
          effectiveStart: effectiveRangeStart,
          effectiveEnd: effectiveRangeEnd,
          freeWindows: freeWindowsByDayKey,
          availabilityRanges: availabilityByDayKey,
          busy: busyEvents,
        );

        if (validation.violations.isNotEmpty) {
          lastWasValidationError = true;
          lastViolations = validation.violations;
          lastError = Exception('AI 输出时间块不满足规则: ${validation.violations.first['reason']}');
          blocksRaw = null;
          reasoning = '';
          if (attempt >= maxJsonParseRetries) {
            break;
          }
          continue;
        }

        parsedBlocks = validation.normalizedBlocks
            .map(
              (b) => _TimeBlockPlan(
                taskId: b['taskId'] as String,
                title: b['title'] as String,
                start: b['start'] as DateTime,
                end: b['end'] as DateTime,
              ),
            )
            .toList(growable: false);
        parsedReasoning = reasoning;
        break;
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        _logLong('DayWeekAiScheduler', 'AI parse attempt=$attempt failed error=$e');
        blocksRaw = null;
        reasoning = '';
        lastWasValidationError = false;
        lastViolations = const [];
        if (attempt >= maxJsonParseRetries) {
          break;
        }
      }
    }

    if (parsedBlocks == null) {
      throw Exception('AI 输出生成失败（已重试 $maxJsonParseRetries 次）：${lastError ?? '未知错误'}');
    }

    return (reasoning: parsedReasoning, blocks: parsedBlocks);
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
