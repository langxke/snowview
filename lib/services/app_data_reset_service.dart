import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/ai_config_hive.dart';
import '../data/models/calendar_event_hive.dart';
import '../data/models/chat_message_hive.dart';
import '../data/models/chat_session_hive.dart';
import '../data/models/checklist_task_hive.dart';
import '../data/models/daily_plan_hive.dart';
import '../data/models/focus_daily_stats_hive.dart';
import '../data/models/focus_session_hive.dart';

class AppDataResetService {
	static const List<String> _allBoxNames = [
		'calendar_events',
		'daily_plans',
		'checklist_tasks',
		'focus_sessions',
		'focus_daily_stats',
		'ai_config',
		'chat_messages',
		'chat_sessions',
		'journal_categories',
		'journal_entries',
	];

	static Future<void> clearAllLocalData() async {
		final prefs = await SharedPreferences.getInstance();
		await prefs.clear();

		for (final name in _allBoxNames) {
			if (!Hive.isBoxOpen(name)) continue;
			try {
				await Hive.box(name).close();
			} catch (_) {}
		}

		for (final name in _allBoxNames) {
			try {
				await Hive.deleteBoxFromDisk(name);
			} catch (_) {}
		}

		await Hive.openBox<CalendarEventHive>('calendar_events');
		await Hive.openBox<DailyPlanHive>('daily_plans');
		await Hive.openBox<ChecklistTaskHive>('checklist_tasks');
		await Hive.openBox<FocusSessionHive>('focus_sessions');
		await Hive.openBox<FocusDailyStatsHive>('focus_daily_stats');
		await Hive.openBox<AIConfigHive>('ai_config');
		await Hive.openBox<ChatMessageHive>('chat_messages');
		await Hive.openBox<ChatSessionHive>('chat_sessions');
	}
}

