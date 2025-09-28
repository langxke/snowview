import 'package:flutter/material.dart';

class CalendarEvent {
	final String title;
	final bool allDay;
	final String description;
	final Color color;
	final DateTime start;
	final DateTime end;

	CalendarEvent({
		required this.title,
		required this.allDay,
		required this.description,
		required this.color,
		required this.start,
		required this.end,
	});

	bool intersects(DateTime day) {
		final d = DateTime(day.year, day.month, day.day);
		final s = DateTime(start.year, start.month, start.day);
		final e = DateTime(end.year, end.month, end.day);
		return !(d.isBefore(s) || d.isAfter(e));
	}
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
