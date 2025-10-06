# Calendar Widgets - 日历UI组件库

这个目录包含了日历视图（DayView 和 WeekView）的共享UI组件。

## 文件结构

```
shared/widgets/
├── editable_text_field.dart  # 可编辑文本框组件
├── event_context_menu.dart   # 右键上下文菜单系统
├── event_block.dart          # 事件块组件
├── resize_handle.dart        # 调整大小手柄组件
└── README.md                 # 本文档
```

## 组件说明

### 1. EventEditableTextField (editable_text_field.dart)

可编辑的事件标题文本框，用于在右键菜单中快速编辑事件名称。

**特性：**
- 实时更新事件标题
- 支持回车提交并关闭菜单
- 自动去除前后空格
- 防止空标题

**使用示例：**
```dart
EventEditableTextField(
  initialText: event.title,
  event: event,
  onUpdateEvent: (oldEvent, newEvent) {
    // 处理事件更新
  },
)
```

### 2. EventContextMenu (event_context_menu.dart)

事件右键上下文菜单系统，提供完整的事件操作功能。

**功能包括：**
- 颜色选择（8种预设颜色）
- 快速编辑标题
- 复制事件
- 粘贴事件
- 创建副本
- 删除事件

**使用示例：**
```dart
EventContextMenu.show(
  context: context,
  position: tapPosition,
  event: selectedEvent,
  onUpdateEvent: _onUpdateEvent,
  onDeleteEvent: _onDeleteEvent,
  onAddEvent: _onAddEvent,
  targetDate: DateTime.now(),
  selectedStartQuarter: 8,
  selectedEndQuarter: 12,
);
```

**参数说明：**
- `context` - BuildContext
- `position` - 菜单显示位置（全局坐标）
- `event` - 当前选中的事件
- `onUpdateEvent` - 事件更新回调
- `onDeleteEvent` - 事件删除回调
- `onAddEvent` - 事件添加回调（用于粘贴和创建副本）
- `targetDate` - 目标日期（用于粘贴）
- `selectedStartQuarter` - 选中的开始15分钟段（可选）
- `selectedEndQuarter` - 选中的结束15分钟段（可选）

### 3. EventResizeHandle (resize_handle.dart)

事件调整大小手柄组件，显示在事件块的顶部或底部。

**特性：**
- 支持顶部和底部两种位置
- 自定义颜色和高度
- 上下箭头光标提示
- 透明背景，带有视觉指示条

**使用示例：**
```dart
EventResizeHandle(
  isTop: true,  // true=顶部，false=底部
  color: Colors.blue,
  handleHeight: 12.0,
  onPanStart: (details) {
    // 开始调整大小
  },
  onPanUpdate: (details) {
    // 调整大小中
  },
  onPanEnd: (details) {
    // 调整大小结束
  },
)
```

### 4. CalendarEventBlock (event_block.dart)

日历事件块组件，完整的事件显示容器。

**特性：**
- 自适应布局（高度 ≤ 30px 使用紧凑布局，> 30px 使用展开布局）
- 集成调整大小手柄
- 选中状态视觉反馈
- 自动文本溢出处理
- 灵活的位置和尺寸控制

**布局模式：**
1. **紧凑布局（≤ 30px）：** 单行显示标题和时间
2. **展开布局（> 30px）：** 多行显示，标题和时间分开

**使用示例：**
```dart
CalendarEventBlock(
  event: calendarEvent,
  isSelected: true,
  height: 100.0,
  leftOffset: 56.0,
  rightOffset: 0,
  topPosition: 200.0,
  resizeHandleHeight: 12.0,
  showResizeHandles: true,
  onTopResizeStart: (details) { /* ... */ },
  onTopResizeUpdate: (details) { /* ... */ },
  onTopResizeEnd: (details) { /* ... */ },
  onBottomResizeStart: (details) { /* ... */ },
  onBottomResizeUpdate: (details) { /* ... */ },
  onBottomResizeEnd: (details) { /* ... */ },
)
```

**参数说明：**
- `event` - 事件对象
- `isSelected` - 是否被选中
- `height` - 事件块高度
- `leftOffset` - 左侧偏移量
- `rightOffset` - 右侧偏移量（可选）
- `width` - 固定宽度（可选，会覆盖 rightOffset）
- `topPosition` - Y坐标位置
- `resizeHandleHeight` - 调整手柄高度
- `showResizeHandles` - 是否显示调整手柄
- `onTopResize*` - 顶部手柄回调
- `onBottomResize*` - 底部手柄回调

## 组件依赖关系

```
CalendarEventBlock
  ├── EventResizeHandle (可选，根据 showResizeHandles)
  ├── TimeUtils (格式化时间)
  └── CalendarEvent (数据模型)

EventContextMenu
  ├── EventEditableTextField
  ├── EventUtils (事件操作)
  └── eventColors (颜色常量，来自 models.dart)

EventEditableTextField
  └── CalendarEvent (数据模型)

EventResizeHandle
  └── (无外部依赖)
```

## 设计原则

1. **单一职责：** 每个组件专注于一个特定功能
2. **可组合性：** 组件可以灵活组合使用
3. **配置化：** 通过参数控制行为，而非硬编码
4. **无状态优先：** 尽可能使用 StatelessWidget
5. **清晰的API：** 参数命名清晰，文档完整

## 在主视图中的使用

### DayView 示例

```dart
// 在 _buildEventBlocks() 中
CalendarEventBlock(
  event: event,
  isSelected: isSelected,
  height: height,
  leftOffset: CalendarConstants.gutterWidth,
  rightOffset: 0,
  topPosition: startY,
  resizeHandleHeight: CalendarConstants.resizeHandleHeightDay,
  showResizeHandles: true,
  onTopResizeStart: (details) => _onResizeStart(event, true, details),
  // ... 其他回调
)

// 在 _onSecondaryTapDown() 中
EventContextMenu.show(
  context: context,
  position: details.globalPosition,
  event: event,
  // ... 其他参数
)
```

### WeekView 示例

```dart
// 在 _buildEventBlocks() 中
CalendarEventBlock(
  event: event,
  isSelected: isSelected,
  height: height,
  leftOffset: leftOffset + 1,
  width: columnWidth - 2,
  topPosition: startY,
  resizeHandleHeight: CalendarConstants.resizeHandleHeightWeek,
  showResizeHandles: height > CalendarConstants.resizeHandleHeightWeek * 1.5,
  // ... 回调
)
```

## 重构历史

**2025-10-06** - UI组件提取重构
- 从 `day_view.dart` 和 `week_view.dart` 提取共享UI组件
- 创建独立的、可复用的组件
- 简化主视图的渲染逻辑
- 提高代码可维护性和可测试性

## 维护建议

在修改这些组件时，请注意：

1. **保持向后兼容：** 谨慎修改公共API
2. **更新文档：** 修改后及时更新本文档
3. **测试覆盖：** 在两个视图中测试所有更改
4. **性能考虑：** 这些组件在列表中频繁渲染，注意性能优化
5. **一致性：** 保持两个视图的视觉和交互一致性

