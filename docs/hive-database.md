# Hive数据库配置说明

## 概述

本项目使用Hive作为本地数据库存储日历活动数据。Hive是一个轻量级、快速的键值数据库，专为Flutter应用设计。

## 数据模型

### CalendarEvent - 日历活动实体

核心字段设计，包含日历活动的基本信息：

```dart
import 'package:hive/hive.dart';
import 'package:flutter/material.dart';

part 'calendar_event.g.dart'; // 生成的适配器文件

@HiveType(typeId: 0)
class CalendarEvent extends HiveObject {
  @HiveField(0)
  String id;              // 唯一标识符
  
  @HiveField(1)
  String title;           // 活动标题
  
  @HiveField(2)
  String description;     // 活动描述
  
  @HiveField(3)
  bool allDay;           // 是否全天活动
  
  @HiveField(4)
  DateTime start;        // 开始时间
  
  @HiveField(5)
  DateTime end;          // 结束时间
  
  @HiveField(6)
  int colorValue;        // 颜色值 (Color.value)
  
  CalendarEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.allDay,
    required this.start,
    required this.end,
    required this.colorValue,
  });
  
  // 获取Color对象
  Color get color => Color(colorValue);
  
  // 设置Color对象
  set color(Color color) => colorValue = color.value;
  
  // 兼容现有代码的intersects方法
  bool intersects(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    return !(d.isBefore(s) || d.isAfter(e));
  }
  
  // 创建副本方法
  CalendarEvent copyWith({
    String? id,
    String? title,
    String? description,
    bool? allDay,
    DateTime? start,
    DateTime? end,
    Color? color,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      allDay: allDay ?? this.allDay,
      start: start ?? this.start,
      end: end ?? this.end,
      colorValue: color?.value ?? this.colorValue,
    );
  }
}
```

## 数据库初始化

### 1. 依赖配置

在 `pubspec.yaml` 中添加必要依赖：

```yaml
dependencies:
  hive: ^2.2.3
  hive_flutter: ^1.1.0

dev_dependencies:
  hive_generator: ^2.0.1
  build_runner: ^2.4.7
```

### 2. 初始化代码

在 `main.dart` 中添加初始化逻辑：

```dart
import 'package:hive_flutter/hive_flutter.dart';
import 'path/to/calendar_event.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化Hive
  await initHive();
  
  runApp(MyApp());
}

Future<void> initHive() async {
  // 初始化Hive Flutter
  await Hive.initFlutter();
  
  // 注册适配器
  Hive.registerAdapter(CalendarEventAdapter());
  
  // 打开数据库
  await Hive.openBox<CalendarEvent>('calendar_events');
}
```

### 3. 数据库服务类

创建数据库操作服务：

```dart
// lib/services/calendar_database_service.dart
import 'package:hive/hive.dart';
import '../models/calendar_event.dart';

class CalendarDatabaseService {
  static const String _boxName = 'calendar_events';
  
  // 获取数据库实例
  Box<CalendarEvent> get _box => Hive.box<CalendarEvent>(_boxName);
  
  // 添加活动
  Future<void> addEvent(CalendarEvent event) async {
    await _box.put(event.id, event);
  }
  
  // 更新活动
  Future<void> updateEvent(CalendarEvent event) async {
    await _box.put(event.id, event);
  }
  
  // 删除活动
  Future<void> deleteEvent(String eventId) async {
    await _box.delete(eventId);
  }
  
  // 获取所有活动
  List<CalendarEvent> getAllEvents() {
    return _box.values.toList();
  }
  
  // 获取指定日期的活动
  List<CalendarEvent> getEventsForDate(DateTime date) {
    return _box.values.where((event) => event.intersects(date)).toList();
  }
  
  // 获取指定日期范围的活动
  List<CalendarEvent> getEventsInRange(DateTime start, DateTime end) {
    return _box.values.where((event) {
      return event.start.isBefore(end.add(Duration(days: 1))) &&
             event.end.isAfter(start.subtract(Duration(days: 1)));
    }).toList();
  }
  
  // 根据ID获取活动
  CalendarEvent? getEventById(String id) {
    return _box.get(id);
  }
  
  // 清空所有数据
  Future<void> clearAllEvents() async {
    await _box.clear();
  }
  
  // 获取活动总数
  int get eventCount => _box.length;
  
  // 监听数据变化
  Stream<BoxEvent> watchEvents() {
    return _box.watch();
  }
}
```

## 代码生成

### 生成适配器

运行以下命令生成Hive适配器：

```bash
flutter packages pub run build_runner build
```

如果需要删除之前生成的文件：

```bash
flutter packages pub run build_runner build --delete-conflicting-outputs
```

## 使用示例

### 基本操作

```dart
// 创建数据库服务实例
final dbService = CalendarDatabaseService();

// 添加新活动
final newEvent = CalendarEvent(
  id: DateTime.now().millisecondsSinceEpoch.toString(),
  title: '重要会议',
  description: '讨论项目进展',
  allDay: false,
  start: DateTime(2024, 1, 15, 14, 0),
  end: DateTime(2024, 1, 15, 16, 0),
  colorValue: Colors.blue.value,
);

await dbService.addEvent(newEvent);

// 获取今天的活动
final today = DateTime.now();
final todayEvents = dbService.getEventsForDate(today);

// 更新活动
final updatedEvent = newEvent.copyWith(title: '更新后的会议标题');
await dbService.updateEvent(updatedEvent);

// 删除活动
await dbService.deleteEvent(newEvent.id);
```

### 与现有代码集成

替换现有的内存存储：

```dart
// 之前：final List<CalendarEvent> _events = [];
// 现在：使用数据库服务

class _ScheduleScreenState extends State<ScheduleScreen> {
  final CalendarDatabaseService _dbService = CalendarDatabaseService();
  List<CalendarEvent> _events = [];
  
  @override
  void initState() {
    super.initState();
    _loadEvents();
  }
  
  void _loadEvents() {
    setState(() {
      _events = _dbService.getAllEvents();
    });
  }
  
  Future<void> _addEvent(CalendarEvent event) async {
    await _dbService.addEvent(event);
    _loadEvents();
  }
  
  Future<void> _updateEvent(CalendarEvent oldEvent, CalendarEvent newEvent) async {
    await _dbService.updateEvent(newEvent);
    _loadEvents();
  }
  
  Future<void> _deleteEvent(CalendarEvent event) async {
    await _dbService.deleteEvent(event.id);
    _loadEvents();
  }
}
```

## 注意事项

### 1. 数据类型限制
- Hive支持的基本类型：int, double, bool, String, List, Map, DateTime
- 复杂对象需要注册适配器
- Color对象通过int值存储

### 2. 性能优化
- Hive是基于内存的数据库，读取速度很快
- 大量数据时考虑分页加载
- 避免频繁的写操作

### 3. 数据安全
- Hive数据存储在本地，应用卸载时会丢失
- 考虑添加数据备份和恢复功能
- 敏感数据可以考虑加密存储

### 4. 字段扩展规划
当前预留字段索引：
- 0-6: 已使用的核心字段
- 7-20: 预留给基础功能扩展
- 21-50: 预留给高级功能
- 51-99: 预留给特殊用途

未来添加字段时，使用未占用的索引号，确保向后兼容。

## 迁移计划

1. **第一阶段**：实现基本的CRUD操作
2. **第二阶段**：添加数据监听和响应式更新
3. **第三阶段**：实现数据备份和恢复
4. **第四阶段**：根据需要添加索引和查询优化

## 故障排除

### 常见问题

1. **适配器未注册**
   - 确保在main.dart中调用了registerAdapter
   - 检查import路径是否正确

2. **生成文件错误**
   - 删除.g.dart文件重新生成
   - 检查part语句是否正确

3. **数据读取失败**
   - 检查box是否已打开
   - 确认数据类型匹配

### 调试技巧

```dart
// 查看数据库内容
void debugPrintAllEvents() {
  final box = Hive.box<CalendarEvent>('calendar_events');
  print('Total events: ${box.length}');
  for (final event in box.values) {
    print('Event: ${event.title}, Start: ${event.start}');
  }
}
```
