import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/calendar_event_hive.dart';
import '../../../data/models/work_session_hive.dart';
import '../../../data/models/checklist_task_hive.dart';
import '../../../data/models/task_category_hive.dart';
import '../../../data/models/subtask_hive.dart';

class CalendarEvent {
	final String id;
	final String title;
	final bool allDay;
	final String description;
	final Color color;
	final DateTime start;
	final DateTime end;
	final bool isTaskSession;  // 是否为任务工作会话
	final String? taskSessionId;  // 如果是工作会话，存储原始会话ID

	CalendarEvent({
		String? id,
		required this.title,
		required this.allDay,
		required this.description,
		required this.color,
		required this.start,
		required this.end,
		this.isTaskSession = false,
		this.taskSessionId,
	}) : id = id ?? const Uuid().v4();

	bool intersects(DateTime day) {
		final d = DateTime(day.year, day.month, day.day);
		final s = DateTime(start.year, start.month, start.day);
		final e = DateTime(end.year, end.month, end.day);
		return !(d.isBefore(s) || d.isAfter(e));
	}

	// 创建修改后的副本，保持相同的ID
	CalendarEvent copyWith({
		String? title,
		bool? allDay,
		String? description,
		Color? color,
		DateTime? start,
		DateTime? end,
		bool? isTaskSession,
		String? taskSessionId,
	}) {
		return CalendarEvent(
			id: id, // 保持相同的ID
			title: title ?? this.title,
			allDay: allDay ?? this.allDay,
			description: description ?? this.description,
			color: color ?? this.color,
			start: start ?? this.start,
			end: end ?? this.end,
			isTaskSession: isTaskSession ?? this.isTaskSession,
			taskSessionId: taskSessionId ?? this.taskSessionId,
		);
	}
	
	@override
	bool operator ==(Object other) {
		if (identical(this, other)) return true;
		return other is CalendarEvent && other.id == id;
	}
	
	@override
	int get hashCode => id.hashCode;
}

const List<Color> eventColors = [
	Colors.red,
	Colors.orange,
	Colors.yellow,
	Colors.green,
	Colors.blue,
	Colors.purple,
	Colors.grey,
];

enum CalendarView { day, week, month }

/// 时间块类型枚举
enum TimeBlockType {
	event,       // 普通日历事件
	taskSession  // 任务工作会话
}

/// 统一的时间块模型，用于在日历中显示事件和任务会话
class TimeBlock {
	final String id;
	final TimeBlockType type;
	final String title;              // 显示标题（任务名称，非"会话x"）
	final String? subtitle;          // 副标题（子步骤名或备注）
	final DateTime startTime;
	final DateTime endTime;
	final Color color;
	final bool isCompleted;
	
	// 关联的原始数据
	final CalendarEventHive? event;
	final WorkSessionHive? session;
	final ChecklistTaskHive? task;
	final SubTaskHive? subTask;
	
	TimeBlock({
		required this.id,
		required this.type,
		required this.title,
		this.subtitle,
		required this.startTime,
		required this.endTime,
		required this.color,
		this.isCompleted = false,
		this.event,
		this.session,
		this.task,
		this.subTask,
	});
	
	/// 从日历事件创建时间块
	factory TimeBlock.fromEvent(CalendarEventHive event) {
		return TimeBlock(
			id: event.id,
			type: TimeBlockType.event,
			title: event.title,
			subtitle: event.description.isNotEmpty ? event.description : null,
			startTime: event.start,
			endTime: event.end,
			color: event.color,
			isCompleted: false,
			event: event,
		);
	}
	
	/// 从工作会话创建时间块
	factory TimeBlock.fromSession(
		WorkSessionHive session,
		ChecklistTaskHive task,
		TaskCategoryHive category, {
		SubTaskHive? subTask,
	}) {
		return TimeBlock(
			id: session.id,
			type: TimeBlockType.taskSession,
			title: task.title,  // 显示任务名称，不是"会话x"
			subtitle: subTask?.title ?? session.note,  // 子步骤名或备注
			startTime: session.startTime,
			endTime: session.endTime,
			color: category.color,  // 使用任务类别的颜色
			isCompleted: session.isCompleted,
			session: session,
			task: task,
			subTask: subTask,
		);
	}
	
	/// 获取图标
	IconData get icon {
		switch (type) {
			case TimeBlockType.event:
				return Icons.event;
			case TimeBlockType.taskSession:
				return Icons.task_alt;
		}
	}
	
	/// 是否为任务会话
	bool get isTaskSession => type == TimeBlockType.taskSession;
	
	/// 是否为普通事件
	bool get isEvent => type == TimeBlockType.event;
	
	/// 是否跨天
	bool get isMultiDay {
		final startDate = DateTime(startTime.year, startTime.month, startTime.day);
		final endDate = DateTime(endTime.year, endTime.month, endTime.day);
		return !startDate.isAtSameMomentAs(endDate);
	}
	
	/// 检查是否与指定日期相交
	bool intersects(DateTime day) {
		final d = DateTime(day.year, day.month, day.day);
		final s = DateTime(startTime.year, startTime.month, startTime.day);
		final e = DateTime(endTime.year, endTime.month, endTime.day);
		return !(d.isBefore(s) || d.isAfter(e));
	}
	
	@override
	String toString() {
		return 'TimeBlock{id: $id, type: $type, title: $title, startTime: $startTime, endTime: $endTime}';
	}
	
	@override
	bool operator ==(Object other) {
		if (identical(this, other)) return true;
		return other is TimeBlock && other.id == id && other.type == type;
	}
	
	@override
	int get hashCode => Object.hash(id, type);
}
