# AI工具顺序执行说明实施文档

## 📋 实施目标
在系统提示词中明确告知AI，当需要调用多个工具时，这些工具会按照调用顺序逐个执行，而非并发执行。这样AI可以更好地规划工具调用顺序，确保有依赖关系的操作能正确执行。

## 📍 影响范围
- **文件**：`snowview/lib/services/ai_context_builder.dart`
- **影响模式**：行动模式（思考模式不调用工具，无需说明）

---

## 🔧 实施步骤

### 步骤1：在系统提示词中添加工具执行机制说明

**位置**：`ai_context_builder.dart` 的 `build()` 方法

**修改内容**：

在现有的系统提示词中，在 `## 核心能力` 部分之后、`## 行为准则` 部分之前，添加新章节：

```dart
String build({String mode = 'action'}) {
  // ... 现有代码 ...
  
  return '''
# 雪象AI助手

## 当前模式：${_getModeName(mode)}

## 角色定义
// ... 现有内容 ...

## 核心能力
// ... 现有内容 ...

## 工具执行机制
当你需要调用多个工具时，请注意：
- **顺序执行**：所有工具调用会按照你返回的顺序逐个执行，而非并发执行
- **依赖规划**：如果后续操作依赖前一个操作的结果，请合理安排调用顺序
- **批量操作**：你可以在一次回复中调用多个工具（如：创建多个任务、修改多个日程等）
- **执行示例**：
  - ✅ 正确：先 create_task 创建任务，再 add_subtask 为该任务添加子步骤
  - ❌ 错误：先 add_subtask（此时任务还未创建，会失败）
  - ✅ 正确：批量创建3个任务，按顺序调用3次 create_task
  - ✅ 正确：批量修改2个活动，按顺序调用2次 update_calendar_event

## 行为准则
// ... 现有内容 ...
''';
}
```

---

### 步骤2：在行动模式规则中强化说明

**位置**：`ai_context_builder.dart` 的 `_getActionModeRules()` 方法

**修改内容**：

在现有的第6点"支持多步操作"中，增加对顺序执行的说明：

```dart
String _getActionModeRules() {
  return '''
**⚡ 行动模式规则**：
// ... 1-5点保持不变 ...

6. **支持多步操作**：
   - 当用户的需求需要多个步骤时，主动连续调用多个工具完成整个流程
   - 不要在中途停下来询问用户
   - **重要**：工具调用会按顺序执行，请合理规划调用顺序
   - 示例：创建任务后再为任务添加子步骤，先查询空闲时间再创建日程

7. **批量操作支持**：
   - 当用户要求批量操作（如"创建5个学习任务"、"修改所有未完成的任务"）时
   - 可以在一次回复中调用多个相同类型的工具
   - 所有工具会按你返回的顺序依次执行
   - 示例：用户说"帮我创建3个任务"，你可以连续调用3次 create_task

// ... 原来的7-9点变成8-10点 ...
''';
}
```

---

### 步骤3：添加工具调用日志优化（可选）

**位置**：`snowview/lib/presentation/providers/ai_provider.dart` 的 `_handleToolCalls()` 方法

**目的**：在控制台输出更友好的工具执行日志，方便开发调试

**修改内容**：

在现有的 `_handleToolCalls()` 方法开头添加：

```dart
Future<void> _handleToolCalls(List<OpenAIToolCall> toolCalls) async {
  print('[AI Provider] 开始处理工具调用，数量: ${toolCalls.length}');
  
  // 添加：打印所有即将执行的工具
  if (toolCalls.length > 1) {
    print('[AI Provider] 📋 执行计划（顺序执行）：');
    for (int i = 0; i < toolCalls.length; i++) {
      print('[AI Provider]   ${i + 1}. ${toolCalls[i].function.name}');
    }
  }
  
  // ... 现有代码继续 ...
}
```

在工具执行循环中，为每个工具添加序号标识：

```dart
// 2. 执行所有工具调用
final toolResults = <Map<String, dynamic>>[];
for (int i = 0; i < toolCalls.length; i++) {
  final toolCall = toolCalls[i];
  
  // 添加：显示当前执行进度
  if (toolCalls.length > 1) {
    print('[AI Provider] ▶️ 执行 ${i + 1}/${toolCalls.length}: ${toolCall.function.name}');
  }
  
  try {
    // ... 现有的执行逻辑 ...
  }
}
```

---

### 步骤4：UI显示优化（可选）

**位置**：`snowview/lib/presentation/widgets/common/ai_tool_call_widget.dart`

**目的**：当AI调用多个工具时，在UI上显示执行序号

**修改内容**：

如果当前没有显示工具调用序号，可以添加：

```dart
// 在工具调用显示组件中
Widget _buildToolCallItem(ToolCall toolCall, int index, int total) {
  return ListTile(
    leading: total > 1 
      ? CircleAvatar(
          radius: 12,
          child: Text('${index + 1}', style: TextStyle(fontSize: 10)),
        )
      : Icon(Icons.build),
    title: Text(_getToolDisplayName(toolCall.name)),
    // ... 其他属性 ...
  );
}
```

---

## ✅ 验证测试

### 测试场景1：依赖关系操作
**用户输入**：`帮我创建一个任务"学习Flutter"，然后为它添加3个子步骤`

**预期行为**：
1. AI先调用 `create_task`
2. 再依次调用3次 `add_subtask`
3. 控制台显示顺序执行日志

### 测试场景2：批量操作
**用户输入**：`创建3个学习任务：Python、JavaScript、Go`

**预期行为**：
1. AI连续调用3次 `create_task`
2. 控制台显示执行计划和进度
3. 所有任务按顺序创建成功

### 测试场景3：复合操作
**用户输入**：`帮我规划明天的学习：上午学Python 2小时，下午学AI 2小时，并创建对应的任务`

**预期行为**：
1. AI先查询明天的空闲时间（`find_free_time`）
2. 创建上午的日程（`create_calendar_event`）
3. 创建下午的日程（`create_calendar_event`）
4. 创建Python学习任务（`create_task`）
5. 创建AI学习任务（`create_task`）

---

## 📝 实施注意事项

1. **文案措辞**：
   - 使用"顺序执行"而非"串行执行"，更易理解
   - 提供具体示例，避免AI理解错误

2. **向后兼容**：
   - 现有的单工具调用不受影响
   - 现有的多工具调用行为保持不变（已经是顺序执行）

3. **性能说明**：
   - 在文档中说明为何选择顺序执行（简单可靠、操作量小）
   - 避免用户误以为系统性能不足

4. **AI模型差异**：
   - 不同的AI模型对系统提示词的理解能力不同
   - 建议在实际使用中观察AI是否按预期规划工具顺序
   - 必要时可以调整提示词的表述方式

---

## 🎯 预期效果

实施后，AI将：
1. **更好地规划工具调用顺序**：理解依赖关系，避免调用顺序错误
2. **更自信地批量操作**：知道可以一次返回多个工具调用
3. **提供更清晰的反馈**：用户能看到多步操作的执行顺序

---

## 📚 相关文档

实施完成后，建议更新以下文档：
- `docs/AI功能对接实施方案.md` - 添加工具执行机制说明
- `docs/AI双模式功能实施方案.md` - 在行动模式中补充说明
- 项目README - 在特性说明中提及支持批量操作

---

## 🔄 未来优化方向

如果未来需要支持并发执行，可以：
1. 在AI工具定义中添加 `parallel: true/false` 标记
2. AI在返回工具调用时，使用特殊格式标记哪些可并发
3. 在 `_handleToolCalls()` 中解析并发标记，分批执行

但当前阶段，顺序执行已经完全满足需求。

---

## 📊 技术背景说明

### 为什么选择顺序执行？

1. **操作量小**：
   - 用户一次操作最多涉及几十个工具调用
   - 每个工具执行时间通常在几十毫秒内
   - 总耗时完全可接受

2. **简单可靠**：
   - 避免并发写入数据库的冲突问题
   - 代码逻辑清晰，易于调试和维护
   - 错误处理更简单直观

3. **依赖关系明确**：
   - 很多操作存在先后依赖（如先创建任务，再添加子任务）
   - 顺序执行天然保证依赖关系正确
   - 无需复杂的依赖分析逻辑

4. **用户体验一致**：
   - 用户看到的执行顺序与AI规划的顺序一致
   - 便于理解和追踪操作进度

### 当前实现方式

在 `ai_provider.dart` 的 `_handleToolCalls()` 方法中：

```dart
// 使用 for 循环顺序执行
for (final toolCall in toolCalls) {
  try {
    final result = await _toolExecutor.execute(
      toolName: toolCall.function.name,
      arguments: arguments,
    );
    // 保存结果...
  } catch (e) {
    // 错误处理...
  }
}
```

这种方式：
- ✅ 实现简单，代码可读性高
- ✅ 错误隔离，某个工具失败不影响其他工具
- ✅ 结果顺序与调用顺序一致
- ✅ 无需考虑并发控制和锁机制

---

**实施优先级**：高  
**预估工作量**：30分钟  
**风险评估**：低（仅修改提示词和日志输出，不改变核心逻辑）  
**文档版本**：v1.0  
**创建日期**：2025-10-22

