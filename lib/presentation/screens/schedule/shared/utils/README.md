# Calendar Utils - 日历工具库

这个目录包含了日历视图（DayView 和 WeekView）的共享工具函数和常量。

## 文件结构

```
shared/utils/
├── constants.dart     # 日历常量定义
├── time_utils.dart    # 时间相关工具函数
├── event_utils.dart   # 事件相关工具函数
└── README.md          # 本文档
```

## 常量 (constants.dart)

### CalendarConstants

日历视图相关的常量定义：

- `hourRowHeight` (100.0) - 每小时行的高度（像素）
- `gutterWidth` (56.0) - 时间标签区域的宽度（像素）
- `resizeHandleHeightDay` (12.0) - 日视图中调整手柄的高度（像素）
- `resizeHandleHeightWeek` (20.0) - 周视图中调整手柄的高度（像素）
- `totalQuarters` (96) - 15分钟段的总数（24小时 * 4）
- `minEventDurationMinutes` (15) - 最小活动时长（分钟）
- `movementThresholdY` (5.0) - 移动检测阈值 - Y轴（像素）
- `movementThresholdX` (10.0) - 移动检测阈值 - X轴（像素）

## 时间工具 (time_utils.dart)

### TimeUtils

时间处理相关的工具函数：

#### formatTime(TimeOfDay time) → String
格式化时间显示为 HH:mm 格式
```dart
TimeUtils.formatTime(TimeOfDay(hour: 9, minute: 30)) // => "09:30"
```

#### hourLabel(int hour) → String
生成小时标签为 HH:00 格式
```dart
TimeUtils.hourLabel(9) // => "09:00"
```

#### getQuarterFromY(double y) → int
根据Y坐标计算15分钟段索引（0-95）
```dart
TimeUtils.getQuarterFromY(100.0) // => 4 (对应1:00)
```

#### quarterToTimeOfDay(int quarter) → TimeOfDay
将15分钟段索引转换为TimeOfDay
```dart
TimeUtils.quarterToTimeOfDay(6) // => TimeOfDay(hour: 1, minute: 30)
```

#### timeToY(DateTime dateTime) → double
计算事件在时间轴上的Y坐标
```dart
TimeUtils.timeToY(DateTime(2024, 1, 1, 9, 30)) // => 380.0
```

#### minutesToY(int minutes) → double
根据分钟数计算Y坐标
```dart
TimeUtils.minutesToY(90) // => 90分钟 = 1.5小时的Y坐标
```

#### yToMinutes(double y) → int
根据Y坐标计算分钟数
```dart
TimeUtils.yToMinutes(100.0) // => 从00:00开始的分钟数
```

## 事件工具 (event_utils.dart)

### EventUtils

事件操作相关的工具函数：

#### getId(CalendarEvent event) → String
获取活动的唯一标识
```dart
String id = EventUtils.getId(event);
```

#### copyToClipboard(CalendarEvent event, BuildContext context)
复制活动到剪贴板
```dart
EventUtils.copyToClipboard(event, context);
```

#### pasteFromClipboard({...}) → Future<void>
从剪贴板粘贴活动
```dart
await EventUtils.pasteFromClipboard(
  context: context,
  date: DateTime.now(),
  selectedStartQuarter: 8,
  selectedEndQuarter: 12,
  onAddEvent: (event) => addEvent(event),
);
```

#### createDuplicate({...})
创建活动副本
```dart
EventUtils.createDuplicate(
  event: originalEvent,
  context: context,
  onAddEvent: (event) => addEvent(event),
  hourOffset: 1, // 默认推迟1小时
);
```

#### updateColor({...}) → bool
更新活动颜色
```dart
bool updated = EventUtils.updateColor(
  originalEvent: event,
  newColor: Colors.blue,
  onUpdateEvent: (old, new) => updateEvent(old, new),
);
```

## 使用示例

### 在视图中使用常量
```dart
Container(
  width: CalendarConstants.gutterWidth,
  height: CalendarConstants.hourRowHeight,
)
```

### 使用时间工具
```dart
// 显示格式化的时间
Text(TimeUtils.formatTime(TimeOfDay.fromDateTime(event.start)))

// 计算事件位置
double eventY = TimeUtils.timeToY(event.start);
```

### 使用事件工具
```dart
// 复制事件
onTap: () => EventUtils.copyToClipboard(event, context)

// 粘贴事件
onTap: () => EventUtils.pasteFromClipboard(
  context: context,
  date: selectedDate,
  onAddEvent: widget.onAddEvent,
)
```

## 重构历史

**2025-10-06** - 初始重构
- 从 `day_view.dart` 和 `week_view.dart` 提取共享常量和工具函数
- 创建独立的工具类，提高代码复用性和可维护性
- 消除代码重复，统一实现逻辑

## 维护说明

在修改这些工具函数时，请注意：

1. 保持 API 的向后兼容性
2. 更新本文档中的使用示例
3. 在两个视图（DayView 和 WeekView）中测试更改
4. 添加适当的文档注释和类型注解

