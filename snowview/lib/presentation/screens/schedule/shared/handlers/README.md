# Calendar Handlers - 日历事件处理器

这个目录包含了日历视图的事件操作逻辑处理器。

## 文件结构

```
shared/handlers/
├── event_resize_handler.dart      # 事件调整大小处理器
├── event_move_handler.dart        # 事件移动处理器
├── time_selection_handler.dart    # 时间段选择处理器
├── keyboard_handler.dart          # 键盘事件处理器
└── README.md                      # 本文档
```

## 处理器说明

### 1. EventResizeHandler (event_resize_handler.dart)

事件调整大小的计算处理器，负责复杂的时间计算逻辑。

**主要功能：**
- 头尾互换：当拖拽超过另一端时平滑切换
- 边界限制：确保事件在当天00:00-23:59范围内
- 最小时长：保证至少15分钟
- 事件验证：最终验证和修正

**核心方法：**

#### `calculateResize()`
计算调整大小后的新时间

```dart
final result = EventResizeHandler.calculateResize(
  originalStartTime: DateTime(2024, 1, 1, 9, 0),
  originalEndTime: DateTime(2024, 1, 1, 10, 0),
  totalDeltaY: 100.0,  // Y轴移动距离
  isResizingTop: true,  // 调整顶部
  boundaryDate: DateTime(2024, 1, 1),
);

print(result.newStart);  // 新的开始时间
print(result.newEnd);    // 新的结束时间
print(result.wasSwapped); // 是否发生了头尾互换
```

#### `validateAndFixEvent()`
验证并修正事件时间

```dart
final fixedEvent = EventResizeHandler.validateAndFixEvent(event);
// 如果时长 < 15分钟，会自动修正为15分钟
```

#### `hasChanged()`
检查事件是否真正改变

```dart
final changed = EventResizeHandler.hasChanged(
  event,
  originalStart,
  originalEnd,
);
```

**返回值：**
- `ResizeResult`: 包含 `newStart`, `newEnd`, `wasSwapped`

---

### 2. EventMoveHandler (event_move_handler.dart)

事件移动的计算处理器，支持日视图和周视图的不同移动逻辑。

**架构设计：**
```
EventMoveHandler (抽象基类)
  ├── DayEventMoveHandler (日视图：垂直移动)
  └── WeekEventMoveHandler (周视图：垂直+水平移动)
```

**主要功能：**
- 时长保持：移动时保持事件时长不变
- 边界限制：确保事件在有效日期范围内
- 移动阈值检测：判断是否超过移动阈值
- 跨天移动：周视图支持跨列（跨天）移动

**核心方法：**

#### DayEventMoveHandler
日视图专用，只处理Y轴移动

```dart
final handler = DayEventMoveHandler();
final result = handler.calculateMove(
  originalStartTime: event.start,
  originalEndTime: event.end,
  totalDeltaY: 50.0,
  boundaryDate: DateTime(2024, 1, 1),
  previouslyMoved: false,
);

print(result.newStart);  // 新的开始时间
print(result.newEnd);    // 新的结束时间
print(result.hasMoved);  // 是否超过移动阈值
```

#### WeekEventMoveHandler
周视图专用，处理X轴和Y轴移动

```dart
final handler = WeekEventMoveHandler();
final result = handler.calculateMove(
  originalStartTime: event.start,
  originalEndTime: event.end,
  totalDeltaY: 50.0,
  boundaryDate: DateTime(2024, 1, 1),
  previouslyMoved: false,
  totalDeltaX: 200.0,  // X轴移动距离
  weekDays: weekDaysList,  // 周日期列表
  targetColumnIndex: 3,  // 目标列索引
);

print(result.targetDate);  // 目标日期（可能不同于原日期）
```

#### 静态工具方法

**calculateTargetColumn()** - 根据X坐标计算目标列
```dart
final targetColumn = WeekEventMoveHandler.calculateTargetColumn(
  currentGlobalX: details.globalPosition.dx,
  stackGlobalX: stackPosition.dx,
  availableWidth: 700.0,
);
// 返回 0-6（周一到周日）
```

**EventMoveHandlerUtils.hasChanged()** - 检查是否改变
```dart
final changed = EventMoveHandlerUtils.hasChanged(
  event,
  originalStart,
  originalEnd,
);
```

**返回值：**
- `MoveResult`: 包含 `newStart`, `newEnd`, `hasMoved`, `targetDate`

---

### 3. TimeSelectionHandler (time_selection_handler.dart)

时间段选择的逻辑处理器。

**主要功能：**
- 判断15分钟段是否被选中
- 计算选择范围
- 创建时间范围
- 验证选择有效性

**核心方法：**

#### `isQuarterSelected()`
判断15分钟段是否被选中（日视图）

```dart
final isSelected = TimeSelectionHandler.isQuarterSelected(
  quarterIndex: 24,  // 6:00 AM (24 = 6 * 4)
  selectedStartQuarter: 20,
  selectedEndQuarter: 28,
);
// 返回 true
```

#### `isQuarterSelectedInColumn()`
判断特定列的15分钟段是否被选中（周视图）

```dart
final isSelected = TimeSelectionHandler.isQuarterSelectedInColumn(
  quarterIndex: 24,
  column: 2,  // 周三
  selectedStartQuarter: 20,
  selectedEndQuarter: 28,
  selectedColumn: 2,
);
```

#### `calculateSelectionRange()`
计算选择范围

```dart
final range = TimeSelectionHandler.calculateSelectionRange(
  initialQuarter: 20,
  currentQuarter: 28,
);

print(range.start);  // 20
print(range.end);    // 28
```

#### `createTimeRange()`
从15分钟段创建时间范围

```dart
final timeRange = TimeSelectionHandler.createTimeRange(
  date: DateTime(2024, 1, 1),
  startQuarter: 20,  // 5:00 AM
  endQuarter: 28,    // 7:00 AM
);

print(timeRange.start);  // DateTime(2024, 1, 1, 5, 0)
print(timeRange.end);    // DateTime(2024, 1, 1, 7, 15)
// 注意：endQuarter + 1 的开始时间
```

#### `isValidSelection()`
验证选择是否有效

```dart
final isValid = TimeSelectionHandler.isValidSelection(
  startQuarter: 20,
  endQuarter: 28,
);
```

#### `clearSelection()`
清空选择状态

```dart
final cleared = TimeSelectionHandler.clearSelection();
// 返回所有状态重置为 null 的记录
```

---

### 4. CalendarKeyboardHandler (keyboard_handler.dart)

键盘事件处理器。

**主要功能：**
- Delete键删除事件
- Escape键清除选择
- 键盘快捷键管理

**核心方法：**

#### `handleKeyEvent()`
处理键盘事件

```dart
final handled = CalendarKeyboardHandler.handleKeyEvent(
  event: keyEvent,
  selectedEvent: currentEvent,
  onDelete: () {
    // 删除事件
  },
);
```

#### `canDeleteEvent()`
检查是否可以删除

```dart
final canDelete = CalendarKeyboardHandler.canDeleteEvent(
  selectedEvent: event,
  onDeleteEvent: widget.onDeleteEvent,
);
```

#### `deleteEvent()`
执行删除操作

```dart
CalendarKeyboardHandler.deleteEvent(
  selectedEvent: event,
  onDeleteEvent: widget.onDeleteEvent,
  onClearSelection: () {
    // 清除选择
  },
);
```

#### `getKeyboardShortcuts()`
获取支持的快捷键列表

```dart
final shortcuts = CalendarKeyboardHandler.getKeyboardShortcuts();
for (final shortcut in shortcuts) {
  print('${shortcut.key}: ${shortcut.description}');
}
// 输出：
// Delete: 删除选中的事件
// Escape: 清除选择
```

---

## 在视图中的使用示例

### DayView 中的使用

```dart
class _DayViewState extends State<DayView> {
  // 状态变量
  bool _isResizing = false;
  CalendarEvent? _resizingEvent;
  DateTime? _originalStartTime;
  DateTime? _originalEndTime;
  
  // 调整大小更新
  void _onResizeUpdate(DragUpdateDetails details) {
    final totalDeltaY = details.globalPosition.dy - _initialResizeY!;
    
    // 使用handler计算
    final result = EventResizeHandler.calculateResize(
      originalStartTime: _originalStartTime!,
      originalEndTime: _originalEndTime!,
      totalDeltaY: totalDeltaY,
      isResizingTop: _isResizingTop,
      boundaryDate: widget.date,
    );
    
    // 应用结果
    final updatedEvent = _resizingEvent!.copyWith(
      start: result.newStart,
      end: result.newEnd,
    );
    
    setState(() {
      _resizingEvent = updatedEvent;
    });
  }
  
  // 移动更新
  void _onEventMoveUpdate(DragUpdateDetails details) {
    final totalDeltaY = details.globalPosition.dy - _initialMoveY!;
    
    // 使用handler计算
    final handler = DayEventMoveHandler();
    final result = handler.calculateMove(
      originalStartTime: _initialMoveStartTime!,
      originalEndTime: _initialMoveEndTime!,
      totalDeltaY: totalDeltaY,
      boundaryDate: widget.date,
      previouslyMoved: _hasMoved,
    );
    
    // 应用结果
    _hasMoved = result.hasMoved;
    // ...
  }
}
```

### WeekView 中的使用

```dart
class _WeekViewState extends State<WeekView> {
  // 移动更新（包含X轴）
  void _onEventMoveUpdate(DragUpdateDetails details) {
    final totalDeltaY = details.globalPosition.dy - _initialMoveY!;
    final totalDeltaX = details.globalPosition.dx - _initialMoveX!;
    
    // 计算目标列
    final days = _weekDays(widget.centerDate);
    final targetColumn = _getTargetColumnFromPosition(
      details.globalPosition.dx,
      availableWidth,
    );
    
    // 使用handler计算
    final handler = WeekEventMoveHandler();
    final result = handler.calculateMove(
      originalStartTime: _initialMoveStartTime!,
      originalEndTime: _initialMoveEndTime!,
      totalDeltaY: totalDeltaY,
      boundaryDate: widget.centerDate,
      previouslyMoved: _hasMoved,
      totalDeltaX: totalDeltaX,
      weekDays: days,
      targetColumnIndex: targetColumn,
    );
    
    // result.targetDate 可能不同于原日期
    _hasMoved = result.hasMoved;
    // ...
  }
}
```

---

## 设计原则

1. **纯函数设计：** Handler只负责计算，不持有状态
2. **职责分离：** 视图管理状态，Handler处理逻辑
3. **可测试性：** 纯计算逻辑易于单元测试
4. **可复用性：** Handler可在不同视图中复用
5. **类型安全：** 明确的参数和返回类型

## 状态管理模式

**视图负责：**
- 持有状态变量（`_isResizing`, `_movingEvent` 等）
- 触发 setState
- 调用数据库更新回调

**Handler负责：**
- 纯计算逻辑
- 边界检查
- 规则验证

这种分离使得：
- 逻辑易于测试（不依赖Widget）
- 代码易于复用（多个视图共享）
- 关注点明确（视图 vs 逻辑）

## 测试建议

Handler的纯函数特性使其非常适合单元测试：

```dart
test('EventResizeHandler - head-tail swap', () {
  final result = EventResizeHandler.calculateResize(
    originalStartTime: DateTime(2024, 1, 1, 10, 0),
    originalEndTime: DateTime(2024, 1, 1, 11, 0),
    totalDeltaY: 200.0,  // 拖拽超过结束时间
    isResizingTop: true,
    boundaryDate: DateTime(2024, 1, 1),
  );
  
  expect(result.wasSwapped, true);
  expect(result.newStart.hour, 11);  // 互换后的开始时间
});
```

## 重构历史

**2025-10-06** - 初始重构
- 从视图中提取事件操作逻辑
- 创建专用的Handler类
- 实现纯函数计算模式
- 减少视图文件 200+ 行代码

## 未来扩展

可以考虑添加的Handler：

1. **EventCollisionHandler** - 事件冲突检测
2. **EventSnapHandler** - 吸附到15分钟网格
3. **EventDragHandler** - 统一拖拽行为
4. **GestureHandler** - 手势识别和分发

---

**维护者请注意：**
- 保持Handler的纯函数特性
- 避免在Handler中访问Widget状态
- 修改后更新对应的使用示例
- 添加适当的单元测试
