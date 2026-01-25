import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/models/openai/openai_models.dart';
import '../../../data/repositories/ai_config_repository.dart';
import '../../../services/ai_service.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/daily_plan_provider.dart';
import '../../providers/task_list_provider.dart'; // Add TaskListProvider import

class MonthAiScheduler {
  static const String _taskMetaPrefsPrefix = 'task_meta_v1_';
  static const String _taskMetaAiDueDateKey = 'aiDueDate';
  static const String _taskMetaAiDueDatesKey = 'aiDueDates';

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

  static Future<void> _saveReasoning({
    required String reasoning,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'ai_reasoning_latest_month'; // 固定 Key
    final data = {
      'timestamp': DateTime.now().toIso8601String(),
      'reasoning': reasoning,
    };
    await prefs.setString(key, jsonEncode(data));
  }

  static Future<String?> getReasoning() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'ai_reasoning_latest_month';
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

  static String _dateKey(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  static Future<void> runSmartSchedule(BuildContext context, {required int year, required int month}) async {
    final aiService = AIService(AIConfigRepository());
    if (!aiService.hasValidConfig) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI 未配置或配置无效，请先在设置中配置 AI 连接')),
      );
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedMonthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month + 1, 0);

    final currentMonthStart = DateTime(today.year, today.month, 1);
    DateTime rangeStart;

    if (selectedMonthStart.isBefore(currentMonthStart)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前选择的是过去的月份，无法安排')),
      );
      return;
    }

    if (selectedMonthStart.isAfter(currentMonthStart)) {
      rangeStart = selectedMonthStart;
    } else {
      rangeStart = today;
    }

    if (rangeStart.isAfter(monthEnd)) return;

    final taskProvider = context.read<TaskListProvider>(); // Now TaskListProvider is imported
    final dailyPlanProvider = context.read<DailyPlanProvider>();
    
    final candidates = taskProvider.tasks
        .where((t) => !t.isCompleted)
        .where((t) => t.dueDate == null)
        .toList(); // Removed growable: false, but toList() is enough. 
                   // The issue was in .map((t) => {...}) later where type inference might fail if not explicit
                   // Or simply TaskListProvider import was not clean.
                   // Actually the error was "The name 'TaskListProvider' isn't a type"
                   // This usually means TaskListProvider is not imported or imported with alias/prefix
                   // But line 11 imports it correctly.
                   // Wait, line 11 imports daily_plan_provider.dart
                   // line 10 imports schedule_provider.dart
                   // TaskListProvider is usually in task_list_provider.dart
                   // Let's check imports.
                   // Missing import for TaskListProvider!

    if (candidates.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可安排的清单任务（未完成且未设置截止日期）')),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI智能安排'),
        content: Text('将从 ${_dateKey(rangeStart)} 到 ${_dateKey(monthEnd)}，为 ${candidates.length} 条任务分配日期（不创建新 todo）。是否继续？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('开始')),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;

    final closeLoading = _showBlockingLoading(context, 'AI 正在分析并安排…');
    try {
      final result = await _callMonthSchedulingAI(
        aiService: aiService,
        today: rangeStart,
        monthEnd: monthEnd,
        candidates: candidates,
      );
      final assignments = result.assignments;
      final reasoning = result.reasoning;
      
      // 保存 Reasoning (固定 Key)
      await _saveReasoning(reasoning: reasoning);

      final prefs = await SharedPreferences.getInstance();
      final byTaskId = <String, List<DateTime>>{};
      for (final a in assignments) {
        (byTaskId[a.taskId] ??= <DateTime>[]).add(a.date);
      }

      int applied = 0;
      
      // 新逻辑：将 AI 安排结果写入 DailyPlan
      for (final entry in byTaskId.entries) {
        final taskId = entry.key;
        final dates = entry.value; // dates 已经包含了循环任务的所有展开日期
        
        for (final date in dates) {
            await dailyPlanProvider.addTodoTask(date, taskId);
        }
        
        // 可选：记录 AI 元数据以便清空（虽然现在清空逻辑也可以改为扫描 DailyPlan）
        // 为了兼容性，我们仍然写入元数据，但不再修改 Task.dueDate
        final repeat = _readTaskRepeat(prefs: prefs, taskId: taskId);
        final isRecurring = repeat != null && repeat.trim().isNotEmpty && repeat.trim() != 'none';
        
        if (isRecurring) {
            await _writeTaskMetaAiDueDates(prefs: prefs, taskId: taskId, dates: dates);
        } else {
            // 对于非循环任务，如果是 AI 安排的，我们只记录元数据，不修改 Task 的物理 dueDate
            // 这样任务在列表中还是“无日期”，但在日历上通过 DailyPlan 显示
            if (dates.isNotEmpty) {
                 await _writeTaskMetaAiDueDate(prefs: prefs, taskId: taskId, date: dates.first);
            }
        }
        
        applied += dates.length;
      }

      if (!context.mounted) return;
      // 刷新 ScheduleScreen 可能会重新获取 DailyPlan
      context.read<ScheduleProvider>().refresh();
      // 通知 UI 刷新（如果 ScheduleScreen 监听了 DailyPlanProvider 则自动刷新，否则可能需要手动触发）
      // 由于 DailyPlanProvider 是 ChangeNotifier，addTodoTask 会 notifyListeners
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI 已安排 $applied 条任务到本月日历')),
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

  static Future<void> runClearSchedule(BuildContext context, {required int year, required int month}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthEnd = DateTime(year, month + 1, 0);

    if (today.isAfter(monthEnd)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前月份已结束，无需清空')),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空安排'),
        content: const Text('将清空“今日→月末”范围内由 AI 安排的待办（仅影响 AI 写入的截止日期），手动设置的不受影响。是否继续？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('清空')),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;

    final closeLoading = _showBlockingLoading(context, '正在清空 AI 安排…');
    try {
      final cleared = await _clearAiDueDatesInRange(context, today: today, monthEnd: monthEnd);
      if (!context.mounted) return;
      context.read<ScheduleProvider>().refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已清空 $cleared 条 AI 安排')),
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

  static Future<int> _clearAiDueDatesInRange(
    BuildContext context, {
    required DateTime today,
    required DateTime monthEnd,
  }) async {
    final taskProvider = context.read<TaskListProvider>();
    final dailyPlanProvider = context.read<DailyPlanProvider>();
    final prefs = await SharedPreferences.getInstance();
    final start = DateTime(today.year, today.month, today.day);
    final end = DateTime(monthEnd.year, monthEnd.month, monthEnd.day);
    int cleared = 0;

    for (final t in taskProvider.tasks) {
      // 1. 检查 AI 安排的单日任务
      final aiDue = _readTaskMetaAiDueDate(prefs: prefs, taskId: t.id);
      if (aiDue != null) {
          final date = DateTime.tryParse(aiDue);
          if (date != null && !date.isBefore(start) && !date.isAfter(end)) {
              await dailyPlanProvider.removeTodoTask(date, t.id);
              await _clearTaskMetaAiDueDate(prefs: prefs, taskId: t.id);
              cleared++;
          }
      }

      // 2. 检查 AI 安排的循环任务日期
      final aiDueDates = _readTaskMetaAiDueDates(prefs: prefs, taskId: t.id);
      if (aiDueDates != null && aiDueDates.isNotEmpty) {
         for (final dStr in aiDueDates) {
             final date = DateTime.tryParse(dStr);
             if (date != null && !date.isBefore(start) && !date.isAfter(end)) {
                 await dailyPlanProvider.removeTodoTask(date, t.id);
                 // 注意：这里我们只移除了 DailyPlan 中的引用
                 // 元数据中的 aiDueDates 列表可能需要更新（移除已清除的日期）
                 // 为简单起见，如果是全量清除，我们会在循环结束后清除整个元数据 key
             }
         }
         await _clearTaskMetaAiDueDates(prefs: prefs, taskId: t.id);
         cleared += aiDueDates.length;
      }
    }

    return cleared;
  }

  static String? _readTaskMetaAiDueDate({required SharedPreferences prefs, required String taskId}) {
    final raw = prefs.getString('$_taskMetaPrefsPrefix$taskId');
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final v = decoded[_taskMetaAiDueDateKey];
      return v?.toString();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeTaskMetaAiDueDate({
    required SharedPreferences prefs,
    required String taskId,
    required DateTime date,
  }) async {
    final key = '$_taskMetaPrefsPrefix$taskId';
    final raw = prefs.getString(key);
    Map<String, dynamic> decoded = {};
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final d = jsonDecode(raw);
        if (d is Map) {
          decoded = Map<String, dynamic>.from(d);
        }
      } catch (_) {}
    }
    decoded[_taskMetaAiDueDateKey] = _dateKey(date);
    decoded.remove(_taskMetaAiDueDatesKey);
    await prefs.setString(key, jsonEncode(decoded));
  }

  static String? _readTaskRepeat({required SharedPreferences prefs, required String taskId}) {
    final raw = prefs.getString('$_taskMetaPrefsPrefix$taskId');
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return decoded['repeat']?.toString();
    } catch (_) {
      return null;
    }
  }

  static List<String>? _readTaskMetaAiDueDates({required SharedPreferences prefs, required String taskId}) {
    final raw = prefs.getString('$_taskMetaPrefsPrefix$taskId');
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final v = decoded[_taskMetaAiDueDatesKey];
      if (v is List) {
        return v.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeTaskMetaAiDueDates({
    required SharedPreferences prefs,
    required String taskId,
    required List<DateTime> dates,
  }) async {
    final key = '$_taskMetaPrefsPrefix$taskId';
    final raw = prefs.getString(key);
    Map<String, dynamic> decoded = {};
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final d = jsonDecode(raw);
        if (d is Map) {
          decoded = Map<String, dynamic>.from(d);
        }
      } catch (_) {}
    }
    decoded[_taskMetaAiDueDatesKey] = dates.map(_dateKey).toList();
    decoded.remove(_taskMetaAiDueDateKey);
    await prefs.setString(key, jsonEncode(decoded));
  }

  static Future<void> _clearTaskMetaAiDueDate({required SharedPreferences prefs, required String taskId}) async {
    final key = '$_taskMetaPrefsPrefix$taskId';
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final map = Map<String, dynamic>.from(decoded);
      map.remove(_taskMetaAiDueDateKey);
      await prefs.setString(key, jsonEncode(map));
    } catch (_) {
      return;
    }
  }

  static Future<void> _clearTaskMetaAiDueDates({required SharedPreferences prefs, required String taskId}) async {
    final key = '$_taskMetaPrefsPrefix$taskId';
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final map = Map<String, dynamic>.from(decoded);
      map.remove(_taskMetaAiDueDatesKey);
      await prefs.setString(key, jsonEncode(map));
    } catch (_) {
      return;
    }
  }

  static Future<({String reasoning, List<_TaskAssignment> assignments})> _callMonthSchedulingAI({
    required AIService aiService,
    required DateTime today,
    required DateTime monthEnd,
    required List<dynamic> candidates,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final taskItems = candidates.map((t) {
      final dyn = t as dynamic;
      String? repeat;
      final raw = prefs.getString('$_taskMetaPrefsPrefix${dyn.id}');
      if (raw != null && raw.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            repeat = decoded['repeat']?.toString();
          }
        } catch (_) {
          // ignore
        }
      }

      return {
        'id': dyn.id,
        'title': dyn.title,
        // 以下字段：仅在模型存在且有值时提供给 AI，便于更好的排期。
        if (dyn.description != null) 'description': dyn.description,
        if (dyn.dueDate != null) 'dueDate': _dateKey(dyn.dueDate as DateTime),
        if (dyn.remindAt != null) 'remindAt': (dyn.remindAt as DateTime).toIso8601String(),
        if (repeat != null && repeat.trim().isNotEmpty) 'repeat': repeat,
        if (dyn.createdAt != null) 'createdAt': (dyn.createdAt as DateTime).toIso8601String(),
      };
    }).toList();

    final systemPrompt =
        '你是一个严格的“日历排期引擎（Calendar Scheduling Engine）”。\n'
        '\n'
        '## 你的用途\n'
        '- 输入：一批未完成的清单任务（taskPool）+ 可用日期范围（range）。\n'
        '- 输出：为部分或全部任务分配一个截止日期（due date），用于把任务展示在月视图日历上。\n'
        '\n'
        '## 关键规则（必须遵守）\n'
        '1) 你【绝对不能】创建新的任务，只能从 taskPool 中挑选并分配日期。\n'
        '2) 你输出的每一条 assignment 必须使用 taskPool 里已有的 taskId。\n'
        '3) date/start/end 必须在 range.start 与 range.end（含）之间，格式必须是 YYYY-MM-DD。\n'
        '4) taskPool 中可能包含 repeat 字段（none|daily|weekly|monthly|workdays|weekends）。\n'
        '   - 当 repeat != none 时，表示循环任务：你【不要】逐日输出，而是输出一个日期范围 start/end（同一个 taskId 只需要出现一次），客户端会按 repeat 规则自动展开到每一天/每周等。\n'
        '   - 对于循环任务，推荐直接使用 range.start 作为 start、range.end 作为 end（即覆盖整个范围）。\n'
        '5) 不允许输出解释、Markdown、代码块、前后缀文字。你必须输出【纯 JSON】。\n'
        '6) 如果无法安排某个任务，可以不输出该任务（即 assignments 里可以缺省）。\n'
        '7) 输出必须可被 JSON.parse 解析。\n'
        '\n'
        '## 输出 JSON Schema（必须严格匹配）\n'
        '{\n'
        '  "reasoning": "<在此处简要说明你的安排逻辑。要求：1. 必须使用通俗易懂的语言（如“优先安排了高优先级任务”、“已将循环任务铺满全月”），严禁使用“taskPool”、“assignments”等技术术语；2. 语言要简洁明了，让用户一眼就能看懂；3. 解释为什么这样安排。>",\n'
        '  "schedule": {\n'
        '    "assignments": [\n'
        '      // 非循环任务：给一个日期\n'
        '      { "taskId": "<string>", "date": "YYYY-MM-DD" },\n'
        '      // 循环任务：给一个日期范围（客户端会按 repeat 规则展开）\n'
        '      { "taskId": "<string>", "start": "YYYY-MM-DD", "end": "YYYY-MM-DD" }\n'
        '    ]\n'
        '  }\n'
        '}\n'
        '\n'
        '## 正确示例（仅示例，实际要根据输入生成）\n'
        '{\n'
        '  "reasoning": "优先安排了高优先级的任务 t_001，并根据循环规则设定了 t_002 的范围。",\n'
        '  "schedule": {\n'
        '    "assignments": [\n'
        '      { "taskId": "t_001", "date": "2025-12-29" }\n'
        '    ]\n'
        '  }\n'
        '}';

    final userPrompt = jsonEncode({
      'instruction': {
        'goal': '在给定日期范围内，为 taskPool 中的任务分配 due date。',
        'must_follow': [
          '只能使用 taskPool 中存在的 taskId',
          'date 格式必须为 YYYY-MM-DD',
          'date 必须在 range.start 与 range.end（含）之间',
          '如果 taskPool[i].repeat != none，则请输出 start/end（同一个 taskId 只出现一次），不要逐日输出',
          '只输出 JSON，不要输出任何额外文字、不要用 Markdown/代码块',
        ],
        'strategy_hint': [
          '尽量把任务分散到不同日期，避免全部堆在同一天',
          '循环任务（repeat != none）优先保证范围覆盖（建议 start=range.start, end=range.end），再考虑把其他非循环任务分散安排',
          '可以优先把更紧急/更重要（从标题语义判断）的任务安排在更靠近 start 的日期',
          '若任务本身已经有 dueDate/remindAt/description 等信息，请参考这些信息进行安排；但不要修改这些字段，只输出分配结果',
        ],
      },
      'range': {
        'start': _dateKey(today),
        'end': _dateKey(monthEnd),
      },
      'taskPool': taskItems,
      'output_schema': {
        'reasoning': '<string>',
        'schedule': {
          'assignments': [
            {'taskId': '<string>', 'date': 'YYYY-MM-DD'},
            {'taskId': '<string>', 'start': 'YYYY-MM-DD', 'end': 'YYYY-MM-DD'}
          ]
        }
      },
      'example_output': {
        'reasoning': '...',
        'schedule': {
          'assignments': [
            {'taskId': 't_001', 'date': _dateKey(today)},
          ]
        }
      }
    });

    _logLong('MonthAiScheduler', 'Request range=${_dateKey(today)}..${_dateKey(monthEnd)} tasks=${taskItems.length}');
    _logLong('MonthAiScheduler', 'Request userPrompt=$userPrompt');

    final resp = await aiService.chat(
      messages: [
        OpenAIChatMessage.text(role: OpenAIMessageRole.user, content: userPrompt),
      ],
      systemPrompt: systemPrompt,
      tools: null,
    );

    final msg = resp.choices.isNotEmpty ? resp.choices.first.message : null;
    final msgJson = msg == null ? {} : msg.toJson();
    _logLong('MonthAiScheduler', 'AI message.toJson=${jsonEncode(msgJson)}');

    final contentText = msg?.textContent ?? '';
    _logLong('MonthAiScheduler', 'AI raw textContent=$contentText');

    final jsonStr = _extractJsonObject(contentText);
    _logLong('MonthAiScheduler', 'AI extracted json=$jsonStr');
    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map) throw Exception('AI 输出不是 JSON 对象');
    
    // 兼容旧格式（直接返回 assignments）或新格式（返回 reasoning + schedule）
    List<dynamic> listRaw;
    String reasoning = '';
    
    if (decoded.containsKey('schedule') && decoded['schedule'] is Map) {
        listRaw = decoded['schedule']['assignments'] ?? [];
        reasoning = decoded['reasoning']?.toString() ?? '';
    } else if (decoded.containsKey('assignments')) {
        listRaw = decoded['assignments'];
        reasoning = decoded['reasoning']?.toString() ?? '无逻辑说明';
    } else {
        throw Exception('AI 输出缺少 schedule.assignments 或 assignments');
    }

    final allowedIds = taskItems.map((e) => e['id'].toString()).toSet();
    final start = DateTime(today.year, today.month, today.day);
    final end = DateTime(monthEnd.year, monthEnd.month, monthEnd.day);

    String? repeatForTaskId(String taskId) {
      final item = taskItems.cast<Map>().firstWhere(
        (e) => e['id']?.toString() == taskId,
        orElse: () => const {},
      );
      final r = item['repeat']?.toString();
      return r;
    }

    List<DateTime> expandRepeatDates({
      required DateTime rangeStart,
      required DateTime rangeEnd,
      required String repeat,
    }) {
      final rs = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
      final re = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day);
      if (re.isBefore(rs)) return const [];

      bool keep(DateTime d) {
        switch (repeat) {
          case 'daily':
            return true;
          case 'workdays':
            return d.weekday >= DateTime.monday && d.weekday <= DateTime.friday;
          case 'weekends':
            return d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;
          default:
            return true;
        }
      }

      final dates = <DateTime>[];

      if (repeat == 'weekly') {
        final anchorWeekday = rs.weekday;
        for (DateTime d = rs; !d.isAfter(re); d = d.add(const Duration(days: 1))) {
          if (d.weekday == anchorWeekday) dates.add(d);
        }
        if (dates.isEmpty) dates.add(rs);
        return dates;
      }

      if (repeat == 'monthly') {
        return [rs];
      }

      for (DateTime d = rs; !d.isAfter(re); d = d.add(const Duration(days: 1))) {
        if (keep(d)) dates.add(d);
      }
      return dates;
    }

    final result = <_TaskAssignment>[];
    for (final item in listRaw) {
      if (item is! Map) continue;
      final taskId = item['taskId']?.toString();
      final dateStr = item['date']?.toString();
      final startStr = item['start']?.toString();
      final endStr = item['end']?.toString();
      if (taskId == null) continue;
      if (!allowedIds.contains(taskId)) continue;

      // 非循环任务：单日
      if (dateStr != null) {
        final parsed = DateTime.tryParse(dateStr);
        if (parsed == null) continue;
        final day = DateTime(parsed.year, parsed.month, parsed.day);
        if (day.isBefore(start) || day.isAfter(end)) continue;
        result.add(_TaskAssignment(taskId: taskId, date: day));
        continue;
      }

      // 循环任务：范围（客户端按 repeat 规则展开）
      if (startStr != null && endStr != null) {
        final ps = DateTime.tryParse(startStr);
        final pe = DateTime.tryParse(endStr);
        if (ps == null || pe == null) continue;
        final rs = DateTime(ps.year, ps.month, ps.day);
        final re = DateTime(pe.year, pe.month, pe.day);

        // clamp to request range
        final clampedStart = rs.isBefore(start) ? start : rs;
        final clampedEnd = re.isAfter(end) ? end : re;

        final repeat = repeatForTaskId(taskId) ?? 'none';
        final isRecurring = repeat.trim().isNotEmpty && repeat.trim() != 'none';
        if (!isRecurring) {
          // 兜底：若 AI 给了范围但任务不是循环任务，则取范围起点
          result.add(_TaskAssignment(taskId: taskId, date: clampedStart));
          continue;
        }

        final expanded = expandRepeatDates(rangeStart: clampedStart, rangeEnd: clampedEnd, repeat: repeat);
        for (final d in expanded) {
          if (d.isBefore(start) || d.isAfter(end)) continue;
          result.add(_TaskAssignment(taskId: taskId, date: d));
        }
      }
    }

    return (reasoning: reasoning, assignments: result);
  }

  static String _extractJsonObject(String s) {
    var text = s.trim();

    // 常见情况：模型把 JSON 包在 Markdown code fence 里
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

    // 优先提取对象，其次提取数组
    final objStart = text.indexOf('{');
    final objEnd = text.lastIndexOf('}');
    if (objStart != -1 && objEnd != -1 && objEnd > objStart) {
      return text.substring(objStart, objEnd + 1);
    }

    final arrStart = text.indexOf('[');
    final arrEnd = text.lastIndexOf(']');
    if (arrStart != -1 && arrEnd != -1 && arrEnd > arrStart) {
      return text.substring(arrStart, arrEnd + 1);
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

class _TaskAssignment {
  final String taskId;
  final DateTime date;
  const _TaskAssignment({required this.taskId, required this.date});
}
