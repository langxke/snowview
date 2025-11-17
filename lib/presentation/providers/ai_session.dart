import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/openai/openai_models.dart';
import '../../data/models/chat_message_hive.dart';
import '../../data/repositories/chat_history_repository.dart';
import '../../services/ai_service.dart';
import '../../services/ai_tool_definitions.dart';
import '../../services/ai_context_builder.dart';
import 'ai_tool_call_orchestrator.dart';

/// AI 会话
/// 
/// 职责：
/// - 管理单个会话的消息列表
/// - 处理流式生成
/// - 委托工具调用给编排器
/// - 维护会话状态（是否正在思考、错误信息等）
class AISession {
  final String sessionId;
  final AIService _aiService;
  final AIToolCallOrchestrator _toolOrchestrator;
  final AIContextBuilder _contextBuilder;
  final ChatHistoryRepository _historyRepo;
  final String Function() _getCurrentMode;
  
  // 会话状态
  List<ChatMessageHive> messages = [];
  bool isThinking = false;
  String? errorMessage;
  int _messagesVersion = 0;  // 🎯 消息版本号，用于强制UI更新
  
  // 模式锁定（针对单次对话）
  String? _lockedMode;
  
  // 流控制
  StreamSubscription? _streamSubscription;
  bool _shouldStop = false;
  
  // 流式输出控制（用于 UI 的 StreamBuilder）
  StreamController<String>? _contentStreamController;
  String? _currentStreamingMessageId;
  bool _hasReceivedFirstContent = false;  // 🎯 追踪是否已收到第一次内容
  
  // 回调函数（通知外部状态变化）
  final VoidCallback? onStateChanged;
  
  AISession({
    required this.sessionId,
    required AIService aiService,
    required AIToolCallOrchestrator toolOrchestrator,
    required AIContextBuilder contextBuilder,
    required ChatHistoryRepository historyRepo,
    required String Function() getCurrentMode,
    this.onStateChanged,
  })  : _aiService = aiService,
        _toolOrchestrator = toolOrchestrator,
        _contextBuilder = contextBuilder,
        _historyRepo = historyRepo,
        _getCurrentMode = getCurrentMode;
  
  /// 加载历史消息
  Future<void> loadHistory() async {
    messages = _historyRepo.getMessagesBySessionId(sessionId);
    print('[AI Session $sessionId] 📚 加载历史消息: ${messages.length} 条');
  }
  
  /// 获取当前生效的模式（优先使用锁定的模式）
  /// 
  /// 此方法供工具编排器调用，确保整个对话过程使用一致的模式
  String getActiveMode() {
    return _lockedMode ?? _getCurrentMode();
  }
  
  /// 发送消息
  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;
    
    _shouldStop = false;
    _toolOrchestrator.shouldStop = false;
    errorMessage = null;
    
    // 🎯 锁定当前对话的模式，避免中途切换导致不一致
    _lockedMode = _getCurrentMode();
    print('[AI Session $sessionId] 🔒 锁定模式: $_lockedMode');
    print('[AI Session $sessionId] 📩 用户输入: $content');
    
    // 1. 添加用户消息
    final userMessage = ChatMessageHive.user(
      id: const Uuid().v4(),
      content: content,
      sessionId: sessionId,
    );
    messages.add(userMessage);
    await _historyRepo.saveMessage(userMessage);
    _notifyChanged();
    
    // 2. 开始思考
    isThinking = true;
    _notifyChanged();
    
    // 3. 创建临时助手消息（用于流式输出）
    final assistantMessageId = const Uuid().v4();
    final assistantMessage = ChatMessageHive.assistant(
      id: assistantMessageId,
      content: '',
      sessionId: sessionId,
    );
    messages.add(assistantMessage);
    
    // 创建流式输出的 StreamController
    _contentStreamController?.close();
    _contentStreamController = StreamController<String>.broadcast();
    _currentStreamingMessageId = assistantMessageId;
    _hasReceivedFirstContent = false;  // 🎯 重置标志
    
    _notifyChanged();
    
    try {
      // 4. 流式生成
      await _streamGeneration(assistantMessageId);
      
    } catch (e, stackTrace) {
      _handleError(e, stackTrace, assistantMessageId);
    } finally {
      isThinking = false;
      _toolOrchestrator.reset(); // 重置工具编排器状态
      
      // 🎯 释放模式锁定
      _lockedMode = null;
      print('[AI Session $sessionId] 🔓 释放模式锁定');
      
      // 关闭流式输出的 StreamController
      _contentStreamController?.close();
      _contentStreamController = null;
      _currentStreamingMessageId = null;
      _hasReceivedFirstContent = false;  // 🎯 重置标志
      
      _notifyChanged();
      print('[AI Session $sessionId] 🏁 消息处理完成');
    }
  }
  
  /// 流式生成核心逻辑
  Future<void> _streamGeneration(String assistantMessageId) async {
    // 🎯 使用锁定的模式，确保整个对话过程模式一致
    final systemContext = _contextBuilder.build(mode: getActiveMode());
    final apiMessages = _convertMessagesToAPIFormat(
      messages.sublist(0, messages.length - 1),
    );
    
    print('[AI Session $sessionId] 📤 发送流式请求（模式: ${getActiveMode()}）');
    
    final stream = _aiService.chatStream(
      messages: apiMessages,
      systemPrompt: systemContext,
      tools: getActiveMode() == 'action' 
          ? AIToolDefinitions.allTools      // 行动模式：所有工具
          : AIToolDefinitions.queryTools,   // 思考模式：只有查询类工具
    );
    
    StringBuffer contentBuffer = StringBuffer();
    Map<int, _ToolCallBuilder> toolCallBuilders = {};
    String? finishReason;
    
    final completer = Completer<void>();
    await _streamSubscription?.cancel();
    
    _streamSubscription = stream.listen(
      (chunk) {
        if (_shouldStop) return;
        if (chunk.choices.isEmpty) return;
        
        final delta = chunk.choices.first.delta;
        
        // 处理内容
        if (delta.content != null && delta.content!.isNotEmpty) {
          contentBuffer.write(delta.content);
          _updateAssistantMessage(assistantMessageId, contentBuffer.toString());
        }
        
        // 累积工具调用
        if (delta.toolCalls != null && delta.toolCalls!.isNotEmpty) {
          _accumulateToolCalls(delta.toolCalls!, toolCallBuilders);
          
          // 更新UI显示规划状态
          if (toolCallBuilders.isNotEmpty) {
            final planningMessage = '🤔 正在规划操作...\n\n已识别 ${toolCallBuilders.length} 个操作';
            _updateAssistantMessage(assistantMessageId, planningMessage);
          }
        }
        
        // 检查是否结束
        if (chunk.choices.first.finishReason != null) {
          finishReason = chunk.choices.first.finishReason;
          isThinking = false;
          _notifyChanged();
        }
      },
      onDone: () {
        _streamSubscription = null;
        completer.complete();
      },
      onError: (error) {
        _streamSubscription = null;
        completer.completeError(error);
      },
      cancelOnError: true,
    );
    
    await completer.future;
    
    if (_shouldStop) {
      print('[AI Session $sessionId] 🛑 流处理被停止');
      return;
    }
    
    // 构建工具调用列表
    final toolCalls = toolCallBuilders.values
        .where((b) => b.name.isNotEmpty)
        .map((b) => b.build())
        .toList();
    
    print('[AI Session $sessionId] 🔧 工具调用数量: ${toolCalls.length}');
    
    // 保存最终消息
    final finalContent = contentBuffer.toString();
    if (finalContent.isNotEmpty && toolCalls.isEmpty) {
      // 只有纯文本回复时才保存
      await _saveAssistantMessage(assistantMessageId, finalContent);
    }
    
    // 处理工具调用（委托给编排器）
    if (finishReason == 'tool_calls' && toolCalls.isNotEmpty) {
      // 移除临时消息（编排器会生成新的执行计划消息）
      messages.removeWhere((m) => m.id == assistantMessageId);
      _notifyChanged();
      
      print('[AI Session $sessionId] 🔧 委托给工具编排器处理');
      
      // 委托给工具编排器处理
      final result = await _toolOrchestrator.handleToolCalls(
        toolCalls: toolCalls,
        sessionId: sessionId,
        conversationHistory: messages,
        onMessageGenerated: (message) async {
          // 工具编排器生成新消息时的回调
          messages.add(message);
          await _historyRepo.saveMessage(message);
          _notifyChanged();
        },
      );
      
      // 处理结果
      if (result.isSuccess && result.message != null) {
        print('[AI Session $sessionId] ✅ 工具调用完成，添加最终回复');
        messages.add(result.message!);
        await _historyRepo.saveMessage(result.message!);
        _notifyChanged();
      } else if (result.isError) {
        print('[AI Session $sessionId] ❌ 工具调用失败: ${result.errorMessage}');
        await _addWarningMessage(result.errorMessage ?? '处理工具调用时出错');
      } else if (result.isStopped) {
        print('[AI Session $sessionId] 🛑 工具调用被停止');
      }
    }
  }
  
  /// 更新助手消息（实时更新UI）
  void _updateAssistantMessage(String messageId, String content) {
    final index = messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      messages[index] = ChatMessageHive.assistant(
        id: messageId,
        content: content,
        sessionId: sessionId,
      );
      
      // 🎯 第一次收到内容时，调用 _notifyChanged() 让UI知道消息已开始输出
      // 这样可以确保消息列表正确显示（否则 Selector 检测不到变化）
      if (!_hasReceivedFirstContent && content.isNotEmpty) {
        _hasReceivedFirstContent = true;
        print('[AI Session $sessionId] 🎯 第一次收到内容，触发UI更新');
        _notifyChanged();
      }
      
      // 🎯 通过 StreamController 发送内容，后续更新只触发 StreamBuilder 重建
      // 这样避免了整个界面的重建，提升性能
      if (_currentStreamingMessageId == messageId && _contentStreamController != null) {
        _contentStreamController!.add(content);
      }
    }
  }
  
  /// 保存助手消息（到数据库）
  Future<void> _saveAssistantMessage(String messageId, String content) async {
    final index = messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      messages[index] = ChatMessageHive.assistant(
        id: messageId,
        content: content,
        sessionId: sessionId,
      );
      await _historyRepo.saveMessage(messages[index]);
      _notifyChanged();
    }
  }
  
  /// 添加警告消息
  Future<void> _addWarningMessage(String content) async {
    final message = ChatMessageHive.assistant(
      id: const Uuid().v4(),
      content: content,
      sessionId: sessionId,
    );
    messages.add(message);
    await _historyRepo.saveMessage(message);
    isThinking = false;
    _notifyChanged();
  }
  
  /// 累积工具调用（处理流式响应）
  void _accumulateToolCalls(
    List<OpenAIToolCall> deltaToolCalls,
    Map<int, _ToolCallBuilder> builders,
  ) {
    for (final tc in deltaToolCalls) {
      final index = tc.index ?? 0;
      
      if (!builders.containsKey(index)) {
        builders[index] = _ToolCallBuilder();
        print('[AI Session $sessionId] 🔧 发现新工具调用 index=$index');
      }
      
      final builder = builders[index]!;
      if (tc.id.isNotEmpty) builder.id = tc.id;
      if (tc.type.isNotEmpty) builder.type = tc.type;
      if (tc.function.name.isNotEmpty) builder.name = tc.function.name;
      if (tc.function.arguments.isNotEmpty) {
        builder.arguments.write(tc.function.arguments);
      }
    }
  }
  
  /// 转换消息为API格式
  List<OpenAIChatMessage> _convertMessagesToAPIFormat(
    List<ChatMessageHive> msgs,
  ) {
    // 设置最大消息数量限制
    const maxMessages = 100;
    
    if (msgs.length > maxMessages) {
      print('[AI Session $sessionId] ⚠️ 消息数量超过上限（${msgs.length} > $maxMessages）');
      throw Exception('CONTEXT_TOO_LONG');
    }
    
    final apiMessages = <OpenAIChatMessage>[];
    
    for (final msg in msgs) {
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
                  print('[AI Session $sessionId] ⚠️ 跳过无效的 tool_call[$i]: $e');
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
              print('[AI Session $sessionId] ❌ 解析 tool_calls 失败: $e');
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
              print('[AI Session $sessionId] ⚠️ 跳过无效的 tool 消息: $e');
            }
          }
          break;
        case 'system':
          // 系统消息（如对话摘要）- 不发送到API
          break;
      }
    }
    
    return apiMessages;
  }
  
  /// 错误处理
  void _handleError(dynamic e, StackTrace stackTrace, String assistantMessageId) {
    if (_shouldStop) {
      print('[AI Session $sessionId] 🛑 已停止，跳过错误处理');
      return;
    }
    
    print('[AI Session $sessionId] ❌ 错误: $e');
    print('[AI Session $sessionId] 堆栈: $stackTrace');
    
    final userFriendlyMessage = _generateErrorMessage(e);
    errorMessage = userFriendlyMessage;
    
    // 移除空消息并添加错误消息
    messages.removeWhere((m) => m.id == assistantMessageId);
    
    final errorMsg = ChatMessageHive.assistant(
      id: const Uuid().v4(),
      content: '😔 $userFriendlyMessage',
      sessionId: sessionId,
    );
    messages.add(errorMsg);
    
    // 保存到数据库（异常不影响UI）
    _historyRepo.saveMessage(errorMsg).catchError((e) {
      print('[AI Session $sessionId] ⚠️ 保存错误消息失败: $e');
    });
    
    _notifyChanged();
  }
  
  /// 生成友好的错误消息
  String _generateErrorMessage(dynamic e) {
    final errorStr = e.toString().toLowerCase();
    
    if (errorStr.contains('context_too_long')) {
      return '💬 对话内容太多了\n\n当前对话已包含 ${messages.length} 条消息，超过了上下文限制。\n\n建议：\n• 点击右上角"+"创建新对话\n• 或者使用"总结对话"功能压缩历史';
    } else if (errorStr.contains('allocationquota') || errorStr.contains('free tier') || errorStr.contains('exhausted')) {
      return '💰 API 额度已用完\n\n您的 AI 服务免费额度已耗尽。\n\n解决方法：\n• 前往 AI 服务控制台充值\n• 或关闭"仅使用免费额度"模式\n• 或等待额度刷新（通常每月重置）\n• 或切换到其他 AI 模型';
    } else if (errorStr.contains('handshake')) {
      return 'SSL 握手失败\n\n可能原因：\n• 网络连接不稳定或中断\n• 代理或防火墙阻止连接\n• 服务器暂时无法访问\n\n建议：\n• 稍后重试\n• 检查网络设置\n• 如持续出现请联系网络管理员';
    } else if (errorStr.contains('socket') || errorStr.contains('network') || errorStr.contains('dns')) {
      return '网络连接失败\n\n请检查：\n• 网络连接是否正常\n• Base URL 是否正确\n• API 服务是否可访问';
    } else if (errorStr.contains('timeout')) {
      return '连接超时\n\n请检查：\n• 网络状态\n• API 服务响应速度\n• 可以稍后重试';
    } else if (errorStr.contains('certificate')) {
      return 'SSL 证书验证失败\n\n可能原因：\n• 服务器证书无效\n• 系统时间不正确\n\n建议：检查系统时间设置';
    } else if (errorStr.contains('401') || errorStr.contains('unauthorized')) {
      return 'API Key 无效\n\n请前往设置检查 API Key 是否正确';
    } else if (errorStr.contains('404')) {
      return 'API 地址错误\n\n请检查 Base URL 是否正确';
    } else if (errorStr.contains('429')) {
      return '请求频率超限\n\n请稍后再试';
    } else {
      return '出错了\n\n错误信息：${e.toString()}';
    }
  }
  
  /// 停止生成
  Future<void> stop() async {
    print('[AI Session $sessionId] 🛑 停止生成');
    
    _shouldStop = true;
    _toolOrchestrator.shouldStop = true;
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    isThinking = false;
    
    // 关闭流式输出
    _contentStreamController?.close();
    _contentStreamController = null;
    _currentStreamingMessageId = null;
    _hasReceivedFirstContent = false;  // 🎯 重置标志
    
    _notifyChanged();
  }
  
  /// 获取当前流式输出的 Stream（供 UI 的 StreamBuilder 使用）
  Stream<String>? get currentMessageStream => _contentStreamController?.stream;
  
  /// 获取当前正在流式生成的消息ID
  String? get currentStreamingMessageId => _currentStreamingMessageId;
  
  /// 获取消息版本号（用于强制UI更新）
  int get messagesVersion => _messagesVersion;
  
  /// 通知状态变化
  void _notifyChanged() {
    _messagesVersion++;  // 🎯 递增版本号，强制 Selector 检测到变化
    onStateChanged?.call();
  }
  
  /// 清理资源
  void dispose() {
    print('[AI Session $sessionId] 🔴 dispose');
    _shouldStop = true;
    _toolOrchestrator.shouldStop = true;
    _streamSubscription?.cancel();
    _streamSubscription = null;
    
    // 清理流式输出资源
    _contentStreamController?.close();
    _contentStreamController = null;
  }
}

/// 工具调用构建器（用于累积流式响应中的工具调用数据）
class _ToolCallBuilder {
  String id = '';
  String type = 'function';
  String name = '';
  StringBuffer arguments = StringBuffer();
  
  OpenAIToolCall build() {
    return OpenAIToolCall(
      id: id,
      type: type,
      function: OpenAIFunctionCall(
        name: name,
        arguments: arguments.toString(),
      ),
    );
  }
}

