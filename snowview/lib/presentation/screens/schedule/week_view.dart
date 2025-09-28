import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'all_day_row.dart';
import 'widgets.dart';

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

class _WeekViewState extends State<WeekView> {
	static const double _hourRowHeight = 100;
	static const double _gutterWidth = 56;
	
	// 时间段选择状态（以15分钟为单位，0-95（24小时*4））
	int? _selectedStartQuarter;
	int? _selectedEndQuarter;
	int? _initialQuarter; // 拖拽开始时的初始位置
	bool _isSelecting = false;
	int? _selectedColumn; // 选中的列（0-6）
	
	// 活动选择状态
	CalendarEvent? _selectedEvent;
	
	// 活动调整大小状态
	bool _isResizing = false;
	bool _isResizingTop = false;
	CalendarEvent? _resizingEvent;
	double? _initialResizeY;
	DateTime? _initialStartTime;
	DateTime? _initialEndTime;
	static const double _resizeHandleHeight = 20; // 增加到20像素，提供更大的操作区域
	
	// 活动移动状态
	bool _isMoving = false;
	CalendarEvent? _movingEvent;
	double? _initialMoveY;
	double? _initialMoveX; // 添加X轴跟踪
	DateTime? _initialMoveStartTime;
	DateTime? _initialMoveEndTime;
	bool _hasMoved = false; // 跟踪是否有实际移动
	
	// 点击记录
	double? _lastTapY; // 记录最后一次点击的Y坐标
	
	// 鼠标悬停跟踪
	double? _currentHoverY; // 当前鼠标悬停的Y坐标
	int? _currentHoverDayIndex; // 当前鼠标悬停的日期列索引
	
	// 布局约束缓存
	BoxConstraints? _currentConstraints; // 当前的布局约束
	GlobalKey _stackKey = GlobalKey(); // 用于获取Stack的全局位置

	List<DateTime> _weekDays(DateTime d) {
		final int offset = (d.weekday + 6) % 7; // 周一为0
		final monday = DateTime(d.year, d.month, d.day).subtract(Duration(days: offset));
		return List<DateTime>.generate(7, (i) => monday.add(Duration(days: i)));
	}

	// 根据当前鼠标位置计算目标列
	int _getTargetColumnFromPosition(double currentGlobalX, double availableWidth) {
		// 获取Stack的全局位置
		final RenderBox? renderBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
		if (renderBox == null) {
			// 如果无法获取位置，回退到简单计算
			final columnWidth = availableWidth / 7;
			return ((currentGlobalX - _gutterWidth) / columnWidth).floor().clamp(0, 6);
		}
		
		final stackGlobalPosition = renderBox.localToGlobal(Offset.zero);
		
		// 计算相对于网格左边缘的位置（考虑时间标签宽度）
		final relativeX = currentGlobalX - stackGlobalPosition.dx - _gutterWidth;
		
		// 计算列宽度
		final columnWidth = availableWidth / 7;
		
		// 计算目标列（直接基于位置）
		int targetColumn = (relativeX / columnWidth).floor();
		
		return targetColumn.clamp(0, 6);
	}

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
				focusNode: FocusNode(),
				onKeyEvent: _handleKeyEvent,
				child: Column(
			children: [
				// 顶部：小时空白+周标题
				SizedBox(
					height: 40,
					child: Row(
						children: [
							const SizedBox(width: _gutterWidth),
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
				// 全天行（固定高度包裹，启用独立滚动）
				ConstrainedBox(
					constraints: const BoxConstraints.tightFor(height: 140),
					child: SingleAllDayRow(days: days, events: allDayEvents, gutterWidth: _gutterWidth),
				),
				const Divider(height: 1),
				// 主体：按小时网格
				Expanded(
					child: SingleChildScrollView(
					child: LayoutBuilder(
						builder: (context, constraints) {
							// 缓存当前约束信息，供移动更新时使用
							_currentConstraints = constraints;
							return Stack(
								key: _stackKey,
								children: [
										Column(
											children: List.generate(24, (hour) {
												return SizedBox(
													height: _hourRowHeight,
													child: Row(
														children: [
															// 左侧小时
															Container(
																width: _gutterWidth,
																alignment: Alignment.topRight,
																padding: const EdgeInsets.only(right: 8, top: 4),
																child: Text(_hourLabel(hour), style: theme.textTheme.bodySmall),
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
																						final quarterHeight = _hourRowHeight / 4;
																						
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

	String _weekdayShort(int weekday) {
		const map = {1: '一', 2: '二', 3: '三', 4: '四', 5: '五', 6: '六', 7: '日'};
		return '周${map[weekday] ?? ''}';
	}

	String _hourLabel(int h) => h.toString().padLeft(2, '0') + ':00';
	
	// 处理键盘事件
	void _handleKeyEvent(KeyEvent event) {
		if (event is KeyDownEvent) {
			if (event.logicalKey == LogicalKeyboardKey.delete && _selectedEvent != null) {
				_deleteSelectedEvent();
			}
		}
	}
	
	// 删除选中的活动
	void _deleteSelectedEvent() {
		if (_selectedEvent != null && widget.onDeleteEvent != null) {
			widget.onDeleteEvent!(_selectedEvent!);
			_clearSelection();
		}
	}
	
	// 判断某个15分钟段是否被选中
	bool _isQuarterSelected(int quarterIndex, int column) {
		if (_selectedStartQuarter == null || _selectedEndQuarter == null || _selectedColumn == null) return false;
		if (_selectedColumn != column) return false;
		final start = _selectedStartQuarter!;
		final end = _selectedEndQuarter!;
		return quarterIndex >= start && quarterIndex <= end;
	}
	
	// 根据y坐标计算15分钟段索引（0-95）
	int _getQuarterFromY(double y) {
		final quarter = (y / (_hourRowHeight / 4)).floor();
		return quarter.clamp(0, 95);
	}
	
	
	// 将15分钟段索引转换为TimeOfDay
	TimeOfDay _quarterToTimeOfDay(int quarter) {
		final hour = quarter ~/ 4;
		final minute = (quarter % 4) * 15;
		return TimeOfDay(hour: hour, minute: minute);
	}
	
	// 获取某天的所有非全天活动
	List<CalendarEvent> _getDayEvents(DateTime day) {
		return widget.events.where((event) {
			if (event.allDay) return false;
			final eventDate = DateTime(event.start.year, event.start.month, event.start.day);
			final currentDate = DateTime(day.year, day.month, day.day);
			
			// 在移动过程中，只在正在移动的活动的日期显示该活动
			if (_isMoving && _movingEvent == event) {
				final movingEventDate = DateTime(_movingEvent!.start.year, _movingEvent!.start.month, _movingEvent!.start.day);
				return movingEventDate.isAtSameMomentAs(currentDate);
			}
			
			// 在调整大小过程中，只在正在调整的活动的日期显示该活动
			if (_isResizing && _resizingEvent == event) {
				final resizingEventDate = DateTime(_resizingEvent!.start.year, _resizingEvent!.start.month, _resizingEvent!.start.day);
				return resizingEventDate.isAtSameMomentAs(currentDate);
			}
			
			return eventDate.isAtSameMomentAs(currentDate);
		}).toList();
	}
	
	// 构建活动显示块
	List<Widget> _buildEventBlocks(List<DateTime> days, BoxConstraints constraints) {
		final List<Widget> eventWidgets = [];
		
		for (int dayIndex = 0; dayIndex < days.length; dayIndex++) {
			final day = days[dayIndex];
			final dayEvents = _getDayEvents(day);
			// 使用实际的布局约束宽度，减去时间标签区域宽度
			final availableWidth = constraints.maxWidth - _gutterWidth;
			final columnWidth = availableWidth / 7;
			
			for (final event in dayEvents) {
				// 计算活动在时间轴上的位置
				final startMinutes = event.start.hour * 60 + event.start.minute;
				final endMinutes = event.end.hour * 60 + event.end.minute;
				
				// 转换为Y坐标
				final startY = (startMinutes / 15) * (_hourRowHeight / 4);
				final endY = (endMinutes / 15) * (_hourRowHeight / 4);
				final height = endY - startY;
				final isSelected = _selectedEvent == event;
				
				// 计算X坐标位置
				final leftOffset = _gutterWidth + dayIndex * columnWidth;
				
				// 创建活动块
				eventWidgets.add(
					Positioned(
						left: leftOffset + 1, // 从左边框线内侧开始，避免覆盖边框
						width: columnWidth - 2, // 减去左右边框线的宽度
						top: startY,
						height: height,
						child: Stack(
							children: [
								// 主活动块
								Container(
									width: double.infinity,
									margin: EdgeInsets.symmetric(horizontal: 0), // 减少边距让左侧更贴边
									decoration: BoxDecoration(
										color: event.color.withOpacity(isSelected ? 0.4 : 0.3),
										borderRadius: BorderRadius.circular(6),
										border: Border.all(
											color: event.color.withOpacity(isSelected ? 0.8 : 0.6),
											width: isSelected ? 2 : 1,
										),
									),
									child: Padding(
										padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
										child: height <= 30
											? // 小于等于30像素时，使用单行布局
											Row(
												children: [
													Flexible(
														child: Text(
															'${event.title} ${_formatTime(TimeOfDay.fromDateTime(event.start))}-${_formatTime(TimeOfDay.fromDateTime(event.end))}',
															style: TextStyle(
																fontSize: 11,
																color: event.color.withOpacity(0.9),
																fontWeight: FontWeight.w600,
															),
															overflow: TextOverflow.ellipsis,
															maxLines: 1,
														),
													),
												],
											)
											: // 大于30像素时，使用两行布局
											Column(
												crossAxisAlignment: CrossAxisAlignment.start,
												children: [
													Text(
														event.title,
														style: TextStyle(
															fontSize: 12,
															color: event.color.withOpacity(0.9),
															fontWeight: FontWeight.w600,
														),
														overflow: TextOverflow.ellipsis,
														maxLines: 1,
													),
													if (height > 30)
														Text(
															'${_formatTime(TimeOfDay.fromDateTime(event.start))}-${_formatTime(TimeOfDay.fromDateTime(event.end))}',
															style: TextStyle(
																fontSize: 10,
																color: event.color.withOpacity(0.7),
															),
															overflow: TextOverflow.ellipsis,
															maxLines: 1,
														),
												],
											),
									),
								),
								// 顶部调整手柄
								if (isSelected && height > _resizeHandleHeight * 1.5) // 降低显示调整手柄的最小高度要求
									Positioned(
										top: 0,
										left: 0,
										right: 0,
										height: _resizeHandleHeight,
										child: MouseRegion(
											cursor: SystemMouseCursors.resizeUpDown,
											child: GestureDetector(
												behavior: HitTestBehavior.opaque,
												onPanStart: (details) => _onResizeStart(event, true, details),
												onPanUpdate: _onResizeUpdate,
												onPanEnd: _onResizeEnd,
												child: Container(
													color: Colors.transparent,
													child: Center(
														child: Container(
															width: 30,
															height: 3,
															decoration: BoxDecoration(
																color: event.color.withOpacity(0.8),
																borderRadius: BorderRadius.circular(2),
															),
														),
													),
												),
											),
										),
									),
								// 底部调整手柄
								if (isSelected && height > _resizeHandleHeight * 1.5) // 降低显示调整手柄的最小高度要求
									Positioned(
										bottom: 0,
										left: 0,
										right: 0,
										height: _resizeHandleHeight,
										child: MouseRegion(
											cursor: SystemMouseCursors.resizeUpDown,
											child: GestureDetector(
												behavior: HitTestBehavior.opaque,
												onPanStart: (details) => _onResizeStart(event, false, details),
												onPanUpdate: _onResizeUpdate,
												onPanEnd: _onResizeEnd,
												child: Container(
													color: Colors.transparent,
													child: Center(
														child: Container(
															width: 30,
															height: 3,
															decoration: BoxDecoration(
																color: event.color.withOpacity(0.8),
																borderRadius: BorderRadius.circular(2),
															),
														),
													),
												),
											),
										),
									),
							],
						),
					),
				);
			}
		}
		
		return eventWidgets;
	}
	
	// 构建手势检测器
	List<Widget> _buildEmptyAreaGestureDetectors(List<DateTime> days, BoxConstraints constraints) {
		return List.generate(7, (dayIndex) {
			// 使用实际的布局约束宽度，减去时间标签区域宽度
			final availableWidth = constraints.maxWidth - _gutterWidth;
			final columnWidth = availableWidth / 7;
			final leftOffset = _gutterWidth + dayIndex * columnWidth;
			
			return Positioned(
				left: leftOffset,
				width: columnWidth,
				top: 0,
				height: 24 * _hourRowHeight,
				child: MouseRegion(
					cursor: _getCurrentCursor(),
					onHover: (event) => _onHover(event, dayIndex),
					child: GestureDetector(
						behavior: HitTestBehavior.translucent,
						onTapDown: (details) => _onTapDown(details, dayIndex),
						onPanStart: (details) => _onPanStart(details, dayIndex, days[dayIndex]),
						onPanUpdate: _onPanUpdate,
						onPanEnd: _onPanEnd,
						onTap: () => _onTap(dayIndex, days[dayIndex]),
						onSecondaryTapDown: (details) => _onSecondaryTapDown(details, dayIndex),
						child: Container(color: Colors.transparent),
					),
				),
			);
		});
	}
	
	// 获取当前光标样式
	SystemMouseCursor _getCurrentCursor() {
		// 如果正在调整大小，保持上下箭头样式
		if (_isResizing) {
			return SystemMouseCursors.resizeUpDown;
		}
		
		if (_currentHoverY == null || _currentHoverDayIndex == null) return SystemMouseCursors.basic;
		
		// 检查是否在调整手柄区域
		final days = _weekDays(widget.centerDate);
		final day = days[_currentHoverDayIndex!];
		final event = _getEventAtPosition(_currentHoverY!, day);
		if (event != null && _selectedEvent == event) {
			final eventStartMinutes = event.start.hour * 60 + event.start.minute;
			final eventStartY = (eventStartMinutes / 15) * (_hourRowHeight / 4);
			final relativeY = _currentHoverY! - eventStartY;
			final eventHeight = (event.end.difference(event.start).inMinutes / 15) * (_hourRowHeight / 4);
			
			// 检查是否在调整手柄区域
			if (eventHeight > _resizeHandleHeight * 1.5) {
				if (relativeY <= _resizeHandleHeight || relativeY >= eventHeight - _resizeHandleHeight) {
					return SystemMouseCursors.resizeUpDown;
				}
			}
		}
		
		return SystemMouseCursors.basic;
	}
	
	// 鼠标悬停处理
	void _onHover(PointerHoverEvent event, int dayIndex) {
		final newY = event.localPosition.dy;
		if (_currentHoverY != newY || _currentHoverDayIndex != dayIndex) {
			setState(() {
				_currentHoverY = newY;
				_currentHoverDayIndex = dayIndex;
			});
		}
	}
	
	// 处理点击按下
	void _onTapDown(TapDownDetails details, int dayIndex) {
		// 记录点击位置，用于后续的_onTap处理
		_lastTapY = details.localPosition.dy;
	}
	
	// 处理单击
	void _onTap(int dayIndex, DateTime day) {
		if (_lastTapY == null) {
			_clearSelection();
			return;
		}
		
		// 检查是否点击了活动块
		final event = _getEventAtPosition(_lastTapY!, day);
		if (event != null) {
			_selectEvent(event);
		} else {
			_clearSelection();
		}
	}
	
	// 开始拖拽
	void _onPanStart(DragStartDetails details, int dayIndex, DateTime day) {
		if (_isResizing || _isMoving) {
			return;
		}
		
		// 检查是否点击了活动块
		final event = _getEventAtPosition(details.localPosition.dy, day);
		if (event != null) {
			if (_selectedEvent == event) {
				// 如果活动已被选中，检查点击位置来决定是移动还是调整大小
				final eventStartMinutes = event.start.hour * 60 + event.start.minute;
				final eventEndMinutes = event.end.hour * 60 + event.end.minute;
				final eventStartY = (eventStartMinutes / 15) * (_hourRowHeight / 4);
				final eventEndY = (eventEndMinutes / 15) * (_hourRowHeight / 4);
				final eventHeight = eventEndY - eventStartY;
				
				final relativeY = details.localPosition.dy - eventStartY;
				
				// 检查是否点击在调整手柄区域
				if (eventHeight > _resizeHandleHeight * 1.5) {
					if (relativeY <= _resizeHandleHeight) {
						// 点击在顶部调整手柄
						_onResizeStart(event, true, details);
						return;
					} else if (relativeY >= eventHeight - _resizeHandleHeight) {
						// 点击在底部调整手柄
						_onResizeStart(event, false, details);
						return;
					}
				}
				
				// 点击在活动主体，开始移动
				_onEventMoveStart(event, details);
				return;
			} else {
				// 未选中的活动：先选中，然后开始移动（这样用户可以直接拖动）
				_selectEvent(event);
				_onEventMoveStart(event, details);
				return;
			}
		}
		
		// 开始时间段选择
		final quarter = _getQuarterFromY(details.localPosition.dy);
		setState(() {
			_initialQuarter = quarter;
			_selectedStartQuarter = quarter;
			_selectedEndQuarter = quarter;
			_selectedColumn = dayIndex;
			_isSelecting = true;
		});
	}
	
	// 拖拽更新
	void _onPanUpdate(DragUpdateDetails details) {
		if (_isResizing) {
			_onResizeUpdate(details);
			return;
		}
		
		if (_isMoving) {
			_onEventMoveUpdate(details);
			return;
		}
		
		if (!_isSelecting || _initialQuarter == null) return;
		final quarter = _getQuarterFromY(details.localPosition.dy);
		setState(() {
			final initial = _initialQuarter!;
			if (quarter >= initial) {
				_selectedStartQuarter = initial;
				_selectedEndQuarter = quarter;
			} else {
				_selectedStartQuarter = quarter;
				_selectedEndQuarter = initial;
			}
		});
	}
	
	// 结束拖拽
	void _onPanEnd(DragEndDetails details) {
		if (_isResizing) {
			_onResizeEnd(details);
			return;
		}
		
		if (_isMoving) {
			_onEventMoveEnd(details);
			return;
		}
		
		if (!_isSelecting || _selectedStartQuarter == null || _selectedEndQuarter == null || _selectedColumn == null) {
			_clearSelection();
			return;
		}
		
		setState(() {
			_isSelecting = false;
		});
		
		_showAddEventDialog();
	}
	
	// 处理右键点击
	void _onSecondaryTapDown(TapDownDetails details, int dayIndex) {
		final days = _weekDays(widget.centerDate);
		final day = days[dayIndex];
		final event = _getEventAtPosition(details.localPosition.dy, day);
		if (event != null) {
			_selectEvent(event);
			_showContextMenu(details.globalPosition, event);
		}
	}
	
	// 显示右键上下文菜单
	void _showContextMenu(Offset position, CalendarEvent event) {
		final colorOptions = eventColors;
		
		showDialog(
			context: context,
			barrierColor: Colors.transparent,
			barrierDismissible: true,
			builder: (context) {
				return Stack(
					children: [
						Positioned(
							left: position.dx,
							top: position.dy,
							child: Material(
								elevation: 8,
								borderRadius: BorderRadius.circular(8),
								child: Container(
									constraints: BoxConstraints(maxWidth: 280),
									decoration: BoxDecoration(
										color: Colors.white,
										borderRadius: BorderRadius.circular(8),
										boxShadow: [
											BoxShadow(
												color: Colors.black26,
												blurRadius: 8,
												offset: Offset(0, 4),
											),
										],
									),
									child: Column(
										mainAxisSize: MainAxisSize.min,
										children: [
											// 颜色选项行
											Padding(
												padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
												child: Row(
													mainAxisSize: MainAxisSize.min,
													children: colorOptions.map((color) {
														final isSelected = event.color == color;
														return Padding(
															padding: EdgeInsets.only(right: 8),
															child: GestureDetector(
																onTap: () {
																	Navigator.of(context).pop();
																	_handleColorChange(event, color);
																},
																child: Container(
																	width: 24,
																	height: 24,
																	decoration: BoxDecoration(
																		color: color,
																		borderRadius: BorderRadius.circular(12),
																		border: Border.all(
																			color: isSelected ? Colors.black : Colors.grey.withOpacity(0.3),
																			width: isSelected ? 3 : 1,
																		),
																		boxShadow: [
																			BoxShadow(
																				color: Colors.black.withOpacity(0.1),
																				blurRadius: 2,
																				offset: Offset(0, 1),
																			),
																		],
																	),
																),
															),
														);
													}).toList(),
												),
											),
											Divider(height: 1),
											// 修改名称输入框
											Padding(
												padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
												child: Row(
													children: [
														Icon(Icons.edit, size: 16),
														SizedBox(width: 8),
														Expanded(
															child: _EditableTextField(
																initialText: event.title,
																event: event,
																onUpdateEvent: widget.onUpdateEvent,
															),
														),
													],
												),
											),
											Divider(height: 1),
											// 其他操作按钮
											_buildMenuButton(Icons.copy, '复制', () {
												Navigator.of(context).pop();
												_copyEvent(event);
											}),
											_buildMenuButton(Icons.paste, '粘贴', () {
												Navigator.of(context).pop();
												_pasteEvent();
											}),
											_buildMenuButton(Icons.content_copy, '创建副本', () {
												Navigator.of(context).pop();
												_duplicateEvent(event);
											}),
											Divider(height: 1),
											_buildMenuButton(Icons.delete, '删除', () {
												Navigator.of(context).pop();
												_deleteSelectedEvent();
											}, color: Colors.red),
										],
									),
								),
							),
						),
					],
				);
			},
		);
	}
	
	// 构建菜单按钮
	Widget _buildMenuButton(IconData icon, String text, VoidCallback onTap, {Color? color}) {
		return InkWell(
			onTap: onTap,
			child: Padding(
				padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
				child: Row(
					children: [
						Icon(icon, size: 16, color: color),
						SizedBox(width: 8),
						Text(
							text,
							style: TextStyle(
								fontSize: 14,
								fontWeight: FontWeight.normal,
								color: color,
							),
						),
					],
				),
			),
		);
	}
	
	// 处理颜色变更
	void _handleColorChange(CalendarEvent event, Color newColor) {
		if (newColor != event.color) {
			final updatedEvent = CalendarEvent(
				title: event.title,
				allDay: event.allDay,
				description: event.description,
				color: newColor,
				start: event.start,
				end: event.end,
			);
			if (widget.onUpdateEvent != null) {
				widget.onUpdateEvent!(event, updatedEvent);
			}
		}
	}
	
	// 复制活动
	void _copyEvent(CalendarEvent event) {
		final eventText = '${event.title}\n${_formatTime(TimeOfDay.fromDateTime(event.start))}-${_formatTime(TimeOfDay.fromDateTime(event.end))}';
		Clipboard.setData(ClipboardData(text: eventText));
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(content: Text('活动已复制到剪贴板')),
		);
	}
	
	// 粘贴活动
	void _pasteEvent() {
		Clipboard.getData('text/plain').then((data) {
			if (data?.text != null && data!.text!.isNotEmpty) {
				final lines = data.text!.split('\n');
				final title = lines[0].trim();
				
				DateTime startTime;
				DateTime endTime;
				
				if (_selectedStartQuarter != null && _selectedEndQuarter != null && _selectedColumn != null) {
					final days = _weekDays(widget.centerDate);
					final selectedDay = days[_selectedColumn!];
					final startTimeOfDay = _quarterToTimeOfDay(_selectedStartQuarter!);
					final endTimeOfDay = _quarterToTimeOfDay(_selectedEndQuarter! + 1);
					startTime = DateTime(
						selectedDay.year,
						selectedDay.month,
						selectedDay.day,
						startTimeOfDay.hour,
						startTimeOfDay.minute,
					);
					endTime = DateTime(
						selectedDay.year,
						selectedDay.month,
						selectedDay.day,
						endTimeOfDay.hour,
						endTimeOfDay.minute,
					);
				} else {
					final now = DateTime.now();
					final days = _weekDays(widget.centerDate);
					final today = days.firstWhere((day) => 
						day.year == now.year && day.month == now.month && day.day == now.day,
						orElse: () => days[0]);
					startTime = DateTime(today.year, today.month, today.day, now.hour, 0);
					endTime = startTime.add(Duration(hours: 1));
				}
				
				final newEvent = CalendarEvent(
					title: title,
					allDay: false,
					description: '',
					color: Colors.blue,
					start: startTime,
					end: endTime,
				);
				
				widget.onAddEvent(newEvent);
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text('活动已粘贴')),
				);
			}
		});
	}
	
	// 创建活动副本
	void _duplicateEvent(CalendarEvent event) {
		final newEvent = CalendarEvent(
			title: '${event.title} (副本)',
			allDay: event.allDay,
			description: event.description,
			color: event.color,
			start: event.start.add(Duration(hours: 1)),
			end: event.end.add(Duration(hours: 1)),
		);
		widget.onAddEvent(newEvent);
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(content: Text('活动副本已创建')),
		);
	}
	
	// 检查点击位置是否在活动块内
	CalendarEvent? _getEventAtPosition(double y, DateTime day) {
		final dayEvents = _getDayEvents(day);
		
		CalendarEvent? foundEvent;
		for (final event in dayEvents) {
			final startMinutes = event.start.hour * 60 + event.start.minute;
			final endMinutes = event.end.hour * 60 + event.end.minute;
			
			final startY = (startMinutes / 15) * (_hourRowHeight / 4);
			final endY = (endMinutes / 15) * (_hourRowHeight / 4);
			
			if (y >= startY && y <= endY) {
				foundEvent = event;
			}
		}
		
		return foundEvent;
	}
	
	// 格式化时间显示
	String _formatTime(TimeOfDay time) {
		return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
	}
	
	// 清除选择
	void _clearSelection() {
		setState(() {
			_selectedStartQuarter = null;
			_selectedEndQuarter = null;
			_initialQuarter = null;
			_selectedColumn = null;
			_isSelecting = false;
			_selectedEvent = null;
			_isResizing = false;
			_isResizingTop = false;
			_resizingEvent = null;
			_initialResizeY = null;
			_initialStartTime = null;
			_initialEndTime = null;
			_isMoving = false;
			_movingEvent = null;
			_initialMoveY = null;
			_initialMoveX = null; // 清除X轴跟踪
			_initialMoveStartTime = null;
			_initialMoveEndTime = null;
			_hasMoved = false;
			_lastTapY = null;
			_currentHoverY = null;
			_currentHoverDayIndex = null;
		});
		// 通知父组件清除选择
		widget.onClearSelection?.call();
	}
	
	// 选择活动
	void _selectEvent(CalendarEvent event) {
		setState(() {
			_selectedEvent = event;
			_selectedStartQuarter = null;
			_selectedEndQuarter = null;
			_selectedColumn = null;
			_isSelecting = false;
		});
		// 通知父组件活动被选中
		widget.onSelectEvent?.call(event);
	}
	
	// 开始调整大小
	void _onResizeStart(CalendarEvent event, bool isTop, DragStartDetails details) {
		setState(() {
			_isResizing = true;
			_isResizingTop = isTop;
			_resizingEvent = event;
			_selectedEvent = event;
			_initialResizeY = details.globalPosition.dy;
			_initialStartTime = event.start;
			_initialEndTime = event.end;
		});
	}
	
	// 调整大小更新
	void _onResizeUpdate(DragUpdateDetails details) {
		if (!_isResizing || _resizingEvent == null || _initialResizeY == null) return;
		
		// 计算从开始位置的总体移动距离
		final totalDeltaY = details.globalPosition.dy - _initialResizeY!;
		final deltaQuarters = (totalDeltaY / (_hourRowHeight / 4)).round();
		
		DateTime newStart = _initialStartTime!;
		DateTime newEnd = _initialEndTime!;
		
		// 定义边界：使用当前活动所在的日期
		final eventDate = DateTime(_resizingEvent!.start.year, _resizingEvent!.start.month, _resizingEvent!.start.day);
		final dayStart = DateTime(eventDate.year, eventDate.month, eventDate.day, 0, 0);
		final dayEnd = DateTime(eventDate.year, eventDate.month, eventDate.day, 23, 59);
		
		if (_isResizingTop) {
			// 调整开始时间
			newStart = _initialStartTime!.add(Duration(minutes: deltaQuarters * 15));
			
			// 检查是否发生了交换
			if (newStart.isAfter(_initialEndTime!)) {
				newEnd = newStart;
				newStart = _initialEndTime!;
				_isResizingTop = false;
				_initialStartTime = newStart;
				_initialEndTime = newEnd;
				_initialResizeY = details.globalPosition.dy;
			} else {
				newEnd = _initialEndTime!;
			}
		} else {
			// 调整结束时间
			newEnd = _initialEndTime!.add(Duration(minutes: deltaQuarters * 15));
			
			// 检查是否发生了交换
			if (newEnd.isBefore(_initialStartTime!)) {
				newStart = newEnd;
				newEnd = _initialStartTime!;
				_isResizingTop = true;
				_initialStartTime = newStart;
				_initialEndTime = newEnd;
				_initialResizeY = details.globalPosition.dy;
			} else {
				newStart = _initialStartTime!;
			}
		}
		
		// 应用边界限制
		if (newStart.isBefore(dayStart)) {
			newStart = dayStart;
		}
		if (newEnd.isAfter(dayEnd)) {
			newEnd = dayEnd;
		}
		
		// 确保最小15分钟时长
		final minDuration = const Duration(minutes: 15);
		if (newEnd.difference(newStart) < minDuration) {
			if (_isResizingTop) {
				newStart = newEnd.subtract(minDuration);
				if (newStart.isBefore(dayStart)) {
					newStart = dayStart;
					newEnd = newStart.add(minDuration);
					if (newEnd.isAfter(dayEnd)) {
						newEnd = dayEnd;
						newStart = newEnd.subtract(minDuration);
					}
				}
			} else {
				newEnd = newStart.add(minDuration);
				if (newEnd.isAfter(dayEnd)) {
					newEnd = dayEnd;
					newStart = newEnd.subtract(minDuration);
					if (newStart.isBefore(dayStart)) {
						newStart = dayStart;
						newEnd = newStart.add(minDuration);
					}
				}
			}
		}
		
		final updatedEvent = CalendarEvent(
			title: _resizingEvent!.title,
			allDay: _resizingEvent!.allDay,
			description: _resizingEvent!.description,
			color: _resizingEvent!.color,
			start: newStart,
			end: newEnd,
		);
		
		if (widget.onUpdateEvent != null) {
			widget.onUpdateEvent!(_resizingEvent!, updatedEvent);
		}
		
		setState(() {
			_resizingEvent = updatedEvent;
			_selectedEvent = updatedEvent;
		});
	}
	
	// 调整大小结束
	void _onResizeEnd(DragEndDetails details) {
		setState(() {
			_isResizing = false;
			_isResizingTop = false;
			_resizingEvent = null;
			_initialResizeY = null;
			_initialStartTime = null;
			_initialEndTime = null;
		});
	}
	
	// 开始移动活动
	void _onEventMoveStart(CalendarEvent event, DragStartDetails details) {
		setState(() {
			_isMoving = true;
			_movingEvent = event;
			_selectedEvent = event;
			_initialMoveY = details.globalPosition.dy;
			_initialMoveX = details.globalPosition.dx; // 记录初始X坐标
			_initialMoveStartTime = event.start;
			_initialMoveEndTime = event.end;
			_hasMoved = false; // 重置移动标记
		});
	}
	
	// 移动活动更新
	void _onEventMoveUpdate(DragUpdateDetails details) {
		if (!_isMoving || _movingEvent == null || _initialMoveY == null || _initialMoveX == null) return;
		
		// 计算从开始位置的Y轴移动距离
		final totalDeltaY = details.globalPosition.dy - _initialMoveY!;
		final deltaQuarters = (totalDeltaY / (_hourRowHeight / 4)).round();
		
		// 计算从开始位置的X轴移动距离，并确定目标日期
		final days = _weekDays(widget.centerDate);
		// 使用与构建活动块相同的宽度计算方式
		final availableWidth = _currentConstraints != null 
			? _currentConstraints!.maxWidth - _gutterWidth 
			: MediaQuery.of(context).size.width - _gutterWidth;
		final targetColumn = _getTargetColumnFromPosition(
			details.globalPosition.dx, 
			availableWidth
		);
		final targetDate = days[targetColumn];
		
		// 如果移动距离超过阈值，标记为已移动
		final totalDeltaX = details.globalPosition.dx - _initialMoveX!;
		if (totalDeltaY.abs() > 5 || totalDeltaX.abs() > 10) { // Y轴5像素或X轴10像素的阈值，降低X轴阈值使移动更敏感
			_hasMoved = true;
		}
		
		// 计算新的开始和结束时间（保持时长不变）
		final duration = _initialMoveEndTime!.difference(_initialMoveStartTime!);
		
		// 获取原始时间在一天中的时分秒
		final originalStartTime = _initialMoveStartTime!;
		final timeOfDay = Duration(
			hours: originalStartTime.hour,
			minutes: originalStartTime.minute,
			seconds: originalStartTime.second,
		);
		
		// 在目标日期上应用时间和Y轴偏移
		var newStart = DateTime(targetDate.year, targetDate.month, targetDate.day)
			.add(timeOfDay)
			.add(Duration(minutes: deltaQuarters * 15));
		var newEnd = newStart.add(duration);
		
		// 限制在目标日期内
		final dayStart = DateTime(targetDate.year, targetDate.month, targetDate.day, 0, 0);
		final dayEnd = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59);
		
		// 限制开始时间不早于00:00
		if (newStart.isBefore(dayStart)) {
			newStart = dayStart;
			newEnd = newStart.add(duration);
		}
		
		// 限制结束时间不晚于23:59
		if (newEnd.isAfter(dayEnd)) {
			newEnd = dayEnd;
			newStart = newEnd.subtract(duration);
			
			// 如果活动时长太长，开始时间会早于00:00，则调整为最大可能的时长
			if (newStart.isBefore(dayStart)) {
				newStart = dayStart;
				newEnd = dayEnd;
			}
		}
		
		final updatedEvent = CalendarEvent(
			title: _movingEvent!.title,
			allDay: _movingEvent!.allDay,
			description: _movingEvent!.description,
			color: _movingEvent!.color,
			start: newStart,
			end: newEnd,
		);
		
		if (widget.onUpdateEvent != null) {
			widget.onUpdateEvent!(_movingEvent!, updatedEvent);
		}
		
		setState(() {
			_movingEvent = updatedEvent;
			_selectedEvent = updatedEvent;
		});
	}
	
	// 移动活动结束
	void _onEventMoveEnd(DragEndDetails details) {
		// 如果没有实际移动，恢复原始状态（相当于只是选中）
		if (!_hasMoved && _movingEvent != null && _initialMoveStartTime != null && _initialMoveEndTime != null) {
			final originalEvent = CalendarEvent(
				title: _movingEvent!.title,
				allDay: _movingEvent!.allDay,
				description: _movingEvent!.description,
				color: _movingEvent!.color,
				start: _initialMoveStartTime!,
				end: _initialMoveEndTime!,
			);
			if (widget.onUpdateEvent != null) {
				widget.onUpdateEvent!(_movingEvent!, originalEvent);
			}
		}
		
		setState(() {
			_isMoving = false;
			_movingEvent = null;
			_initialMoveY = null;
			_initialMoveX = null; // 清除X轴跟踪
			_initialMoveStartTime = null;
			_initialMoveEndTime = null;
			_hasMoved = false;
		});
	}
	
	// 显示添加活动对话框
	Future<void> _showAddEventDialog() async {
		if (_selectedStartQuarter == null || _selectedEndQuarter == null || _selectedColumn == null) return;
		
		final days = _weekDays(widget.centerDate);
		final selectedDay = days[_selectedColumn!];
		final startTime = _quarterToTimeOfDay(_selectedStartQuarter!);
		final endTime = _quarterToTimeOfDay(_selectedEndQuarter! + 1);
		
		final event = await showDialog<CalendarEvent>(
			context: context,
			builder: (context) => DayViewAddEventDialog(
				date: selectedDay,
				startTime: startTime,
				endTime: endTime,
			),
		);
		
		if (event != null) {
			widget.onAddEvent(event);
		}
		
		_clearSelection();
	}
	
}

// 可编辑文本字段组件
class _EditableTextField extends StatefulWidget {
	final String initialText;
	final CalendarEvent event;
	final Function(CalendarEvent, CalendarEvent)? onUpdateEvent;

	const _EditableTextField({
		required this.initialText,
		required this.event,
		this.onUpdateEvent,
	});

	@override
	State<_EditableTextField> createState() => _EditableTextFieldState();
}

class _EditableTextFieldState extends State<_EditableTextField> {
	late TextEditingController _controller;
	late CalendarEvent _currentEvent;

	@override
	void initState() {
		super.initState();
		_controller = TextEditingController(text: widget.initialText);
		_currentEvent = widget.event;
	}

	@override
	void dispose() {
		_controller.dispose();
		super.dispose();
	}

	void _updateEvent(String newTitle) {
		if (newTitle.trim().isNotEmpty && newTitle.trim() != _currentEvent.title) {
			final updatedEvent = CalendarEvent(
				title: newTitle.trim(),
				allDay: _currentEvent.allDay,
				description: _currentEvent.description,
				color: _currentEvent.color,
				start: _currentEvent.start,
				end: _currentEvent.end,
			);
			
			if (widget.onUpdateEvent != null) {
				widget.onUpdateEvent!(_currentEvent, updatedEvent);
				_currentEvent = updatedEvent;
			}
		}
	}

	@override
	Widget build(BuildContext context) {
		return TextField(
			controller: _controller,
			style: TextStyle(fontSize: 14),
			decoration: InputDecoration(
				isDense: true,
				contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
				border: OutlineInputBorder(
					borderRadius: BorderRadius.circular(4),
				),
				hintText: '修改活动名称',
			),
			onChanged: _updateEvent,
			onSubmitted: (newTitle) {
				Navigator.of(context).pop();
			},
		);
	}
}
