# 放弃 dart_openai SDK，使用 HTTP 请求调用大模型 - 实施方案

## 📋 方案概述

### 目标
移除 `dart_openai` 依赖，使用 `dio` HTTP 客户端直接调用 OpenAI 兼容 API，解决 BaseURL 自动追加路径导致的兼容性问题。

### 核心优势
- ✅ 完全控制请求 URL（解决阿里百炼等非标准 API 地址问题）
- ✅ 支持任何 OpenAI 兼容的 API 服务
- ✅ 更灵活的错误处理和重试机制
- ✅ 更小的依赖体积

---

## 🎯 实施步骤总览

| 步骤 | 任务 | 影响范围 | 工作量 |
|------|------|---------|-------|
| 1 | 创建数据模型 | 新增 `lib/data/models/openai/` 目录 | 🟡 中 |
| 2 | 创建 HTTP 客户端 | 新增 `lib/services/openai_http_client.dart` | 🟢 低 |
| 3 | 重写 AIService | 修改 `lib/services/ai_service.dart` | 🔴 高 |
| 4 | 更新工具定义 | 修改 `lib/services/ai_tool_definitions.dart` | 🟢 低 |
| 5 | 更新 AIProvider | 修改 `lib/presentation/providers/ai_provider.dart` | 🟡 中 |
| 6 | 移除 SDK 依赖 | 修改 `pubspec.yaml` | 🟢 低 |
| 7 | 测试验证 | 全功能测试 | 🟡 中 |

---

## 📝 详细实施步骤

### 步骤 1：创建自定义数据模型

**目标**：替代 `dart_openai` 的数据类型

#### 1.1 目录结构
```
lib/data/models/openai/
├── openai_message.dart      # 消息模型
├── openai_tool.dart          # 工具定义模型
├── openai_chat_response.dart # 聊天响应模型
├── openai_stream_response.dart # 流式响应模型
└── openai_models.dart        # 统一导出
```

#### 1.2 核心类型定义

**`openai_message.dart`**
- `OpenAIMessageRole` 枚举：`system`, `user`, `assistant`, `tool`
- `OpenAIMessageContent` 类：消息内容（文本或图片）
- `OpenAIToolCall` 类：工具调用
- `OpenAIFunctionCall` 类：函数调用
- `OpenAIChatMessage` 类：完整的聊天消息

**关键方法**：
```dart
// 工厂方法
OpenAIChatMessage.text({required OpenAIMessageRole role, required String content})
OpenAIChatMessage.toolResponse({required String toolCallId, required String content})

// 序列化
Map<String, dynamic> toJson()
factory OpenAIChatMessage.fromJson(Map<String, dynamic> json)

// 辅助方法
String get textContent  // 获取纯文本内容
```

**`openai_tool.dart`**
- `OpenAITool` 类：工具定义
- `OpenAIFunction` 类：函数定义

**`openai_chat_response.dart`**
- `OpenAIChatResponse` 类：聊天完成响应
- `OpenAIChatChoice` 类：选择项
- `OpenAIUsage` 类：Token 使用统计

**`openai_stream_response.dart`**
- `OpenAIStreamResponse` 类：流式响应
- `OpenAIStreamChoice` 类：流式选择项
- `OpenAIStreamDelta` 类：增量数据

---

### 步骤 2：创建 HTTP 客户端

**目标**：封装 Dio，提供类型安全的 OpenAI API 调用

#### 2.1 文件路径
`lib/services/openai_http_client.dart`

#### 2.2 核心类设计

**`OpenAIHttpException` 类**
```dart
class OpenAIHttpException implements Exception {
  final int? statusCode;
  final String message;
  final Map<String, dynamic>? errorData;
}
```

**`OpenAIHttpClient` 类**

**字段**：
- `Dio _dio`
- `String? _apiKey`
- `String? _baseUrl`
- `Duration _timeout`

**方法**：
```dart
// 配置方法
void configure({required String apiKey, String? baseUrl, Duration? timeout})

// 聊天完成（非流式）
Future<OpenAIChatResponse> createChatCompletion({
  required String model,
  required List<OpenAIChatMessage> messages,
  List<OpenAITool>? tools,
  double? temperature,
  int? maxTokens,
})

// 聊天完成（流式）
Stream<OpenAIStreamResponse> createChatCompletionStream({...})

// 内部方法
String _getApiUrl(String endpoint)  // 拼接完整 URL
OpenAIHttpException _handleErrorResponse(Response response)
OpenAIHttpException _handleDioException(DioException e)
```

**关键逻辑**：
```dart
String _getApiUrl(String endpoint) {
  final base = _baseUrl ?? 'https://api.openai.com';
  final cleanBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
  return '$cleanBase$cleanEndpoint';
}
```

**请求拦截器**：
- 自动添加 `Authorization: Bearer {apiKey}` 头
- 自动添加 `Content-Type: application/json` 头
- 打印请求日志

**错误处理**：
- 按状态码分类：401（认证）、429（限流）、404（不存在）
- 网络异常分类：超时、连接失败、取消
- 统一转换为 `OpenAIHttpException`

---

### 步骤 3：重写 AIService

**目标**：使用新的 HTTP 客户端替代 `dart_openai` SDK

#### 3.1 文件路径
`lib/services/ai_service.dart`

#### 3.2 修改内容

**导入替换**：
```dart
// 移除
import 'package:dart_openai/dart_openai.dart';

// 新增
import '../data/models/openai/openai_models.dart';
import 'openai_http_client.dart';
```

**字段修改**：
```dart
class AIService {
  final AIConfigRepository _configRepo;
  final OpenAIHttpClient _httpClient;  // 新增

  AIService(this._configRepo) : _httpClient = OpenAIHttpClient();
}
```

**方法签名变化**：

| 旧方法签名 | 新方法签名 | 说明 |
|-----------|-----------|------|
| `Future<OpenAIChatCompletionModel> chat(...)` | `Future<OpenAIChatResponse> chat(...)` | 返回类型变化 |
| `Stream<OpenAIStreamChatCompletionModel> chatStream(...)` | `Stream<OpenAIStreamResponse> chatStream(...)` | 返回类型变化 |
| `List<OpenAIChatCompletionChoiceMessageModel>` | `List<OpenAIChatMessage>` | 参数类型变化 |
| `List<OpenAIToolModel>` | `List<OpenAITool>` | 参数类型变化 |

**核心方法改造**：

1. **`testConnection()` 方法**
   - 使用 `_httpClient.createChatCompletion()` 替代 `OpenAI.instance.chat.create()`
   - 捕获 `OpenAIHttpException` 替代 `RequestFailedException`
   - 保持返回类型 `Future<(bool, String?)>` 不变

2. **`chat()` 方法**
   - 调用 `_setupHttpClient()` 配置客户端
   - 使用 `_httpClient.createChatCompletion()` 发送请求
   - 保持重试逻辑不变

3. **`chatStream()` 方法**
   - 使用 `_httpClient.createChatCompletionStream()` 返回流

4. **`_setupHttpClient()` 方法**（新增）
   ```dart
   void _setupHttpClient(AIConfigHive config) {
     _httpClient.configure(
       apiKey: config.apiKey,
       baseUrl: config.baseUrl,
       timeout: const Duration(seconds: 60),
     );
   }
   ```

5. **移除的方法**
   - `_setupOpenAI()` - 不再需要
   - `textMessage()` - 移到 `OpenAIChatMessage.text()`
   - `toolCallMessage()` - SDK 专用
   - `toolResponseMessage()` - 移到 `OpenAIChatMessage.toolResponse()`

---

### 步骤 4：更新工具定义

**目标**：替换 SDK 工具类型

#### 4.1 文件路径
`lib/services/ai_tool_definitions.dart`

#### 4.2 修改内容

**导入替换**：
```dart
// 移除
import 'package:dart_openai/dart_openai.dart';

// 新增
import '../data/models/openai/openai_models.dart';
```

**类型替换**：
| 旧类型 | 新类型 |
|-------|-------|
| `OpenAIToolModel` | `OpenAITool` |
| `OpenAIFunctionModel` | `OpenAIFunction` |

**示例**：
```dart
static OpenAITool get createTask => OpenAITool(
  type: 'function',
  function: OpenAIFunction(
    name: 'create_task',
    description: '创建新任务',
    parametersSchema: {...},  // 保持不变
  ),
);
```

**说明**：只需全局替换类型名，工具定义的结构完全不变。

---

### 步骤 5：更新 AIProvider

**目标**：适配新的数据类型

#### 5.1 文件路径
`lib/presentation/providers/ai_provider.dart`

#### 5.2 修改内容

**导入替换**：
```dart
// 移除
import 'package:dart_openai/dart_openai.dart';

// 新增
import '../../data/models/openai/openai_models.dart';
```

**类型替换表**：

| 位置 | 旧类型 | 新类型 |
|-----|-------|-------|
| `_handleAIResponse` 参数 | `OpenAIChatCompletionModel` | `OpenAIChatResponse` |
| `_handleToolCalls` 参数 | `List<OpenAIResponseToolCall>` | `List<OpenAIToolCall>` |
| `_convertMessagesToAPIFormat` 返回 | `List<OpenAIChatCompletionChoiceMessageModel>` | `List<OpenAIChatMessage>` |
| `_getFinalResponse` 参数 | `List<OpenAIResponseToolCall>` | `List<OpenAIToolCall>` |

**消息创建方式变化**：

```dart
// 旧方式
AIService.textMessage(
  content: msg.content,
  role: OpenAIChatMessageRole.user,
)

// 新方式
OpenAIChatMessage.text(
  role: OpenAIMessageRole.user,
  content: msg.content,
)
```

```dart
// 旧方式
AIService.toolResponseMessage(
  toolCallId: msg.toolCallId!,
  content: msg.content,
)

// 新方式
OpenAIChatMessage.toolResponse(
  toolCallId: msg.toolCallId!,
  content: msg.content,
)
```

**角色枚举变化**：
```dart
// 旧
OpenAIChatMessageRole.user
OpenAIChatMessageRole.assistant
OpenAIChatMessageRole.system
OpenAIChatMessageRole.tool

// 新
OpenAIMessageRole.user
OpenAIMessageRole.assistant
OpenAIMessageRole.system
OpenAIMessageRole.tool
```

---

### 步骤 6：移除 SDK 依赖

#### 6.1 修改 `pubspec.yaml`

**删除**：
```yaml
# AI相关
dart_openai: ^5.1.0  # 删除这一行
```

**保留**：
```yaml
# 网络请求
dio: ^5.7.0  # 已存在，无需添加
```

#### 6.2 清理依赖

```bash
flutter pub get
flutter clean
flutter pub get
```

---

### 步骤 7：测试验证

#### 7.1 功能测试清单

**基础连接测试**
- [ ] 配置 OpenAI API，测试连接成功
- [ ] 配置阿里百炼 API，测试连接成功
- [ ] 配置无效 API Key，显示正确错误提示
- [ ] 配置错误 BaseURL，显示正确错误提示

**聊天功能测试**
- [ ] 发送简单消息，收到正常回复
- [ ] 消息正确保存到历史
- [ ] 清除历史功能正常
- [ ] 新建对话功能正常

**工具调用测试**
- [ ] 创建任务指令触发工具调用
- [ ] 工具执行成功并返回结果
- [ ] AI 根据工具结果生成最终回复
- [ ] 工具调用记录正确显示

**错误处理测试**
- [ ] 网络断开时显示友好提示
- [ ] API 限流时自动重试
- [ ] 超时时显示超时提示

**特殊 API 测试**
- [ ] 阿里百炼配置：`https://dashscope.aliyuncs.com/compatible-mode/v1`
- [ ] 其他兼容 API 服务

---

## 📊 影响分析

### 修改文件清单

| 文件 | 修改类型 | 说明 |
|------|---------|------|
| `lib/data/models/openai/*.dart` | 🆕 新增 | 5 个模型文件 + 1 个导出文件 |
| `lib/services/openai_http_client.dart` | 🆕 新增 | HTTP 客户端 |
| `lib/services/ai_service.dart` | ♻️ 重写 | 完全重写，接口保持兼容 |
| `lib/services/ai_tool_definitions.dart` | 🔧 修改 | 仅类型替换 |
| `lib/presentation/providers/ai_provider.dart` | 🔧 修改 | 类型适配 |
| `pubspec.yaml` | 🔧 修改 | 移除依赖 |

### 不需要修改的文件

✅ `lib/services/ai_tool_executor.dart` - 不依赖 SDK  
✅ `lib/services/ai_context_builder.dart` - 不依赖 SDK  
✅ `lib/presentation/screens/*.dart` - 只依赖 Provider  
✅ `lib/presentation/widgets/*.dart` - 只依赖 Provider  

---

## ⚠️ 关键技术点

### 1. BaseURL 处理策略

**新实现逻辑**：
```
用户输入：https://dashscope.aliyuncs.com/compatible-mode/v1
系统追加：/v1/chat/completions
最终地址：https://dashscope.aliyuncs.com/compatible-mode/v1/v1/chat/completions
```

**解决方案**：
- 用户应输入：`https://dashscope.aliyuncs.com/compatible-mode`（不含 `/v1`）
- 系统自动追加：`/v1/chat/completions`
- 最终正确地址：`https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions`

**配置示例表**：

| 服务商 | 用户应输入 BaseURL | 最终请求地址 |
|--------|-------------------|-------------|
| OpenAI 官方 | `https://api.openai.com` | `https://api.openai.com/v1/chat/completions` |
| 阿里百炼 | `https://dashscope.aliyuncs.com/compatible-mode` | `https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions` |
| 自定义代理 | `https://my-proxy.com` | `https://my-proxy.com/v1/chat/completions` |

**UI 提示建议**：
```
BaseURL 配置说明：
• 填写基础域名即可（不要包含 /v1 或 /chat/completions）
• 系统会自动追加标准 OpenAI API 路径
• 例如：https://api.openai.com
• 阿里百炼：https://dashscope.aliyuncs.com/compatible-mode
```

### 2. 错误处理映射

**HTTP 状态码映射**：
```
401 → "API Key 无效或已过期"
429 → "请求频率超限，请稍后再试"（自动重试）
404 → "API地址不存在，请检查BaseURL"
500+ → "服务器错误，请稍后再试"
```

**网络异常映射**：
```
SocketException → "网络连接失败"
TimeoutException → "连接超时，请检查网络"
HandshakeException → "SSL证书验证失败"
FormatException → "服务器返回了非JSON内容"
```

### 3. 流式响应处理

**SSE 格式解析**：
```
data: {"id":"...","object":"chat.completion.chunk",...}
data: {"id":"...","object":"chat.completion.chunk",...}
data: [DONE]
```

**实现要点**：
- 使用 `ResponseType.stream` 获取字节流
- 使用 `utf8.decoder` 解码
- 按行分割，过滤 `data:` 前缀
- 检测 `[DONE]` 结束标志
- 每个 JSON 解析为 `OpenAIStreamResponse`

### 4. 工具调用流程

**完整流程**：
```
1. 用户发送消息
2. AI 返回工具调用（finishReason: 'tool_calls'）
3. Provider 执行工具，保存结果
4. 将工具结果发送回 AI
5. AI 返回最终回复（finishReason: 'stop'）
```

**消息格式示例**：
```dart
// 工具调用消息
{
  "role": "assistant",
  "tool_calls": [
    {
      "id": "call_abc123",
      "type": "function",
      "function": {
        "name": "create_task",
        "arguments": "{\"title\":\"写周报\"}"
      }
    }
  ]
}

// 工具响应消息
{
  "role": "tool",
  "tool_call_id": "call_abc123",
  "content": "{\"success\":true,\"taskId\":\"xxx\"}"
}
```

---

## ✅ 验收标准

1. ✅ 所有现有功能正常工作（聊天、工具调用、历史管理）
2. ✅ 支持标准 OpenAI API
3. ✅ 支持阿里百炼等自定义 BaseURL 的 API
4. ✅ 错误提示友好清晰
5. ✅ 代码结构清晰，易于维护
6. ✅ 无 linter 错误

---

## 📅 预计时间

- **步骤 1-2**：创建模型和客户端 - 2 小时
- **步骤 3-5**：重写服务和适配 - 2 小时
- **步骤 6-7**：清理和测试 - 1 小时
- **总计**：约 5 小时

---

## 🔄 回滚方案

如果新实现有问题，可以快速回滚：

1. 恢复 `pubspec.yaml` 中的 `dart_openai: ^5.1.0`
2. 从 Git 恢复被修改的文件
3. 删除新增的 `lib/data/models/openai/` 目录
4. 删除 `lib/services/openai_http_client.dart`
5. 运行 `flutter pub get`

---

**方案制定完成！准备开始执行时请告知。**

