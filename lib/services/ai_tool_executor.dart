import 'package:uuid/uuid.dart';
import 'package:hive/hive.dart';
import '../presentation/providers/task_list_provider.dart';
import '../presentation/providers/schedule_provider.dart';
import '../presentation/providers/focus_provider.dart';
import '../data/models/calendar_event_hive.dart';
import '../data/repositories/task_list_repository.dart';
import 'ai_tool_registry.dart';
import 'ai_tool_metadata.dart';

/// AI工具执行器 - 执行Function Calling的工具调用
class AIToolExecutor {
  final TaskListProvider taskProvider;
  final ScheduleProvider scheduleProvider;
  final FocusProvider focusProvider;
  final TaskListRepository taskRepository;

  AIToolExecutor({
    required this.taskProvider,
    required this.scheduleProvider,
    required this.focusProvider,
    required this.taskRepository,
  });

  /// 执行工具调用
  /// 
  /// ⚠️ 此方法已废弃，请使用 AIToolRegistry.execute()
  /// 保留用于向后兼容
  @Deprecated('使用 AIToolRegistry.execute() 代替')
  Future<Map<String, dynamic>> execute({
    required String toolName,
    required Map<String, dynamic> arguments,
  }) async {
    // 直接委托给注册表执行
    return AIToolRegistry.execute(toolName, arguments);
  }

  // ==================== 任务管理工具实现 ====================

  Future<Map<String, dynamic>> _createTask(Map<String, dynamic> args) async {
    try {
      final title = args['title'] as String;

      // 使用 TaskListProvider 的 createTask 方法
      await taskProvider.createTask(
        title: title,
      );

      // 获取刚创建的任务（最后一个）
      final tasks = taskProvider.tasks;
      if (tasks.isEmpty) {
        return {
          'success': false,
          'error': '任务创建失败：无法获取任务',
        };
      }

      final taskId = tasks.last.id;

      // 如果有额外的字段（dueDate, description），需要更新任务
      final dueDateStr = args['dueDate'] as String?;
      final description = args['description'] as String?;

      if (dueDateStr != null || description != null) {
        await taskProvider.updateTask(
          id: taskId,
          title: title,
          description: description,
          dueDate: dueDateStr != null ? DateTime.parse(dueDateStr) : null,
        );
      }

      return {
        'success': true,
        'message': '任务「$title」已创建',
        'taskId': taskId,  // ✅ 返回 taskId，供后续工具使用
      };
    } catch (e) {
      return {
        'success': false,
        'error': '创建任务失败: $e',
      };
    }
  }

  Future<Map<String, dynamic>> _batchCreateTasks(Map<String, dynamic> args) async {
    try {
      final taskList = (args['tasks'] as List).cast<Map<String, dynamic>>();
      
      if (taskList.isEmpty) {
        return {
          'success': false,
          'error': '任务列表不能为空',
        };
      }

      int successCount = 0;
      int failureCount = 0;
      final createdTitles = <String>[];
      final errors = <String>[];

      for (final taskData in taskList) {
        try {
          final title = taskData['title'] as String;
          final dueDateStr = taskData['dueDate'] as String?;
          final description = taskData['description'] as String?;

          // 创建任务
          await taskProvider.createTask(
            title: title,
          );

          // 如果有额外字段，更新任务
          if (dueDateStr != null || description != null) {
            final tasks = taskProvider.tasks;
            if (tasks.isNotEmpty) {
              final taskId = tasks.last.id;
              await taskProvider.updateTask(
                id: taskId,
                title: title,
                description: description,
                dueDate: dueDateStr != null ? DateTime.parse(dueDateStr) : null,
              );
            }
          }

          successCount++;
          createdTitles.add(title);
        } catch (e) {
          failureCount++;
          final title = taskData['title'] as String? ?? '未知任务';
          errors.add('创建「$title」失败: $e');
        }
      }

      return {
        'success': successCount > 0,
        'totalCount': taskList.length,
        'successCount': successCount,
        'failureCount': failureCount,
        'message': '批量创建完成：成功 $successCount 个，失败 $failureCount 个',
        if (createdTitles.isNotEmpty) 'createdTasks': createdTitles,
        if (errors.isNotEmpty) 'errors': errors,
      };
    } catch (e) {
      return {
        'success': false,
        'error': '批量创建任务失败: $e',
      };
    }
  }

  Future<Map<String, dynamic>> _updateTask(Map<String, dynamic> args) async {
    try {
      final taskId = args['taskId'] as String;
      final task = taskRepository.getTaskById(taskId);

      if (task == null) {
        return {
          'success': false,
          'error': '任务不存在: $taskId',
        };
      }

      await taskProvider.updateTask(
        id: taskId,
        title: args['title'] as String?,
        dueDate: args['dueDate'] != null
            ? DateTime.parse(args['dueDate'] as String)
            : null,
        description: args['description'] as String?,
      );

      return {
        'success': true,
        'message': '任务已更新',
      };
    } catch (e) {
      return {
        'success': false,
        'error': '更新任务失败: $e',
      };
    }
  }

  Future<Map<String, dynamic>> _completeTask(Map<String, dynamic> args) async {
    try {
      final taskId = args['taskId'] as String;
      final task = taskRepository.getTaskById(taskId);

      if (task == null) {
        return {
          'success': false,
          'error': '任务不存在: $taskId',
        };
      }

      await taskProvider.toggleTaskCompletion(taskId);

      return {
        'success': true,
        'message': '任务「${task.title}」已完成',
      };
    } catch (e) {
      return {
        'success': false,
        'error': '完成任务失败: $e',
      };
    }
  }

  Future<Map<String, dynamic>> _deleteTask(Map<String, dynamic> args) async {
    try {
      final taskId = args['taskId'] as String;
      final task = taskRepository.getTaskById(taskId);

      if (task == null) {
        return {
          'success': false,
          'error': '任务不存在: $taskId',
        };
      }

      await taskProvider.deleteTask(taskId);

      return {
        'success': true,
        'message': '任务「${task.title}」已删除',
      };
    } catch (e) {
      return {
        'success': false,
        'error': '删除任务失败: $e',
      };
    }
  }

  Future<Map<String, dynamic>> _batchDeleteTasks(Map<String, dynamic> args) async {
    try {
      final taskIds = (args['taskIds'] as List).cast<String>();
      
      if (taskIds.isEmpty) {
        return {
          'success': false,
          'error': '任务ID列表不能为空',
        };
      }

      int successCount = 0;
      int failureCount = 0;
      final deletedTitles = <String>[];
      final errors = <String>[];

      for (final taskId in taskIds) {
        final task = taskRepository.getTaskById(taskId);
        
        if (task == null) {
          failureCount++;
          errors.add('任务不存在: $taskId');
          continue;
        }

        try {
          await taskProvider.deleteTask(taskId);
          successCount++;
          deletedTitles.add(task.title);
        } catch (e) {
          failureCount++;
          errors.add('删除「${task.title}」失败: $e');
        }
      }

      // 构建详细的删除信息
      final messageBuffer = StringBuffer();
      messageBuffer.writeln('批量删除完成：成功 $successCount 个，失败 $failureCount 个');
      
      if (deletedTitles.isNotEmpty) {
        messageBuffer.writeln('\n✅ 已删除的任务：');
        for (final title in deletedTitles) {
          messageBuffer.writeln('  • $title');
        }
      }
      
      if (errors.isNotEmpty) {
        messageBuffer.writeln('\n❌ 删除失败：');
        for (final error in errors) {
          messageBuffer.writeln('  • $error');
        }
      }
      
      return {
        'success': successCount > 0,
        'totalCount': taskIds.length,
        'successCount': successCount,
        'failureCount': failureCount,
        'message': messageBuffer.toString().trim(),
        if (deletedTitles.isNotEmpty) 'deletedTasks': deletedTitles,
        if (errors.isNotEmpty) 'errors': errors,
      };
    } catch (e) {
      return {
        'success': false,
        'error': '批量删除任务失败: $e',
      };
    }
  }

  Future<Map<String, dynamic>> _queryTasks(Map<String, dynamic> args) async {
    try {
      final completed = args['completed'] as bool?;
      final limit = args['limit'] as int?;

      var tasks = taskProvider.tasks;

      // 筛选
      if (completed != null) {
        tasks = tasks.where((t) => t.isCompleted == completed).toList();
      }

      // 限制数量
      if (limit != null && tasks.length > limit) {
        tasks = tasks.take(limit).toList();
      }

      return {
        'success': true,
        'count': tasks.length,
        'tasks': tasks.map((t) => {
          'id': t.id,
          'title': t.title,
          'description': t.description,
          'isCompleted': t.isCompleted,
          'dueDate': t.dueDate?.toIso8601String(),
        }).toList(),
      };
    } catch (e) {
      return {
        'success': false,
        'error': '查询任务失败: $e',
      };
    }
  }

  // ==================== 日历管理工具实现 ====================

  Future<Map<String, dynamic>> _createCalendarEvent(Map<String, dynamic> args) async {
    try {
      final title = args['title'] as String;
      final startTime = DateTime.parse(args['startTime'] as String);
      final endTime = DateTime.parse(args['endTime'] as String);
      final description = args['description'] as String? ?? '';
      final colorValue = args['colorValue'] as int?;

      final event = CalendarEventHive(
        id: const Uuid().v4(),
        title: title,
        start: startTime,
        end: endTime,
        description: description,
        colorValue: colorValue ?? 0xFF2196F3, // 默认蓝色
        allDay: false,
      );

      // 直接操作Hive box
      final eventBox = Hive.box<CalendarEventHive>('calendar_events');
      await eventBox.put(event.id, event);

      // 通知 ScheduleProvider 刷新 UI
      scheduleProvider.refresh();

      return {
        'success': true,
        'message': '日程「$title」已创建',
        'eventId': event.id,
      };
    } catch (e) {
      return {
        'success': false,
        'error': '创建日程失败: $e',
      };
    }
  }

  Future<Map<String, dynamic>> _batchCreateCalendarEvents(Map<String, dynamic> args) async {
    try {
      final eventList = (args['events'] as List).cast<Map<String, dynamic>>();
      
      if (eventList.isEmpty) {
        return {
          'success': false,
          'error': '事件列表不能为空',
        };
      }

      final eventBox = Hive.box<CalendarEventHive>('calendar_events');
      int successCount = 0;
      int failureCount = 0;
      final createdTitles = <String>[];
      final errors = <String>[];

      for (final eventData in eventList) {
        try {
          final title = eventData['title'] as String;
          final startTime = DateTime.parse(eventData['startTime'] as String);
          final endTime = DateTime.parse(eventData['endTime'] as String);
          final description = eventData['description'] as String? ?? '';
          final colorValue = eventData['colorValue'] as int?;

          final event = CalendarEventHive(
            id: const Uuid().v4(),
            title: title,
            start: startTime,
            end: endTime,
            description: description,
            colorValue: colorValue ?? 0xFF2196F3, // 默认蓝色
            allDay: false,
          );

          await eventBox.put(event.id, event);
          successCount++;
          createdTitles.add(title);
        } catch (e) {
          failureCount++;
          final title = eventData['title'] as String? ?? '未知事件';
          errors.add('创建「$title」失败: $e');
        }
      }

      // 只在有成功创建时才刷新UI
      if (successCount > 0) {
        scheduleProvider.refresh();
      }

      return {
        'success': successCount > 0,
        'totalCount': eventList.length,
        'successCount': successCount,
        'failureCount': failureCount,
        'message': '批量创建完成：成功 $successCount 个，失败 $failureCount 个',
        if (createdTitles.isNotEmpty) 'createdEvents': createdTitles,
        if (errors.isNotEmpty) 'errors': errors,
      };
    } catch (e) {
      return {
        'success': false,
        'error': '批量创建日程失败: $e',
      };
    }
  }

  Future<Map<String, dynamic>> _updateCalendarEvent(Map<String, dynamic> args) async {
    try {
      final eventId = args['eventId'] as String;
      final eventBox = Hive.box<CalendarEventHive>('calendar_events');
      final event = eventBox.get(eventId);

      if (event == null) {
        return {
          'success': false,
          'error': '日程不存在: $eventId',
        };
      }

      final updatedEvent = event.copyWith(
        title: args['title'] as String?,
        start: args['startTime'] != null
            ? DateTime.parse(args['startTime'] as String)
            : null,
        end: args['endTime'] != null
            ? DateTime.parse(args['endTime'] as String)
            : null,
      );

      await eventBox.put(eventId, updatedEvent);

      // 通知 ScheduleProvider 刷新 UI
      scheduleProvider.refresh();

      return {
        'success': true,
        'message': '日程「${updatedEvent.title}」已更新',
      };
    } catch (e) {
      return {
        'success': false,
        'error': '更新日程失败: $e',
      };
    }
  }

  Future<Map<String, dynamic>> _deleteCalendarEvent(Map<String, dynamic> args) async {
    try {
      final eventId = args['eventId'] as String;
      final eventBox = Hive.box<CalendarEventHive>('calendar_events');
      final event = eventBox.get(eventId);

      if (event == null) {
        return {
          'success': false,
          'error': '日程不存在: $eventId',
        };
      }

      await eventBox.delete(eventId);

      // 通知 ScheduleProvider 刷新 UI
      scheduleProvider.refresh();

      return {
        'success': true,
        'message': '日程「${event.title}」已删除',
      };
    } catch (e) {
      return {
        'success': false,
        'error': '删除日程失败: $e',
      };
    }
  }

  Future<Map<String, dynamic>> _batchDeleteCalendarEvents(Map<String, dynamic> args) async {
    try {
      final eventIds = (args['eventIds'] as List).cast<String>();
      
      if (eventIds.isEmpty) {
        return {
          'success': false,
          'error': '事件ID列表不能为空',
        };
      }

      final eventBox = Hive.box<CalendarEventHive>('calendar_events');
      int successCount = 0;
      int failureCount = 0;
      final deletedInfo = <String>[]; // 存储详细信息（标题 + 日期）
      final errors = <String>[];

      for (final eventId in eventIds) {
        final event = eventBox.get(eventId);
        
        if (event == null) {
          failureCount++;
          errors.add('日程不存在: $eventId');
          continue;
        }

        try {
          await eventBox.delete(eventId);
          successCount++;
          // 保存标题和日期信息
          final dateStr = event.start.toString().split(' ')[0]; // 获取日期部分
          deletedInfo.add('${event.title} ($dateStr)');
        } catch (e) {
          failureCount++;
          errors.add('删除「${event.title}」失败: $e');
        }
      }

      // 只在有成功删除时才刷新UI
      if (successCount > 0) {
        scheduleProvider.refresh();
      }

      // 构建详细的删除信息
      final messageBuffer = StringBuffer();
      messageBuffer.writeln('批量删除完成：成功 $successCount 个，失败 $failureCount 个');
      
      if (deletedInfo.isNotEmpty) {
        messageBuffer.writeln('\n✅ 已删除的日程：');
        for (final info in deletedInfo) {
          messageBuffer.writeln('  • $info');
        }
      }
      
      if (errors.isNotEmpty) {
        messageBuffer.writeln('\n❌ 删除失败：');
        for (final error in errors) {
          messageBuffer.writeln('  • $error');
        }
      }
      
      return {
        'success': successCount > 0,
        'totalCount': eventIds.length,
        'successCount': successCount,
        'failureCount': failureCount,
        'message': messageBuffer.toString().trim(),
        if (deletedInfo.isNotEmpty) 'deletedEvents': deletedInfo,
        if (errors.isNotEmpty) 'errors': errors,
      };
    } catch (e) {
      return {
        'success': false,
        'error': '批量删除日程失败: $e',
      };
    }
  }

  Future<Map<String, dynamic>> _queryEvents(Map<String, dynamic> args) async {
    try {
      final eventBox = Hive.box<CalendarEventHive>('calendar_events');
      List<CalendarEventHive> events = eventBox.values.toList();

      // 支持三种查询方式
      if (args['date'] != null) {
        // 方式1: 查询某一天的事件
        final date = DateTime.parse(args['date'] as String);
        final startOfDay = DateTime(date.year, date.month, date.day);
        final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
        
        events = events.where((e) => 
          e.start.isBefore(endOfDay) && e.end.isAfter(startOfDay)
        ).toList();
      } else if (args['startDate'] != null && args['endDate'] != null) {
        // 方式2: 查询日期范围内的事件
        final startDate = DateTime.parse(args['startDate'] as String);
        final endDate = DateTime.parse(args['endDate'] as String);
        
        events = events.where((e) => 
          e.start.isBefore(endDate) && e.end.isAfter(startDate)
        ).toList();
      } else if (args['startDate'] != null) {
        // 方式3: 查询指定日期之后的事件
        final startDate = DateTime.parse(args['startDate'] as String);
        events = events.where((e) => e.start.isAfter(startDate)).toList();
      }
      // 如果没有任何参数，返回所有事件

      return {
        'success': true,
        'count': events.length,
        'events': events.map((e) => {
          'id': e.id,
          'title': e.title,
          'startTime': e.start.toIso8601String(),
          'endTime': e.end.toIso8601String(),
          'description': e.description,
        }).toList(),
      };
    } catch (e) {
      return {
        'success': false,
        'error': '查询日程失败: $e',
      };
    }
  }

  Future<Map<String, dynamic>> _findFreeTime(Map<String, dynamic> args) async {
    try {
      final date = DateTime.parse(args['date'] as String);
      final duration = args['duration'] as int;

      // 1. 获取当天的所有日程事件
      final events = scheduleProvider.getEventsForDate(date);
      
      // 2. 定义工作时间范围
      final workStart = DateTime(date.year, date.month, date.day, 9, 0);
      final lunchStart = DateTime(date.year, date.month, date.day, 12, 0);
      final lunchEnd = DateTime(date.year, date.month, date.day, 13, 0);
      final workEnd = DateTime(date.year, date.month, date.day, 18, 0);
      
      // 3. 构建忙碌时间段列表
      final busySlots = <Map<String, DateTime>>[];
      
      // 添加午休时间
      busySlots.add({'start': lunchStart, 'end': lunchEnd});
      
      // 添加已有的日程事件
      for (final event in events) {
        busySlots.add({
          'start': event.start,
          'end': event.end,
        });
      }
      
      // 按开始时间排序
      busySlots.sort((a, b) => a['start']!.compareTo(b['start']!));
      
      // 4. 查找空闲时间段
      final freeSlots = <Map<String, dynamic>>[];
      DateTime currentTime = workStart;
      
      for (final busy in busySlots) {
        final busyStart = busy['start']!;
        final busyEnd = busy['end']!;
        
        // 如果当前时间在忙碌时段之前，有空闲时间
        if (currentTime.isBefore(busyStart)) {
          final freeDuration = busyStart.difference(currentTime).inMinutes;
          if (freeDuration >= duration) {
            freeSlots.add({
              'start': currentTime.toIso8601String(),
              'end': busyStart.toIso8601String(),
              'duration': freeDuration,
            });
          }
        }
        
        // 更新当前时间为忙碌时段结束时间
        if (busyEnd.isAfter(currentTime)) {
          currentTime = busyEnd;
        }
      }
      
      // 5. 检查最后一个忙碌时段到下班时间的空闲
      if (currentTime.isBefore(workEnd)) {
        final freeDuration = workEnd.difference(currentTime).inMinutes;
        if (freeDuration >= duration) {
          freeSlots.add({
            'start': currentTime.toIso8601String(),
            'end': workEnd.toIso8601String(),
            'duration': freeDuration,
          });
        }
      }
      
      // 6. 返回结果
      if (freeSlots.isEmpty) {
        return {
          'success': true,
          'message': '当天没有足够的空闲时间（需要${duration}分钟）',
          'freeSlots': [],
        };
      }
      
      return {
        'success': true,
        'message': '找到${freeSlots.length}个空闲时间段',
        'freeSlots': freeSlots,
      };
    } catch (e) {
      return {
        'success': false,
        'error': '查询空闲时间失败: $e',
      };
    }
  }

  // ==================== 专注管理工具实现 ====================

  Future<Map<String, dynamic>> _startFocusSession(Map<String, dynamic> args) async {
    try {
      final taskId = args['taskId'] as String?;
      final duration = args['duration'] as int? ?? 25;
      final sessionType = args['sessionType'] as String? ?? 'pomodoro';

      // 检查是否已有活动会话
      if (focusProvider.isActive) {
        return {
          'success': false,
          'error': '已有进行中的专注会话，请先完成或取消当前会话',
        };
      }

      // 根据会话类型启动相应的专注会话
      switch (sessionType) {
        case 'pomodoro':
          await focusProvider.startPomodoro(
            taskId: taskId,
          );
          break;
        case 'custom':
          await focusProvider.startCustomSession(
            duration,
            taskId: taskId,
          );
          break;
        case 'break':
          await focusProvider.startBreak(duration);
          break;
        default:
          // 默认启动自定义会话
          await focusProvider.startCustomSession(
            duration,
            taskId: taskId,
          );
      }

      return {
        'success': true,
        'message': '已启动${duration}分钟的$sessionType会话',
        'taskId': taskId,
        'duration': duration,
        'sessionType': sessionType,
      };
    } catch (e) {
      return {
        'success': false,
        'error': '启动专注会话失败: $e',
      };
    }
  }

  Future<Map<String, dynamic>> _getFocusStats(Map<String, dynamic> args) async {
    try {
      // 简化实现：返回今日统计
      final todayStats = focusProvider.todayStats;

      return {
        'success': true,
        'pomodoroCount': todayStats?.pomodoroCount ?? 0,
        'totalMinutes': (todayStats?.totalFocusSeconds ?? 0) ~/ 60, // 转换秒为分钟
        'completedSessions': todayStats?.completedSessionCount ?? 0,
      };
    } catch (e) {
      return {
        'success': false,
        'error': '获取专注统计失败: $e',
      };
    }
  }
  
  // ==================== 工具注册 ====================
  
  /// 将所有执行器绑定到注册表
  /// 
  /// 应在应用启动时调用一次
  void registerAllExecutors() {
    // 获取所有工具元数据
    final taskTools = AIToolMetadata.taskManagementTools;
    final calendarTools = AIToolMetadata.calendarManagementTools;
    final focusTools = AIToolMetadata.focusManagementTools;
    
    // 任务管理工具
    AIToolRegistry.register(taskTools[0].withExecutor(_createTask));
    AIToolRegistry.register(taskTools[1].withExecutor(_batchCreateTasks));
    AIToolRegistry.register(taskTools[2].withExecutor(_updateTask));
    AIToolRegistry.register(taskTools[3].withExecutor(_completeTask));
    AIToolRegistry.register(taskTools[4].withExecutor(_deleteTask));
    AIToolRegistry.register(taskTools[5].withExecutor(_batchDeleteTasks));
    AIToolRegistry.register(taskTools[6].withExecutor(_queryTasks));
    
    // 日历管理工具
    AIToolRegistry.register(calendarTools[0].withExecutor(_createCalendarEvent));
    AIToolRegistry.register(calendarTools[1].withExecutor(_batchCreateCalendarEvents));
    AIToolRegistry.register(calendarTools[2].withExecutor(_updateCalendarEvent));
    AIToolRegistry.register(calendarTools[3].withExecutor(_deleteCalendarEvent));
    AIToolRegistry.register(calendarTools[4].withExecutor(_batchDeleteCalendarEvents));
    AIToolRegistry.register(calendarTools[5].withExecutor(_queryEvents));
    AIToolRegistry.register(calendarTools[6].withExecutor(_findFreeTime));
    
    // 专注管理工具
    AIToolRegistry.register(focusTools[0].withExecutor(_startFocusSession));
    AIToolRegistry.register(focusTools[1].withExecutor(_getFocusStats));
  }
}
