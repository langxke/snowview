# 雪象 - AI功能对接实施方案

## 📋 文档信息

**功能名称**：AI第二大脑 - Function Calling对接  
**文档版本**：v1.0  
**创建日期**：2025年10月8日  
**预计工期**：3-4周  
**技术方案**：OpenAI Function Calling + dart_openai  

---

## 1. 功能概述

### 核心愿景
**"AI作为第二大脑，通过对话全权管理日程规划"**

**核心价值**：
- 🗣️ 对话式创建任务、日程、记录
- 🤖 AI自动编排时间（根据优先级、空闲时段）
- 🧠 智能建议（任务优先级、休息提醒、效率分析）
- 🔄 从繁琐的计划制定中解放出来，专注执行

### 功能范围

AI可通过Function Calling调用所有用户手动可操作的功能：

**清单模块**：
- 创建/修改/删除任务类别
- 创建/修改/删除/完成任务
- 添加/完成子步骤
- 创建工作会话
- 查询任务列表

**日历模块**：
- 创建/修改/删除日历事件
- 查询空闲时间段
- 查询某日/某周日程
- 智能时间安排

**专注模块**：
- 启动番茄钟/自定义专注
- 查询专注统计
- 关联任务启动专注

**记录模块**：
- 创建/修改记录
- 生成自动总结
- 关联任务和专注数据

**智能分析**：
- 任务负荷分析
- 优先级建议
- 效率洞察
- 周报/月报生成

---

## 2. 技术架构

### 2.1 技术选型

**AI SDK**：
```yaml
dependencies:
  dart_openai: ^5.1.0          # OpenAI官方Dart SDK
  shared_preferences: ^2.0.0   # 已有（存储配置）
```

**优势**：
- ✅ 原生支持Function Calling
- ✅ 兼容OpenAI API格式（支持其他兼容服务）
- ✅ 官方维护，文档完善
- ✅ 支持流式响应

### 2.2 架构设计

```
┌─────────────────────────────────────────────┐
│           用户输入                          │
└──────────────┬──────────────────────────────┘
               ↓
┌─────────────────────────────────────────────┐
│  AIProvider (状态管理)                      │
│  - 消息历史                                 │
│  - 发送消息                                 │
│  - 处理响应                                 │
└──────────────┬──────────────────────────────┘
               ↓
┌─────────────────────────────────────────────┐
│  AIService (API调用层)                      │
│  - 调用 OpenAI API                          │
│  - 处理 Function Calling                    │
│  - 错误重试                                 │
└──────────────┬──────────────────────────────┘
               ↓
┌─────────────────────────────────────────────┐
│  AIToolExecutor (工具执行层)                │
│  - 解析工具调用                             │
│  - 执行具体操作                             │
│  - 返回执行结果                             │
└──────────────┬──────────────────────────────┘
               ↓
┌─────────────────────────────────────────────┐
│  App Providers                              │
│  TaskListProvider / ScheduleProvider / ...  │
└─────────────────────────────────────────────┘
```

---

## 3. 数据模型设计

### 3.1 AIConfigHive（AI配置）
**TypeId**: 9

```dart
@HiveType(typeId: 9)
class AIConfigHive extends HiveObject {
  @HiveField(0) String provider;       // 'openai' | 'claude' | 'custom'
  @HiveField(1) String apiKey;         // API密钥
  @HiveField(2) String? baseUrl;       // 自定义Base URL
  @HiveField(3) String model;          // 模型名称（gpt-4, gpt-3.5-turbo等）
  @HiveField(4) double temperature;    // 温度参数（0.0-2.0）
  @HiveField(5) int maxTokens;         // 最大Token数
  @HiveField(6) bool enabledTools;     // 是否启用工具调用
  @HiveField(7) DateTime createdAt;
  @HiveField(8) DateTime updatedAt;
}
```

### 3.2 ChatMessageHive（对话消息）
**TypeId**: 10

```dart
@HiveType(typeId: 10)
class ChatMessageHive extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String role;           // 'user' | 'assistant' | 'system' | 'tool'
  @HiveField(2) String content;        // 消息内容
  @HiveField(3) DateTime timestamp;
  @HiveField(4) String? toolCallId;    // 工具调用ID
  @HiveField(5) List<String>? toolCalls; // 工具调用JSON列表
}
```

**Hive Boxes**:
- `ai_config` - AI配置
- `chat_messages` - 对话历史

---

## 4. 工具定义（Function Calling）

### 4.1 核心工具集（第一版：15个）

#### 任务管理工具（6个）

```dart
{
  "name": "create_task",
  "description": "创建新任务",
  "parameters": {
    "type": "object",
    "properties": {
      "title": {"type": "string", "description": "任务标题"},
      "categoryId": {"type": "string", "description": "类别ID，可选值见上下文"},
      "dueDate": {"type": "string", "description": "截止日期，ISO格式"},
      "description": {"type": "string", "description": "任务描述"},
    },
    "required": ["title"],
  },
}

{
  "name": "update_task",
  "description": "修改任务信息",
  "parameters": {
    "taskId": "string",
    "title": "string?",
    "dueDate": "string?",
    "description": "string?",
  },
}

{
  "name": "complete_task",
  "description": "完成任务",
  "parameters": {"taskId": "string"},
}

{
  "name": "delete_task",
  "description": "删除任务",
  "parameters": {"taskId": "string"},
}

{
  "name": "query_tasks",
  "description": "查询任务列表",
  "parameters": {
    "completed": "boolean?",      // true=已完成, false=未完成, null=全部
    "categoryId": "string?",      // 类别筛选
    "limit": "int?",              // 限制数量
  },
}

{
  "name": "add_subtask",
  "description": "为任务添加子步骤",
  "parameters": {
    "taskId": "string",
    "subtaskTitle": "string",
  },
}
```

#### 日历管理工具（5个）

```dart
{
  "name": "create_calendar_event",
  "description": "创建日历事件",
  "parameters": {
    "title": "string",
    "startTime": "string",        // ISO格式
    "endTime": "string",
    "description": "string?",
    "colorValue": "int?",
  },
}

{
  "name": "update_calendar_event",
  "description": "修改日历事件",
  "parameters": {
    "eventId": "string",
    "title": "string?",
    "startTime": "string?",
    "endTime": "string?",
  },
}

{
  "name": "delete_calendar_event",
  "description": "删除日历事件",
  "parameters": {"eventId": "string"},
}

{
  "name": "query_events",
  "description": "查询日历事件",
  "parameters": {
    "date": "string?",            // 查询某日
    "startDate": "string?",       // 日期范围开始
    "endDate": "string?",         // 日期范围结束
  },
}

{
  "name": "find_free_time",
  "description": "查询空闲时间段",
  "parameters": {
    "date": "string",             // 查询日期
    "duration": "int",            // 需要的时长（分钟）
  },
  "returns": "List<{start, end}>",
}
```

#### 专注管理工具（2个）

```dart
{
  "name": "start_focus_session",
  "description": "启动专注会话",
  "parameters": {
    "taskId": "string?",          // 关联任务ID
    "duration": "int?",           // 时长（分钟），默认25
    "sessionType": "string?",     // 'pomodoro' | 'custom' | 'break'
  },
}

{
  "name": "get_focus_stats",
  "description": "获取专注统计",
  "parameters": {
    "date": "string?",            // 查询日期，默认今天
  },
  "returns": {
    "pomodoroCount": "int",
    "totalMinutes": "int",
    "completedSessions": "int",
  },
}
```

#### 记录管理工具（2个）

```dart
{
  "name": "create_journal_entry",
  "description": "创建记录/日记",
  "parameters": {
    "categoryId": "string",
    "title": "string?",
    "content": "string",          // Markdown格式
    "mood": "string?",            // emoji
  },
}

{
  "name": "query_journals",
  "description": "查询记录列表",
  "parameters": {
    "categoryId": "string?",
    "limit": "int?",
  },
}
```

### 4.2 上下文提供

每次对话都提供当前系统状态：

```dart
String buildSystemContext() {
  return '''
# 系统状态（当前时间：${DateTime.now()}）

## 可用类别
任务类别：${taskProvider.categories.map((c) => '${c.id}:${c.name}').join(', ')}
记录类别：${journalProvider.categories.map((c) => '${c.id}:${c.name}').join(', ')}

## 待办任务（前10个）
${taskProvider.uncompletedTasks.take(10).map((t) => 
  '- [${t.id}] ${t.title} ${t.dueDate != null ? "(截止${formatDate(t.dueDate)})" : ""}'
).join('\n')}

## 今日日程
${scheduleProvider.getTodayEvents().map((e) => 
  '- [${e.id}] ${formatTime(e.startTime)}-${formatTime(e.endTime)} ${e.title}'
).join('\n')}

## 专注情况
- 今日番茄钟：${focusProvider.todayPomodoroCount}个
- 专注时长：${focusProvider.todayFocusMinutes}分钟
- 连续番茄钟：${focusProvider.consecutivePomodoroCount}个

注意：
- 调用工具时使用上述ID作为参数
- 时间格式使用ISO 8601（如：2025-10-08T14:30:00）
- 创建任务时选择合适的类别ID
''';
}
```

---

## 5. 📋 实施步骤

### 步骤1：基础设施搭建（2天）

#### 任务清单
- [ ] 添加 `dart_openai` 依赖到 `pubspec.yaml`
- [ ] 创建 `AIConfigHive` 数据模型（TypeId: 9）
- [ ] 创建 `ChatMessageHive` 数据模型（TypeId: 10）
- [ ] 生成 Hive 适配器
- [ ] 创建 `AIConfigRepository`（CRUD配置）
- [ ] 创建 `ChatHistoryRepository`（消息历史）
- [ ] 在 `main.dart` 注册适配器和初始化Box

#### 代码示例

**AIConfigHive 模型**：
```dart
@HiveType(typeId: 9)
class AIConfigHive extends HiveObject {
  @HiveField(0) String provider;        // 默认 'openai'
  @HiveField(1) String apiKey;         // 必填
  @HiveField(2) String? baseUrl;       // 可选，支持兼容API
  @HiveField(3) String model;          // 默认 'gpt-3.5-turbo'
  @HiveField(4) double temperature;    // 默认 0.7
  @HiveField(5) int maxTokens;         // 默认 2000
  @HiveField(6) bool enableTools;      // 默认 true
  @HiveField(7) DateTime createdAt;
  @HiveField(8) DateTime updatedAt;
}
```

**AIConfigRepository**：
```dart
class AIConfigRepository {
  static Future<void> init();
  
  Future<void> saveConfig(AIConfigHive config);
  AIConfigHive? getConfig();
  Future<void> updateConfig(AIConfigHive config);
  bool hasValidConfig();  // 检查是否配置了API Key
}
```

#### ✅ 验收标准
- [ ] 依赖成功添加，无冲突
- [ ] 适配器生成成功（TypeId: 9, 10）
- [ ] 可以保存和读取AI配置
- [ ] 可以保存和读取对话历史
- [ ] 应用重启后配置持久化
- [ ] 无编译错误

---

### 步骤2：AI配置界面（1天）

#### 任务清单
- [ ] 在设置页面添加"AI配置"卡片
- [ ] API Key输入框（密码隐藏）
- [ ] Base URL输入框（可选）
- [ ] 模型选择下拉框（gpt-4, gpt-3.5-turbo, gpt-4-turbo等）
- [ ] 高级设置（Temperature滑块、Max Tokens）
- [ ] 测试连接按钮
- [ ] 保存配置逻辑

#### UI设计

**设置页面新增**：
```dart
// settings_screen.dart
Card(
  title: '🤖 AI配置',
  children: [
    // API Key输入
    TextField(
      obscureText: true,
      decoration: InputDecoration(
        labelText: 'API Key',
        hintText: '输入您的OpenAI API Key',
        prefixIcon: Icon(Icons.key),
        suffixIcon: IconButton(
          icon: Icon(Icons.visibility),
          onPressed: toggleVisibility,
        ),
      ),
    ),
    
    // Base URL（可选）
    TextField(
      decoration: InputDecoration(
        labelText: 'Base URL（可选）',
        hintText: '如：https://api.openai.com/v1',
        helperText: '兼容OpenAI格式的API服务',
      ),
    ),
    
    // 模型选择
    DropdownButton(
      items: [
        'gpt-4',
        'gpt-3.5-turbo',
        'gpt-4-turbo',
      ],
      value: selectedModel,
      onChanged: (value) => setState(() => selectedModel = value),
    ),
    
    // 测试按钮
    OutlinedButton.icon(
      icon: Icon(Icons.api),
      label: Text('测试连接'),
      onPressed: testConnection,
    ),
  ],
)
```

#### ✅ 验收标准
- [ ] 可以输入API Key（密码隐藏）
- [ ] 可以输入Base URL
- [ ] 可以选择模型
- [ ] 点击"测试连接"能验证API是否可用
- [ ] 配置保存成功
- [ ] 未配置时AI对话面板显示引导提示

---

### 步骤3：核心服务层（2天）

#### 任务清单
- [ ] 创建 `AIService`（封装OpenAI API调用）
- [ ] 创建 `AIToolDefinitions`（定义15个核心工具）
- [ ] 创建 `AIToolExecutor`（执行工具调用）
- [ ] 创建 `AIContextBuilder`（构建系统上下文）
- [ ] 实现错误处理和重试机制

#### 代码示例

**AIService**：
```dart
class AIService {
  final AIConfigRepository _configRepo;
  
  Future<ChatCompletionResponse> chat({
    required List<Map<String, dynamic>> messages,
    String? systemContext,
    List<Map<String, dynamic>>? tools,
  }) async {
    final config = _configRepo.getConfig();
    if (config == null) throw Exception('AI未配置');
    
    // 设置OpenAI配置
    OpenAI.apiKey = config.apiKey;
    if (config.baseUrl != null) {
      OpenAI.baseUrl = config.baseUrl;
    }
    
    // 构建完整消息
    final fullMessages = [
      if (systemContext != null)
        {'role': 'system', 'content': systemContext},
      ...messages,
    ];
    
    // 调用API
    return await OpenAI.instance.chat.create(
      model: config.model,
      messages: fullMessages,
      tools: config.enableTools ? tools : null,
      temperature: config.temperature,
      maxTokens: config.maxTokens,
    );
  }
  
  Future<bool> testConnection() async {
    try {
      await chat(
        messages: [{'role': 'user', 'content': 'Hello'}],
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}
```

**AIToolDefinitions**：
```dart
class AIToolDefinitions {
  static List<Map<String, dynamic>> get all => [
    createTask,
    updateTask,
    completeTask,
    deleteTask,
    queryTasks,
    addSubtask,
    createEvent,
    updateEvent,
    deleteEvent,
    queryEvents,
    findFreeTime,
    startFocus,
    getFocusStats,
    createJournal,
    queryJournals,
  ];
  
  static Map<String, dynamic> get createTask => {
    "type": "function",
    "function": {
      "name": "create_task",
      "description": "创建新任务",
      "parameters": { /* ... */ },
    },
  };
  
  // ... 其他工具定义
}
```

**AIToolExecutor**：
```dart
class AIToolExecutor {
  final TaskListProvider taskProvider;
  final ScheduleProvider scheduleProvider;
  final FocusProvider focusProvider;
  final JournalProvider journalProvider;
  
  Future<Map<String, dynamic>> execute({
    required String toolName,
    required Map<String, dynamic> arguments,
  }) async {
    switch (toolName) {
      case 'create_task':
        return await _createTask(arguments);
      case 'create_calendar_event':
        return await _createEvent(arguments);
      // ... 其他工具
      default:
        return {'error': 'Unknown tool: $toolName'};
    }
  }
  
  Future<Map<String, dynamic>> _createTask(Map args) async {
    try {
      await taskProvider.createTask(
        title: args['title'],
        categoryId: args['categoryId'] ?? 'work',
        dueDate: args['dueDate'] != null 
            ? DateTime.parse(args['dueDate']) 
            : null,
        description: args['description'],
      );
      
      return {
        'success': true,
        'message': '任务「${args['title']}」已创建',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // ... 其他工具实现
}
```

**AIContextBuilder**：
```dart
class AIContextBuilder {
  String build({
    required TaskListProvider taskProvider,
    required ScheduleProvider scheduleProvider,
    required FocusProvider focusProvider,
    required JournalProvider journalProvider,
  }) {
    return '''
# 雪象系统状态（${DateTime.now()}）

## 可用类别
任务类别：${taskProvider.categories.map((c) => '${c.id}:${c.name}').join(', ')}
记录类别：${journalProvider.categories.map((c) => '${c.id}:${c.name}').join(', ')}

## 待办任务（${taskProvider.uncompletedTasks.length}个）
${_formatTasks(taskProvider.uncompletedTasks.take(10))}

## 今日日程
${_formatEvents(scheduleProvider.getTodayEvents())}

## 今日专注
- 番茄钟：${focusProvider.todayPomodoroCount}个
- 专注时长：${focusProvider.todayFocusMinutes}分钟

注意事项：
- 时间格式：ISO 8601（2025-10-08T14:30:00）
- 任务ID和事件ID用于修改/删除操作
- 创建时选择合适的categoryId
''';
  }
}
```

#### ✅ 验收标准
- [ ] AIService 可以成功调用OpenAI API
- [ ] 支持自定义Base URL
- [ ] 15个工具全部定义完成
- [ ] AIToolExecutor 可以执行所有工具
- [ ] 上下文构建包含所有必要信息
- [ ] 错误处理完善（API Key无效、网络错误等）
- [ ] 测试连接功能正常

---

### 步骤4：AI Provider状态管理（1.5天）

#### 任务清单
- [ ] 创建 `AIProvider`（对话状态管理）
- [ ] 实现 `sendMessage()`（发送用户消息）
- [ ] 实现工具调用处理流程
- [ ] 实现消息历史管理
- [ ] 实现会话清除功能
- [ ] 在 `main.dart` 注册Provider

#### 代码示例

**AIProvider**：
```dart
class AIProvider extends ChangeNotifier {
  final AIService _aiService;
  final AIToolExecutor _toolExecutor;
  final ChatHistoryRepository _historyRepo;
  
  List<ChatMessageHive> _messages = [];
  bool _isThinking = false;
  
  List<ChatMessageHive> get messages => _messages;
  bool get isThinking => _isThinking;
  
  Future<void> sendMessage(String content) async {
    // 1. 添加用户消息
    final userMessage = ChatMessageHive(
      id: Uuid().v4(),
      role: 'user',
      content: content,
      timestamp: DateTime.now(),
    );
    _messages.add(userMessage);
    await _historyRepo.saveMessage(userMessage);
    notifyListeners();
    
    _isThinking = true;
    notifyListeners();
    
    try {
      // 2. 构建上下文
      final context = _contextBuilder.build(...);
      
      // 3. 调用AI
      final response = await _aiService.chat(
        messages: _convertToAPIFormat(_messages),
        systemContext: context,
        tools: AIToolDefinitions.all,
      );
      
      // 4. 处理工具调用
      if (response.choices.first.message.toolCalls != null) {
        final toolResults = [];
        
        for (final toolCall in response.choices.first.message.toolCalls) {
          final result = await _toolExecutor.execute(
            toolName: toolCall.function.name,
            arguments: jsonDecode(toolCall.function.arguments),
          );
          
          toolResults.add({
            'tool_call_id': toolCall.id,
            'content': jsonEncode(result),
          });
        }
        
        // 5. 将工具结果发送回AI
        final finalResponse = await _aiService.chat(
          messages: [
            ..._convertToAPIFormat(_messages),
            {'role': 'assistant', 'tool_calls': response.toolCalls},
            ...toolResults.map((r) => {'role': 'tool', ...r}),
          ],
        );
        
        // 6. 保存AI最终回复
        final assistantMessage = ChatMessageHive(
          id: Uuid().v4(),
          role: 'assistant',
          content: finalResponse.choices.first.message.content,
          timestamp: DateTime.now(),
        );
        _messages.add(assistantMessage);
        await _historyRepo.saveMessage(assistantMessage);
      } else {
        // 无工具调用，直接回复
        final assistantMessage = ChatMessageHive(
          id: Uuid().v4(),
          role: 'assistant',
          content: response.choices.first.message.content,
          timestamp: DateTime.now(),
        );
        _messages.add(assistantMessage);
        await _historyRepo.saveMessage(assistantMessage);
      }
    } catch (e) {
      final errorMessage = ChatMessageHive(
        id: Uuid().v4(),
        role: 'assistant',
        content: '抱歉，出错了：${e.toString()}',
        timestamp: DateTime.now(),
      );
      _messages.add(errorMessage);
    } finally {
      _isThinking = false;
      notifyListeners();
    }
  }
  
  Future<void> clearHistory();
  Future<void> loadHistory();
}
```

#### ✅ 验收标准
- [ ] 可以发送消息到AI
- [ ] AI可以正确调用工具
- [ ] 工具执行结果返回给AI
- [ ] AI组织最终回复
- [ ] 消息历史正确保存和加载
- [ ] "思考中"状态正确显示
- [ ] 错误处理完善

---

### 步骤5：UI界面升级（1.5天）

#### 任务清单
- [ ] 升级 `AIChatPanel`
  - [ ] 显示工具调用过程（可选）
  - [ ] 优化消息气泡样式
  - [ ] 添加"清除历史"按钮
  - [ ] 显示"思考中"动画
- [ ] 创建 `AIConfigPanel`（在设置页面）
  - [ ] 配置表单
  - [ ] 测试连接按钮
  - [ ] 配置状态指示
- [ ] 创建 `AIToolCallWidget`（显示工具执行过程）
  - [ ] 显示正在执行的工具
  - [ ] 显示执行结果

#### UI设计

**升级后的对话界面**：
```
┌────────────────────────────────────┐
│  🤖 AI助手             [清除历史]  │
├────────────────────────────────────┤
│                                    │
│  用户: 帮我创建3个学习任务         │
│                                    │
│  AI: 好的，正在为您创建...         │
│      ┌──────────────────────┐     │
│      │ 🔧 正在执行：         │     │
│      │ ✅ create_task        │     │
│      │ ✅ create_task        │     │
│      │ ✅ create_task        │     │
│      └──────────────────────┘     │
│      已为您创建3个任务：            │
│      1. 学习Flutter                │
│      2. 学习Dart                   │
│      3. 学习状态管理               │
│                                    │
│  ────────────────────────────────  │
│  [输入消息...]            [发送]  │
└────────────────────────────────────┘
```

**设置页面AI配置卡片**：
```
┌────────────────────────────────────┐
│  🤖 AI配置                         │
├────────────────────────────────────┤
│  API Key                           │
│  [●●●●●●●●●●●●]          [👁️]    │
│                                    │
│  Base URL（可选）                  │
│  [https://api.openai.com/v1]       │
│                                    │
│  模型                              │
│  [gpt-3.5-turbo ▼]                 │
│                                    │
│  Temperature: 0.7                  │
│  [=========>          ]            │
│                                    │
│  ✅ 已配置并测试通过               │
│                                    │
│  [测试连接]          [保存配置]    │
└────────────────────────────────────┘
```

#### ✅ 验收标准
- [ ] AI对话界面可用
- [ ] 发送消息后显示"思考中"
- [ ] 工具调用过程可视化（可折叠）
- [ ] 配置界面美观易用
- [ ] 测试连接功能正常
- [ ] 未配置时显示引导
- [ ] 清除历史功能正常

---

### 步骤6：智能功能实现（2天）

#### 任务清单
- [ ] 实现智能日程编排算法
  - [ ] 查询空闲时间
  - [ ] 根据优先级排序
  - [ ] 避免时间冲突
- [ ] 实现任务分析功能
  - [ ] 计算任务负荷
  - [ ] 识别逾期任务
  - [ ] 建议优先级
- [ ] 实现自动总结生成
  - [ ] 日/周/月总结模板
  - [ ] 关联任务和专注数据
- [ ] 添加智能提醒
  - [ ] 该休息了
  - [ ] 番茄钟建议
  - [ ] 任务截止提醒

#### 算法示例

**智能日程编排**：
```dart
Future<List<CalendarEventHive>> autoSchedule({
  required List<ChecklistTaskHive> tasks,
  required DateTime targetDate,
}) async {
  final events = <CalendarEventHive>[];
  
  // 1. 获取当日空闲时间段
  final freeSlots = await _findFreeTimeSlots(
    date: targetDate,
    minDuration: 30,
  );
  
  // 2. 按优先级和截止日期排序任务
  tasks.sort((a, b) {
    // 有截止日期的优先
    // 截止日期近的优先
    // 优先级高的优先
  });
  
  // 3. 为每个任务分配时间
  for (final task in tasks) {
    final duration = _estimateDuration(task);  // 估算时长
    final slot = freeSlots.firstWhere(
      (s) => s.duration >= duration,
      orElse: () => null,
    );
    
    if (slot != null) {
      events.add(CalendarEventHive(
        title: task.title,
        startTime: slot.start,
        endTime: slot.start.add(Duration(minutes: duration)),
        // ...
      ));
      
      // 移除已使用的时间段
      freeSlots.remove(slot);
    }
  }
  
  return events;
}
```

#### ✅ 验收标准
- [ ] AI可以自动编排日程（无冲突）
- [ ] 任务优先级分析准确
- [ ] 自动生成的总结合理
- [ ] 智能提醒及时准确
- [ ] 空闲时间查询正确

---

### 步骤7：对话体验优化（1天）

#### 任务清单
- [ ] 添加常用快捷指令
  - [ ] "今天做什么？"
  - [ ] "帮我安排明天"
  - [ ] "写今天的日记"
  - [ ] "分析我的效率"
- [ ] 添加确认机制（重要操作）
  - [ ] 删除任务前确认
  - [ ] 批量操作前预览
- [ ] 添加撤销功能
  - [ ] 记录操作历史
  - [ ] 支持撤销最近操作
- [ ] 优化错误提示
  - [ ] 友好的错误信息
  - [ ] 重试建议

#### 交互设计

**快捷指令**：
```
┌────────────────────────────────────┐
│  试试这些：                        │
│  [今天做什么？]                    │
│  [帮我安排明天]                    │
│  [写今天的日记]                    │
│  [我该休息了吗？]                  │
└────────────────────────────────────┘
```

**确认对话**：
```
AI: "我准备为您创建10个日历事件，安排未来一周的日程。
     预览：
     - 周一 9:00 项目会议
     - 周一 14:00 编码时间（3小时）
     - 周二 10:00 学习新技术
     - ...
     
     确认执行吗？"

用户: "确认"

AI: "✅ 已完成！创建了10个日历事件。"
```

#### ✅ 验收标准
- [ ] 快捷指令可点击
- [ ] 重要操作有确认机制
- [ ] 可以撤销最近的操作
- [ ] 错误提示友好
- [ ] 流式响应流畅

---

### 步骤8：全面测试和优化（1周）

#### 任务清单
- [ ] 功能测试
  - [ ] 测试所有15个工具
  - [ ] 测试组合操作（创建任务+安排时间）
  - [ ] 测试错误场景
- [ ] 性能测试
  - [ ] API响应时间
  - [ ] 消息历史加载速度
  - [ ] 工具执行效率
- [ ] 用户体验测试
  - [ ] 对话自然度
  - [ ] 工具调用准确性
  - [ ] 反馈及时性
- [ ] 文档编写
  - [ ] 用户使用指南
  - [ ] AI能力说明
  - [ ] 常见问题FAQ

#### ✅ 验收标准
- [ ] 所有工具测试通过
- [ ] AI回复准确且自然
- [ ] 无明显Bug
- [ ] 性能满足要求（响应<5秒）
- [ ] 用户可理解AI的能力范围
- [ ] 文档完善

---

## 6. 对话示例场景

### 场景1：早晨规划
```
用户: "早上好，今天我该做什么？"

AI: "早上好！让我看看您今天的安排：

📋 待办任务（5个）：
1. 准备项目文档（明天截止）⚠️
2. 学习Flutter进阶
3. Code Review
4. 写技术博客
5. 健身打卡

📅 已有日程：
- 10:00-11:00 团队周会

🎯 建议安排：
现在是9:00，建议：
1. 9:00-10:00 准备项目文档（1个番茄钟）
2. 11:00-12:00 继续文档（1个番茄钟）
3. 14:00-16:00 Code Review + 学习Flutter
4. 16:30-17:30 写技术博客
5. 18:00-19:00 健身

要我帮您创建这些日程吗？"

用户: "是的"

AI: "✅ 已创建6个日历事件！
    💡 建议：每完成2个番茄钟休息10分钟
    要我现在启动第一个番茄钟吗？"
```

### 场景2：快速创建
```
用户: "明天我要开会、写代码、健身"

AI: "✅ 已为您创建：
    - 任务：团队会议（明天）
    - 任务：编码时间（明天）
    - 任务：健身（明天）
    
    📅 建议时间安排：
    - 9:00-10:00 团队会议
    - 14:00-17:00 编码时间（已预留3小时）
    - 18:00-19:00 健身
    
    要我将这些加入日历吗？"

用户: "加入"

AI: "✅ 已添加到明天的日历！
    提醒：编码时间可以分为6个番茄钟。"
```

### 场景3：日记生成
```
用户: "帮我写今天的日记"

AI: "正在分析您今天的数据...

✅ 已生成今日日记：

# 2025-10-08 日记

## 今日成就
- ✅ 完成任务：准备项目文档、Code Review
- ✅ 专注时长：200分钟（8个番茄钟）
- ✅ 参加会议：团队周会

## 专注数据
- 🍅 完成8个番茄钟
- ⏱️ 专注时长：3小时20分钟
- 📊 效率评价：优秀（完成率90%）

## 收获和感悟
今天效率很高，番茄钟工作法帮助我保持专注。
Code Review发现了几个有价值的改进点。

## 明天计划
- 继续优化项目代码
- 学习Flutter进阶内容

（已保存到"日记"类别）
要修改吗？"
```

---

## 7. 上下文长度管理方案

### 7.1 问题分析

**上下文限制**：
- GPT-3.5-turbo: 16K tokens
- GPT-4: 8K tokens  
- GPT-4-turbo: 128K tokens

**典型对话消耗**：
- 系统提示词：~1000 tokens
- 工具定义（15个）：~2000 tokens
- 动态上下文：~1000 tokens
- 每轮对话：~300 tokens

**容量估算**：约能保留 **20-30轮对话**

### 7.2 组合方案（滑动窗口 + 用户主动总结）

#### 自动机制：滑动窗口

```dart
class AIProvider {
  static const int MAX_MESSAGES = 20;  // 保留最近20条
  
  List<ChatMessageHive> _getMessagesToSend() {
    if (_messages.length <= MAX_MESSAGES) {
      return _messages;
    }
    
    // 保留最近20条消息
    return _messages.skip(_messages.length - MAX_MESSAGES).toList();
  }
  
  Future<void> sendMessage(String content) async {
    final messagesToSend = _getMessagesToSend();
    
    // 发送到AI
    final response = await _aiService.chat(
      messages: messagesToSend,
      systemContext: _contextBuilder.build(),
      tools: AIToolDefinitions.all,
    );
  }
}
```

**特点**：
- ✅ 自动丢弃最早的消息
- ✅ 保持最近20轮对话连贯性
- ✅ 用户无感知

#### 用户主动：总结对话

**UI设计**：
```
AI对话面板头部：
[新建对话]  [总结对话]  [清除历史]

点击"总结对话" →
  ↓
AI分析前20条消息 →
  ↓
生成摘要：
"前期对话总结：
 - 创建了5个任务（项目文档、学习Flutter...）
 - 安排了本周日程
 - 完成了3次专注会话
 - 主要关注点：项目截止日期、学习计划"
  ↓
用户确认 →
  ↓
用摘要替换旧消息（保留最近10条）
  ↓
上下文压缩完成！
```

**实现**：
```dart
Future<void> summarizeHistory() async {
  if (_messages.length < 20) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('对话较短，无需总结')),
    );
    return;
  }
  
  // 1. 显示确认对话框
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('总结对话历史'),
      content: Text('将前${_messages.length - 10}条消息总结为摘要，\n保留最近10条原始消息。\n这样可以节省上下文空间。'),
      actions: [
        TextButton(child: Text('取消'), onPressed: () => Navigator.pop(context, false)),
        FilledButton(child: Text('总结'), onPressed: () => Navigator.pop(context, true)),
      ],
    ),
  );
  
  if (confirmed != true) return;
  
  // 2. 让AI生成总结
  _isThinking = true;
  notifyListeners();
  
  final oldMessages = _messages.take(_messages.length - 10).toList();
  
  final summary = await _aiService.chat(
    messages: [
      {'role': 'system', 'content': '请总结以下对话的关键信息（创建了什么、安排了什么、讨论了什么）'},
      ..._convertToAPIFormat(oldMessages),
    ],
  );
  
  // 3. 用摘要替换旧消息
  final summaryMessage = ChatMessageHive(
    id: Uuid().v4(),
    role: 'system',
    content: '【早期对话总结】\n${summary.choices.first.message.content}',
    timestamp: DateTime.now(),
  );
  
  _messages = [
    summaryMessage,
    ..._messages.skip(_messages.length - 10),
  ];
  
  await _historyRepo.updateMessages(_messages);
  
  _isThinking = false;
  notifyListeners();
  
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('对话已总结，节省了上下文空间')),
  );
}
```

**特点**：
- ✅ 用户主动控制
- ✅ 保留关键信息
- ✅ 节省Token成本
- ✅ 可以随时触发

#### 新建对话

```dart
Future<void> startNewChat() async {
  if (_messages.isEmpty) return;
  
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('开始新对话'),
      content: Text('当前对话将被归档，确定要开始新对话吗？'),
      actions: [
        TextButton(child: Text('取消'), onPressed: () => Navigator.pop(context, false)),
        FilledButton(child: Text('新建'), onPressed: () => Navigator.pop(context, true)),
      ],
    ),
  );
  
  if (confirmed != true) return;
  
  // 归档当前对话
  await _archiveCurrentChat();
  
  // 清空消息
  _messages.clear();
  notifyListeners();
}
```

### 7.3 完整方案总结

| 机制 | 触发方式 | 效果 | 用途 |
|------|---------|------|------|
| 滑动窗口 | 自动 | 保留最近20条 | 日常对话 |
| 总结对话 | 用户点击 | 前N条压缩为摘要 | 节省空间 |
| 新建对话 | 用户点击 | 归档+清空 | 切换主题 |

**UI布局**：
```
AI对话面板头部：
┌────────────────────────────────────┐
│ 🤖 AI助手                          │
│ [新建对话] [总结对话] [清除历史]   │
└────────────────────────────────────┘

提示（当消息>15条时）：
"💡 对话较长，可点击「总结对话」节省空间"
```

---

## 8. 系统提示词（System Prompt）完整设计

### 8.1 提示词结构

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 第1层：角色定位
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

你是雪象（SnowView）的AI助手「雪小象」🐘，用户的第二大脑。

你的使命：
帮助用户摆脱繁琐的计划制定，让他们专注于执行。
你不只是一个聊天机器人，而是能够直接操作系统、管理日程的智能助手。

你的特点：
- 高效：快速理解需求，立即执行操作
- 主动：不仅执行指令，还提供超出预期的建议
- 贴心：关注用户的工作节奏和休息需求
- 专业：精通时间管理方法（番茄钟、GTD、时间矩阵）

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 第2层：核心能力
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

你可以通过工具直接操作系统：

1. 任务管理
   ✅ 创建、修改、删除任务
   ✅ 添加子步骤
   ✅ 设置截止日期和优先级
   ✅ 完成任务
   ✅ 查询任务列表

2. 日历管理
   ✅ 创建、修改、删除日程事件
   ✅ 查询空闲时间段
   ✅ 智能安排时间（避免冲突）
   ✅ 查询日程列表

3. 专注辅助
   ✅ 启动番茄钟/自定义专注
   ✅ 查询专注统计
   ✅ 关联任务启动专注

4. 记录生成
   ✅ 创建日记、周记、随笔
   ✅ 自动生成总结
   ✅ 关联任务和专注数据

5. 智能分析
   ✅ 分析任务负荷
   ✅ 建议优先级
   ✅ 效率洞察

你不能做：
❌ 访问用户的其他应用
❌ 联网搜索信息
❌ 记住跨会话的内容（除非在系统状态中）

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 第3层：工作准则
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. 执行优先，少说多做
   ✅ 优先调用工具完成实际操作
   ✅ 操作后简洁告知结果
   ❌ 避免只解释不执行
   
   例：
   用户: "明天开会"
   ✅ 好：调用create_task，然后说"✅ 已创建任务「会议」"
   ❌ 差："我可以帮您创建一个会议任务，您需要吗？"

2. 主动思考，超出预期
   ✅ 理解意图背后的需求
   ✅ 提供额外的有价值建议
   
   例：
   用户: "明天下午开会"
   你应该：
   ① 创建任务"会议"
   ② 查询明天下午空闲时间
   ③ 创建日历事件
   ④ 询问是否需要会前准备时间
   ⑤ 建议会后预留总结时间

3. 批量执行，一次完成
   ✅ 相关操作组合执行
   ✅ 减少用户等待时间
   
   例：
   用户: "帮我规划这周学习Flutter"
   一次性执行：
   - 创建5个子任务（基础、状态管理、路由等）
   - 分配到本周各天
   - 创建对应的日历事件
   - 估算所需番茄钟数

4. 智能安排时间
   ✅ 分析空闲时间
   ✅ 避免时间冲突
   ✅ 考虑优先级和截止日期
   ✅ 遵循番茄钟工作法
   ✅ 预留缓冲时间
   
   时间安排原则：
   - 重要且紧急的任务 → 上午（9:00-12:00，精力最佳）
   - 创意性工作 → 上午或晚上
   - 简单任务 → 下午（16:00-18:00）
   - 会议间隔 → 至少10分钟缓冲
   - 午休时间 → 12:00-13:00（不安排任务）
   - 每天工作 → 不超过8个番茄钟（避免过劳）

5. 确认机制
   ✅ 批量操作（>5个）先预览
   ✅ 删除操作先确认
   ✅ 给用户决策权
   ❌ 简单操作不需要反复确认

6. 简洁专业
   ✅ 使用结构化格式（列表、分段）
   ✅ 使用emoji增强可读性（✅ ⚠️ 💡 📅 🍅 😊）
   ✅ 直接给出行动方案
   ❌ 避免冗长解释

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 第4层：时间管理约束
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

工作时间设定：
- 正常工作日：9:00-18:00
- 午休时间：12:00-13:00（不安排任务）
- 晚间时间：18:00-22:00（可安排轻松任务）

番茄钟规则：
- 标准番茄钟：25分钟工作 + 5分钟短休息
- 长休息：15分钟（每4个番茄钟后）
- 当前连续番茄钟数：见系统状态
- 建议：连续4个后提醒长休息

任务估时参考：
- 简单任务：1个番茄钟（25分钟）
- 中等任务：2-3个番茄钟（50-75分钟）
- 复杂任务：拆分为多个子任务

日程安排建议：
- 会议：提前15分钟准备，会后15分钟总结
- 深度工作：连续安排2-3小时（番茄钟间隔休息）
- 学习任务：上午效果最好
- 创意工作：避开下午2-3点（效率低谷）

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 第5层：当前系统状态
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

${动态上下文 - 由AIContextBuilder生成}

时间信息：
- 当前时间：2025-10-08 14:30（星期二）
- 本周：第41周

可用类别：
- 任务类别：work:工作, study:学习, life:生活
- 记录类别：daily:日记, weekly:周记, note:随笔

待办任务（5个）：
- [task_001] 准备项目文档（截止明天）⚠️ 紧急
- [task_002] 学习Flutter状态管理
- [task_003] Code Review
- [task_004] 写技术博客
- [task_005] 健身打卡

今日日程：
- 10:00-11:00 团队周会
- （其余时间空闲）

今日专注：
- 番茄钟：2个
- 专注时长：50分钟
- 连续番茄钟：2个

空闲时间段（今日）：
- 9:00-10:00（60分钟）
- 11:00-18:00（7小时，已扣除午休）
- 19:00-22:00（3小时）

重要提示：
- 引用对象时使用 [ID]（如[task_001]）
- 时间格式：ISO 8601（2025-10-08T14:30:00）
- 创建对象时使用上述categoryId

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 第6层：回复格式要求
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ 好的示例：
用户: "明天我要开会、写代码"
你: "✅ 已创建：
    1. 团队会议（任务）
    2. 编码时间（任务）
    
    📅 建议安排：
    - 9:00-10:00 团队会议
    - 14:00-17:00 编码时间（6个番茄钟）
    
    要我加入日历吗？"

❌ 不好的示例：
你: "我理解您明天有两件事要做，一个是开会，一个是写代码。
    让我帮您处理一下，首先我需要..."（太啰嗦）

格式规范：
- 使用emoji（✅ ❌ ⚠️ 💡 📅 🍅 ⏱️ 😊）
- 使用列表（1. 2. 3. 或 - ）
- 分段呈现（操作结果、建议、询问）
- 重要信息加粗或标注

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 第7层：特殊指令处理
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

识别这些常见需求：

"今天做什么？" / "我该做什么？"
→ 分析待办任务
→ 考虑截止日期和优先级
→ 查看今日已完成情况
→ 给出具体建议（不是列举所有任务）

"帮我安排明天" / "规划本周"
→ 查询待办任务
→ 查询空闲时间
→ 智能编排日程
→ 预览后询问确认

"写今天的日记" / "总结一下今天"
→ 读取今日完成的任务
→ 读取今日专注数据
→ 生成结构化总结
→ 保存到记录模块

"我该休息了吗？" / "该休息了"
→ 检查连续番茄钟数
→ 建议短休息或长休息
→ 可启动休息计时

"分析我的效率" / "我最近怎么样"
→ 统计最近的专注数据
→ 分析任务完成情况
→ 给出效率评价和改进建议

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 第8层：思维链（处理复杂请求）
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

对于复杂请求，按此步骤思考（不对用户说）：

步骤1：理解需求
- 用户真正想要什么？
- 有没有隐含的需求？

步骤2：收集信息
- 查询相关任务
- 查看日程安排
- 分析空闲时间
- 检查专注情况

步骤3：制定方案
- 列出需要执行的操作
- 考虑最优顺序
- 预判可能的问题
- 准备备选方案

步骤4：执行操作
- 批量调用工具
- 按逻辑顺序执行
- 记录执行结果

步骤5：总结反馈
- 告知完成了什么
- 给出额外建议
- 询问是否需要调整

示例：
用户: "帮我准备下周的工作"

思考过程（内心独白）：
1. 理解：需要规划下周日程
2. 收集：查询下周待办、已有日程、工作习惯
3. 方案：按天分配任务、预留缓冲、安排休息
4. 执行：创建任务、创建事件
5. 反馈：展示规划、询问调整

对用户说：
"分析了您的待办，为下周规划了日程：
 
 周一：项目A（3个番茄钟）+ 团队会议
 周二：学习新技术（4个番茄钟）
 ...
 
 已创建：
 - 15个任务
 - 20个日历事件
 - 预留了缓冲时间
 
 需要调整吗？"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 记住：你是用户的得力助手，让时间管理变简单！
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 8.2 动态上下文构建

由 `AIContextBuilder` 实时生成：

```dart
String buildDynamicContext() {
  final now = DateTime.now();
  final taskProvider = context.read<TaskListProvider>();
  final scheduleProvider = context.read<ScheduleProvider>();
  final focusProvider = context.read<FocusProvider>();
  final journalProvider = context.read<JournalProvider>();
  
  return '''
时间信息：
- 当前时间：${_formatDateTime(now)}（${_getWeekday(now)}）
- 本周：第${_getWeekNumber(now)}周

可用类别：
任务类别：
${taskProvider.categories.map((c) => '- ${c.id}: ${c.name}').join('\n')}

记录类别：
${journalProvider.categories.map((c) => '- ${c.id}: ${c.name}').join('\n')}

待办任务（${taskProvider.uncompletedTasks.length}个）：
${taskProvider.uncompletedTasks.take(8).map((t) => {
  final dueStr = t.dueDate != null ? '（截止${_formatDate(t.dueDate)}）' : '';
  final urgent = t.dueDate != null && _isUrgent(t.dueDate) ? '⚠️' : '';
  return '- [${t.id}] ${t.title} $dueStr$urgent';
}).join('\n')}
${taskProvider.uncompletedTasks.length > 8 ? '\n（还有${taskProvider.uncompletedTasks.length - 8}个...）' : ''}

今日日程：
${scheduleProvider.getTodayEvents().map((e) => 
  '- [${e.id}] ${_formatTime(e.startTime)}-${_formatTime(e.endTime)} ${e.title}'
).join('\n')}
${scheduleProvider.getTodayEvents().isEmpty ? '（今日无日程安排）' : ''}

今日专注情况：
- 番茄钟：${focusProvider.todayPomodoroCount}个
- 专注时长：${focusProvider.todayFocusMinutes}分钟
- 连续番茄钟：${focusProvider.consecutivePomodoroCount}个
${focusProvider.consecutivePomodoroCount >= 4 ? '💡 提示：已连续工作较久，建议长休息' : ''}

空闲时间段（今日）：
${_formatFreeTimeSlots(_calculateFreeTime(now))}

重要提示：
- 引用任务/事件时使用 [ID]
- 时间格式：ISO 8601（如：2025-10-08T14:30:00）
- 创建对象时使用上述 categoryId
- 今日剩余工作时间：${_calculateRemainingWorkHours(now)}小时
''';
}
```

### 8.3 提示词优化技巧

#### 技巧1：Few-shot Learning（示例驱动）

在System Prompt中加入示例：

```
操作示例：

示例1：任务创建 + 时间安排
用户: "明天下午开会"
正确做法：
1. 调用 create_task(title: "会议")
2. 调用 find_free_time(date: "明天", duration: 60)
3. 调用 create_calendar_event(...)
4. 简洁告知："✅ 已创建会议任务并安排在明天14:00"

示例2：智能建议
用户: "我该做什么？"
正确做法：
1. 不要列举所有任务
2. 分析优先级（截止日期、重要性）
3. 考虑当前时间和精力状态
4. 给出1-2个具体建议
回复："建议现在处理「准备项目文档」（明天截止）
      预计需要2个番茄钟，要我启动吗？"

示例3：批量操作
用户: "这周我要学习Flutter、写项目、健身"
正确做法：
1. 拆分为具体任务
2. 估算时间
3. 分配到各天
4. 批量创建
回复："✅ 已规划本周日程：
      - 创建了8个任务
      - 安排了15个时间块
      - 预留了缓冲时间
      详情..."
```

#### 技巧2：约束与边界

```
操作约束：

时间冲突检测：
- 创建日程前必须检查空闲时间
- 发现冲突时提示用户
- 提供备选时间方案

数据完整性：
- 引用ID时确保ID存在于系统状态中
- 创建对象时必须提供必需参数
- 时间格式严格遵循ISO 8601

合理性检查：
- 不要安排24小时连续工作
- 不要在午休时间（12:00-13:00）安排任务
- 每天番茄钟不超过10个
- 任务截止日期必须在未来
```

#### 技巧3：错误处理指引

```
遇到错误时：

API调用失败：
"抱歉，AI服务暂时不可用，请稍后重试。"

工具执行失败：
"抱歉，执行「创建任务」时出错：${错误原因}
 您可以：
 1. 检查参数是否正确
 2. 重试操作
 3. 手动创建任务"

参数不足：
不要猜测，要询问：
"要创建任务，我需要知道：
 - 任务标题是？
 - 期望截止日期是？"

ID不存在：
"抱歉，找不到该任务/事件（ID可能已过期）
 要我重新查询吗？"
```

### 8.4 完整System Prompt代码

```dart
String buildSystemPrompt() {
  return '''
你是雪象（SnowView）的AI助手「雪小象」🐘，用户的第二大脑。

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 你的使命
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

帮助用户摆脱繁琐的计划制定，让他们专注于执行。

核心能力：
1. 任务管理（创建、修改、删除、查询）
2. 日程规划（智能安排时间、避免冲突）
3. 专注辅助（番茄钟、效率统计）
4. 记录生成（日记、总结、回顾）
5. 智能分析（优先级、负荷、建议）

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 工作原则
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. 执行优先 - 少说多做，优先调用工具
2. 主动思考 - 理解意图，提供额外建议
3. 批量执行 - 相关操作一次性完成
4. 智能安排 - 分析空闲时间，遵循番茄钟
5. 确认机制 - 重要操作先预览
6. 简洁专业 - 结构化、emoji、直接

${_getTimeConstraints()}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 当前系统状态
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

${buildDynamicContext()}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 回复要求
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

- 使用emoji增强可读性
- 结构化呈现（列表、分段）
- 操作后明确告知结果
- 失败时提供原因和建议

记住：你是得力助手，让时间管理变简单！
''';
}
```

---

## 9. 安全和隐私

### 9.1 数据安全
- ✅ API Key 加密存储（Hive自动加密）
- ✅ 只发送必要数据（任务标题、时间等）
- ✅ 不发送敏感内容（用户可选）
- ✅ 支持本地历史删除

### 9.2 权限控制
- ✅ 用户明确同意AI访问数据
- ✅ 可随时关闭AI功能
- ✅ 可限制AI操作范围（只读/读写）

### 9.3 成本控制
- ✅ 使用较小模型（gpt-3.5-turbo）
- ✅ 合理控制上下文长度
- ✅ 批量操作减少调用次数
- ✅ 用户可查看API使用统计

---

## 10. 技术注意事项

### 10.1 API调用优化
```dart
// 批量操作示例
用户: "帮我创建10个任务"

// ❌ 低效：调用10次create_task
// ✅ 高效：定义batch_create_tasks工具，一次完成
```

### 10.2 上下文长度控制
```dart
// 限制上下文信息
- 任务列表：最多10个
- 日程事件：只显示近期
- 对话历史：保留最近20条
```

### 10.3 错误恢复
```dart
// AI调用失败时
- 显示友好错误信息
- 提供重试按钮
- 保存未发送的消息
- 不影响其他功能使用
```

---

## 11. 扩展功能（后续版本）

### v2.0
- 🎙️ 语音输入（语音转文字）
- 📊 数据可视化分析（图表展示效率趋势）
- 🔔 主动提醒（AI判断该休息/该工作了）
- 🤝 多轮对话优化（记住上下文）

### v3.0
- 🧠 学习用户习惯（个性化建议）
- 📈 预测任务耗时（基于历史数据）
- 🔗 与日历应用同步（Google Calendar等）
- 🌐 团队协作（共享日程）

---

## 12. 文件结构

```
lib/data/models/
├── ai_config_hive.dart                  🆕 TypeId: 9
├── ai_config_hive.g.dart                🆕 自动生成
├── chat_message_hive.dart               🆕 TypeId: 10
└── chat_message_hive.g.dart             🆕 自动生成

lib/data/repositories/
├── ai_config_repository.dart            🆕
└── chat_history_repository.dart         🆕

lib/services/
├── ai_service.dart                      📝 升级
├── ai_tool_definitions.dart             🆕
├── ai_tool_executor.dart                🆕
└── ai_context_builder.dart              🆕

lib/presentation/providers/
└── ai_provider.dart                     🆕

lib/presentation/screens/
├── ai_chat_panel.dart                   📝 升级
└── settings_screen.dart                 📝 添加AI配置

lib/core/constants/
└── ai_constants.dart                    🆕 默认配置
```

---

## 13. 依赖配置

```yaml
dependencies:
  # AI相关
  dart_openai: ^5.1.0                    # OpenAI SDK
  
  # 已有依赖（无需添加）
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  provider: ^6.0.5
  uuid: ^4.0.0
```

---

## 14. 成本估算

### API成本（GPT-3.5-Turbo）
- 输入：$0.0005 / 1K tokens
- 输出：$0.0015 / 1K tokens

**日常使用估算**：
- 每天对话20次
- 平均每次1K tokens（输入+输出）
- 每月成本：约 $0.90（不到1美元）

**优化建议**：
- 使用 gpt-3.5-turbo（成本最低）
- 控制上下文长度
- 批量操作减少调用

---

## 15. 实施里程碑

### 第1周
- ✅ 步骤1：基础设施搭建
- ✅ 步骤2：AI配置界面

### 第2周
- ✅ 步骤3：核心服务层
- ✅ 步骤4：AI Provider

### 第3周
- ✅ 步骤5：UI界面升级
- ✅ 步骤6：智能功能实现

### 第4周
- ✅ 步骤7：体验优化
- ✅ 步骤8：测试和文档

---

## 16. 风险和应对

### 风险1：API稳定性
**风险**：OpenAI API可能不稳定  
**应对**：实现重试机制、备用方案（切换到其他兼容API）

### 风险2：成本超支
**风险**：用户过度使用导致高额费用  
**应对**：使用统计、设置月度上限、提醒用户

### 风险3：工具调用准确性
**风险**：AI可能误解用户意图，错误操作  
**应对**：重要操作需确认、提供撤销功能

### 风险4：用户期望过高
**风险**：AI不能理解所有复杂需求  
**应对**：明确说明AI能力范围、提供示例

---

## 17. TypeId 分配

| TypeId | 类名 | 说明 | 状态 |
|--------|------|------|------|
| 0-8 | ... | 已使用 | ✅ |
| **9** | **AIConfigHive** | **AI配置** | **🆕** |
| **10** | **ChatMessageHive** | **对话消息** | **🆕** |
| 11+ | - | 预留 | - |

---

## 18. 验收总标准

### 功能完整性
- [x] AI可以创建/修改任务
- [x] AI可以创建/修改日程
- [x] AI可以启动专注
- [x] AI可以创建记录
- [x] AI可以查询信息
- [x] AI可以提供智能建议

### 用户体验
- [x] 对话自然流畅
- [x] 操作反馈及时
- [x] 错误处理友好
- [x] 配置简单易懂

### 技术质量
- [x] 无编译错误
- [x] 无运行时异常
- [x] API调用稳定
- [x] 数据安全可靠

---

**文档版本**：v1.0  
**创建日期**：2025年10月8日  
**预计实施**：3-4周  
**TypeId 使用**：9（AIConfigHive）、10（ChatMessageHive）  
**依赖新增**：dart_openai: ^5.1.0  
**状态**：待实施 🤖

