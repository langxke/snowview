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

  @visibleForTesting
  static Future<({String reasoning, Map<String, List<String>> byTaskId})> callMonthSchedulingAIForTest({
    required AIService aiService,
    required DateTime today,
    required DateTime monthEnd,
    required List<dynamic> candidates,
  }) async {
    final res = await _callMonthSchedulingAI(aiService: aiService, today: today, monthEnd: monthEnd, candidates: candidates);
    final byTaskId = <String, List<String>>{};
    for (final a in res.assignments) {
      (byTaskId[a.taskId] ??= <String>[]).add(_dateKey(a.date));
    }
    return (reasoning: res.reasoning, byTaskId: byTaskId);
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
        if (dates.length >= 2) {
          await _writeTaskMetaAiDueDates(prefs: prefs, taskId: taskId, dates: dates);
        } else if (dates.isNotEmpty) {
          await _writeTaskMetaAiDueDate(prefs: prefs, taskId: taskId, date: dates.first);
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
      final errText = e.toString();
      if (errText.contains('输出解析失败') || errText.contains('JSON')) {
        await _saveReasoning(reasoning: 'AI 输出解析失败：$errText');
      }
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
        '- 输出：为部分或全部任务分配具体日期，用于把任务展示在月视图日历上。\n'
        '\n'
        '## 关键规则（必须遵守）\n'
        '1) 你【绝对不能】创建新的任务，只能从 taskPool 中挑选并分配日期。\n'
        '2) 你输出的每一条 assignment 必须使用 taskPool 里已有的 taskId。\n'
        '3) 所有日期必须在 range.start 与 range.end（含）之间，格式必须是 YYYY-MM-DD。\n'
        '4) taskPool 中可能包含 description（备注）和 repeat（循环提示）等信息。\n'
        '   - 备注（description）仅作为参考偏好：在可行的情况下尽可能满足，但可以折中。\n'
        '   - repeat 仅作为参考提示（不需要假设客户端会做任何自动展开）。\n'
        '5) 你必须输出【纯 JSON】；不要输出解释、Markdown、代码块、前后缀文字。\n'
        '6) 如果无法安排某个任务，可以不输出该任务（即 assignments 里可以缺省）。\n'
        '7) 输出必须可被 JSON.parse 解析。\n'
        '\n'
        '## 输出 JSON Schema（必须严格匹配）\n'
        '{\n'
        '  "reasoning": "<在此处简要说明你的安排逻辑。要求：1. 必须使用通俗易懂的语言，严禁使用“taskPool”、“assignments”等技术术语；2. 语言要简洁明了，让用户一眼就能看懂；3. 解释为什么这样安排，以及哪些备注偏好被满足/被折中。>",\n'
        '  "schedule": {\n'
        '    "assignments": [\n'
        '      { "taskId": "<string>", "date": "YYYY-MM-DD" },\n'
        '      { "taskId": "<string>", "dates": ["YYYY-MM-DD", "..."] }\n'
        '    ]\n'
        '  }\n'
        '}\n'
        '\n'
        '## 正确示例（仅示例，实际要根据输入生成）\n'
        '{\n'
        '  "reasoning": "优先安排了更紧急的任务，并尽量参考了备注里的频率偏好。",\n'
        '  "schedule": {\n'
        '    "assignments": [\n'
        '      { "taskId": "t_001", "date": "2026-02-06" },\n'
        '      { "taskId": "t_002", "dates": ["2026-02-07", "2026-02-09", "2026-02-11"] }\n'
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
          '只输出 JSON，不要输出任何额外文字、不要用 Markdown/代码块',
        ],
        'strategy_hint': [
          '尽量把任务分散到不同日期，避免全部堆在同一天',
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
            {'taskId': '<string>', 'dates': ['YYYY-MM-DD']}
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

    String buildRetryPrompt({
      required int attempt,
      required String error,
      required String lastRawOutput,
    }) {
      return jsonEncode({
        'instruction': {
          'goal': '请修复上一次输出的格式错误，并重新输出符合要求的纯 JSON。',
          'attempt': attempt,
          'previous_error': error,
          'must_follow': [
            '只输出纯 JSON（不要 Markdown/代码块/解释）',
            '严格匹配 output_schema',
            '只能使用 taskPool 中存在的 taskId',
            '所有日期必须在 range.start 与 range.end（含）之间，格式为 YYYY-MM-DD',
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
              {'taskId': '<string>', 'dates': ['YYYY-MM-DD']}
            ]
          }
        },
        'previous_output': clip(lastRawOutput, 1400),
      });
    }

    Exception? lastError;
    String lastRawText = '';

    for (int attempt = 1; attempt <= maxJsonParseRetries; attempt++) {
      final content = attempt == 1 ? userPrompt : buildRetryPrompt(attempt: attempt, error: lastError.toString(), lastRawOutput: lastRawText);
      _logLong('MonthAiScheduler', 'AI request attempt=$attempt max=$maxJsonParseRetries');

      try {
        final resp = await aiService.chat(
          messages: [
            OpenAIChatMessage.text(role: OpenAIMessageRole.user, content: content),
          ],
          systemPrompt: systemPrompt,
          tools: null,
        );

        final msg = resp.choices.isNotEmpty ? resp.choices.first.message : null;
        final msgJson = msg == null ? {} : msg.toJson();
        _logLong('MonthAiScheduler', 'AI message.toJson=${jsonEncode(msgJson)}');

        final contentText = msg?.textContent ?? '';
        lastRawText = contentText;
        _logLong('MonthAiScheduler', 'AI raw textContent=$contentText');

        final jsonStr = _extractJsonObject(contentText);
        _logLong('MonthAiScheduler', 'AI extracted json=$jsonStr');
        final decoded = jsonDecode(jsonStr);
        if (decoded is! Map) throw Exception('AI 输出不是 JSON 对象');

        List<dynamic> listRaw;
        String reasoning = '';

        if (decoded.containsKey('schedule') && decoded['schedule'] is Map) {
          final schedule = decoded['schedule'];
          final raw = (schedule as Map)['assignments'];
          if (raw is! List) {
            throw Exception('AI 输出 schedule.assignments 不是数组');
          }
          listRaw = raw;
          reasoning = decoded['reasoning']?.toString() ?? '';
        } else if (decoded.containsKey('assignments')) {
          final raw = decoded['assignments'];
          if (raw is! List) {
            throw Exception('AI 输出 assignments 不是数组');
          }
          listRaw = raw;
          reasoning = decoded['reasoning']?.toString() ?? '无逻辑说明';
        } else {
          throw Exception('AI 输出缺少 schedule.assignments 或 assignments');
        }

        final allowedIds = taskItems.map((e) => e['id'].toString()).toSet();
        final start = DateTime(today.year, today.month, today.day);
        final end = DateTime(monthEnd.year, monthEnd.month, monthEnd.day);

        final result = <_TaskAssignment>[];
        final seen = <String>{};

        for (final item in listRaw) {
          if (item is! Map) continue;
          final taskId = item['taskId']?.toString();
          final dateStr = item['date']?.toString();
          final datesRaw = item['dates'];
          if (taskId == null) continue;
          if (!allowedIds.contains(taskId)) continue;

          void addDay(DateTime day) {
            final k = '$taskId|${_dateKey(day)}';
            if (seen.add(k)) {
              result.add(_TaskAssignment(taskId: taskId, date: day));
            }
          }

          if (dateStr != null) {
            final parsed = DateTime.tryParse(dateStr);
            if (parsed == null) continue;
            final day = DateTime(parsed.year, parsed.month, parsed.day);
            if (day.isBefore(start) || day.isAfter(end)) continue;
            addDay(day);
            continue;
          }

          if (datesRaw is List) {
            for (final d0 in datesRaw) {
              final s = d0?.toString();
              if (s == null) continue;
              final parsed = DateTime.tryParse(s);
              if (parsed == null) continue;
              final day = DateTime(parsed.year, parsed.month, parsed.day);
              if (day.isBefore(start) || day.isAfter(end)) continue;
              addDay(day);
            }
          }
        }

        return (reasoning: reasoning, assignments: result);
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        _logLong('MonthAiScheduler', 'AI parse attempt=$attempt failed error=$e');
        if (attempt >= maxJsonParseRetries) {
          break;
        }
      }
    }

    throw Exception('AI 输出解析失败（已重试 $maxJsonParseRetries 次）：${lastError ?? '未知错误'}');
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
