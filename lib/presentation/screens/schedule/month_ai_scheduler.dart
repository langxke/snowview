import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/models/openai/openai_models.dart';
import '../../../data/repositories/ai_config_repository.dart';
import '../../../services/ai_service.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/task_list_provider.dart';

class MonthAiScheduler {
  static const String _taskMetaPrefsPrefix = 'task_meta_v1_';
  static const String _taskMetaAiDueDateKey = 'aiDueDate';

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

    final taskProvider = context.read<TaskListProvider>();
    final candidates = taskProvider.tasks
        .where((t) => !t.isCompleted)
        .where((t) => t.dueDate == null)
        .toList(growable: false);

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
      final assignments = await _callMonthSchedulingAI(
        aiService: aiService,
        today: rangeStart,
        monthEnd: monthEnd,
        candidates: candidates,
      );

      final prefs = await SharedPreferences.getInstance();
      int applied = 0;
      for (final a in assignments) {
        await taskProvider.updateTask(id: a.taskId, dueDate: a.date);
        await _writeTaskMetaAiDueDate(prefs: prefs, taskId: a.taskId, date: a.date);
        applied++;
      }

      if (!context.mounted) return;
      context.read<ScheduleProvider>().refresh();
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
    final prefs = await SharedPreferences.getInstance();
    final start = DateTime(today.year, today.month, today.day);
    final end = DateTime(monthEnd.year, monthEnd.month, monthEnd.day);
    int cleared = 0;

    for (final t in taskProvider.tasks) {
      if (t.isCompleted) continue;
      final due = t.dueDate;
      if (due == null) continue;
      final dueDay = DateTime(due.year, due.month, due.day);
      if (dueDay.isBefore(start) || dueDay.isAfter(end)) continue;
      final aiDue = _readTaskMetaAiDueDate(prefs: prefs, taskId: t.id);
      if (aiDue == null) continue;
      if (aiDue != _dateKey(dueDay)) continue;
      await taskProvider.updateTask(id: t.id, clearDueDate: true);
      await _clearTaskMetaAiDueDate(prefs: prefs, taskId: t.id);
      cleared++;
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

  static Future<List<_TaskAssignment>> _callMonthSchedulingAI({
    required AIService aiService,
    required DateTime today,
    required DateTime monthEnd,
    required List<dynamic> candidates,
  }) async {
    final taskItems = candidates.map((t) {
      final dyn = t as dynamic;
      return {
        'id': dyn.id,
        'title': dyn.title,
        // 以下字段：仅在模型存在且有值时提供给 AI，便于更好的排期。
        if (dyn.description != null) 'description': dyn.description,
        if (dyn.dueDate != null) 'dueDate': _dateKey(dyn.dueDate as DateTime),
        if (dyn.remindAt != null) 'remindAt': (dyn.remindAt as DateTime).toIso8601String(),
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
        '3) date 必须在 range.start 与 range.end（含）之间，格式必须是 YYYY-MM-DD。\n'
        '4) 不允许输出解释、Markdown、代码块、前后缀文字。你必须输出【纯 JSON】。\n'
        '5) 如果无法安排某个任务，可以不输出该任务（即 assignments 里可以缺省）。\n'
        '6) 输出必须可被 JSON.parse 解析。\n'
        '\n'
        '## 输出 JSON Schema（必须严格匹配）\n'
        '{\n'
        '  "assignments": [\n'
        '    { "taskId": "<string>", "date": "YYYY-MM-DD" }\n'
        '  ]\n'
        '}\n'
        '\n'
        '## 正确示例（仅示例，实际要根据输入生成）\n'
        '{\n'
        '  "assignments": [\n'
        '    { "taskId": "t_001", "date": "2025-12-29" },\n'
        '    { "taskId": "t_002", "date": "2025-12-30" }\n'
        '  ]\n'
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
        'assignments': [
          {'taskId': '<string>', 'date': 'YYYY-MM-DD'}
        ]
      },
      'example_output': {
        'assignments': [
          {'taskId': 't_001', 'date': _dateKey(today)},
        ]
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
    final list = decoded['assignments'];
    if (list is! List) throw Exception('AI 输出缺少 assignments');

    final allowedIds = taskItems.map((e) => e['id'].toString()).toSet();
    final start = DateTime(today.year, today.month, today.day);
    final end = DateTime(monthEnd.year, monthEnd.month, monthEnd.day);

    final result = <_TaskAssignment>[];
    for (final item in list) {
      if (item is! Map) continue;
      final taskId = item['taskId']?.toString();
      final dateStr = item['date']?.toString();
      if (taskId == null || dateStr == null) continue;
      if (!allowedIds.contains(taskId)) continue;
      final parsed = DateTime.tryParse(dateStr);
      if (parsed == null) continue;
      final day = DateTime(parsed.year, parsed.month, parsed.day);
      if (day.isBefore(start) || day.isAfter(end)) continue;
      result.add(_TaskAssignment(taskId: taskId, date: day));
    }

    return result;
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
