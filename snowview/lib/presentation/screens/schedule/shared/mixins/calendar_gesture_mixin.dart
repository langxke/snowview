import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models.dart';
import 'calendar_state_mixin.dart';
import '../utils/constants.dart';
import '../utils/time_utils.dart';
import '../handlers/event_resize_handler.dart';
import '../handlers/event_move_handler.dart';
import '../handlers/keyboard_handler.dart';
import '../widgets/event_context_menu.dart';

/// 日历视图的手势协调 Mixin
/// 
/// 提供统一的手势处理方法，协调三种操作模式：
/// 1. 时间段选择
/// 2. 事件移动
/// 3. 事件调整大小
mixin CalendarGestureMixin<T extends StatefulWidget> on State<T>, CalendarStateMixin<T> {
	
	// ============ 抽象方法（由子类实现）============
	
	/// 获取指定位置的事件
	CalendarEvent? getEventAtPosition(double y, {DateTime? day});
	
	/// 获取当前日期（日视图）或中心日期（周视图）
	DateTime getTargetDate();
	
	/// 获取事件列表
	List<CalendarEvent> getEvents();
	
	/// 添加事件回调
	Function(CalendarEvent) get onAddEvent;
	
	/// 更新事件回调
	Function(CalendarEvent, CalendarEvent)? get onUpdateEvent;
	
	/// 删除事件回调
	Function(CalendarEvent)? get onDeleteEvent;
	
	/// 选择事件回调
	Function(CalendarEvent)? get onSelectEvent;
	
	/// 清除选择回调
	VoidCallback? get onClearSelection;
	
	/// 创建移动处理器（日视图/周视图不同）
	dynamic createMoveHandler();
	
	/// 显示添加事件对话框
	Future<void> showAddEventDialogImpl();
	
	// ============ 键盘事件处理 ============
	
	/// 处理键盘事件
	void handleKeyEvent(KeyEvent event) {
		CalendarKeyboardHandler.handleKeyEvent(
			event: event,
			selectedEvent: selectedEvent,
			onDelete: deleteSelectedEvent,
		);
	}
	
	/// 删除选中的事件
	void deleteSelectedEvent() {
		if (CalendarKeyboardHandler.canDeleteEvent(
			selectedEvent: selectedEvent,
			onDeleteEvent: onDeleteEvent,
		)) {
			CalendarKeyboardHandler.deleteEvent(
				selectedEvent: selectedEvent!,
				onDeleteEvent: onDeleteEvent!,
				onClearSelection: () => clearSelection(onClearSelection: onClearSelection),
			);
		}
	}
	
	// ============ 鼠标悬停处理 ============
	
	/// 鼠标悬停处理
	void onHoverImpl(PointerHoverEvent event, {int? dayIndex}) {
		final newY = event.localPosition.dy;
		if (currentHoverY != newY || (dayIndex != null && currentHoverDayIndex != dayIndex)) {
			updateHoverPosition(y: newY, dayIndex: dayIndex);
		}
	}
	
	/// 获取当前光标样式
	SystemMouseCursor getCurrentCursor() {
		// 如果正在调整大小，保持上下箭头样式
		if (isResizing) {
			return SystemMouseCursors.resizeUpDown;
		}
		
		if (currentHoverY == null) return SystemMouseCursors.basic;
		
		// 检查是否在调整手柄区域
		final event = getEventAtPosition(currentHoverY!);
		if (event != null && selectedEvent == event) {
			final eventStartMinutes = event.start.hour * 60 + event.start.minute;
			final eventStartY = (eventStartMinutes / 15) * (CalendarConstants.hourRowHeight / 4);
			final relativeY = currentHoverY! - eventStartY;
			final eventHeight = (event.end.difference(event.start).inMinutes / 15) * (CalendarConstants.hourRowHeight / 4);
			
			// 根据视图类型选择不同的手柄高度
			final handleHeight = getResizeHandleHeight();
			
			// 检查是否在调整手柄区域
			if (eventHeight > handleHeight * 2) {
				if (relativeY <= handleHeight || relativeY >= eventHeight - handleHeight) {
					return SystemMouseCursors.resizeUpDown;
				}
			}
		}
		
		return SystemMouseCursors.basic;
	}
	
	// ============ 点击处理 ============
	
	/// 处理点击按下
	void onTapDownImpl(TapDownDetails details, {int? dayIndex}) {
		lastTapY = details.localPosition.dy;
	}
	
	/// 处理单击
	void onTapImpl({DateTime? day}) {
		if (lastTapY == null) {
			clearSelection(onClearSelection: onClearSelection);
			return;
		}
		
		// 检查是否点击了活动块
		final event = getEventAtPosition(lastTapY!, day: day);
		if (event != null) {
			selectEvent(event, onSelectEvent: onSelectEvent);
		} else {
			clearSelection(onClearSelection: onClearSelection);
		}
	}
	
	/// 处理右键点击
	void onSecondaryTapDownImpl(TapDownDetails details, {DateTime? day}) {
		final event = getEventAtPosition(details.localPosition.dy, day: day);
		if (event != null) {
			selectEvent(event, onSelectEvent: onSelectEvent);
			EventContextMenu.show(
				context: context,
				position: details.globalPosition,
				event: event,
				onUpdateEvent: onUpdateEvent,
				onDeleteEvent: deleteSelectedEvent,
				onAddEvent: onAddEvent,
				targetDate: day ?? getTargetDate(),
				selectedStartQuarter: selectedStartQuarter,
				selectedEndQuarter: selectedEndQuarter,
			);
		}
	}
	
	// ============ 拖拽处理 ============
	
	/// 开始拖拽
	void onPanStartImpl(DragStartDetails details, {DateTime? day, int? dayIndex}) {
		// 如果正在调整大小或移动，不处理
		if (isResizing || isMoving) {
			return;
		}
		
		// 检查是否点击了活动块
		final event = getEventAtPosition(details.localPosition.dy, day: day);
		if (event != null) {
			// 如果活动已被选中，检查点击位置来决定是移动还是调整大小
			if (selectedEvent == event) {
				final eventStartMinutes = event.start.hour * 60 + event.start.minute;
				final eventEndMinutes = event.end.hour * 60 + event.end.minute;
				final eventStartY = (eventStartMinutes / 15) * (CalendarConstants.hourRowHeight / 4);
				final eventEndY = (eventEndMinutes / 15) * (CalendarConstants.hourRowHeight / 4);
				final eventHeight = eventEndY - eventStartY;
				
				final relativeY = details.localPosition.dy - eventStartY;
				final handleHeight = getResizeHandleHeight();
				
				// 检查是否点击在调整手柄区域
				if (eventHeight > handleHeight * 2) {
					if (relativeY <= handleHeight) {
						// 点击在顶部调整手柄
						onResizeStartImpl(event, true, details);
						return;
					} else if (relativeY >= eventHeight - handleHeight) {
						// 点击在底部调整手柄
						onResizeStartImpl(event, false, details);
						return;
					}
				}
				
				// 点击在活动主体，开始移动
				onEventMoveStartImpl(event, details);
				return;
			} else {
				// 活动未被选中，先选中然后开始移动
				selectEvent(event, onSelectEvent: onSelectEvent);
				onEventMoveStartImpl(event, details);
				return;
			}
		}
		
		// 开始时间段选择
		final quarter = TimeUtils.getQuarterFromY(details.localPosition.dy);
		startTimeSelection(quarter: quarter, column: dayIndex);
	}
	
	/// 拖拽更新
	void onPanUpdateImpl(DragUpdateDetails details) {
		// 处理调整大小
		if (isResizing) {
			onResizeUpdateImpl(details);
			return;
		}
		
		// 处理移动
		if (isMoving) {
			onEventMoveUpdateImpl(details);
			return;
		}
		
		// 处理时间段选择
		if (!isSelecting || initialQuarter == null) return;
		final quarter = TimeUtils.getQuarterFromY(details.localPosition.dy);
		updateTimeSelection(quarter);
	}
	
	/// 结束拖拽
	void onPanEndImpl(DragEndDetails details) {
		// 处理调整大小结束
		if (isResizing) {
			onResizeEndImpl(details);
			return;
		}
		
		// 处理移动结束
		if (isMoving) {
			onEventMoveEndImpl(details);
			return;
		}
		
		// 处理时间段选择结束
		if (!isSelecting || selectedStartQuarter == null || selectedEndQuarter == null) {
			clearSelection(onClearSelection: onClearSelection);
			return;
		}
		
		endTimeSelection();
		
		// 显示添加活动对话框
		showAddEventDialogImpl();
	}
	
	// ============ 调整大小处理 ============
	
	/// 开始调整大小
	void onResizeStartImpl(CalendarEvent event, bool isTop, DragStartDetails details) {
		startResize(
			event: event,
			isTop: isTop,
			details: details,
			onSelectEvent: onSelectEvent,
		);
	}
	
	/// 调整大小更新
	void onResizeUpdateImpl(DragUpdateDetails details) {
		if (!isResizing || resizingEvent == null || initialResizeY == null) return;
		
		// 计算从开始位置的总体移动距离
		final totalDeltaY = details.globalPosition.dy - initialResizeY!;
		
		// 使用handler计算新时间
		final result = EventResizeHandler.calculateResize(
			originalStartTime: originalStartTime!,
			originalEndTime: originalEndTime!,
			totalDeltaY: totalDeltaY,
			isResizingTop: isResizingTop,
			boundaryDate: _getEventBoundaryDate(resizingEvent!),
		);
		
		final updatedEvent = resizingEvent!.copyWith(
			start: result.newStart,
			end: result.newEnd,
		);
		
		// 更新本地状态
		updateResizingEvent(updatedEvent);
		
		// 通知父组件选中状态已更新
		onSelectEvent?.call(updatedEvent);
	}
	
	/// 调整大小结束
	void onResizeEndImpl(DragEndDetails details) {
		// 调整大小结束时才进行数据库更新
		if (resizingEvent != null && originalStartTime != null && originalEndTime != null) {
			final originalEvent = resizingEvent!.copyWith(
				start: originalStartTime!,
				end: originalEndTime!,
			);
			
			// 使用handler验证并修正最终事件
			var finalEvent = EventResizeHandler.validateAndFixEvent(resizingEvent!);
			
			// 只有当大小真正改变时才更新数据库
			if (EventResizeHandler.hasChanged(finalEvent, originalStartTime!, originalEndTime!)) {
				if (onUpdateEvent != null) {
					onUpdateEvent!(originalEvent, finalEvent);
				}
				// 通知父组件选中状态已更新
				onSelectEvent?.call(finalEvent);
			}
			
			endResize(finalEvent: finalEvent);
		} else {
			endResize();
		}
	}
	
	// ============ 移动处理 ============
	
	/// 开始移动活动
	void onEventMoveStartImpl(CalendarEvent event, DragStartDetails details) {
		startMove(
			event: event,
			details: details,
			onSelectEvent: onSelectEvent,
		);
	}
	
	/// 移动活动更新
	void onEventMoveUpdateImpl(DragUpdateDetails details) {
		if (!isMoving || movingEvent == null || initialMoveY == null) return;
		
		// 计算从开始位置的总体移动距离
		final totalDeltaY = details.globalPosition.dy - initialMoveY!;
		
		// 使用handler计算新位置（由子类提供具体实现）
		final handler = createMoveHandler();
		final result = calculateMoveResult(handler, details, totalDeltaY);
		
		final updatedEvent = movingEvent!.copyWith(
			start: result.newStart,
			end: result.newEnd,
		);
		
		// 更新本地状态
		updateMovingEvent(updatedEvent, moved: result.hasMoved);
		
		// 通知父组件选中状态已更新
		onSelectEvent?.call(updatedEvent);
	}
	
	/// 移动活动结束
	void onEventMoveEndImpl(DragEndDetails details) {
		// 移动结束时才进行数据库更新
		CalendarEvent? finalEvent;
		
		if (movingEvent != null && initialMoveStartTime != null && initialMoveEndTime != null) {
			final originalEvent = movingEvent!.copyWith(
				start: initialMoveStartTime!,
				end: initialMoveEndTime!,
			);
			
			// 如果没有实际移动，恢复原始状态
			if (!hasMoved) {
				finalEvent = originalEvent;
			} else {
				// 只有当位置真正改变时才更新数据库
				if (EventMoveHandlerUtils.hasChanged(movingEvent!, initialMoveStartTime!, initialMoveEndTime!)) {
					finalEvent = movingEvent!;
					
					if (onUpdateEvent != null) {
						onUpdateEvent!(originalEvent, movingEvent!);
					}
					// 通知父组件选中状态已更新
					onSelectEvent?.call(movingEvent!);
				} else {
					finalEvent = movingEvent!;
				}
			}
			
			endMove(finalEvent: finalEvent);
		} else {
			endMove();
		}
	}
	
	// ============ 辅助方法 ============
	
	/// 获取调整大小手柄高度（由子类覆盖）
	double getResizeHandleHeight() {
		return CalendarConstants.resizeHandleHeightDay;
	}
	
	/// 获取事件的边界日期
	DateTime _getEventBoundaryDate(CalendarEvent event) {
		return DateTime(event.start.year, event.start.month, event.start.day);
	}
	
	/// 计算移动结果（由子类提供具体实现）
	/// 这个方法需要根据日视图/周视图的不同而有不同的实现
	MoveResult calculateMoveResult(
		dynamic handler,
		DragUpdateDetails details,
		double totalDeltaY,
	) {
		// 默认实现（日视图）
		if (handler is DayEventMoveHandler) {
			return handler.calculateMove(
				originalStartTime: initialMoveStartTime!,
				originalEndTime: initialMoveEndTime!,
				totalDeltaY: totalDeltaY,
				boundaryDate: getTargetDate(),
				previouslyMoved: hasMoved,
			);
		}
		
		// 周视图需要额外的参数，由子类覆盖此方法
		throw UnimplementedError('子类需要实现 calculateMoveResult 方法');
	}
}

