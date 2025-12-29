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

  static Future<void> runDaySmartSchedule(BuildContext context, {required DateTime day}) async {
    final rangeStart = _dayStart(day);
    final rangeEnd = _dayEnd(day);
    await _runSmartSchedule(context, rangeStart: rangeStart, rangeEnd: rangeEnd, scopeLabel: '当天');
  }

  static Future<void> runWeekSmartSchedule(BuildContext context, {required DateTime centerDate}) async {
    final start = _dayStart(centerDate.subtract(Duration(days: centerDate.weekday - 1)));
    final end = _dayEnd(start.add(const Duration(days: 6)));
    await _runSmartSchedule(context, rangeStart: start, rangeEnd: end, scopeLabel: '本周');
  }

  static Future<void> runDayClearSchedule(BuildContext context, {required DateTime day}) async {
    final rangeStart = _dayStart(day);
    final rangeEnd = _dayEnd(day);
    await _runClearSchedule(context, rangeStart: rangeStart, rangeEnd: rangeEnd, scopeLabel: '当天');
  }

  static Future<void> runWeekClearSchedule(BuildContext context, {required DateTime centerDate}) async {
    final start = _dayStart(centerDate.subtract(Duration(days: centerDate.weekday - 1)));
    final end = _dayEnd(start.add(const Duration(days: 6)));
    await _runClearSchedule(context, rangeStart: start, rangeEnd: end, scopeLabel: '本周');
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
    final dueInRangeTasks = taskProvider.tasks
        .where((t) => !t.isCompleted)
        .where((t) {
          final due = (t as dynamic).dueDate as DateTime?;
          if (due == null) return false;
          return !due.isBefore(rangeStart) && !due.isAfter(rangeEnd);
        })
        .toList();

    final unscheduledTasks = taskProvider.tasks
        .where((t) => !t.isCompleted)
        .where((t) => (t as dynamic).dueDate == null)
        .toList();

    final sourceTasks = <dynamic>[...dueInRangeTasks, ...unscheduledTasks];

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
      final plan = await _callTimeBlockSchedulingAI(
        aiService: aiService,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        busyEvents: busyEvents,
        candidates: sourceTasks,
      );

      final db = CalendarDatabaseService();
      final prefs = await SharedPreferences.getInstance();

      int created = 0;
      for (final block in plan) {
        final event = CalendarEvent(
          title: block.title,
          allDay: false,
          description: block.description,
          color: Colors.blue,
          start: block.start,
          end: block.end,
        );
        final id = await db.addEventFromCalendarEvent(event);
        await _writeEventMetaAi(prefs: prefs, eventId: id);
        await _markTaskScheduledForDate(prefs: prefs, date: block.start, taskId: block.taskId);
        created++;
      }

      if (!context.mounted) return;
      scheduleProvider.refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI 已生成 $created 个时间块')),
      );
    } catch (e) {
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
      final cleared = await _clearAiEventsInRange(rangeStart: rangeStart, rangeEnd: rangeEnd);
      if (!context.mounted) return;
      context.read<ScheduleProvider>().refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已清空 $cleared 个 AI 时间块')),
      );
    } catch (e) {
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
    int cleared = 0;
    for (final e in events) {
      final isAi = _readEventMetaAi(prefs: prefs, eventId: e.id);
      if (!isAi) continue;
      await db.deleteEvent(e.id);
      await _clearEventMetaAi(prefs: prefs, eventId: e.id);

      final taskId = _tryExtractTaskIdFromDescription(e.description);
      if (taskId != null && taskId.isNotEmpty) {
        await _unmarkTaskScheduledForDate(prefs: prefs, date: e.start, taskId: taskId);
      }
      cleared++;
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
    final taskItems = candidates.map((t) {
      final dyn = t as dynamic;
      return {
        'id': dyn.id,
        'title': dyn.title,
        if (dyn.description != null) 'description': dyn.description,
        if (dyn.remindAt != null) 'remindAt': (dyn.remindAt as DateTime).toIso8601String(),
        'isLongTerm': dyn.isLongTerm == true,
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

    final systemPrompt =
        '你是一个严格的“日历时间块排期引擎（Time-Block Scheduling Engine）”。\n'
        '你要把任务安排到具体的时间段中，并生成日程块。\n'
        '\n'
        '## 关键规则（必须遵守）\n'
        '1) 你不能创建新的任务，只能从 taskPool 中选择 taskId。\n'
        '2) 你必须避开 busyEvents 中的忙碌时间段，不能产生冲突。\n'
        '3) 所有输出的 start/end 必须落在 range.start 与 range.end（含）之间。\n'
        '4) 每个时间块必须 end > start，且建议以 15 分钟为粒度。\n'
        '5) 你必须只输出纯 JSON，不允许输出解释/Markdown/代码块。\n'
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
        'goal': '在指定范围内生成不冲突的时间块，并从 taskPool 中选择任务填充。',
        'range': {
          'start': rangeStart.toIso8601String(),
          'end': rangeEnd.toIso8601String(),
        },
        'workingHoursHint': {
          'startHour': 9,
          'endHour': 18,
        }
      },
      'busyEvents': busy,
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
    final result = <_TimeBlockPlan>[];
    for (final item in blocks) {
      if (item is! Map) continue;
      final taskId = item['taskId']?.toString();
      final title = item['title']?.toString();
      final startStr = item['start']?.toString();
      final endStr = item['end']?.toString();
      if (taskId == null || title == null || startStr == null || endStr == null) continue;
      if (!allowedIds.contains(taskId)) continue;
      final start = DateTime.tryParse(startStr);
      final end = DateTime.tryParse(endStr);
      if (start == null || end == null) continue;
      if (!end.isAfter(start)) continue;
      if (start.isBefore(rangeStart) || end.isAfter(rangeEnd)) continue;

      // 最后再做一次冲突过滤（防 AI 输出冲突）
      bool conflict = false;
      for (final b in busyEvents) {
        if (b.allDay) continue;
        if (start.isBefore(b.end) && end.isAfter(b.start)) {
          conflict = true;
          break;
        }
      }
      if (conflict) continue;

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
