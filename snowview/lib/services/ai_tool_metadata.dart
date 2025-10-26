import '../data/models/openai/openai_models.dart';
import 'ai_tool_registry.dart';

/// AI工具元数据定义
/// 
/// 定义所有AI工具的元数据，包括：
/// - 工具名称常量
/// - OpenAI工具定义
/// - 显示名称和分类
class AIToolMetadata {
  // ==================== 工具名称常量 ====================
  
  // 任务管理
  static const taskCreate = 'create_task';
  static const taskBatchCreate = 'batch_create_tasks';
  static const taskUpdate = 'update_task';
  static const taskComplete = 'complete_task';
  static const taskDelete = 'delete_task';
  static const taskBatchDelete = 'batch_delete_tasks';
  static const taskQuery = 'query_tasks';
  static const taskAddSubtask = 'add_subtask';
  
  // 日历管理
  static const calendarCreate = 'create_calendar_event';
  static const calendarBatchCreate = 'batch_create_calendar_events';
  static const calendarUpdate = 'update_calendar_event';
  static const calendarDelete = 'delete_calendar_event';
  static const calendarBatchDelete = 'batch_delete_calendar_events';
  static const calendarQuery = 'query_events';
  static const calendarFindFreeTime = 'find_free_time';
  
  // 专注管理
  static const focusStart = 'start_focus_session';
  static const focusGetStats = 'get_focus_stats';
  
  // 记录管理
  static const journalCreate = 'create_journal_entry';
  static const journalQuery = 'query_journals';
  
  // ==================== 工具元数据定义 ====================
  
  /// 获取所有工具元数据
  static List<ToolMetadata> getAllMetadata() => [
    // 任务管理工具
    ...taskManagementTools,
    // 日历管理工具
    ...calendarManagementTools,
    // 专注管理工具
    ...focusManagementTools,
    // 记录管理工具
    ...journalManagementTools,
  ];
  
  // ==================== 任务管理工具 ====================
  
  static List<ToolMetadata> get taskManagementTools => [
    ToolMetadata(
      name: taskCreate,
      displayName: '创建任务',
      description: '创建新任务',
      category: ToolCategory.task,
      openAIToolDefinition: OpenAITool(
        type: 'function',
        function: OpenAIFunction(
          name: taskCreate,
          description: '创建新任务',
          parametersSchema: {
            'type': 'object',
            'properties': {
              'title': {
                'type': 'string',
                'description': '任务标题',
              },
              'categoryId': {
                'type': 'string',
                'description': '类别ID，需要从系统状态中获取可用类别',
              },
              'dueDate': {
                'type': 'string',
                'description': '截止日期，ISO 8601格式（如：2025-10-08T14:30:00）',
              },
              'description': {
                'type': 'string',
                'description': '任务描述或备注',
              },
            },
            'required': ['title', 'categoryId'],
          },
        ),
      ),
    ),
    
    ToolMetadata(
      name: taskBatchCreate,
      displayName: '批量创建任务',
      description: '批量创建多个任务',
      category: ToolCategory.task,
      openAIToolDefinition: OpenAITool(
        type: 'function',
        function: OpenAIFunction(
          name: taskBatchCreate,
          description: '批量创建多个任务。当需要创建多个任务时，使用此工具比多次调用create_task更高效。',
          parametersSchema: {
            'type': 'object',
            'properties': {
              'tasks': {
                'type': 'array',
                'description': '要创建的任务列表',
                'items': {
                  'type': 'object',
                  'properties': {
                    'title': {
                      'type': 'string',
                      'description': '任务标题',
                    },
                    'categoryId': {
                      'type': 'string',
                      'description': '类别ID',
                    },
                    'dueDate': {
                      'type': 'string',
                      'description': '截止日期，ISO 8601格式',
                    },
                    'description': {
                      'type': 'string',
                      'description': '任务描述',
                    },
                  },
                  'required': ['title', 'categoryId'],
                },
              },
            },
            'required': ['tasks'],
          },
        ),
      ),
    ),
    
    ToolMetadata(
      name: taskUpdate,
      displayName: '更新任务',
      description: '修改任务信息',
      category: ToolCategory.task,
      openAIToolDefinition: OpenAITool(
        type: 'function',
        function: OpenAIFunction(
          name: taskUpdate,
          description: '修改任务信息',
          parametersSchema: {
            'type': 'object',
            'properties': {
              'taskId': {
                'type': 'string',
                'description': '任务ID',
              },
              'title': {
                'type': 'string',
                'description': '新的任务标题',
              },
              'dueDate': {
                'type': 'string',
                'description': '新的截止日期，ISO 8601格式',
              },
              'description': {
                'type': 'string',
                'description': '新的任务描述',
              },
            },
            'required': ['taskId'],
          },
        ),
      ),
    ),
    
    ToolMetadata(
      name: taskComplete,
      displayName: '完成任务',
      description: '将任务标记为已完成',
      category: ToolCategory.task,
      openAIToolDefinition: OpenAITool(
        type: 'function',
        function: OpenAIFunction(
          name: taskComplete,
          description: '将任务标记为已完成',
          parametersSchema: {
            'type': 'object',
            'properties': {
              'taskId': {
                'type': 'string',
                'description': '任务ID',
              },
            },
            'required': ['taskId'],
          },
        ),
      ),
    ),
    
    ToolMetadata(
      name: taskDelete,
      displayName: '删除任务',
      description: '删除任务',
      category: ToolCategory.task,
      openAIToolDefinition: OpenAITool(
        type: 'function',
        function: OpenAIFunction(
          name: taskDelete,
          description: '删除任务',
          parametersSchema: {
            'type': 'object',
            'properties': {
              'taskId': {
                'type': 'string',
                'description': '任务ID',
              },
            },
            'required': ['taskId'],
          },
        ),
      ),
    ),
    
    ToolMetadata(
      name: taskBatchDelete,
      displayName: '批量删除任务',
      description: '批量删除多个任务',
      category: ToolCategory.task,
      openAIToolDefinition: OpenAITool(
        type: 'function',
        function: OpenAIFunction(
          name: taskBatchDelete,
          description: '批量删除多个任务。当需要删除多个任务时，使用此工具比多次调用delete_task更高效，不会触发递归限制。',
          parametersSchema: {
            'type': 'object',
            'properties': {
              'taskIds': {
                'type': 'array',
                'description': '要删除的任务ID列表',
                'items': {
                  'type': 'string',
                },
              },
            },
            'required': ['taskIds'],
          },
        ),
      ),
    ),
    
    ToolMetadata(
      name: taskQuery,
      displayName: '查询任务',
      description: '查询任务列表',
      category: ToolCategory.task,
      openAIToolDefinition: OpenAITool(
        type: 'function',
        function: OpenAIFunction(
          name: taskQuery,
          description: '查询任务列表',
          parametersSchema: {
            'type': 'object',
            'properties': {
              'completed': {
                'type': 'boolean',
                'description': 'true=已完成, false=未完成, 不传=全部',
              },
              'categoryId': {
                'type': 'string',
                'description': '类别筛选',
              },
              'limit': {
                'type': 'integer',
                'description': '限制返回数量',
              },
            },
          },
        ),
      ),
    ),
    
    ToolMetadata(
      name: taskAddSubtask,
      displayName: '添加子步骤',
      description: '为任务添加子步骤',
      category: ToolCategory.task,
      openAIToolDefinition: OpenAITool(
        type: 'function',
        function: OpenAIFunction(
          name: taskAddSubtask,
          description: '为任务添加子步骤',
          parametersSchema: {
            'type': 'object',
            'properties': {
              'taskId': {
                'type': 'string',
                'description': '任务ID',
              },
              'subtaskTitle': {
                'type': 'string',
                'description': '子步骤标题',
              },
            },
            'required': ['taskId', 'subtaskTitle'],
          },
        ),
      ),
    ),
  ];
  
  // ==================== 日历管理工具 ====================
  
  static List<ToolMetadata> get calendarManagementTools => [
    ToolMetadata(
      name: calendarCreate,
      displayName: '创建日程',
      description: '创建日历事件',
      category: ToolCategory.calendar,
      openAIToolDefinition: OpenAITool(
        type: 'function',
        function: OpenAIFunction(
          name: calendarCreate,
          description: '创建日历事件',
          parametersSchema: {
            'type': 'object',
            'properties': {
              'title': {
                'type': 'string',
                'description': '事件标题',
              },
              'startTime': {
                'type': 'string',
                'description': '开始时间，ISO 8601格式',
              },
              'endTime': {
                'type': 'string',
                'description': '结束时间，ISO 8601格式',
              },
              'description': {
                'type': 'string',
                'description': '事件描述',
              },
              'colorValue': {
                'type': 'integer',
                'description': '颜色值，可选：0xFFF44336(红)、0xFFFF9800(橙)、0xFFFFEB3B(黄)、0xFF4CAF50(绿)、0xFF2196F3(蓝)、0xFF9C27B0(紫)、0xFFE91E63(粉)',
                'enum': [
                  0xFFF44336, // 红色
                  0xFFFF9800, // 橙色
                  0xFFFFEB3B, // 黄色
                  0xFF4CAF50, // 绿色
                  0xFF2196F3, // 蓝色
                  0xFF9C27B0, // 紫色
                  0xFFE91E63, // 粉色
                ],
              },
            },
            'required': ['title', 'startTime', 'endTime'],
          },
        ),
      ),
    ),
    
    ToolMetadata(
      name: calendarBatchCreate,
      displayName: '批量创建日程',
      description: '批量创建多个日历事件',
      category: ToolCategory.calendar,
      openAIToolDefinition: OpenAITool(
        type: 'function',
        function: OpenAIFunction(
          name: calendarBatchCreate,
          description: '批量创建多个日历事件。当需要创建多个日程时，使用此工具比多次调用create_calendar_event更高效。',
          parametersSchema: {
            'type': 'object',
            'properties': {
              'events': {
                'type': 'array',
                'description': '要创建的事件列表',
                'items': {
                  'type': 'object',
                  'properties': {
                    'title': {
                      'type': 'string',
                      'description': '事件标题',
                    },
                    'startTime': {
                      'type': 'string',
                      'description': '开始时间，ISO 8601格式',
                    },
                    'endTime': {
                      'type': 'string',
                      'description': '结束时间，ISO 8601格式',
                    },
                    'description': {
                      'type': 'string',
                      'description': '事件描述',
                    },
                    'colorValue': {
                      'type': 'integer',
                      'description': '颜色值',
                    },
                  },
                  'required': ['title', 'startTime', 'endTime'],
                },
              },
            },
            'required': ['events'],
          },
        ),
      ),
    ),
    
    ToolMetadata(
      name: calendarUpdate,
      displayName: '更新日程',
      description: '修改日历事件',
      category: ToolCategory.calendar,
      openAIToolDefinition: OpenAITool(
        type: 'function',
        function: OpenAIFunction(
          name: calendarUpdate,
          description: '修改日历事件',
          parametersSchema: {
            'type': 'object',
            'properties': {
              'eventId': {
                'type': 'string',
                'description': '事件ID',
              },
              'title': {
                'type': 'string',
                'description': '新的事件标题',
              },
              'startTime': {
                'type': 'string',
                'description': '新的开始时间，ISO 8601格式',
              },
              'endTime': {
                'type': 'string',
                'description': '新的结束时间，ISO 8601格式',
              },
            },
            'required': ['eventId'],
          },
        ),
      ),
    ),
    
    ToolMetadata(
      name: calendarDelete,
      displayName: '删除日程',
      description: '删除日历事件',
      category: ToolCategory.calendar,
      openAIToolDefinition: OpenAITool(
        type: 'function',
        function: OpenAIFunction(
          name: calendarDelete,
          description: '删除日历事件',
          parametersSchema: {
            'type': 'object',
            'properties': {
              'eventId': {
                'type': 'string',
                'description': '事件ID',
              },
            },
            'required': ['eventId'],
          },
        ),
      ),
    ),
    
    ToolMetadata(
      name: calendarBatchDelete,
      displayName: '批量删除日程',
      description: '批量删除多个日历事件',
      category: ToolCategory.calendar,
      openAIToolDefinition: OpenAITool(
        type: 'function',
        function: OpenAIFunction(
          name: calendarBatchDelete,
          description: '批量删除多个日历事件。当需要删除多个日程时，使用此工具比多次调用delete_calendar_event更高效，不会触发递归限制。',
          parametersSchema: {
            'type': 'object',
            'properties': {
              'eventIds': {
                'type': 'array',
                'description': '要删除的事件ID列表',
                'items': {
                  'type': 'string',
                },
              },
            },
            'required': ['eventIds'],
          },
        ),
      ),
    ),
    
    ToolMetadata(
      name: calendarQuery,
      displayName: '查询日程',
      description: '查询日历事件',
      category: ToolCategory.calendar,
      openAIToolDefinition: OpenAITool(
        type: 'function',
        function: OpenAIFunction(
          name: calendarQuery,
          description: '查询日历事件。返回结果包含 id、title、startTime、endTime、description。可根据 title 和 description 判断事件类型。',
          parametersSchema: {
            'type': 'object',
            'properties': {
              'date': {
                'type': 'string',
                'description': '查询某一天的事件，ISO 8601格式（如 2025-10-24）。与 startDate/endDate 互斥。',
              },
              'startDate': {
                'type': 'string',
                'description': '日期范围查询的起始日期，ISO 8601格式。需与 endDate 一起使用，或单独使用查询该日期之后的所有事件。',
              },
              'endDate': {
                'type': 'string',
                'description': '日期范围查询的结束日期，ISO 8601格式。需与 startDate 一起使用。',
              },
            },
            'description': '三种查询方式：1) 只传 date 查询某天；2) 传 startDate 和 endDate 查询范围；3) 不传参数查询所有。',
          },
        ),
      ),
    ),
    
    ToolMetadata(
      name: calendarFindFreeTime,
      displayName: '查询空闲时间',
      description: '查询指定日期的空闲时间段',
      category: ToolCategory.calendar,
      openAIToolDefinition: OpenAITool(
        type: 'function',
        function: OpenAIFunction(
          name: calendarFindFreeTime,
          description: '查询指定日期的空闲时间段',
          parametersSchema: {
            'type': 'object',
            'properties': {
              'date': {
                'type': 'string',
                'description': '查询日期，ISO 8601格式',
              },
              'duration': {
                'type': 'integer',
                'description': '需要的时长（分钟）',
              },
            },
            'required': ['date', 'duration'],
          },
        ),
      ),
    ),
  ];
  
  // ==================== 专注管理工具 ====================
  
  static List<ToolMetadata> get focusManagementTools => [
    ToolMetadata(
      name: focusStart,
      displayName: '启动专注',
      description: '启动专注会话（番茄钟或自定义专注）',
      category: ToolCategory.focus,
      openAIToolDefinition: OpenAITool(
        type: 'function',
        function: OpenAIFunction(
          name: focusStart,
          description: '启动专注会话（番茄钟或自定义专注）',
          parametersSchema: {
            'type': 'object',
            'properties': {
              'taskId': {
                'type': 'string',
                'description': '关联的任务ID（可选）',
              },
              'duration': {
                'type': 'integer',
                'description': '时长（分钟），默认25',
              },
              'sessionType': {
                'type': 'string',
                'description': '会话类型：pomodoro（番茄钟）、custom（自定义）、break（休息）',
                'enum': ['pomodoro', 'custom', 'break'],
              },
            },
          },
        ),
      ),
    ),
    
    ToolMetadata(
      name: focusGetStats,
      displayName: '获取专注统计',
      description: '获取专注统计数据',
      category: ToolCategory.focus,
      openAIToolDefinition: OpenAITool(
        type: 'function',
        function: OpenAIFunction(
          name: focusGetStats,
          description: '获取专注统计数据',
          parametersSchema: {
            'type': 'object',
            'properties': {
              'date': {
                'type': 'string',
                'description': '查询日期，ISO 8601格式，默认今天',
              },
            },
          },
        ),
      ),
    ),
  ];
  
  // ==================== 记录管理工具 ====================
  
  static List<ToolMetadata> get journalManagementTools => [
    ToolMetadata(
      name: journalCreate,
      displayName: '创建记录',
      description: '创建记录/日记',
      category: ToolCategory.journal,
      openAIToolDefinition: OpenAITool(
        type: 'function',
        function: OpenAIFunction(
          name: journalCreate,
          description: '创建记录/日记',
          parametersSchema: {
            'type': 'object',
            'properties': {
              'categoryId': {
                'type': 'string',
                'description': '记录类别ID',
              },
              'title': {
                'type': 'string',
                'description': '标题（可选）',
              },
              'content': {
                'type': 'string',
                'description': '内容（Markdown格式）',
              },
              'mood': {
                'type': 'string',
                'description': '心情emoji（可选）',
              },
            },
            'required': ['categoryId', 'content'],
          },
        ),
      ),
    ),
    
    ToolMetadata(
      name: journalQuery,
      displayName: '查询记录',
      description: '查询记录列表',
      category: ToolCategory.journal,
      openAIToolDefinition: OpenAITool(
        type: 'function',
        function: OpenAIFunction(
          name: journalQuery,
          description: '查询记录列表',
          parametersSchema: {
            'type': 'object',
            'properties': {
              'categoryId': {
                'type': 'string',
                'description': '类别筛选',
              },
              'limit': {
                'type': 'integer',
                'description': '限制返回数量',
              },
            },
          },
        ),
      ),
    ),
  ];
}

