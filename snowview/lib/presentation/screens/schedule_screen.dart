import 'package:flutter/material.dart';
import 'dart:math' as math;

import 'schedule/models.dart';
import 'schedule/widgets.dart';
import 'schedule/day_view.dart';
import 'schedule/week_view.dart';
import 'schedule/month_view.dart';
import 'schedule/event_sidebar.dart';

class ScheduleScreen extends StatefulWidget {
	const ScheduleScreen({super.key});

	@override
	State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
	CalendarView _view = CalendarView.month;
	late int _year;
	late int _month; // 1-12
	DateTime _selected = DateTime.now();
	final List<CalendarEvent> _events = [];
	CalendarEvent? _selectedEvent;

	static const int _yearRange = 10; // 当前年 ±10 年

	@override
	void initState() {
		super.initState();
		final now = DateTime.now();
		_year = now.year;
		_month = now.month;
	}

	@override
	Widget build(BuildContext context) {
		return Column(
			children: [
				_buildHeader(context),
				const Divider(height: 1),
				Expanded(
					child: Row(
						children: [
							// 左侧边栏：迷你月历 + 活动详情
							SizedBox(
								width: 280,
								child: Column(
									children: [
										// 迷你月历
										SizedBox(
											height: 325,
											child: MiniMonthCalendar(
												date: _selected, 
												onSelect: _onSelectDate,
											),
										),
										const Divider(height: 1),
										// 活动侧边栏
										Expanded(
											child: EventSidebar(
												selectedDate: _selected,
												selectedEvent: _selectedEvent,
												onAddEvent: () => _openAddEventDialog(
													_selected,
													DateTime(_selected.year, _selected.month, _selected.day, DateTime.now().hour + 1),
												),
												onEditEvent: _editEvent,
												onDeleteEvent: _deleteEvent,
												onClearSelection: () => setState(() => _selectedEvent = null),
											),
										),
									],
								),
							),
							const VerticalDivider(width: 1),
							// 右侧主视图
							Expanded(child: _buildMainCalendarArea(context)),
						],
					),
				),
			],
		);
	}

	Widget _buildHeader(BuildContext context) {
		final years = List<int>.generate(
			_yearRange * 2 + 1, (i) => DateTime.now().year - _yearRange + i,
		);
		final months = List<int>.generate(12, (i) => i + 1);

		return Padding(
			padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
			child: Row(
				children: [
					IconButton(
						tooltip: '上一月',
						icon: const Icon(Icons.chevron_left),
						onPressed: _prevMonth,
					),
					DropdownButton<int>(
						value: _year,
						items: years
							.map((y) => DropdownMenuItem<int>(value: y, child: Text('$y 年')))
							.toList(),
						onChanged: (v) => setState(() => _year = v ?? _year),
					),
					const SizedBox(width: 8),
					DropdownButton<int>(
						value: _month,
						items: months
							.map((m) => DropdownMenuItem<int>(value: m, child: Text('$m 月')))
							.toList(),
						onChanged: (v) => setState(() => _month = v ?? _month),
					),
					IconButton(
						tooltip: '下一月',
						icon: const Icon(Icons.chevron_right),
						onPressed: _nextMonth,
					),
					const Spacer(),
					// 视图切换
					ToggleButtons(
						isSelected: [
							_view == CalendarView.day,
							_view == CalendarView.week,
							_view == CalendarView.month,
						],
						onPressed: (i) {
							setState(() {
								switch (i) {
									case 0:
										_view = CalendarView.day;
										break;
									case 1:
										_view = CalendarView.week;
										break;
									case 2:
										_view = CalendarView.month;
										break;
								}
							});
						},
						children: const [
							Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('日')),
							Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('周')),
							Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('月')),
						],
					),
					const SizedBox(width: 12),
					TextButton.icon(
						icon: const Icon(Icons.today_outlined),
						label: const Text('今日'),
						onPressed: _goToday,
					),
					const SizedBox(width: 4),
					IconButton(
						tooltip: _stepTooltip(false),
						icon: const Icon(Icons.chevron_left),
						onPressed: () => _stepView(-1),
					),
					IconButton(
						tooltip: _stepTooltip(true),
						icon: const Icon(Icons.chevron_right),
						onPressed: () => _stepView(1),
					),
				],
			),
		);
	}

	// 主区域：根据模式切换
	Widget _buildMainCalendarArea(BuildContext context) {
		switch (_view) {
			case CalendarView.day:
				return DayView(
					date: _selected, 
					events: _events,
					onAddEvent: (event) => setState(() => _events.add(event)),
					onUpdateEvent: (oldEvent, newEvent) {
						setState(() {
							final index = _events.indexOf(oldEvent);
							if (index != -1) {
								_events[index] = newEvent;
								// 如果更新的是当前选中的活动，同时更新选中活动引用
								if (_selectedEvent == oldEvent) {
									_selectedEvent = newEvent;
								}
							}
						});
					},
					onDeleteEvent: (event) {
						setState(() {
							_events.remove(event);
						});
					},
					onSelectEvent: (event) => setState(() => _selectedEvent = event),
					onClearSelection: () => setState(() => _selectedEvent = null),
				);
			case CalendarView.week:
				return WeekView(
					centerDate: _selected, 
					events: _events,
					onAddEvent: (event) => setState(() => _events.add(event)),
					onUpdateEvent: (oldEvent, newEvent) {
						setState(() {
							final index = _events.indexOf(oldEvent);
							if (index != -1) {
								_events[index] = newEvent;
								// 如果更新的是当前选中的活动，同时更新选中活动引用
								if (_selectedEvent == oldEvent) {
									_selectedEvent = newEvent;
								}
							}
						});
					},
					onDeleteEvent: (event) {
						setState(() {
							_events.remove(event);
						});
					},
					onSelectEvent: (event) => setState(() => _selectedEvent = event),
					onClearSelection: () => setState(() => _selectedEvent = null),
				);
			case CalendarView.month:
				return MonthView(
					year: _year,
					month: _month,
					events: _events,
					onAddEvent: _openAddEventDialog,
				);
		}
	}

	void _onSelectDate(DateTime d) {
		setState(() {
			_selected = d;
			_year = d.year;
			_month = d.month;
			_selectedEvent = null; // 切换日期时清除选中的活动
		});
	}

	void _goToday() {
		final now = DateTime.now();
		setState(() {
			_selected = DateTime(now.year, now.month, now.day);
			_year = now.year;
			_month = now.month;
		});
	}

	Future<void> _openAddEventDialog(DateTime start, DateTime end) async {
		final event = await showDialog<CalendarEvent>(
			context: context,
			builder: (context) => AddEventDialog(startDate: start, endDate: end),
		);
		
		if (event != null) {
			setState(() {
				_events.add(event);
			});
		}
	}

	String _stepTooltip(bool next) {
		switch (_view) {
			case CalendarView.day:
				return next ? '下一天' : '前一天';
			case CalendarView.week:
				return next ? '下一周' : '上一周';
			case CalendarView.month:
				return next ? '下一月' : '上一月';
		}
	}

	void _stepView(int delta) {
		setState(() {
			if (_view == CalendarView.day) {
				_selected = DateTime(_selected.year, _selected.month, _selected.day + delta);
				_year = _selected.year;
				_month = _selected.month;
			} else if (_view == CalendarView.week) {
				_selected = DateTime(_selected.year, _selected.month, _selected.day + 7 * delta);
				_year = _selected.year;
				_month = _selected.month;
			} else {
				final newMonth = _month + delta;
				final newYear = _year + ((newMonth - 1) ~/ 12);
				final monthNorm = ((newMonth - 1) % 12) + 1;
				final days = DateTime(newYear, monthNorm + 1, 0).day;
				final safeDay = math.min(_selected.day, days);
				_year = newYear;
				_month = monthNorm;
				_selected = DateTime(_year, _month, safeDay);
			}
		});
	}

	void _prevMonth() {
		setState(() {
			if (_month == 1) {
				_month = 12;
				_year -= 1;
			} else {
				_month -= 1;
			}
			final days = DateTime(_year, _month + 1, 0).day;
			final safeDay = math.min(_selected.day, days);
			_selected = DateTime(_year, _month, safeDay);
		});
	}

	void _nextMonth() {
		setState(() {
			if (_month == 12) {
				_month = 1;
				_year += 1;
			} else {
				_month += 1;
			}
			final days = DateTime(_year, _month + 1, 0).day;
			final safeDay = math.min(_selected.day, days);
			_selected = DateTime(_year, _month, safeDay);
		});
	}


	void _editEvent(CalendarEvent updatedEvent) {
		setState(() {
			// 找到原活动的索引
			final index = _events.indexWhere((e) => 
				e.title == _selectedEvent?.title &&
				e.start == _selectedEvent?.start &&
				e.end == _selectedEvent?.end
			);
			
			if (index != -1) {
				// 更新活动数据
				_events[index] = updatedEvent;
				// 更新选中的活动引用
				_selectedEvent = updatedEvent;
			}
		});
	}

	void _deleteEvent(CalendarEvent event) {
		showDialog(
			context: context,
			builder: (context) => AlertDialog(
				title: const Text('删除活动'),
				content: Text('确定要删除活动"${event.title}"吗？'),
				actions: [
					TextButton(
						onPressed: () => Navigator.of(context).pop(),
						child: const Text('取消'),
					),
					TextButton(
						onPressed: () {
							setState(() {
								_events.remove(event);
								if (_selectedEvent == event) {
									_selectedEvent = null;
								}
							});
							Navigator.of(context).pop();
						},
						style: TextButton.styleFrom(
							foregroundColor: Theme.of(context).colorScheme.error,
						),
						child: const Text('删除'),
					),
				],
			),
		);
	}
}