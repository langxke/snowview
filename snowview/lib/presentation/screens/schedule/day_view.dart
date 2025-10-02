import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'all_day_row.dart';
import 'widgets.dart';

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

class _DayViewState extends State<DayView> {
	static const double _hourRowHeight = 100;
	static const double _gutterWidth = 56;
	
	int? _selectedStartQuarter; // 以15分钟为单位，0-95（24小时*4）
	int? _selectedEndQuarter;
	int? _initialQuarter; // 拖拽开始时的初始位置
	bool _isSelecting = false;
	
	// 活动选择状态
	CalendarEvent? _selectedEvent;
	String? _selectedEventId; // 用于跟踪选中活动的唯一标识
	
	// 活动调整大小状态
	bool _isResizing = false;
	bool _isResizingTop = false; // true表示调整顶部(开始时间)，false表示调整底部(结束时间)
	CalendarEvent? _resizingEvent;
	double? _initialResizeY; // 调整开始时的Y坐标
	// 保存真正的原始时间，不会在拖拽过程中被修改
	DateTime? _originalStartTime;
	DateTime? _originalEndTime;
	static const double _resizeHandleHeight = 12; // 调整手柄的高度
	
	// 活动移动状态
	bool _isMoving = false;
	CalendarEvent? _movingEvent;
	double? _initialMoveY; // 移动开始时的Y坐标
	DateTime? _initialMoveStartTime; // 移动开始时的开始时间
	DateTime? _initialMoveEndTime; // 移动开始时的结束时间
	bool _hasMoved = false; // 移动标记，用于判断是否实际移动

	@override
	Widget build(BuildContext context) {
		final theme = Theme.of(context);
		bool inRange(DateTime d, DateTime a, DateTime b) {
			final dd = DateTime(d.year, d.month, d.day);
			final aa = DateTime(a.year, a.month, a.day);
			final bb = DateTime(b.year, b.month, b.day);
			return !dd.isBefore(aa) && !dd.isAfter(bb);
		}
		final allDayEvents = widget.events.where((e) => e.allDay && inRange(widget.date, e.start, e.end)).toList();
		return Focus(
			autofocus: true,
			child: KeyboardListener(
				focusNode: FocusNode(),
				onKeyEvent: _handleKeyEvent,
				child: Column(
			children: [
				// 顶部：日期标题
				SizedBox(
					height: 40,
					child: Row(
						children: [
							const SizedBox(width: _gutterWidth),
							Expanded(
								child: Center(
									child: Text('${widget.date.year}-${widget.date.month}-${widget.date.day}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
								),
							),
						],
					),
				),
				const Divider(height: 1),
				// 全天行（与组件 minHeight 绑定，自适应高度）
				SingleAllDayRow(
					days: [widget.date],
					events: allDayEvents,
					gutterWidth: _gutterWidth,
					minHeight: 140, // 最小高度与参数绑定
					maxHeight: 220,
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
										final BorderSide line = BorderSide(color: Colors.grey.withOpacity(0.5), width: 1);
										
										return SizedBox(
											height: _hourRowHeight,
											child: Row(
												children: [
													// 时间标签区域（不参与选择高亮）
													Container(
														width: _gutterWidth,
														alignment: Alignment.topRight,
														padding: const EdgeInsets.only(right: 8, top: 4),
														child: Text(_hourLabel(hour), style: theme.textTheme.bodySmall),
													),
													// 时间段选择区域（支持15分钟单位选择）
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
													),
												],
											),
										);
									}),
								),
								// 活动显示层
								..._buildEventBlocks(),
								// 空白区域手势检测层（时间段选择）
								..._buildEmptyAreaGestureDetectors(),
							],
						),
					),
				),
			],
				),
			),
		);
	}

	String _hourLabel(int h) => h.toString().padLeft(2, '0') + ':00';
	
	// 获取活动的唯一标识
	String _getEventId(CalendarEvent event) {
		return event.id;
	}
	
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
	
	// 处理右键点击
	void _onSecondaryTapDown(TapDownDetails details) {
		final event = _getEventAtPosition(details.localPosition.dy);
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
	
	
	
	// 粘贴活动（从剪贴板创建新活动）
	void _pasteEvent() {
		Clipboard.getData('text/plain').then((data) {
			if (data?.text != null && data!.text!.isNotEmpty) {
				// 解析剪贴板内容
				final lines = data.text!.split('\n');
				final title = lines[0].trim();
				
				// 如果是从我们的复制功能来的文本，第二行可能包含时间信息
				// 否则就创建一个默认的1小时活动
				DateTime startTime;
				DateTime endTime;
				
				if (_selectedStartQuarter != null && _selectedEndQuarter != null) {
					// 如果有选中的时间段，使用选中的时间
					final startTimeOfDay = _quarterToTimeOfDay(_selectedStartQuarter!);
					final endTimeOfDay = _quarterToTimeOfDay(_selectedEndQuarter! + 1);
					startTime = DateTime(
						widget.date.year,
						widget.date.month,
						widget.date.day,
						startTimeOfDay.hour,
						startTimeOfDay.minute,
					);
					endTime = DateTime(
						widget.date.year,
						widget.date.month,
						widget.date.day,
						endTimeOfDay.hour,
						endTimeOfDay.minute,
					);
				} else {
					// 默认创建1小时活动，从当前时间开始
					final now = DateTime.now();
					startTime = DateTime(
						widget.date.year,
						widget.date.month,
						widget.date.day,
						now.hour,
						0,
					);
					endTime = startTime.add(Duration(hours: 1));
				}
				
				final newEvent = CalendarEvent(
					title: title,
					allDay: false,
					description: '',
					color: Colors.blue, // 默认颜色
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
	
	// 复制活动（复制到剪贴板）
	void _copyEvent(CalendarEvent event) {
		final eventText = '${event.title}\n${_formatTime(TimeOfDay.fromDateTime(event.start))}-${_formatTime(TimeOfDay.fromDateTime(event.end))}';
		Clipboard.setData(ClipboardData(text: eventText));
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(content: Text('活动已复制到剪贴板')),
		);
	}
	
	// 创建活动副本
	void _duplicateEvent(CalendarEvent event) {
		final newEvent = CalendarEvent(
			title: '${event.title} (副本)',
			allDay: event.allDay,
			description: event.description,
			color: event.color,
			start: event.start.add(Duration(hours: 1)), // 推迟1小时
			end: event.end.add(Duration(hours: 1)),
		);
		widget.onAddEvent(newEvent);
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(content: Text('活动副本已创建')),
		);
	}
	
	// 判断某个15分钟段是否被选中
	bool _isQuarterSelected(int quarterIndex) {
		if (_selectedStartQuarter == null || _selectedEndQuarter == null) return false;
		final start = _selectedStartQuarter!;
		final end = _selectedEndQuarter!;
		return quarterIndex >= start && quarterIndex <= end;
	}
	
	// 根据y坐标计算15分钟段索引（0-95）
	int _getQuarterFromY(double y) {
		final quarter = (y / (_hourRowHeight / 4)).floor();
		return quarter.clamp(0, 95); // 24小时 * 4 = 96个15分钟段，索引0-95
	}
	
	// 将15分钟段索引转换为TimeOfDay
	TimeOfDay _quarterToTimeOfDay(int quarter) {
		final hour = quarter ~/ 4;
		final minute = (quarter % 4) * 15;
		return TimeOfDay(hour: hour, minute: minute);
	}
	
	// 获取当前日期的所有非全天活动（优化版）
	List<CalendarEvent> _getDayEvents() {
		final currentDate = DateTime(widget.date.year, widget.date.month, widget.date.day);
		final events = <CalendarEvent>[];
		
		// 获取正在操作的事件ID（避免重复计算）
		final movingEventId = _isMoving ? _movingEvent?.id : null;
		final resizingEventId = _isResizing ? _resizingEvent?.id : null;
		
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
		if (_isMoving && _movingEvent != null) {
			final movingDate = DateTime(_movingEvent!.start.year, _movingEvent!.start.month, _movingEvent!.start.day);
			if (movingDate.isAtSameMomentAs(currentDate)) {
				events.add(_movingEvent!);
			}
		}
		
		if (_isResizing && _resizingEvent != null) {
			final resizingDate = DateTime(_resizingEvent!.start.year, _resizingEvent!.start.month, _resizingEvent!.start.day);
			if (resizingDate.isAtSameMomentAs(currentDate)) {
				events.add(_resizingEvent!);
			}
		}
		
		return events;
	}
	
	// 构建活动显示块
	List<Widget> _buildEventBlocks() {
		final dayEvents = _getDayEvents();
		final List<Widget> eventWidgets = [];
		
		for (final event in dayEvents) {
			// 计算活动在时间轴上的位置
			final startMinutes = event.start.hour * 60 + event.start.minute;
			final endMinutes = event.end.hour * 60 + event.end.minute;
			
			// 转换为Y坐标（从00:00开始计算）
			final startY = (startMinutes / 15) * (_hourRowHeight / 4);
			final endY = (endMinutes / 15) * (_hourRowHeight / 4);
			final height = endY - startY;
			final isSelected = _selectedEventId != null && _selectedEventId == _getEventId(event);
			
			// 创建活动块
			eventWidgets.add(
				Positioned(
					left: _gutterWidth, // 从时间段区域开始（覆盖左边框）
					right: 0, // 直到右边缘（覆盖右边框）
					top: startY,
					height: height,
					child: Stack(
						children: [
							// 主活动块
							Container(
								width: double.infinity, // 强制占满整个可用宽度
								// 移除所有边距，让活动块完全覆盖时间段宽度
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
										: // 大于30像素时，使用原来的两行布局
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
												if (height > 30) // 只有足够高度时才显示时间
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
							// 顶部调整手柄（只有选中状态且足够高时才显示）
							if (isSelected && height > _resizeHandleHeight * 2)
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
							if (isSelected && height > _resizeHandleHeight * 2)
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
		
		return eventWidgets;
	}
	
	// 构建背景手势检测器（全覆盖，智能处理不同类型的手势）
	List<Widget> _buildEmptyAreaGestureDetectors() {
		return [
			Positioned.fill(
				left: _gutterWidth,
				child: MouseRegion(
					cursor: _getCurrentCursor(),
					onHover: _onHover,
					child: GestureDetector(
						behavior: HitTestBehavior.translucent,
						onTapDown: _onTapDown,
						onPanStart: _onPanStart,
						onPanUpdate: _onPanUpdate,
						onPanEnd: _onPanEnd,
						onTap: _onTap,
						onSecondaryTapDown: _onSecondaryTapDown,
						child: Container(color: Colors.transparent),
					),
				),
			),
		];
	}
	
	// 检查点击位置是否在活动块内
	CalendarEvent? _getEventAtPosition(double y) {
		final dayEvents = _getDayEvents();
		
		CalendarEvent? foundEvent;
		for (final event in dayEvents) {
			// 计算活动在时间轴上的位置
			final startMinutes = event.start.hour * 60 + event.start.minute;
			final endMinutes = event.end.hour * 60 + event.end.minute;
			
			// 转换为Y坐标
			final startY = (startMinutes / 15) * (_hourRowHeight / 4);
			final endY = (endMinutes / 15) * (_hourRowHeight / 4);
			
			// 检查点击位置是否在这个活动范围内
			if (y >= startY && y <= endY) {
				foundEvent = event;
				// 继续循环以找到最后一个匹配的活动（处理重叠情况）
			}
		}
		
		return foundEvent;
	}
	
	// 格式化时间显示
	String _formatTime(TimeOfDay time) {
		return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
	}
	
	double? _lastTapY; // 记录最后一次点击的Y坐标
	double? _currentHoverY; // 当前鼠标悬停的Y坐标
	
	// 鼠标悬停处理
	void _onHover(PointerHoverEvent event) {
		final newY = event.localPosition.dy;
		if (_currentHoverY != newY) {
			setState(() {
				_currentHoverY = newY;
			});
		}
	}
	
	// 获取当前光标样式
	SystemMouseCursor _getCurrentCursor() {
		// 如果正在调整大小，保持上下箭头样式
		if (_isResizing) {
			return SystemMouseCursors.resizeUpDown;
		}
		
		if (_currentHoverY == null) return SystemMouseCursors.basic;
		
		// 检查是否在调整手柄区域
		final event = _getEventAtPosition(_currentHoverY!);
		if (event != null && _selectedEvent == event) {
			final eventStartMinutes = event.start.hour * 60 + event.start.minute;
			final eventStartY = (eventStartMinutes / 15) * (_hourRowHeight / 4);
			final relativeY = _currentHoverY! - eventStartY;
			final eventHeight = (event.end.difference(event.start).inMinutes / 15) * (_hourRowHeight / 4);
			
			// 检查是否在调整手柄区域
			if (eventHeight > _resizeHandleHeight * 2) {
				if (relativeY <= _resizeHandleHeight || relativeY >= eventHeight - _resizeHandleHeight) {
					return SystemMouseCursors.resizeUpDown;
				}
			}
		}
		
		return SystemMouseCursors.basic;
	}
	
	// 处理点击按下
	void _onTapDown(TapDownDetails details) {
		_lastTapY = details.localPosition.dy;
	}
	
	// 处理单击
	void _onTap() {
		
		if (_lastTapY == null) {
			_clearSelection();
			return;
		}
		
		// 检查是否点击了活动块
		final event = _getEventAtPosition(_lastTapY!);
		if (event != null) {
			_selectEvent(event);
		} else {
			_clearSelection();
		}
	}
	
	// 开始拖拽
	void _onPanStart(DragStartDetails details) {
		
		// 如果正在调整大小或移动，不处理时间段选择
		if (_isResizing || _isMoving) {
			return;
		}
		
		// 首先检查是否点击了活动块
		final event = _getEventAtPosition(details.localPosition.dy);
		if (event != null) {
			
			// 如果活动已被选中，检查点击位置来决定是移动还是调整大小
			if (_selectedEvent == event) {
				final eventStartMinutes = event.start.hour * 60 + event.start.minute;
				final eventEndMinutes = event.end.hour * 60 + event.end.minute;
				final eventStartY = (eventStartMinutes / 15) * (_hourRowHeight / 4);
				final eventEndY = (eventEndMinutes / 15) * (_hourRowHeight / 4);
				final eventHeight = eventEndY - eventStartY;
				
				final relativeY = details.localPosition.dy - eventStartY;
				
				// 检查是否点击在调整手柄区域
				if (eventHeight > _resizeHandleHeight * 2) {
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
				// 活动未被选中，直接开始移动（同时会自动选中）
				_onEventMoveStart(event, details);
				return;
			}
		}
		
		// 如果没有点击活动块，开始时间段选择
		final quarter = _getQuarterFromY(details.localPosition.dy);
		setState(() {
			_initialQuarter = quarter;
			_selectedStartQuarter = quarter;
			_selectedEndQuarter = quarter;
			_isSelecting = true;
		});
	}
	
	// 拖拽更新
	void _onPanUpdate(DragUpdateDetails details) {
		// 处理调整大小
		if (_isResizing) {
			_onResizeUpdate(details);
			return;
		}
		
		// 处理移动
		if (_isMoving) {
			_onEventMoveUpdate(details);
			return;
		}
		
		// 处理时间段选择
		if (!_isSelecting || _initialQuarter == null) return;
		final quarter = _getQuarterFromY(details.localPosition.dy);
		setState(() {
			// 总是以初始点为基准，确保开始时间 <= 结束时间
			final initial = _initialQuarter!;
			if (quarter >= initial) {
				// 向下拖拽：从初始位置到当前位置
				_selectedStartQuarter = initial;
				_selectedEndQuarter = quarter;
			} else {
				// 向上拖拽：从当前位置到初始位置
				_selectedStartQuarter = quarter;
				_selectedEndQuarter = initial;
			}
		});
	}
	
	// 结束拖拽
	void _onPanEnd(DragEndDetails details) {
		// 处理调整大小结束
		if (_isResizing) {
			_onResizeEnd(details);
			return;
		}
		
		// 处理移动结束
		if (_isMoving) {
			_onEventMoveEnd(details);
			return;
		}
		
		// 处理时间段选择结束
		if (!_isSelecting || _selectedStartQuarter == null || _selectedEndQuarter == null) {
			_clearSelection();
			return;
		}
		
		setState(() {
			_isSelecting = false;
		});
		
		// 显示添加活动对话框
		_showAddEventDialog();
	}
	
	// 清除选择
	void _clearSelection() {
		setState(() {
			_selectedStartQuarter = null;
			_selectedEndQuarter = null;
			_initialQuarter = null;
			_isSelecting = false;
			_selectedEvent = null; // 同时清除活动选择
			_selectedEventId = null; // 清除选中活动ID
			// 清除调整大小状态
			_isResizing = false;
			_isResizingTop = false;
			_resizingEvent = null;
			_initialResizeY = null;
			_originalStartTime = null;
			_originalEndTime = null;
			// 清除移动状态
			_isMoving = false;
			_movingEvent = null;
			_initialMoveY = null;
			_initialMoveStartTime = null;
			_initialMoveEndTime = null;
			_hasMoved = false;
		});
		// 通知父组件清除选择
		widget.onClearSelection?.call();
	}
	
	// 选择活动
	void _selectEvent(CalendarEvent event) {
		setState(() {
			_selectedEvent = event;
			_selectedEventId = _getEventId(event); // 设置选中活动ID
			// 清除时间段选择
			_selectedStartQuarter = null;
			_selectedEndQuarter = null;
			_isSelecting = false;
		});
		// 通知父组件活动被选中
		widget.onSelectEvent?.call(event);
	}
	
	// === 活动调整大小相关方法 ===
	
	// 开始调整大小
	void _onResizeStart(CalendarEvent event, bool isTop, DragStartDetails details) {
		setState(() {
			_isResizing = true;
			_isResizingTop = isTop;
			_resizingEvent = event;
			_selectedEvent = event; // 确保事件被选中
			_selectedEventId = _getEventId(event); // 设置选中活动ID
			_initialResizeY = details.globalPosition.dy;
			// 保存真正的原始时间，不会在拖拽过程中被修改
			_originalStartTime = event.start;
			_originalEndTime = event.end;
		});
	}
	
	// 调整大小更新
	void _onResizeUpdate(DragUpdateDetails details) {
		if (!_isResizing || _resizingEvent == null || _initialResizeY == null) return;
		
		// 计算从开始位置的总体移动距离
		final totalDeltaY = details.globalPosition.dy - _initialResizeY!;
		final deltaQuarters = (totalDeltaY / (_hourRowHeight / 4)).round();
		
		DateTime newStart = _originalStartTime!;
		DateTime newEnd = _originalEndTime!;
		
		// 定义边界：使用当前显示日期
		final dayStart = DateTime(widget.date.year, widget.date.month, widget.date.day, 0, 0);
		final dayEnd = DateTime(widget.date.year, widget.date.month, widget.date.day, 23, 59);
		
		// 使用原始时间作为计算基准，避免状态突变
		if (_isResizingTop) {
			// 调整开始时间（拖动顶部）
			newStart = _originalStartTime!.add(Duration(minutes: deltaQuarters * 15));
			
			// 如果新开始时间超过原始结束时间，进行平滑的头尾互换
			if (newStart.isAfter(_originalEndTime!)) {
				// 计算超出部分，应用到另一端
				final overflowMinutes = newStart.difference(_originalEndTime!).inMinutes;
				newStart = _originalEndTime!;
				newEnd = _originalEndTime!.add(Duration(minutes: overflowMinutes));
			} else {
				// 正常拖动，保持结束时间不变
				newEnd = _originalEndTime!;
			}
		} else {
			// 调整结束时间（拖动底部）
			newEnd = _originalEndTime!.add(Duration(minutes: deltaQuarters * 15));
			
			// 如果新结束时间早于原始开始时间，进行平滑的头尾互换
			if (newEnd.isBefore(_originalStartTime!)) {
				// 计算超出部分，应用到另一端
				final overflowMinutes = _originalStartTime!.difference(newEnd).inMinutes;
				newEnd = _originalStartTime!;
				newStart = _originalStartTime!.subtract(Duration(minutes: overflowMinutes));
			} else {
				// 正常拖动，保持开始时间不变
				newStart = _originalStartTime!;
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
				// 如果在拖动顶部，调整开始时间
				newStart = newEnd.subtract(minDuration);
				if (newStart.isBefore(dayStart)) {
					newStart = dayStart;
					newEnd = newStart.add(minDuration);
					// 如果调整后的结束时间超出边界，则限制在边界内
					if (newEnd.isAfter(dayEnd)) {
						newEnd = dayEnd;
						newStart = newEnd.subtract(minDuration);
					}
				}
			} else {
				// 如果在拖动底部，调整结束时间
				newEnd = newStart.add(minDuration);
				if (newEnd.isAfter(dayEnd)) {
					newEnd = dayEnd;
					newStart = newEnd.subtract(minDuration);
					// 如果调整后的开始时间超出边界，则限制在边界内
					if (newStart.isBefore(dayStart)) {
						newStart = dayStart;
						newEnd = newStart.add(minDuration);
					}
				}
			}
		}
		
		
		final updatedEvent = _resizingEvent!.copyWith(
			start: newStart,
			end: newEnd,
		);
		
		// 在调整大小过程中只更新本地状态，不触发数据库操作
		setState(() {
			_resizingEvent = updatedEvent;
			_selectedEvent = updatedEvent;
			_selectedEventId = _getEventId(updatedEvent); // 更新选中活动ID
		});
		
		// 通知父组件选中状态已更新（用于实时更新编辑面板）
		widget.onSelectEvent?.call(updatedEvent);
		
	}
	
	// 调整大小结束
	void _onResizeEnd(DragEndDetails details) {
		// 调整大小结束时才进行数据库更新
		if (_resizingEvent != null && _originalStartTime != null && _originalEndTime != null) {
			// 使用真正的原始状态创建原始事件用于数据库更新
			final originalEvent = _resizingEvent!.copyWith(
				start: _originalStartTime!,
				end: _originalEndTime!,
			);
			
			var finalEvent = _resizingEvent!;
			
			// 最后一次验证事件时间的有效性
			final duration = finalEvent.end.difference(finalEvent.start);
			
			// 如果时长小于15分钟，进行最终修正
			if (duration.inMinutes < 15) {
				finalEvent = finalEvent.copyWith(
					end: finalEvent.start.add(const Duration(minutes: 15)),
				);
			}
			
			// 只有当大小真正改变时才更新数据库
			if (finalEvent.start != _originalStartTime! || finalEvent.end != _originalEndTime!) {
				if (widget.onUpdateEvent != null) {
					widget.onUpdateEvent!(originalEvent, finalEvent);
				}
				// 通知父组件选中状态已更新
				widget.onSelectEvent?.call(finalEvent);
			}
		}
		
		// 合并setState调用，避免多次重建
		setState(() {
			// 在清除_resizingEvent之前保存最终状态
			if (_resizingEvent != null) {
				_selectedEvent = _resizingEvent!;
				_selectedEventId = _getEventId(_resizingEvent!);
			}
			
			_isResizing = false;
			_isResizingTop = false;
			_resizingEvent = null;
			_initialResizeY = null;
			_originalStartTime = null;
			_originalEndTime = null;
		});
	}
	
	// === 活动移动相关方法 ===
	
	// 开始移动活动
	void _onEventMoveStart(CalendarEvent event, DragStartDetails details) {
		// 计算相对于活动块的位置
		final eventStartMinutes = event.start.hour * 60 + event.start.minute;
		final eventStartY = (eventStartMinutes / 15) * (_hourRowHeight / 4);
		final relativeY = details.localPosition.dy - eventStartY;
		final eventHeight = (event.end.difference(event.start).inMinutes / 15) * (_hourRowHeight / 4);
		
		
		// 如果点击在顶部或底部调整手柄区域，不开始移动
		if (_selectedEvent == event && eventHeight > _resizeHandleHeight * 2) {
			if (relativeY <= _resizeHandleHeight || relativeY >= eventHeight - _resizeHandleHeight) {
				return;
			}
		}
		
		setState(() {
			_isMoving = true;
			_movingEvent = event;
			_selectedEvent = event; // 确保事件被选中
			_selectedEventId = _getEventId(event); // 设置选中活动ID
			_initialMoveY = details.globalPosition.dy;
			_initialMoveStartTime = event.start;
			_initialMoveEndTime = event.end;
			_hasMoved = false; // 重置移动标记
		});
	}
	
	// 移动活动更新
	void _onEventMoveUpdate(DragUpdateDetails details) {
		if (!_isMoving || _movingEvent == null || _initialMoveY == null) return;
		
		
		// 计算从开始位置的总体移动距离
		final totalDeltaY = details.globalPosition.dy - _initialMoveY!;
		final deltaQuarters = (totalDeltaY / (_hourRowHeight / 4)).round();
		
		// 如果移动距离超过阈值，标记为已移动
		if (totalDeltaY.abs() > 5) { // Y轴5像素的阈值
			_hasMoved = true;
		}
		
		
		// 计算新的开始和结束时间（保持时长不变）
		final duration = _initialMoveEndTime!.difference(_initialMoveStartTime!);
		var newStart = _initialMoveStartTime!.add(Duration(minutes: deltaQuarters * 15));
		var newEnd = newStart.add(duration);
		
		// 实时边界限制：确保活动块始终在当前显示日期的有效范围内
		final dayStart = DateTime(widget.date.year, widget.date.month, widget.date.day, 0, 0);
		final dayEnd = DateTime(widget.date.year, widget.date.month, widget.date.day, 23, 59);
		
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
		
		
		final updatedEvent = _movingEvent!.copyWith(
			start: newStart,
			end: newEnd,
		);
		
		// 在拖拽过程中只更新本地状态，不触发数据库操作
		setState(() {
			_movingEvent = updatedEvent;
			_selectedEvent = updatedEvent;
			_selectedEventId = _getEventId(updatedEvent); // 更新选中活动ID
		});
		
		// 通知父组件选中状态已更新（用于实时更新编辑面板）
		widget.onSelectEvent?.call(updatedEvent);
		
	}
	
	// 移动活动结束（统一状态恢复逻辑）
	void _onEventMoveEnd(DragEndDetails details) {
		// 移动结束时才进行数据库更新
		CalendarEvent? finalEvent;
		
		if (_movingEvent != null && _initialMoveStartTime != null && _initialMoveEndTime != null) {
			final originalEvent = _movingEvent!.copyWith(
				start: _initialMoveStartTime!,
				end: _initialMoveEndTime!,
			);
			
			// 如果没有实际移动，恢复原始状态
			if (!_hasMoved) {
				finalEvent = originalEvent;
			} else {
				// 只有当位置真正改变时才更新数据库
				if (_movingEvent!.start != _initialMoveStartTime! || _movingEvent!.end != _initialMoveEndTime!) {
					finalEvent = _movingEvent!;
					
					if (widget.onUpdateEvent != null) {
						widget.onUpdateEvent!(originalEvent, _movingEvent!);
					}
					// 通知父组件选中状态已更新
					widget.onSelectEvent?.call(_movingEvent!);
				} else {
					finalEvent = _movingEvent!;
				}
			}
		}
		
		// 统一的setState调用，确保状态同步
		setState(() {
			// 设置最终状态（避免状态不同步问题）
			if (finalEvent != null) {
				_selectedEvent = finalEvent;
				_selectedEventId = _getEventId(finalEvent);
			}
			
			_isMoving = false;
			_movingEvent = null;
			_initialMoveY = null;
			_initialMoveStartTime = null;
			_initialMoveEndTime = null;
			_hasMoved = false;
		});
	}
	
	// 显示添加活动对话框
	Future<void> _showAddEventDialog() async {
		if (_selectedStartQuarter == null || _selectedEndQuarter == null) return;
		
		final startTime = _quarterToTimeOfDay(_selectedStartQuarter!);
		// 结束时间为选中结束时间段的下一个15分钟
		final endTime = _quarterToTimeOfDay(_selectedEndQuarter! + 1);
		
		final event = await showDialog<CalendarEvent>(
			context: context,
			builder: (context) => DayViewAddEventDialog(
				date: widget.date,
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
				// 更新当前事件引用
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

