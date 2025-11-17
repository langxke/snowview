import 'package:flutter/material.dart';
import '../../models.dart';

/// 日历视图的状态管理 Mixin
/// 
/// 提供所有共享的状态变量和状态管理方法
/// 分组管理：时间段选择、事件选择、调整大小、移动、UI 状态等
mixin CalendarStateMixin<T extends StatefulWidget> on State<T> {
	// ============ 时间段选择状态 ============
	/// 选中的开始15分钟段（0-95，24小时*4）
	int? selectedStartQuarter;
	/// 选中的结束15分钟段
	int? selectedEndQuarter;
	/// 拖拽开始时的初始位置
	int? initialQuarter;
	/// 是否正在选择时间段
	bool isSelecting = false;
	/// 选中的列（仅周视图使用，0-6）
	int? selectedColumn;
	
	// ============ 事件选择状态 ============
	/// 当前选中的事件
	CalendarEvent? selectedEvent;
	/// 选中事件的唯一标识（用于跟踪）
	String? selectedEventId;
	
	// ============ 调整大小状态 ============
	/// 是否正在调整大小
	bool isResizing = false;
	/// true表示调整顶部（开始时间），false表示调整底部（结束时间）
	bool isResizingTop = false;
	/// 正在调整大小的事件
	CalendarEvent? resizingEvent;
	/// 调整开始时的Y坐标
	double? initialResizeY;
	/// 原始开始时间（不会在拖拽过程中被修改）
	DateTime? originalStartTime;
	/// 原始结束时间（不会在拖拽过程中被修改）
	DateTime? originalEndTime;
	
	// ============ 移动状态 ============
	/// 是否正在移动事件
	bool isMoving = false;
	/// 正在移动的事件
	CalendarEvent? movingEvent;
	/// 移动开始时的Y坐标
	double? initialMoveY;
	/// 移动开始时的X坐标（仅周视图使用）
	double? initialMoveX;
	/// 移动开始时的事件开始时间
	DateTime? initialMoveStartTime;
	/// 移动开始时的事件结束时间
	DateTime? initialMoveEndTime;
	/// 移动标记，用于判断是否实际移动
	bool hasMoved = false;
	
	// ============ UI 状态 ============
	/// 记录最后一次点击的Y坐标
	double? lastTapY;
	/// 当前鼠标悬停的Y坐标
	double? currentHoverY;
	/// 当前鼠标悬停的日期列索引（仅周视图使用）
	int? currentHoverDayIndex;
	
	// ============ 焦点节点 ============
	/// 键盘焦点节点
	late final FocusNode focusNode;
	
	// ============ 布局约束（仅周视图使用）============
	/// 当前的布局约束
	BoxConstraints? currentConstraints;
	/// 用于获取Stack的全局位置
	final GlobalKey stackKey = GlobalKey();
	
	// ============ 初始化和清理 ============
	
	/// 初始化状态（在 initState 中调用）
	@mustCallSuper
	void initCalendarState() {
		focusNode = FocusNode();
	}
	
	/// 清理资源（在 dispose 中调用）
	@mustCallSuper
	void disposeCalendarState() {
		focusNode.dispose();
	}
	
	// ============ 状态管理方法 ============
	
	/// 选择事件
	void selectEvent(CalendarEvent event, {
		required Function(CalendarEvent)? onSelectEvent,
	}) {
		setState(() {
			selectedEvent = event;
			selectedEventId = _getEventId(event);
			// 清除时间段选择
			selectedStartQuarter = null;
			selectedEndQuarter = null;
			selectedColumn = null;
			isSelecting = false;
		});
		// 通知父组件活动被选中
		onSelectEvent?.call(event);
	}
	
	/// 清除所有选择和状态
	void clearSelection({
		required VoidCallback? onClearSelection,
	}) {
		setState(() {
			// 清除时间段选择
			selectedStartQuarter = null;
			selectedEndQuarter = null;
			initialQuarter = null;
			selectedColumn = null;
			isSelecting = false;
			
			// 清除事件选择
			selectedEvent = null;
			selectedEventId = null;
			
			// 清除调整大小状态
			isResizing = false;
			isResizingTop = false;
			resizingEvent = null;
			initialResizeY = null;
			originalStartTime = null;
			originalEndTime = null;
			
			// 清除移动状态
			isMoving = false;
			movingEvent = null;
			initialMoveY = null;
			initialMoveX = null;
			initialMoveStartTime = null;
			initialMoveEndTime = null;
			hasMoved = false;
			
			// 清除UI状态
			lastTapY = null;
			currentHoverY = null;
			currentHoverDayIndex = null;
		});
		// 通知父组件清除选择
		onClearSelection?.call();
	}
	
	/// 开始调整大小
	void startResize({
		required CalendarEvent event,
		required bool isTop,
		required DragStartDetails details,
		required Function(CalendarEvent)? onSelectEvent,
	}) {
		setState(() {
			isResizing = true;
			isResizingTop = isTop;
			resizingEvent = event;
			selectedEvent = event;
			selectedEventId = _getEventId(event);
			initialResizeY = details.globalPosition.dy;
			// 保存真正的原始时间
			originalStartTime = event.start;
			originalEndTime = event.end;
		});
	}
	
	/// 更新调整大小的事件
	void updateResizingEvent(CalendarEvent event) {
		setState(() {
			resizingEvent = event;
			selectedEvent = event;
			selectedEventId = _getEventId(event);
		});
	}
	
	/// 结束调整大小
	void endResize({CalendarEvent? finalEvent}) {
		setState(() {
			// 在清除之前保存最终状态
			if (finalEvent != null) {
				selectedEvent = finalEvent;
				selectedEventId = _getEventId(finalEvent);
			} else if (resizingEvent != null) {
				selectedEvent = resizingEvent!;
				selectedEventId = _getEventId(resizingEvent!);
			}
			
			isResizing = false;
			isResizingTop = false;
			resizingEvent = null;
			initialResizeY = null;
			originalStartTime = null;
			originalEndTime = null;
		});
	}
	
	/// 开始移动事件
	void startMove({
		required CalendarEvent event,
		required DragStartDetails details,
		required Function(CalendarEvent)? onSelectEvent,
	}) {
		setState(() {
			isMoving = true;
			movingEvent = event;
			selectedEvent = event;
			selectedEventId = _getEventId(event);
			initialMoveY = details.globalPosition.dy;
			initialMoveX = details.globalPosition.dx;
			initialMoveStartTime = event.start;
			initialMoveEndTime = event.end;
			hasMoved = false;
		});
	}
	
	/// 更新移动的事件
	void updateMovingEvent(CalendarEvent event, {required bool moved}) {
		setState(() {
			movingEvent = event;
			selectedEvent = event;
			selectedEventId = _getEventId(event);
			hasMoved = moved;
		});
	}
	
	/// 结束移动
	void endMove({CalendarEvent? finalEvent}) {
		setState(() {
			// 设置最终状态
			if (finalEvent != null) {
				selectedEvent = finalEvent;
				selectedEventId = _getEventId(finalEvent);
			} else if (movingEvent != null) {
				selectedEvent = movingEvent!;
				selectedEventId = _getEventId(movingEvent!);
			}
			
			isMoving = false;
			movingEvent = null;
			initialMoveY = null;
			initialMoveX = null;
			initialMoveStartTime = null;
			initialMoveEndTime = null;
			hasMoved = false;
		});
	}
	
	/// 开始时间段选择
	void startTimeSelection({
		required int quarter,
		int? column, // 仅周视图使用
	}) {
		setState(() {
			initialQuarter = quarter;
			selectedStartQuarter = quarter;
			selectedEndQuarter = quarter;
			selectedColumn = column;
			isSelecting = true;
		});
	}
	
	/// 更新时间段选择
	void updateTimeSelection(int quarter) {
		setState(() {
			final initial = initialQuarter!;
			if (quarter >= initial) {
				selectedStartQuarter = initial;
				selectedEndQuarter = quarter;
			} else {
				selectedStartQuarter = quarter;
				selectedEndQuarter = initial;
			}
		});
	}
	
	/// 结束时间段选择
	void endTimeSelection() {
		setState(() {
			isSelecting = false;
		});
	}
	
	/// 更新鼠标悬停位置
	void updateHoverPosition({double? y, int? dayIndex}) {
		setState(() {
			currentHoverY = y;
			currentHoverDayIndex = dayIndex;
		});
	}
	
	/// 更新布局约束（仅周视图使用）
	void updateConstraints(BoxConstraints constraints) {
		currentConstraints = constraints;
	}
	
	// ============ 辅助方法 ============
	
	/// 获取事件的唯一标识
	String _getEventId(CalendarEvent event) {
		return event.id;
	}
}

