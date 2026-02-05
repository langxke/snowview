import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:snowview/data/models/calendar_event_hive.dart';
import 'package:snowview/data/models/checklist_task_hive.dart';
import 'package:snowview/data/models/daily_plan_hive.dart';
import 'package:snowview/data/models/focus_session_hive.dart';
import 'package:snowview/data/models/focus_daily_stats_hive.dart';
import 'package:snowview/data/models/ai_config_hive.dart';
import 'package:snowview/data/models/chat_message_hive.dart';
import 'package:snowview/data/models/chat_session_hive.dart';
import 'package:snowview/services/app_data_reset_service.dart';

void main() {
  test('AppDataResetService clears Hive boxes and SharedPreferences', () async {
    final dir = await Directory.systemTemp.createTemp('snowview_hive_test_');
    Hive.init(dir.path);

    Hive.registerAdapter(CalendarEventHiveAdapter());
    Hive.registerAdapter(ChecklistTaskHiveAdapter());
    Hive.registerAdapter(FocusSessionHiveAdapter());
    Hive.registerAdapter(FocusDailyStatsHiveAdapter());
    Hive.registerAdapter(AIConfigHiveAdapter());
    Hive.registerAdapter(ChatMessageHiveAdapter());
    Hive.registerAdapter(ChatSessionHiveAdapter());
    Hive.registerAdapter(DailyPlanHiveAdapter());

    SharedPreferences.setMockInitialValues({
      'some_key': 'some_value',
      'task_meta_v1_123': '{"a":1}',
    });

    final eventBox = await Hive.openBox<CalendarEventHive>('calendar_events');
    await eventBox.put(
      'e1',
      CalendarEventHive(
        id: 'e1',
        title: 't',
        description: '',
        allDay: false,
        start: DateTime(2026, 1, 1, 9),
        end: DateTime(2026, 1, 1, 10),
        colorValue: 0xff000000,
      ),
    );

    final taskBox = await Hive.openBox<ChecklistTaskHive>('checklist_tasks');
    await taskBox.put(
      't1',
      ChecklistTaskHive(
        id: 't1',
        title: 'task',
        isCompleted: false,
        createdAt: DateTime(2026, 1, 1),
        order: 0,
      ),
    );

    expect(eventBox.isNotEmpty, true);
    expect(taskBox.isNotEmpty, true);
    final prefsBefore = await SharedPreferences.getInstance();
    expect(prefsBefore.getKeys().isNotEmpty, true);

    await AppDataResetService.clearAllLocalData();

    final prefsAfter = await SharedPreferences.getInstance();
    expect(prefsAfter.getKeys(), isEmpty);

    final eventBoxAfter = Hive.box<CalendarEventHive>('calendar_events');
    final taskBoxAfter = Hive.box<ChecklistTaskHive>('checklist_tasks');
    expect(eventBoxAfter.isEmpty, true);
    expect(taskBoxAfter.isEmpty, true);

    await Hive.close();
    await dir.delete(recursive: true);
  });
}

