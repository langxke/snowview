import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class CalendarEvent {
	final String id;
	final String title;
	final bool allDay;
	final String description;
	final Color color;
	final DateTime start;
	final DateTime end;

	CalendarEvent({
		String? id,
		required this.title,
		required this.allDay,
		required this.description,
		required this.color,
		required this.start,
		required this.end,
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
	}) {
		return CalendarEvent(
			id: id, // 保持相同的ID
			title: title ?? this.title,
			allDay: allDay ?? this.allDay,
			description: description ?? this.description,
			color: color ?? this.color,
			start: start ?? this.start,
			end: end ?? this.end,
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
