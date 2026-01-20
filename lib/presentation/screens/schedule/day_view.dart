import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models.dart';
import 'all_day_row.dart';
import 'widgets.dart';
import 'shared/utils/constants.dart';
import 'shared/utils/time_utils.dart';
import 'shared/utils/event_utils.dart';
import 'shared/widgets/event_block.dart';
import 'shared/handlers/event_move_handler.dart';
import 'shared/handlers/time_selection_handler.dart';
import 'shared/mixins/calendar_state_mixin.dart';
import 'shared/mixins/calendar_gesture_mixin.dart';
import 'now_indicator_painter.dart';
import '../../providers/task_list_provider.dart';
import '../../providers/daily_plan_provider.dart';
import '../../../data/models/daily_plan_hive.dart';

class DayView extends StatefulWidget {
	final DateTime date;
	final List<CalendarEvent> events;
	final Function(CalendarEvent) onAddEvent;
	final Function(CalendarEvent, CalendarEvent)? onUpdateEvent;
	final Function(CalendarEvent)? onDeleteEvent;
	final Function(CalendarEvent)? onSelectEvent;
	final VoidCallback? onClearSelection;
	const DayView({
		super.key, 
		required this.date, 
		required this.events, 
		required this.onAddEvent,
		this.onUpdateEvent,
		this.onDeleteEvent,
		this.onSelectEvent,
		this.onClearSelection,
	});

	@override
	State<DayView> createState() => _DayViewState();
}

class _DayViewState extends State<DayView> with CalendarStateMixin, CalendarGestureMixin {
	bool _isTodayTasksExpanded = true;
	bool _isTodayTodosExpanded = true;
	Timer? _nowTimer;
	DateTime _now = DateTime.now();
	final ValueNotifier<DateTime> _nowVN = ValueNotifier<DateTime>(DateTime.now());

	bool get _isViewingToday {
		final n = DateTime.now();
		final today = DateTime(n.year, n.month, n.day);
		final d = DateTime(widget.date.year, widget.date.month, widget.date.day);
		return d.year == today.year && d.month == today.month && d.day == today.day;
	}
	
	// ============ 实现 CalendarGestureMixin 的抽象方法 ============
	
	@override
	CalendarEvent? getEventAtPosition(double y, {DateTime? day}) {
		final dayEvents = _getDayEvents();
		
		CalendarEvent? foundEvent;
		for (final event in dayEvents) {
			// 计算活动在时间轴上的位置
			final startMinutes = event.start.hour * 60 + event.start.minute;
			final endMinutes = event.end.hour * 60 + event.end.minute;
			
			// 转换为Y坐标
			final startY = (startMinutes / 15) * (CalendarConstants.hourRowHeight / 4);
			final endY = (endMinutes / 15) * (CalendarConstants.hourRowHeight / 4);
			
			// 检查点击位置是否在这个活动范围内
			if (y >= startY && y <= endY) {
				foundEvent = event;
				// 继续循环以找到最后一个匹配的活动（处理重叠情况）
			}
		}
		
		return foundEvent;
	}
	
	@override
	DateTime getTargetDate() => widget.date;
	
	@override
	List<CalendarEvent> getEvents() => widget.events;
	
	@override
	Function(CalendarEvent) get onAddEvent => widget.onAddEvent;
	
	@override
	Function(CalendarEvent, CalendarEvent)? get onUpdateEvent => widget.onUpdateEvent;
	
	@override
	Function(CalendarEvent)? get onDeleteEvent => widget.onDeleteEvent;
	
	@override
	Function(CalendarEvent)? get onSelectEvent => widget.onSelectEvent;
	
	@override
	VoidCallback? get onClearSelection => widget.onClearSelection;
	
	@override
	dynamic createMoveHandler() => DayEventMoveHandler();
	
	@override
	Future<void> showAddEventDialogImpl() async {
		if (!TimeSelectionHandler.isValidSelection(
			startQuarter: selectedStartQuarter,
			endQuarter: selectedEndQuarter,
		)) {
			return;
		}
		
		// 使用handler创建时间范围
		final timeRange = TimeSelectionHandler.createTimeRange(
			date: widget.date,
			startQuarter: selectedStartQuarter!,
			endQuarter: selectedEndQuarter!,
		);
		
		final event = await showDialog<CalendarEvent>(
			context: context,
			builder: (context) => DayViewAddEventDialog(
				date: widget.date,
				startTime: TimeOfDay.fromDateTime(timeRange.start),
				endTime: TimeOfDay.fromDateTime(timeRange.end),
			),
		);
		
		if (event != null) {
			widget.onAddEvent(event);
		}
		
		clearSelection(onClearSelection: widget.onClearSelection);
	}
	
	@override
	double getResizeHandleHeight() => CalendarConstants.resizeHandleHeightDay;
	
	// ============ 初始化和清理 ============
	
	@override
	void initState() {
		super.initState();
		initCalendarState();
		_updateNowTimer();
	}

	@override
	void didUpdateWidget(covariant DayView oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (oldWidget.date.year != widget.date.year || oldWidget.date.month != widget.date.month || oldWidget.date.day != widget.date.day) {
			_updateNowTimer();
		}
	}

	@override
	void dispose() {
		_nowTimer?.cancel();
		_nowVN.dispose();
		disposeCalendarState();
		super.dispose();
	}

	// ============ UI 构建 ============
	
	@override
	Widget build(BuildContext context) {
		final theme = Theme.of(context);
		bool inRange(DateTime d, DateTime a, DateTime b) {
			final dd = DateTime(d.year, d.month, d.day);
			final aa = DateTime(a.year, a.month, a.day);
			final bb = DateTime(b.year, b.month, b.day);
			return !dd.isBefore(aa) && !dd.isAfter(bb);
		}
		final taskListProvider = context.watch<TaskListProvider>();
		return Focus(
			autofocus: true,
			child: KeyboardListener(
				focusNode: focusNode,
				onKeyEvent: handleKeyEvent,
				child: Column(
			children: [
				// 顶部：日期标题
				SizedBox(
					height: 40,
					child: Row(
						children: [
							const SizedBox(width: CalendarConstants.gutterWidth),
							Expanded(
								child: Center(
									child: Text('${widget.date.year}-${widget.date.month}-${widget.date.day}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
								),
							),
						],
					),
				),
				const Divider(height: 1),
				// 全天行 & 待办行 (使用 DailyPlanProvider)
				FutureBuilder<DailyPlanHive>(
					future: context.read<DailyPlanProvider>().getPlanForDate(widget.date),
					builder: (context, snapshot) {
						final plan = snapshot.data;
						final planAllDayTaskIds = plan?.allDayTaskIds ?? [];
						
						// 1. 准备全天任务 (Legacy Events + Plan Tasks)
						final legacyAllDay = widget.events.where((e) => e.allDay && inRange(widget.date, e.start, e.end) && !planAllDayTaskIds.contains(e.id)).toList();
						final planAllDayEvents = planAllDayTaskIds.map((id) {
							final t = taskListProvider.getTaskById(id);
							if (t == null) return null;
							return CalendarEvent(
								id: t.id,
								title: t.title,
								description: t.description ?? '',
								allDay: true,
								start: widget.date,
								end: widget.date,
								color: Colors.blue, // 默认颜色，后续可从 Task 读取优先级颜色
								isCompleted: t.isCompleted,
							);
						}).whereType<CalendarEvent>().toList();
						
						final combinedAllDay = [...legacyAllDay, ...planAllDayEvents];

						// 2. 准备今日待办 (Plan Todos)
						final planTodoIds = plan?.todoTaskIds ?? [];
						final planTodoTitles = planTodoIds.map((id) {
							 final t = taskListProvider.getTaskById(id);
							 return t?.title;
						}).whereType<String>().toList();

						return Column(
							children: [
								SingleAllDayRow(
									days: [widget.date],
									events: combinedAllDay,
									gutterWidth: CalendarConstants.gutterWidth,
									minHeight: 140,
									maxHeight: 220,
									isExpanded: _isTodayTasksExpanded,
									onToggleExpanded: () => setState(() => _isTodayTasksExpanded = !_isTodayTasksExpanded),
								),
								const Divider(height: 1),
								SingleTodoRow(
									days: [widget.date],
									todos: [planTodoTitles],
									gutterWidth: CalendarConstants.gutterWidth,
									minHeight: 64,
									maxHeight: 180,
									isExpanded: _isTodayTodosExpanded,
									onToggleExpanded: () => setState(() => _isTodayTodosExpanded = !_isTodayTodosExpanded),
								),
							],
						);
					},
				),
				const Divider(height: 1),
				Expanded(
					child: SingleChildScrollView(
						child: Stack(
							children: [
								Column(
									children: List.generate(24, (hour) {
										final bool isFirstRow = hour == 0;
										final bool isLastRow = hour == 23;
										final BorderSide line = BorderSide(color: Colors.grey.withAlpha(128), width: 1);
										
										return SizedBox(
											height: CalendarConstants.hourRowHeight,
											child: Row(
												children: [
													// 时间标签区域
													Container(
														width: CalendarConstants.gutterWidth,
														alignment: Alignment.topRight,
														padding: const EdgeInsets.only(right: 8, top: 4),
														child: Text(TimeUtils.hourLabel(hour), style: theme.textTheme.bodySmall),
													),
													// 时间段选择区域
													Expanded(
														child: Stack(
															children: [
																// 边框
																Container(
																	decoration: BoxDecoration(
																		border: Border(
																			top: isFirstRow ? BorderSide.none : line,
																			left: line,
																			right: line,
																			bottom: isLastRow ? BorderSide.none : BorderSide.none,
																		),
																	),
																),
																// 15分钟区间高亮
																...List.generate(4, (quarter) {
																	final quarterIndex = hour * 4 + quarter;
																	final isQuarterSelected = _isQuarterSelected(quarterIndex);
																	final quarterHeight = CalendarConstants.hourRowHeight / 4;
																	
																	return Positioned(
																		top: quarter * quarterHeight,
																		left: 0,
																		right: 0,
																		height: quarterHeight,
																		child: Container(
																			color: isQuarterSelected ? Colors.blue.withAlpha(77) : Colors.transparent,
																		),
																	);
																}),
															],
														),
													),
												],
											),
										);
									}),
								),
								// 活动显示层
								..._buildEventBlocks(),
								// 空白区域手势检测层
								..._buildEmptyAreaGestureDetectors(),
								if (_isViewingToday)
									Positioned.fill(
										child: NowIndicatorPaintLayer(
											nowListenable: _nowVN,
											showLine: true,
											showThickTodayLine: false,
											gutterWidth: CalendarConstants.gutterWidth,
										),
									),
							],
						),
					),
				),
			],
				),
			),
		);
	}
	
	void _updateNowTimer() {
		_nowTimer?.cancel();
		_nowTimer = null;
		if (!_isViewingToday) {
			return;
		}
		final now = DateTime.now();
		final nextMinute = DateTime(now.year, now.month, now.day, now.hour, now.minute).add(const Duration(minutes: 1));
		final delay = nextMinute.difference(now);
		_nowTimer = Timer(delay, () {
			if (!mounted) return;
			final n = DateTime.now();
			_now = n;
			_nowVN.value = n;
			_nowTimer = Timer.periodic(const Duration(minutes: 1), (_) {
				if (!mounted) return;
				if (!_isViewingToday) {
					_nowTimer?.cancel();
					_nowTimer = null;
					return;
				}
				final nn = DateTime.now();
				final prev = _now;
				if (nn.year == prev.year && nn.month == prev.month && nn.day == prev.day && nn.hour == prev.hour && nn.minute == prev.minute) {
					return;
				}
				_now = nn;
				_nowVN.value = nn;
			});
		});
	}
	
	// ============ 辅助方法 ============
	
	// 判断某个15分钟段是否被选中
	bool _isQuarterSelected(int quarterIndex) {
		return TimeSelectionHandler.isQuarterSelected(
			quarterIndex: quarterIndex,
			selectedStartQuarter: selectedStartQuarter,
			selectedEndQuarter: selectedEndQuarter,
		);
	}
	
	// 获取当前日期的所有非全天活动
	List<CalendarEvent> _getDayEvents() {
		final currentDate = DateTime(widget.date.year, widget.date.month, widget.date.day);
		
		// 1. 获取通过 props 传入的事件（可能来自外部查询）
		final events = widget.events.where((e) => !e.allDay).toList();
		
		final resultEvents = <CalendarEvent>[];
		
		// 获取正在操作的事件ID
		final movingEventId = isMoving ? movingEvent?.id : null;
		final resizingEventId = isResizing ? resizingEvent?.id : null;
		
		// 一次遍历处理所有逻辑
		for (final event in events) {
			final eventDate = DateTime(event.start.year, event.start.month, event.start.day);
			if (!eventDate.isAtSameMomentAs(currentDate)) continue;
			
			// 跳过正在操作的原始事件
			if ((movingEventId != null && event.id == movingEventId) ||
			    (resizingEventId != null && event.id == resizingEventId)) {
				continue;
			}
			
			resultEvents.add(event);
		}
		
		// 添加正在操作的事件到新位置
		if (isMoving && movingEvent != null) {
			final movingDate = DateTime(movingEvent!.start.year, movingEvent!.start.month, movingEvent!.start.day);
			if (movingDate.isAtSameMomentAs(currentDate)) {
				resultEvents.add(movingEvent!);
			}
		}
		
		if (isResizing && resizingEvent != null) {
			final resizingDate = DateTime(resizingEvent!.start.year, resizingEvent!.start.month, resizingEvent!.start.day);
			if (resizingDate.isAtSameMomentAs(currentDate)) {
				resultEvents.add(resizingEvent!);
			}
		}
		
		return resultEvents;
	}
	
	// 构建活动显示块
	List<Widget> _buildEventBlocks() {
		final dayEvents = _getDayEvents();
		final List<Widget> eventWidgets = [];
		
		for (final event in dayEvents) {
			// 计算活动在时间轴上的位置
			final startY = TimeUtils.timeToY(event.start);
			final endY = TimeUtils.timeToY(event.end);
			final height = endY - startY;
			final isSelected = selectedEventId != null && selectedEventId == EventUtils.getId(event);
			
			// 创建活动块
			eventWidgets.add(
				CalendarEventBlock(
					event: event,
					isSelected: isSelected,
					height: height,
					leftOffset: CalendarConstants.gutterWidth,
					rightOffset: 0,
					topPosition: startY,
					resizeHandleHeight: CalendarConstants.resizeHandleHeightDay,
					showResizeHandles: true,
					onTopResizeStart: (details) => onResizeStartImpl(event, true, details),
					onTopResizeUpdate: onResizeUpdateImpl,
					onTopResizeEnd: onResizeEndImpl,
					onBottomResizeStart: (details) => onResizeStartImpl(event, false, details),
					onBottomResizeUpdate: onResizeUpdateImpl,
					onBottomResizeEnd: onResizeEndImpl,
				),
			);
		}
		
		return eventWidgets;
	}
	
	// 构建背景手势检测器
	List<Widget> _buildEmptyAreaGestureDetectors() {
		return [
			Positioned.fill(
				left: CalendarConstants.gutterWidth,
				child: MouseRegion(
					cursor: getCurrentCursor(),
					onHover: (event) => onHoverImpl(event),
					child: GestureDetector(
						behavior: HitTestBehavior.translucent,
						onTapDown: (details) => onTapDownImpl(details),
						onPanStart: (details) => onPanStartImpl(details),
						onPanUpdate: onPanUpdateImpl,
						onPanEnd: onPanEndImpl,
						onTap: () => onTapImpl(),
						onSecondaryTapDown: (details) => onSecondaryTapDownImpl(details),
						child: Container(color: Colors.transparent),
					),
				),
			),
		];
	}
}
