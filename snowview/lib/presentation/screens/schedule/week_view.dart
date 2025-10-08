import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class WeekView extends StatefulWidget {
	final DateTime centerDate;
	final List<CalendarEvent> events;
	final Function(CalendarEvent) onAddEvent;
	final Function(CalendarEvent, CalendarEvent)? onUpdateEvent;
	final Function(CalendarEvent)? onDeleteEvent;
	final Function(CalendarEvent)? onSelectEvent;
	final VoidCallback? onClearSelection;
	const WeekView({
		super.key, 
		required this.centerDate, 
		required this.events,
		required this.onAddEvent,
		this.onUpdateEvent,
		this.onDeleteEvent,
		this.onSelectEvent,
		this.onClearSelection,
	});

	@override
	State<WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends State<WeekView> with CalendarStateMixin, CalendarGestureMixin {

	// ============ 实现 CalendarGestureMixin 的抽象方法 ============
	
	@override
	CalendarEvent? getEventAtPosition(double y, {DateTime? day}) {
		if (day == null) return null;
		
		final dayEvents = _getDayEvents(day);
		
		CalendarEvent? foundEvent;
		for (final event in dayEvents) {
			final startMinutes = event.start.hour * 60 + event.start.minute;
			final endMinutes = event.end.hour * 60 + event.end.minute;
			
			final startY = (startMinutes / 15) * (CalendarConstants.hourRowHeight / 4);
			final endY = (endMinutes / 15) * (CalendarConstants.hourRowHeight / 4);
			
			if (y >= startY && y <= endY) {
				foundEvent = event;
			}
		}
		
		return foundEvent;
	}
	
	@override
	DateTime getTargetDate() => widget.centerDate;
	
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
	dynamic createMoveHandler() => WeekEventMoveHandler();
	
	@override
	Future<void> showAddEventDialogImpl() async {
		if (!TimeSelectionHandler.isValidSelection(
			startQuarter: selectedStartQuarter,
			endQuarter: selectedEndQuarter,
		) || selectedColumn == null) return;
		
		final days = _weekDays(widget.centerDate);
		final selectedDay = days[selectedColumn!];
		
		// 使用handler创建时间范围
		final timeRange = TimeSelectionHandler.createTimeRange(
			date: selectedDay,
			startQuarter: selectedStartQuarter!,
			endQuarter: selectedEndQuarter!,
		);
		
		final event = await showDialog<CalendarEvent>(
			context: context,
			builder: (context) => DayViewAddEventDialog(
				date: selectedDay,
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
	double getResizeHandleHeight() => CalendarConstants.resizeHandleHeightWeek;
	
	// 覆盖移动计算方法，因为周视图需要额外的X轴参数
	@override
	MoveResult calculateMoveResult(
		dynamic handler,
		DragUpdateDetails details,
		double totalDeltaY,
	) {
		if (handler is! WeekEventMoveHandler) {
			throw StateError('Week view requires WeekEventMoveHandler');
		}
		
		// 计算X轴移动距离
		final totalDeltaX = details.globalPosition.dx - initialMoveX!;
		
		// 计算目标列
		final days = _weekDays(widget.centerDate);
		final availableWidth = currentConstraints != null 
			? currentConstraints!.maxWidth - CalendarConstants.gutterWidth 
			: MediaQuery.of(context).size.width - CalendarConstants.gutterWidth;
		final targetColumn = _getTargetColumnFromPosition(
			details.globalPosition.dx, 
			availableWidth
		);
		
		return handler.calculateMove(
			originalStartTime: initialMoveStartTime!,
			originalEndTime: initialMoveEndTime!,
			totalDeltaY: totalDeltaY,
			boundaryDate: widget.centerDate,
			previouslyMoved: hasMoved,
			totalDeltaX: totalDeltaX,
			weekDays: days,
			targetColumnIndex: targetColumn,
		);
	}
	
	// ============ 初始化和清理 ============
	
	@override
	void initState() {
		super.initState();
		initCalendarState();
	}

	@override
	void dispose() {
		disposeCalendarState();
		super.dispose();
	}

	// ============ UI 构建 ============

	@override
	Widget build(BuildContext context) {
		final theme = Theme.of(context);
		final days = _weekDays(widget.centerDate);
		bool inRange(DateTime d, DateTime a, DateTime b) {
			final dd = DateTime(d.year, d.month, d.day);
			final aa = DateTime(a.year, a.month, a.day);
			final bb = DateTime(b.year, b.month, b.day);
			return !dd.isBefore(aa) && !dd.isAfter(bb);
		}
		final allDayEvents = widget.events.where((e) => e.allDay && days.any((day) => inRange(day, e.start, e.end))).toList();
		return Focus(
			autofocus: true,
			child: KeyboardListener(
				focusNode: focusNode,
				onKeyEvent: handleKeyEvent,
				child: Column(
			children: [
				// 顶部：小时空白+周标题
				SizedBox(
					height: 40,
					child: Row(
						children: [
							const SizedBox(width: CalendarConstants.gutterWidth),
							for (final day in days)
								Expanded(
									child: Center(
										child: Text('${_weekdayShort(day.weekday)} ${day.month}/${day.day}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
									),
								),
						],
					),
				),
				const Divider(height: 1),
				// 全天行
				ConstrainedBox(
					constraints: const BoxConstraints.tightFor(height: 140),
					child: SingleAllDayRow(days: days, events: allDayEvents, gutterWidth: CalendarConstants.gutterWidth),
				),
				const Divider(height: 1),
				// 主体：按小时网格
				Expanded(
					child: SingleChildScrollView(
					child: LayoutBuilder(
						builder: (context, constraints) {
							// 缓存当前约束信息
							updateConstraints(constraints);
							return Stack(
								key: stackKey,
								children: [
										Column(
											children: List.generate(24, (hour) {
												return SizedBox(
													height: CalendarConstants.hourRowHeight,
													child: Row(
														children: [
															// 左侧小时
															Container(
																width: CalendarConstants.gutterWidth,
																alignment: Alignment.topRight,
																padding: const EdgeInsets.only(right: 8, top: 4),
																child: Text(TimeUtils.hourLabel(hour), style: theme.textTheme.bodySmall),
															),
															// 右侧7列
															Expanded(
																child: Row(
																	children: List.generate(7, (col) {
																		final bool isLastCol = col == 6;
																		final bool isFirstRow = hour == 0;
																		final bool isLastRow = hour == 23;
																		final BorderSide line = BorderSide(color: Colors.grey.withOpacity(0.5), width: 1);
																		
																		return Expanded(
																			child: Stack(
																				children: [
																					// 边框
																					Container(
																						decoration: BoxDecoration(
																							border: Border(
																								top: isFirstRow ? BorderSide.none : line,
																								left: line,
																								right: isLastCol ? line : BorderSide.none,
																								bottom: isLastRow ? BorderSide.none : BorderSide.none,
																							),
																						),
																					),
																					// 15分钟区间高亮
																					...List.generate(4, (quarter) {
																						final quarterIndex = hour * 4 + quarter;
																						final isQuarterSelected = _isQuarterSelected(quarterIndex, col);
																						final quarterHeight = CalendarConstants.hourRowHeight / 4;
																						
																						return Positioned(
																							top: quarter * quarterHeight,
																							left: 0,
																							right: 0,
																							height: quarterHeight,
																							child: Container(
																								color: isQuarterSelected ? Colors.blue.withOpacity(0.3) : Colors.transparent,
																							),
																						);
																					}),
																				],
																			),
																		);
																	}),
																),
															),
														],
													),
												);
											}),
										),
										// 活动显示层
										..._buildEventBlocks(days, constraints),
										// 空白区域手势检测层
										..._buildEmptyAreaGestureDetectors(days, constraints),
									],
								);
							}
						),
					),
				),
			],
				),
			),
		);
	}

	// ============ 辅助方法 ============
	
	String _weekdayShort(int weekday) {
		const map = {1: '一', 2: '二', 3: '三', 4: '四', 5: '五', 6: '六', 7: '日'};
		return '周${map[weekday] ?? ''}';
	}
	
	List<DateTime> _weekDays(DateTime d) {
		final int offset = (d.weekday + 6) % 7; // 周一为0
		final monday = DateTime(d.year, d.month, d.day).subtract(Duration(days: offset));
		return List<DateTime>.generate(7, (i) => monday.add(Duration(days: i)));
	}

	// 根据当前鼠标位置计算目标列
	int _getTargetColumnFromPosition(double currentGlobalX, double availableWidth) {
		// 获取Stack的全局位置
		final RenderBox? renderBox = stackKey.currentContext?.findRenderObject() as RenderBox?;
		if (renderBox == null) {
			// 如果无法获取位置，回退到简单计算
			final columnWidth = availableWidth / 7;
			return ((currentGlobalX - CalendarConstants.gutterWidth) / columnWidth).floor().clamp(0, 6);
		}
		
		final stackGlobalPosition = renderBox.localToGlobal(Offset.zero);
		
		// 计算相对于网格左边缘的位置
		final relativeX = currentGlobalX - stackGlobalPosition.dx - CalendarConstants.gutterWidth;
		
		// 计算列宽度
		final columnWidth = availableWidth / 7;
		
		// 计算目标列
		int targetColumn = (relativeX / columnWidth).floor();
		
		return targetColumn.clamp(0, 6);
	}
	
	// 判断某个15分钟段是否被选中
	bool _isQuarterSelected(int quarterIndex, int column) {
		return TimeSelectionHandler.isQuarterSelectedInColumn(
			quarterIndex: quarterIndex,
			column: column,
			selectedStartQuarter: selectedStartQuarter,
			selectedEndQuarter: selectedEndQuarter,
			selectedColumn: selectedColumn,
		);
	}
	
	// 获取某天的所有非全天活动
	List<CalendarEvent> _getDayEvents(DateTime day) {
		final currentDate = DateTime(day.year, day.month, day.day);
		final events = <CalendarEvent>[];
		
		// 获取正在操作的事件ID
		final movingEventId = isMoving ? movingEvent?.id : null;
		final resizingEventId = isResizing ? resizingEvent?.id : null;
		
		// 一次遍历处理所有逻辑
		for (final event in widget.events) {
			if (event.allDay) continue;
			
			final eventDate = DateTime(event.start.year, event.start.month, event.start.day);
			if (!eventDate.isAtSameMomentAs(currentDate)) continue;
			
			// 跳过正在操作的原始事件
			if ((movingEventId != null && event.id == movingEventId) ||
			    (resizingEventId != null && event.id == resizingEventId)) {
				continue;
			}
			
			events.add(event);
		}
		
		// 添加正在操作的事件到新位置
		if (isMoving && movingEvent != null) {
			final movingDate = DateTime(movingEvent!.start.year, movingEvent!.start.month, movingEvent!.start.day);
			if (movingDate.isAtSameMomentAs(currentDate)) {
				events.add(movingEvent!);
			}
		}
		
		if (isResizing && resizingEvent != null) {
			final resizingDate = DateTime(resizingEvent!.start.year, resizingEvent!.start.month, resizingEvent!.start.day);
			if (resizingDate.isAtSameMomentAs(currentDate)) {
				events.add(resizingEvent!);
			}
		}
		
		return events;
	}
	
	// 构建活动显示块
	List<Widget> _buildEventBlocks(List<DateTime> days, BoxConstraints constraints) {
		final List<Widget> eventWidgets = [];
		
		for (int dayIndex = 0; dayIndex < days.length; dayIndex++) {
			final day = days[dayIndex];
			final dayEvents = _getDayEvents(day);
			final availableWidth = constraints.maxWidth - CalendarConstants.gutterWidth;
			final columnWidth = availableWidth / 7;
			
			for (final event in dayEvents) {
				// 计算活动在时间轴上的位置
				final startY = TimeUtils.timeToY(event.start);
				final endY = TimeUtils.timeToY(event.end);
				final height = endY - startY;
				final isSelected = selectedEventId != null && selectedEventId == EventUtils.getId(event);
				
				// 计算X坐标位置
				final leftOffset = CalendarConstants.gutterWidth + dayIndex * columnWidth;
				
				// 创建活动块
				eventWidgets.add(
					CalendarEventBlock(
						event: event,
						isSelected: isSelected,
						height: height,
						leftOffset: leftOffset + 1,
						width: columnWidth - 2,
						topPosition: startY,
						resizeHandleHeight: CalendarConstants.resizeHandleHeightWeek,
						showResizeHandles: true,  // ✅ 总是显示手柄（与日视图一致）
						onTopResizeStart: (details) => onResizeStartImpl(event, true, details),
						onTopResizeUpdate: onResizeUpdateImpl,
						onTopResizeEnd: onResizeEndImpl,
						onBottomResizeStart: (details) => onResizeStartImpl(event, false, details),
						onBottomResizeUpdate: onResizeUpdateImpl,
						onBottomResizeEnd: onResizeEndImpl,
					),
				);
			}
		}
		
		return eventWidgets;
	}
	
	// 构建手势检测器
	List<Widget> _buildEmptyAreaGestureDetectors(List<DateTime> days, BoxConstraints constraints) {
		return List.generate(7, (dayIndex) {
			final availableWidth = constraints.maxWidth - CalendarConstants.gutterWidth;
			final columnWidth = availableWidth / 7;
			final leftOffset = CalendarConstants.gutterWidth + dayIndex * columnWidth;
			
			return Positioned(
				left: leftOffset,
				width: columnWidth,
				top: 0,
				height: 24 * CalendarConstants.hourRowHeight,
				child: MouseRegion(
					cursor: getCurrentCursor(),
					onHover: (event) => onHoverImpl(event, dayIndex: dayIndex),
					child: GestureDetector(
						behavior: HitTestBehavior.translucent,
						onTapDown: (details) => onTapDownImpl(details, dayIndex: dayIndex),
						onPanStart: (details) => onPanStartImpl(details, day: days[dayIndex], dayIndex: dayIndex),
						onPanUpdate: onPanUpdateImpl,
						onPanEnd: onPanEndImpl,
						onTap: () => onTapImpl(day: days[dayIndex]),
						onSecondaryTapDown: (details) => onSecondaryTapDownImpl(details, day: days[dayIndex]),
						child: Container(color: Colors.transparent),
					),
				),
			);
		});
	}
}
