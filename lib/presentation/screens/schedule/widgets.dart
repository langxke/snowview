import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'models.dart';

class EventPill extends StatelessWidget {
	final String title;
	final Color color;
	const EventPill({super.key, required this.title, required this.color});

	@override
	Widget build(BuildContext context) {
		final theme = Theme.of(context);
		return Container(
			width: double.infinity,
			margin: const EdgeInsets.only(bottom: 4),
			padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
			decoration: BoxDecoration(
				color: color.withOpacity(0.2),
				borderRadius: BorderRadius.circular(999),
			),
			child: Text(
				title,
				style: theme.textTheme.bodySmall?.copyWith(
					color: color,
					fontWeight: FontWeight.w600,
					height: 1.1,
				),
				overflow: TextOverflow.ellipsis,
				maxLines: 1,
			),
		);
	}
}

class EventList extends StatelessWidget {
	final List<CalendarEvent> events;
	final Future<void> Function(CalendarEvent event, Offset globalPosition)? onSecondaryTapEvent;
	const EventList({
		super.key,
		required this.events,
		this.onSecondaryTapEvent,
	});

	@override
	Widget build(BuildContext context) {
		final theme = Theme.of(context);
		if (events.isEmpty) return const SizedBox.shrink();
		return LayoutBuilder(
			builder: (context, constraints) {
				// 较精确估算：基于当前字体，减少保守余量，让更多条目可显示
				final double fontSize = Theme.of(context).textTheme.bodySmall?.fontSize ?? 12.0;
				final double pillHeight = fontSize + 14.0;
				final double overflowLabelHeight = fontSize + 6.0;
				const double safety = 2.0; // 更小的安全余量
				double available = (constraints.maxHeight - safety).clamp(0.0, double.infinity);
				// 初步估算最多可显示条数（不考虑"其他n个"）
				int show = (available / pillHeight).floor().clamp(0, events.length);
				// 如果会有溢出，需要为"其他n个"预留高度并重算
				if (events.length > show) {
					final double remain = (available - overflowLabelHeight).clamp(0.0, available);
					show = (remain / pillHeight).floor().clamp(0, (events.length - 1));
				}
				final int overflow = (events.length - show).clamp(0, events.length);
				final list = events.take(show).toList();
				return Column(
					mainAxisSize: MainAxisSize.min,
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						for (final e in list)
							Listener(
								behavior: HitTestBehavior.opaque,
								onPointerDown: (ev) {
									if (onSecondaryTapEvent == null) return;
									if (ev.kind != PointerDeviceKind.mouse) return;
									if (ev.buttons != kSecondaryMouseButton) return;
									onSecondaryTapEvent!(e, ev.position);
								},
								child: EventPill(title: e.title, color: e.color),
							),
						if (overflow > 0)
							Text('其他$overflow个', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
					],
				);
			},
		);
	}
}

class WeekdayLabel extends StatelessWidget {
	final String text;
	const WeekdayLabel(this.text, {super.key});

	@override
	Widget build(BuildContext context) {
		return Expanded(
			child: Center(
				child: Text('周$text', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
			),
		);
	}
}

class MiniMonthCalendar extends StatelessWidget {
	final DateTime date;
	final ValueChanged<DateTime> onSelect;
	const MiniMonthCalendar({super.key, required this.date, required this.onSelect});

	@override
	Widget build(BuildContext context) {
		final theme = Theme.of(context);
		final int year = date.year;
		final int month = date.month;
		final firstOfMonth = DateTime(year, month, 1);
		final firstWeekdayMonFirst = ((firstOfMonth.weekday + 6) % 7);
		final startDate = firstOfMonth.subtract(Duration(days: firstWeekdayMonFirst));
		const int columns = 7;
		final int daysInMonth = DateTime(year, month + 1, 0).day;
		final int weeksNeeded = ((firstWeekdayMonFirst + daysInMonth + columns - 1) ~/ columns);
		final int totalCells = weeksNeeded * columns;

		return Padding(
			padding: const EdgeInsets.all(8),
			child: Column(
				children: [
					// 月份标题
					Text('${year.toString().padLeft(4, '0')}年 ${month.toString().padLeft(2, '0')}月', style: theme.textTheme.titleSmall),
					const SizedBox(height: 8),
					// 周标题
					const Row(
						children: [
							WeekdayLabel('一'), WeekdayLabel('二'), WeekdayLabel('三'), WeekdayLabel('四'), WeekdayLabel('五'), WeekdayLabel('六'), WeekdayLabel('日'),
						],
					),
					const SizedBox(height: 4),
					// 迷你网格
					GridView.builder(
						shrinkWrap: true,
						physics: const NeverScrollableScrollPhysics(),
						gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
							crossAxisCount: 7,
							childAspectRatio: 0.8,
							mainAxisSpacing: 0,
							crossAxisSpacing: 0,
						),
						itemCount: totalCells,
						itemBuilder: (context, index) {
							final d = startDate.add(Duration(days: index));
							final inCurrentMonth = d.month == month;
							final int col = index % columns;
							final bool isLastCol = col == columns - 1;
							final bool isLastRow = index >= totalCells - columns;
							final BorderSide line = BorderSide(color: theme.dividerColor, width: 1);
							final bool isSelected = d.year == date.year && d.month == date.month && d.day == date.day;
							final Color textColor = inCurrentMonth
								? theme.colorScheme.onSurface
								: (theme.textTheme.bodyMedium?.color?.withOpacity(0.4) ?? theme.colorScheme.onSurface.withOpacity(0.4));
							return InkWell(
								onTap: () => onSelect(d),
								child: Container(
									decoration: BoxDecoration(
										color: isSelected ? theme.colorScheme.primary.withOpacity(0.08) : Colors.transparent,
										border: Border(
											top: line,
											left: line,
											right: isLastCol ? line : BorderSide.none,
											bottom: isLastRow ? line : BorderSide.none,
										),
									),
									padding: const EdgeInsets.all(6),
									child: Align(
										alignment: Alignment.topLeft,
										child: Text('${d.day}', style: TextStyle(fontSize: 12, color: textColor)),
									),
								),
							);
						},
					),
				],
			),
		);
	}
}

class DayCell extends StatelessWidget {
	final int index;
	final int totalCells;
	final int columns;
	final DateTime date;
	final bool inCurrentMonth;
	final bool isSelected;
	final List<CalendarEvent> events;
	final List<MonthPlanItem> todos;
	final Function(DateTime start, DateTime end)? onAddEvent;
	final Function(CalendarEvent event)? onDeleteEvent;
	final Future<void> Function(DateTime date, MonthPlanItem item)? onRemovePlanItem;
	final Future<void> Function(DateTime date, MonthPlanItemType type, String title)? onCreatePlanTask;
	const DayCell({
		super.key,
		required this.index,
		required this.totalCells,
		required this.columns,
		required this.date,
		required this.inCurrentMonth,
		this.isSelected = false,
		this.events = const [],
		this.todos = const [],
		this.onAddEvent,
		this.onDeleteEvent,
		this.onRemovePlanItem,
		this.onCreatePlanTask,
	});

	@override
	Widget build(BuildContext context) {
		final theme = Theme.of(context);
		final allDayTasks = events.where((e) => e.allDay).toList(growable: false);
		final timedEvents = events.where((e) => !e.allDay).toList(growable: false);
		final textColor = inCurrentMonth
			? theme.colorScheme.onSurface
			: theme.textTheme.bodyMedium?.color?.withOpacity(0.4);
		// 计算所在行列，用于只绘制上/左边线，末列和末行补齐右/下边线
		final int col = index % columns;
		final bool isLastRow = index >= totalCells - columns;

		final Color gridColor = theme.dividerColor.withOpacity(0.5);
		final BorderSide line = BorderSide(color: gridColor, width: 1);
		// overflow 将在 EventList 内部动态计算，这里无需预估

		Future<void> showDeleteMenu(CalendarEvent event, Offset globalPosition) async {
			if (onDeleteEvent == null) return;
			final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
			final selected = await showMenu<bool>(
				context: context,
				position: RelativeRect.fromLTRB(
					globalPosition.dx,
					globalPosition.dy,
					overlay.size.width - globalPosition.dx,
					overlay.size.height - globalPosition.dy,
				),
				items: const [
					PopupMenuItem<bool>(
						value: true,
						child: Row(
							children: [
								Icon(Icons.delete_outline, size: 18, color: Colors.red),
								SizedBox(width: 8),
								Text('删除', style: TextStyle(color: Colors.red)),
							],
						),
					),
				],
			);
			if (selected == true) {
				final result = onDeleteEvent!(event);
				if (result is Future) {
					await result;
				}
			}
		}

		Widget eventPillWithMenu(CalendarEvent e, Color color) {
			return Listener(
				behavior: HitTestBehavior.opaque,
				onPointerDown: (ev) {
					if (onDeleteEvent == null) return;
					if (ev.kind != PointerDeviceKind.mouse) return;
					if (ev.buttons != kSecondaryMouseButton) return;
					showDeleteMenu(e, ev.position);
				},
				child: EventPill(title: e.title, color: color),
			);
		}

		Future<void> showRemovePlanItemMenu(MonthPlanItem item, Offset globalPosition) async {
			if (onRemovePlanItem == null) return;
			final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
			final selected = await showMenu<bool>(
				context: context,
				position: RelativeRect.fromLTRB(
					globalPosition.dx,
					globalPosition.dy,
					overlay.size.width - globalPosition.dx,
					overlay.size.height - globalPosition.dy,
				),
				items: const [
					PopupMenuItem<bool>(
						value: true,
						child: Row(
							children: [
								Icon(Icons.remove_circle_outline, size: 18, color: Colors.red),
								SizedBox(width: 8),
								Text('从当天移除', style: TextStyle(color: Colors.red)),
							],
						),
					),
				],
			);
			if (selected == true) {
				await onRemovePlanItem!(date, item);
			}
		}

		Future<String?> promptTitle() async {
			final controller = TextEditingController();
			final result = await showDialog<String>(
				context: context,
				builder: (context) {
					return AlertDialog(
						title: const Text('新增任务'),
						content: TextField(
							controller: controller,
							autofocus: true,
							decoration: const InputDecoration(hintText: '输入任务标题'),
							onSubmitted: (_) => Navigator.of(context).pop(controller.text),
						),
						actions: [
							TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('取消')),
							FilledButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('添加')),
						],
					);
				},
			);
			return result?.trim();
		}

		Future<void> showCellMenu(Offset globalPosition) async {
			final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
			final selected = await showMenu<_MonthCellAction>(
				context: context,
				position: RelativeRect.fromLTRB(
					globalPosition.dx,
					globalPosition.dy,
					overlay.size.width - globalPosition.dx,
					overlay.size.height - globalPosition.dy,
				),
				items: const [
					PopupMenuItem<_MonthCellAction>(
						value: _MonthCellAction.addTodoTask,
						child: Row(
							children: [
								Icon(Icons.playlist_add, size: 18),
								SizedBox(width: 8),
								Text('新增待办'),
							],
						),
					),
					PopupMenuItem<_MonthCellAction>(
						value: _MonthCellAction.addAllDayTask,
						child: Row(
							children: [
								Icon(Icons.task_alt, size: 18),
								SizedBox(width: 8),
								Text('新增全天任务'),
							],
						),
					),
					PopupMenuDivider(),
					PopupMenuItem<_MonthCellAction>(
						value: _MonthCellAction.addEvent,
						child: Row(
							children: [
								Icon(Icons.event_available, size: 18),
								SizedBox(width: 8),
								Text('新增日程'),
							],
						),
					),
				],
			);

			if (selected == null) return;
			if (selected == _MonthCellAction.addEvent) {
				if (onAddEvent != null) {
					onAddEvent!(date, date);
				}
				return;
			}

			if (onCreatePlanTask == null) return;
			final title = await promptTitle();
			if (title == null || title.isEmpty) return;
			final type = selected == _MonthCellAction.addAllDayTask ? MonthPlanItemType.allDayTask : MonthPlanItemType.todoTask;
			await onCreatePlanTask!(date, type, title);
		}

		return Container(
			decoration: BoxDecoration(
				color: isSelected ? Colors.lightBlue.withOpacity(0.15) : Colors.transparent,
				border: Border(
					top: line,
					left: col == 0 ? BorderSide.none : line,
					right: BorderSide.none,
					bottom: isLastRow ? line : BorderSide.none,
				),
			),
			padding: const EdgeInsets.all(8),
			child: Stack(
				children: [
					Positioned.fill(
						child: Listener(
							behavior: HitTestBehavior.translucent,
							onPointerDown: (ev) {
								if (ev.kind != PointerDeviceKind.mouse) return;
								if (ev.buttons != kSecondaryMouseButton) return;
								showCellMenu(ev.position);
							},
							child: const SizedBox.expand(),
						),
					),
					Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							Row(
								children: [
									const Spacer(),
									Text('${date.day}', style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
									// 可扩展：显示当日任务计数徽标
								],
							),
							const SizedBox(height: 6),
							if (allDayTasks.isNotEmpty) ...[
								...allDayTasks.take(2).map((e) => eventPillWithMenu(e, theme.colorScheme.primary)),
								if (allDayTasks.length > 2)
									Text('任务+${allDayTasks.length - 2}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
								const SizedBox(height: 4),
							],
							if (todos.isNotEmpty) ...[
								...todos.take(2).map((t) {
									final pillColor = t.type == MonthPlanItemType.allDayTask ? theme.colorScheme.primary : theme.colorScheme.secondary;
									return Listener(
										behavior: HitTestBehavior.opaque,
										onPointerDown: (ev) {
											if (onRemovePlanItem == null) return;
											if (ev.kind != PointerDeviceKind.mouse) return;
											if (ev.buttons != kSecondaryMouseButton) return;
											showRemovePlanItemMenu(t, ev.position);
										},
										child: EventPill(title: t.title, color: pillColor),
									);
								}),
								if (todos.length > 2)
									Text('待办+${todos.length - 2}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
								const SizedBox(height: 4),
							],
							Expanded(
								child: EventList(
									events: timedEvents,
									onSecondaryTapEvent: onDeleteEvent == null ? null : showDeleteMenu,
								),
							),
						],
					),
				],
			),
		);
	}
}

enum _MonthCellAction { addTodoTask, addAllDayTask, addEvent }

class AddEventDialog extends StatefulWidget {
	final DateTime startDate;
	final DateTime endDate;
	
	const AddEventDialog({
		super.key,
		required this.startDate,
		required this.endDate,
	});

	@override
	State<AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<AddEventDialog> {
	String title = '';
	bool allDay = true;
	String desc = '';
	Color color = Colors.blue;
	TimeOfDay? startTime = const TimeOfDay(hour: 12, minute: 0); // 默认12:00
	TimeOfDay? endTime;
	
	// 生成24小时制的时间选项，每15分钟一个单位
	static List<TimeOfDay> generateTimeOptions() {
		List<TimeOfDay> times = [];
		for (int hour = 0; hour < 24; hour++) {
			for (int minute = 0; minute < 60; minute += 15) {
				times.add(TimeOfDay(hour: hour, minute: minute));
			}
		}
		return times;
	}
	
	static final List<TimeOfDay> _allTimeOptions = generateTimeOptions();
	
	// 根据开始时间过滤结束时间选项
	List<TimeOfDay> _getEndTimeOptions() {
		if (startTime == null) return _allTimeOptions;
		return _allTimeOptions.where((time) {
			final startMinutes = startTime!.hour * 60 + startTime!.minute;
			final timeMinutes = time.hour * 60 + time.minute;
			return timeMinutes > startMinutes;
		}).toList();
	}
	
	// 格式化时间显示（24小时制）
	String _formatTime(TimeOfDay time) {
		return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
	}

	@override
	Widget build(BuildContext context) {
		return AlertDialog(
			title: const Text('添加活动'),
			content: SizedBox(
				width: 360,
				child: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						TextField(
							decoration: const InputDecoration(labelText: '活动名称'),
							onChanged: (v) => title = v,
						),
						Row(
							children: [
								Checkbox(value: allDay, onChanged: (v) => setState(() => allDay = v ?? true)),
								const Text('全天活动'),
							],
						),
						if (!allDay) ...[
							const SizedBox(height: 16),
							Row(
								children: [
									Expanded(
										child: Column(
											crossAxisAlignment: CrossAxisAlignment.start,
											children: [
												const Text('开始时间', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
												const SizedBox(height: 4),
												DropdownButtonFormField<TimeOfDay>(
													initialValue: startTime,
													decoration: const InputDecoration(
														border: OutlineInputBorder(),
														contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
													),
													hint: const Text('选择开始时间'),
													items: _allTimeOptions.map((time) {
														return DropdownMenuItem(
															value: time,
															child: Text(_formatTime(time)),
														);
													}).toList(),
													onChanged: (value) {
														if (value != null) {
															setState(() {
																startTime = value;
																// 如果结束时间早于或等于新的开始时间，则调整结束时间
																if (endTime != null) {
																	final startMinutes = value.hour * 60 + value.minute;
																	final endMinutes = endTime!.hour * 60 + endTime!.minute;
																	if (endMinutes <= startMinutes) {
																		// 设置结束时间为开始时间后一小时
																		final newEndMinutes = startMinutes + 60;
																		final newHour = (newEndMinutes ~/ 60) % 24;
																		final newMinute = newEndMinutes % 60;
																		endTime = TimeOfDay(hour: newHour, minute: newMinute);
																	}
																} else {
																	// 初始化结束时间为开始时间后一小时
																	final startMinutes = value.hour * 60 + value.minute;
																	final newEndMinutes = startMinutes + 60;
																	final newHour = (newEndMinutes ~/ 60) % 24;
																	final newMinute = newEndMinutes % 60;
																	endTime = TimeOfDay(hour: newHour, minute: newMinute);
																}
															});
														}
													},
												),
											],
										),
									),
									const SizedBox(width: 16),
									Expanded(
										child: Column(
											crossAxisAlignment: CrossAxisAlignment.start,
											children: [
												const Text('结束时间', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
												const SizedBox(height: 4),
												DropdownButtonFormField<TimeOfDay>(
													initialValue: endTime,
													decoration: const InputDecoration(
														border: OutlineInputBorder(),
														contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
													),
													items: _getEndTimeOptions().map((time) {
														return DropdownMenuItem(
															value: time,
															child: Text(_formatTime(time)),
														);
													}).toList(),
													onChanged: (value) {
														if (value != null) {
															setState(() {
																endTime = value;
															});
														}
													},
												),
											],
										),
									),
								],
							),
						],
						TextField(
							decoration: const InputDecoration(labelText: '描述'),
							maxLines: 3,
							onChanged: (v) => desc = v,
						),
						const SizedBox(height: 8),
						const Align(alignment: Alignment.centerLeft, child: Text('颜色')),
						Wrap(
							spacing: 8,
							runSpacing: 8,
							children: eventColors.map((c) {
								final bool sel = c.value == color.value;
								return GestureDetector(
									onTap: () => setState(() => color = c),
									child: Container(
										width: 24,
										height: 24,
										decoration: BoxDecoration(
											color: c,
											shape: BoxShape.circle,
											border: sel ? Border.all(color: Colors.black, width: 2) : null,
										),
									),
								);
							}).toList(),
						),
					],
				),
			),
			actions: [
				TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('取消')),
				FilledButton(
					onPressed: () {
						if (title.trim().isEmpty) return;
						if (!allDay && (startTime == null || endTime == null)) return;
						
					DateTime s = widget.startDate;
					DateTime e = widget.endDate;
					if (!allDay) {
						s = DateTime(widget.startDate.year, widget.startDate.month, widget.startDate.day, startTime!.hour, startTime!.minute);
						e = DateTime(widget.endDate.year, widget.endDate.month, widget.endDate.day, endTime!.hour, endTime!.minute);
					}
					
					final event = CalendarEvent(
						title: title.trim(),
						allDay: allDay,
						description: desc.trim(),
						color: color,
						start: s,
						end: e,
					);
					
					Navigator.pop(context, event);
					},
					child: const Text('添加')
				),
			],
		);
	}
}

class DayViewAddEventDialog extends StatefulWidget {
	final DateTime date;
	final TimeOfDay startTime;
	final TimeOfDay endTime;
	
	const DayViewAddEventDialog({
		super.key,
		required this.date,
		required this.startTime,
		required this.endTime,
	});

	@override
	State<DayViewAddEventDialog> createState() => _DayViewAddEventDialogState();
}

class _DayViewAddEventDialogState extends State<DayViewAddEventDialog> {
	String title = '';
	bool allDay = false; // 日视图默认不是全天
	String desc = '';
	Color color = Colors.blue;
	late TimeOfDay startTime;
	late TimeOfDay endTime;
	
	@override
	void initState() {
		super.initState();
		startTime = widget.startTime;
		endTime = widget.endTime;
	}
	
	// 生成24小时制的时间选项，每15分钟一个单位
	static List<TimeOfDay> generateTimeOptions() {
		List<TimeOfDay> times = [];
		for (int hour = 0; hour < 24; hour++) {
			for (int minute = 0; minute < 60; minute += 15) {
				times.add(TimeOfDay(hour: hour, minute: minute));
			}
		}
		return times;
	}
	
	static final List<TimeOfDay> _allTimeOptions = generateTimeOptions();
	
	// 根据开始时间过滤结束时间选项
	List<TimeOfDay> _getEndTimeOptions() {
		return _allTimeOptions.where((time) {
			final startMinutes = startTime.hour * 60 + startTime.minute;
			final timeMinutes = time.hour * 60 + time.minute;
			return timeMinutes > startMinutes;
		}).toList();
	}
	
	// 格式化时间显示（24小时制）
	String _formatTime(TimeOfDay time) {
		return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
	}

	@override
	Widget build(BuildContext context) {
		return AlertDialog(
			title: const Text('添加活动'),
			content: SizedBox(
				width: 360,
				child: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						TextField(
							decoration: const InputDecoration(labelText: '活动名称'),
							onChanged: (v) => title = v,
						),
						Row(
							children: [
								Checkbox(value: allDay, onChanged: (v) => setState(() => allDay = v ?? false)),
								const Text('全天活动'),
							],
						),
						if (!allDay) ...[
							const SizedBox(height: 16),
							Row(
								children: [
									Expanded(
										child: Column(
											crossAxisAlignment: CrossAxisAlignment.start,
											children: [
												const Text('开始时间', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
												const SizedBox(height: 4),
												DropdownButtonFormField<TimeOfDay>(
													initialValue: startTime,
													decoration: const InputDecoration(
														border: OutlineInputBorder(),
														contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
													),
													items: _allTimeOptions.map((time) {
														return DropdownMenuItem(
															value: time,
															child: Text(_formatTime(time)),
														);
													}).toList(),
													onChanged: (value) {
														if (value != null) {
															setState(() {
																startTime = value;
																// 如果结束时间早于或等于新的开始时间，则调整结束时间
																final startMinutes = value.hour * 60 + value.minute;
																final endMinutes = endTime.hour * 60 + endTime.minute;
																if (endMinutes <= startMinutes) {
																	// 设置结束时间为开始时间后一小时
																	final newEndMinutes = startMinutes + 60;
																	final newHour = (newEndMinutes ~/ 60) % 24;
																	final newMinute = newEndMinutes % 60;
																	endTime = TimeOfDay(hour: newHour, minute: newMinute);
																}
															});
														}
													},
												),
											],
										),
									),
									const SizedBox(width: 16),
									Expanded(
										child: Column(
											crossAxisAlignment: CrossAxisAlignment.start,
											children: [
												const Text('结束时间', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
												const SizedBox(height: 4),
												DropdownButtonFormField<TimeOfDay>(
													initialValue: endTime,
													decoration: const InputDecoration(
														border: OutlineInputBorder(),
														contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
													),
													items: _getEndTimeOptions().map((time) {
														return DropdownMenuItem(
															value: time,
															child: Text(_formatTime(time)),
														);
													}).toList(),
													onChanged: (value) {
														if (value != null) {
															setState(() {
																endTime = value;
															});
														}
													},
												),
											],
										),
									),
								],
							),
						],
						TextField(
							decoration: const InputDecoration(labelText: '描述'),
							maxLines: 3,
							onChanged: (v) => desc = v,
						),
						const SizedBox(height: 8),
						const Align(alignment: Alignment.centerLeft, child: Text('颜色')),
						Wrap(
							spacing: 8,
							runSpacing: 8,
							children: eventColors.map((c) {
								final bool sel = c.value == color.value;
								return GestureDetector(
									onTap: () => setState(() => color = c),
									child: Container(
										width: 24,
										height: 24,
										decoration: BoxDecoration(
											color: c,
											shape: BoxShape.circle,
											border: sel ? Border.all(color: Colors.black, width: 2) : null,
										),
									),
								);
							}).toList(),
						),
					],
				),
			),
			actions: [
				TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('取消')),
				FilledButton(
					onPressed: () {
						if (title.trim().isEmpty) return;
						
					DateTime s = widget.date;
					DateTime e = widget.date;
					if (allDay) {
						s = DateTime(widget.date.year, widget.date.month, widget.date.day);
						e = DateTime(widget.date.year, widget.date.month, widget.date.day, 23, 59, 59);
					} else {
						s = DateTime(widget.date.year, widget.date.month, widget.date.day, startTime.hour, startTime.minute);
						e = DateTime(widget.date.year, widget.date.month, widget.date.day, endTime.hour, endTime.minute);
					}
					
					final event = CalendarEvent(
						title: title.trim(),
						allDay: allDay,
						description: desc.trim(),
						color: color,
						start: s,
						end: e,
					);
					
					Navigator.pop(context, event);
					},
					child: const Text('添加')
				),
			],
		);
	}
}
