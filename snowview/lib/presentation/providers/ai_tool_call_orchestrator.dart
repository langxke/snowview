import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../data/models/openai/openai_models.dart';
import '../../data/models/chat_message_hive.dart';
import '../../services/ai_service.dart';
import '../../services/ai_tool_definitions.dart';
import '../../services/ai_context_builder.dart';
import '../../services/ai_tool_registry.dart';

/// 工具调用编排器
/// 
/// 职责：
/// - 管理工具调用的完整流程（解析、执行、递归）
/// - 控制递归深度，防止无限循环
/// - 获取AI的最终回复
/// - 处理工具调用相关的错误
class AIToolCallOrchestrator {
  final AIService _aiService;
  final AIContextBuilder _contextBuilder;
  final String Function() _getCurrentMode;
  
  // 递归控制
  int _recursiveDepth = 0;
  static const int _maxRecursiveDepth = 30;  // 提高限制，支持更复杂的操作链
  
  // 停止标志（外部可以设置）
  bool shouldStop = false;
  
  AIToolCallOrchestrator({
    required AIService aiService,
    required AIContextBuilder contextBuilder,
    required String Function() getCurrentMode,
  })  : _aiService = aiService,
        _contextBuilder = contextBuilder,
        _getCurrentMode = getCurrentMode;
  
  /// 处理工具调用的完整流程
  /// 
  /// 参数：
  /// - toolCalls: 要执行的工具调用列表
  /// - sessionId: 会话ID
  /// - conversationHistory: 对话历史（用于获取最终回复）
  /// - onMessageGenerated: 生成新消息时的回调
  /// 
  /// 返回值：
  /// - ToolCallResult: 包含执行结果和最终消息
  Future<ToolCallResult> handleToolCalls({
    required List<OpenAIToolCall> toolCalls,
    required String sessionId,
    required List<ChatMessageHive> conversationHistory,
    required Future<void> Function(ChatMessageHive) onMessageGenerated,
  }) async {
    if (shouldStop) {
      print('[Tool Orchestrator] 🛑 已停止，跳过工具调用');
      return ToolCallResult.stopped();
    }
    
    _recursiveDepth++;
    print('[Tool Orchestrator] 🔄 递归深度: $_recursiveDepth/$_maxRecursiveDepth');
    
    // 检查递归深度
    if (_recursiveDepth > _maxRecursiveDepth) {
      print('[Tool Orchestrator] ❌ 超过最大递归深度($_maxRecursiveDepth)');
      // ✅ 不重置计数器，让 finally 块自然递减，避免计数错乱
      return ToolCallResult.error(
        '⚠️ 检测到可能的无限循环，已自动停止执行。\n\n已完成的操作仍然有效。如需继续，请重新描述您的需求。',
      );
    }
    
    try {
      // 1. 生成并保存执行计划消息
      final planMessage = _createExecutionPlanMessage(toolCalls, sessionId);
      await onMessageGenerated(planMessage);
      
      // 2. 执行所有工具
      await _executeAllTools(
        toolCalls,
        sessionId,
        onMessageGenerated,
      );
      
      if (shouldStop) {
        print('[Tool Orchestrator] 🛑 执行过程中被停止');
        return ToolCallResult.stopped();
      }
      
      // 3. 获取AI的最终回复
      final finalResponse = await _getFinalResponse(
        conversationHistory: conversationHistory,
        sessionId: sessionId,
      );
      
      // 4. 检查是否有新的工具调用（递归）
      if (finalResponse.hasToolCalls) {
        print('[Tool Orchestrator] 🔄 AI 又请求了 ${finalResponse.toolCalls!.length} 个工具调用');
        return await handleToolCalls(
          toolCalls: finalResponse.toolCalls!,
          sessionId: sessionId,
          conversationHistory: conversationHistory,
          onMessageGenerated: onMessageGenerated,
        );
      }
      
      // 5. 返回最终结果
      return ToolCallResult.success(
        message: finalResponse.message!,
        executedToolsCount: toolCalls.length,
      );
      
    } catch (e, stackTrace) {
      print('[Tool Orchestrator] ❌ 错误: $e');
      print('[Tool Orchestrator] 堆栈: $stackTrace');
      
      // 根据错误类型生成友好提示
      String errorMessage;
      if (e.toString().contains('HandshakeException') || 
          e.toString().contains('Connection')) {
        errorMessage = '✅ 操作已执行\n\n（由于网络不稳定，无法生成详细总结）';
      } else {
        errorMessage = '操作已执行，但生成总结时出错：${e.toString()}';
      }
      
      return ToolCallResult.error(errorMessage);
      
    } finally {
      _recursiveDepth--;
      print('[Tool Orchestrator] 🔄 递归深度回退: $_recursiveDepth');
    }
  }
  
  /// 执行所有工具（顺序执行）
  Future<List<ToolExecutionResult>> _executeAllTools(
    List<OpenAIToolCall> toolCalls,
    String sessionId,
    Future<void> Function(ChatMessageHive) onMessageGenerated,
  ) async {
    final results = <ToolExecutionResult>[];
    
    // 打印执行计划
    if (toolCalls.length > 1) {
      print('[Tool Orchestrator] 📋 执行计划（顺序执行）：');
      for (int i = 0; i < toolCalls.length; i++) {
        print('[Tool Orchestrator]   ${i + 1}. ${toolCalls[i].function.name}');
      }
    }
    
    for (int i = 0; i < toolCalls.length; i++) {
      if (shouldStop) {
        print('[Tool Orchestrator] 🛑 执行过程中被停止（已完成$i/${toolCalls.length}）');
        break;
      }
      
      final toolCall = toolCalls[i];
      
      // 执行工具
      final result = await _executeSingleTool(toolCall);
      results.add(result);
      
      // 生成工具结果消息
      final toolMessage = ChatMessageHive.tool(
        id: const Uuid().v4(),
        content: jsonEncode(result.toJson()),
        toolCallId: toolCall.id,
        sessionId: sessionId,
      );
      await onMessageGenerated(toolMessage);
      
      if (toolCalls.length > 1) {
        print('[Tool Orchestrator] ✅ [${i + 1}/${toolCalls.length}] ${toolCall.function.name}');
      }
    }
    
    // 打印执行总结
    if (toolCalls.length > 1) {
      // 统计业务成功/失败，而不是调用成功/失败
      final businessSuccessCount = results.where((r) => 
        r.result != null && r.result!['success'] == true
      ).length;
      final businessFailureCount = results.where((r) => 
        r.result != null && r.result!['success'] == false
      ).length;
      final exceptionCount = results.where((r) => !r.success).length;
      
      print('[Tool Orchestrator] 📊 执行总结：业务成功 $businessSuccessCount 个，业务失败 $businessFailureCount 个，调用异常 $exceptionCount 个');
    }
    
    return results;
  }
  
  /// 执行单个工具
  Future<ToolExecutionResult> _executeSingleTool(OpenAIToolCall toolCall) async {
    try {
      final arguments = _parseToolArguments(toolCall.function.arguments);
      
      print('[Tool Orchestrator] 🔧 执行: ${toolCall.function.name}');
      print('[Tool Orchestrator] 📝 参数: $arguments');
      
      // ✅ 直接使用注册表执行，无需通过 executor
      final result = await AIToolRegistry.execute(
        toolCall.function.name,
        arguments,
      );
      
      // 检查业务结果
      final businessSuccess = result['success'] == true;
      final icon = businessSuccess ? '✅' : '⚠️';
      print('[Tool Orchestrator] $icon 执行结果: ${toolCall.function.name}');
      print('[Tool Orchestrator] 📊 返回数据: $result');
      
      if (!businessSuccess && result['error'] != null) {
        print('[Tool Orchestrator] ⚠️ 业务失败原因: ${result['error']}');
      }
      
      // 特殊处理：查询事件时显示详细信息
      if (toolCall.function.name == 'query_events' && businessSuccess) {
        final events = result['events'] as List?;
        if (events != null && events.isNotEmpty) {
          print('[Tool Orchestrator] 📋 查询到 ${events.length} 个事件：');
          for (var event in events) {
            print('[Tool Orchestrator]    - [${event['id']}] ${event['title']}');
          }
        }
      }
      
      return ToolExecutionResult.success(
        toolCallId: toolCall.id,
        toolName: toolCall.function.name,
        result: result,
      );
      
    } catch (e) {
      print('[Tool Orchestrator] ❌ 工具执行失败: ${toolCall.function.name}');
      print('[Tool Orchestrator] ❌ 错误: $e');
      
      return ToolExecutionResult.failure(
        toolCallId: toolCall.id,
        toolName: toolCall.function.name,
        error: e.toString(),
      );
    }
  }
  
  /// 获取AI的最终回复
  Future<FinalResponseResult> _getFinalResponse({
    required List<ChatMessageHive> conversationHistory,
    required String sessionId,
  }) async {
    if (shouldStop) {
      return FinalResponseResult.stopped();
    }
    
    print('[Tool Orchestrator] 📤 开始获取最终回复...');
    
    // ✅ 连接池会自动管理连接复用，无需手动延迟
    // 之前的硬编码延迟已由底层 HTTP 客户端的连接池机制优雅替代
    
    if (shouldStop) {
      return FinalResponseResult.stopped();
    }
    
    // 最多重试2次
    const maxRetries = 2;
    
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      if (shouldStop) {
        return FinalResponseResult.stopped();
      }
      
      try {
        if (attempt > 0) {
          print('[Tool Orchestrator] 重试获取最终回复 (${attempt + 1}/$maxRetries)');
          await Future.delayed(Duration(seconds: (attempt + 1) * 2));
          
          if (shouldStop) {
            return FinalResponseResult.stopped();
          }
        }
        
        // 转换消息历史为API格式
        final systemContext = _contextBuilder.build(mode: _getCurrentMode());
        final apiMessages = _convertMessagesToAPIFormat(conversationHistory);
        
        print('[Tool Orchestrator] 📤 发送最终回复请求');
        print('[Tool Orchestrator] 消息数量: ${apiMessages.length}');
        
        // 调用AI
        final response = await _aiService.chat(
          messages: apiMessages,
          systemPrompt: systemContext,
          tools: _getCurrentMode() == 'action' 
              ? AIToolDefinitions.allTools      // 行动模式：所有工具
              : AIToolDefinitions.queryTools,   // 思考模式：只有查询类工具
        );
        
        print('[Tool Orchestrator] ✅ 收到最终回复');
        
        final responseMessage = response.choices.first.message;
        
        // 检查是否有新的工具调用
        if (responseMessage.toolCalls != null && responseMessage.toolCalls!.isNotEmpty) {
          print('[Tool Orchestrator] ⚠️ AI 又请求了工具调用，数量: ${responseMessage.toolCalls!.length}');
          return FinalResponseResult.hasMoreToolCalls(responseMessage.toolCalls!);
        }
        
        // 提取文本内容
        final content = responseMessage.content
                ?.map((c) => c.text ?? '')
                .join('') ?? '操作已完成';
        
        final finalMessage = ChatMessageHive.assistant(
          id: const Uuid().v4(),
          content: content,
          sessionId: sessionId,
        );
        
        print('[Tool Orchestrator] ✅ 最终回复处理完成');
        
        return FinalResponseResult.completed(finalMessage);
        
      } catch (e) {
        print('[Tool Orchestrator] 获取最终回复失败 (尝试 ${attempt + 1}/$maxRetries): $e');
        
        // 如果不是最后一次尝试，继续重试
        if (attempt < maxRetries - 1) {
          continue;
        }
        
        // 所有重试都失败，返回错误
        throw e;
      }
    }
    
    // 理论上不会到达这里
    throw Exception('获取最终回复失败：所有重试次数已用尽');
  }
  
  /// 创建执行计划消息
  ChatMessageHive _createExecutionPlanMessage(
    List<OpenAIToolCall> toolCalls,
    String sessionId,
  ) {
    final planSummary = _generateExecutionPlan(toolCalls);
    
    final toolCallsJson = toolCalls.map((tc) {
      return jsonEncode({
        'id': tc.id,
        'type': tc.type,
        'function': {
          'name': tc.function.name,
          'arguments': _parseToolArguments(tc.function.arguments),
        },
      });
    }).toList();
    
    return ChatMessageHive.assistant(
      id: const Uuid().v4(),
      content: planSummary,
      toolCalls: toolCallsJson,
      sessionId: sessionId,
    );
  }
  
  /// 生成执行计划摘要
  String _generateExecutionPlan(List<OpenAIToolCall> toolCalls) {
    if (toolCalls.isEmpty) return '正在执行操作...';
    
    final buffer = StringBuffer();
    buffer.writeln('📋 **执行计划**（共 ${toolCalls.length} 项操作）\n');
    
    // 统计工具类型
    final toolStats = <String, int>{};
    for (final tc in toolCalls) {
      toolStats[tc.function.name] = (toolStats[tc.function.name] ?? 0) + 1;
    }
    
    // 工具名称映射
    const toolNameMap = {
      'create_task': '创建任务',
      'update_task': '更新任务',
      'delete_task': '删除任务',
      'complete_task': '完成任务',
      'add_subtask': '添加子步骤',
      'create_calendar_event': '创建日程',
      'update_calendar_event': '更新日程',
      'delete_calendar_event': '删除日程',
      'create_journal_entry': '创建记录',
      'start_focus_session': '启动专注',
      'query_tasks': '查询任务',
      'query_events': '查询日程',
      'query_journals': '查询记录',
      'find_free_time': '查询空闲时间',
      'get_focus_stats': '查询专注统计',
    };
    
    toolStats.forEach((name, count) {
      final displayName = toolNameMap[name] ?? name;
      buffer.writeln('• $displayName × $count');
    });
    
    // 如果操作数量不多，显示详细信息
    if (toolCalls.length <= 10) {
      buffer.writeln('\n**操作详情**:');
      for (int i = 0; i < toolCalls.length && i < 10; i++) {
        final tc = toolCalls[i];
        final toolName = toolNameMap[tc.function.name] ?? tc.function.name;
        buffer.writeln('${i + 1}. $toolName');
      }
    }
    
    buffer.writeln('\n⏳ 正在执行中...');
    
    return buffer.toString();
  }
  
  /// 解析工具参数
  Map<String, dynamic> _parseToolArguments(dynamic rawArgs) {
    // 处理空值
    if (rawArgs == null) return {};
    
    // 最常见情况：JSON字符串
    if (rawArgs is String) {
      final trimmed = rawArgs.trim();
      if (trimmed.isEmpty) return {};
      
      try {
        // 处理多个JSON对象粘连的情况（API偶尔会返回这种格式）
        String jsonToParse = trimmed;
        if (trimmed.contains('}{')) {
          // 只取第一个完整的JSON对象
          final firstEnd = trimmed.indexOf('}{') + 1;
          jsonToParse = trimmed.substring(0, firstEnd);
          print('[Tool Orchestrator] ⚠️ 检测到粘连JSON，只使用第一个对象');
        }
        
        final decoded = jsonDecode(jsonToParse);
        return decoded is Map<String, dynamic> 
            ? decoded 
            : Map<String, dynamic>.from(decoded as Map);
      } catch (e) {
        print('[Tool Orchestrator] ⚠️ JSON解析失败: ${e.runtimeType}');
        print('[Tool Orchestrator] 原始数据: $rawArgs');
        return {};
      }
    }
    
    // 已经是Map的情况
    if (rawArgs is Map<String, dynamic>) return rawArgs;
    if (rawArgs is Map) return Map<String, dynamic>.from(rawArgs);
    
    // 其他类型（理论上不应该出现）
    print('[Tool Orchestrator] ⚠️ 未知参数类型: ${rawArgs.runtimeType}');
    return {};
  }
  
  /// 转换消息为API格式
  List<OpenAIChatMessage> _convertMessagesToAPIFormat(
    List<ChatMessageHive> messages,
  ) {
    final apiMessages = <OpenAIChatMessage>[];
    
    for (final msg in messages) {
      switch (msg.role) {
        case 'user':
          apiMessages.add(OpenAIChatMessage.text(
            role: OpenAIMessageRole.user,
            content: msg.content,
          ));
          break;
        case 'assistant':
          // 助手消息
          if (msg.toolCalls != null && msg.toolCalls!.isNotEmpty) {
            // 包含工具调用的消息
            try {
              final toolCalls = <OpenAIToolCall>[];
              
              for (int i = 0; i < msg.toolCalls!.length; i++) {
                try {
                  final tcJson = msg.toolCalls![i];
                  final tc = jsonDecode(tcJson) as Map<String, dynamic>;
                  
                  // 处理 arguments
                  final dynamic rawArgs = tc['function']?['arguments'];
                  String argumentsStr;
                  if (rawArgs is String) {
                    argumentsStr = rawArgs;
                  } else if (rawArgs is Map) {
                    argumentsStr = jsonEncode(rawArgs);
                  } else {
                    argumentsStr = '{}';
                  }
                  
                  toolCalls.add(OpenAIToolCall(
                    id: tc['id'] as String? ?? '',
                    type: tc['type'] as String? ?? 'function',
                    function: OpenAIFunctionCall(
                      name: tc['function']?['name'] as String? ?? '',
                      arguments: argumentsStr,
                    ),
                  ));
                } catch (e) {
                  print('[Tool Orchestrator] ⚠️ 跳过无效的 tool_call[$i]: $e');
                  continue;
                }
              }
              
              if (toolCalls.isNotEmpty) {
                apiMessages.add(OpenAIChatMessage(
                  role: OpenAIMessageRole.assistant,
                  content: msg.content.isNotEmpty 
                      ? [OpenAIMessageContent.text(msg.content)]
                      : null,
                  toolCalls: toolCalls,
                ));
              } else {
                apiMessages.add(OpenAIChatMessage.text(
                  role: OpenAIMessageRole.assistant,
                  content: msg.content.isNotEmpty ? msg.content : '操作已完成',
                ));
              }
            } catch (e) {
              print('[Tool Orchestrator] ❌ 解析 tool_calls 失败: $e');
              apiMessages.add(OpenAIChatMessage.text(
                role: OpenAIMessageRole.assistant,
                content: msg.content.isNotEmpty ? msg.content : '操作已完成',
              ));
            }
          } else {
            // 普通助手消息
            apiMessages.add(OpenAIChatMessage.text(
              role: OpenAIMessageRole.assistant,
              content: msg.content.isNotEmpty ? msg.content : '...',
            ));
          }
          break;
        case 'tool':
          // 工具执行结果
          if (msg.toolCallId != null && msg.toolCallId!.isNotEmpty) {
            try {
              apiMessages.add(OpenAIChatMessage.toolResponse(
                toolCallId: msg.toolCallId!,
                content: msg.content,
              ));
            } catch (e) {
              print('[Tool Orchestrator] ⚠️ 跳过无效的 tool 消息: $e');
            }
          }
          break;
        case 'system':
          // 系统消息（如对话摘要）- 不发送到API
          break;
      }
    }

    // 清理孤立的消息
    return _cleanOrphanedMessages(apiMessages);
  }
  
  /// 清理孤立的 tool 消息和没有对应 tool 响应的 assistant+tool_calls 消息
  List<OpenAIChatMessage> _cleanOrphanedMessages(List<OpenAIChatMessage> messages) {
    // 第一步：清理孤立的 tool 消息
    final stepOneMessages = <OpenAIChatMessage>[];
    
    for (var i = 0; i < messages.length; i++) {
      final msg = messages[i];
      final role = msg.role.name;
      
      if (role == 'tool') {
        // 向前查找最近的 assistant 消息
        bool hasValidPreceding = false;
        for (var j = stepOneMessages.length - 1; j >= 0; j--) {
          if (stepOneMessages[j].role == OpenAIMessageRole.assistant) {
            if (stepOneMessages[j].toolCalls != null && 
                stepOneMessages[j].toolCalls!.isNotEmpty) {
              hasValidPreceding = true;
            }
            break;
          }
        }
        
        if (!hasValidPreceding) {
          continue; // 跳过这条消息
        }
      }
      
      stepOneMessages.add(msg);
    }
    
    // 第二步：清理没有对应 tool 响应的 assistant+tool_calls 消息
    final cleanedMessages = <OpenAIChatMessage>[];
    
    for (var i = 0; i < stepOneMessages.length; i++) {
      final msg = stepOneMessages[i];
      final role = msg.role.name;
      
      if (role == 'assistant' && msg.toolCalls != null && msg.toolCalls!.isNotEmpty) {
        // 向后查找是否有对应的 tool 消息
        bool hasFollowingTool = false;
        for (var j = i + 1; j < stepOneMessages.length; j++) {
          if (stepOneMessages[j].role == OpenAIMessageRole.tool) {
            hasFollowingTool = true;
            break;
          }
          if (stepOneMessages[j].role == OpenAIMessageRole.user || 
              stepOneMessages[j].role == OpenAIMessageRole.assistant) {
            break;
          }
        }
        
        if (!hasFollowingTool) {
          continue; // 跳过这条消息
        }
      }
      
      cleanedMessages.add(msg);
    }
    
    return cleanedMessages;
  }
  
  /// 重置状态
  void reset() {
    _recursiveDepth = 0;
    shouldStop = false;
  }
}

/// ==================== 结果类定义 ====================

/// 工具调用处理的最终结果
class ToolCallResult {
  final ToolCallStatus status;
  final ChatMessageHive? message;
  final int executedToolsCount;
  final String? errorMessage;
  
  ToolCallResult._({
    required this.status,
    this.message,
    this.executedToolsCount = 0,
    this.errorMessage,
  });
  
  factory ToolCallResult.success({
    required ChatMessageHive message,
    required int executedToolsCount,
  }) {
    return ToolCallResult._(
      status: ToolCallStatus.success,
      message: message,
      executedToolsCount: executedToolsCount,
    );
  }
  
  factory ToolCallResult.stopped() {
    return ToolCallResult._(status: ToolCallStatus.stopped);
  }
  
  factory ToolCallResult.error(String errorMessage) {
    return ToolCallResult._(
      status: ToolCallStatus.error,
      errorMessage: errorMessage,
    );
  }
  
  bool get isSuccess => status == ToolCallStatus.success;
  bool get isStopped => status == ToolCallStatus.stopped;
  bool get isError => status == ToolCallStatus.error;
}

enum ToolCallStatus { success, stopped, error }

/// 单个工具执行的结果
class ToolExecutionResult {
  final String toolCallId;
  final String toolName;
  final bool success;
  final Map<String, dynamic>? result;
  final String? error;
  
  ToolExecutionResult._({
    required this.toolCallId,
    required this.toolName,
    required this.success,
    this.result,
    this.error,
  });
  
  factory ToolExecutionResult.success({
    required String toolCallId,
    required String toolName,
    required Map<String, dynamic> result,
  }) {
    return ToolExecutionResult._(
      toolCallId: toolCallId,
      toolName: toolName,
      success: true,
      result: result,
    );
  }
  
  factory ToolExecutionResult.failure({
    required String toolCallId,
    required String toolName,
    required String error,
  }) {
    return ToolExecutionResult._(
      toolCallId: toolCallId,
      toolName: toolName,
      success: false,
      error: error,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'success': success,
      if (result != null) ...result!,
      if (error != null) 'error': error,
    };
  }
}

/// 最终回复的结果
class FinalResponseResult {
  final FinalResponseStatus status;
  final ChatMessageHive? message;
  final List<OpenAIToolCall>? toolCalls;
  
  FinalResponseResult._({
    required this.status,
    this.message,
    this.toolCalls,
  });
  
  factory FinalResponseResult.completed(ChatMessageHive message) {
    return FinalResponseResult._(
      status: FinalResponseStatus.completed,
      message: message,
    );
  }
  
  factory FinalResponseResult.hasMoreToolCalls(List<OpenAIToolCall> toolCalls) {
    return FinalResponseResult._(
      status: FinalResponseStatus.hasMoreToolCalls,
      toolCalls: toolCalls,
    );
  }
  
  factory FinalResponseResult.stopped() {
    return FinalResponseResult._(status: FinalResponseStatus.stopped);
  }
  
  bool get hasToolCalls => status == FinalResponseStatus.hasMoreToolCalls;
}

enum FinalResponseStatus { completed, hasMoreToolCalls, stopped }

