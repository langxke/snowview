import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/chat_message_hive.dart';
import '../../data/models/chat_session_hive.dart';
import '../../data/repositories/chat_history_repository.dart';
import '../../data/repositories/chat_session_repository.dart';
import '../../data/repositories/ai_config_repository.dart';
import '../../services/ai_service.dart';
import '../../services/ai_tool_executor.dart';
import '../../services/ai_context_builder.dart';
import 'ai_session.dart';
import 'ai_tool_call_orchestrator.dart';

/// AI对话状态管理Provider
/// 
/// 职责：
/// - 管理多个会话实例
/// - 处理会话切换、创建、删除
/// - 协调全局状态（AI模式、并发控制）
/// - 通知UI更新
class AIProvider extends ChangeNotifier {
  final AIService _aiService;
  final AIContextBuilder _contextBuilder;
  final ChatHistoryRepository _historyRepo;
  final ChatSessionRepository _sessionRepo;
  final AIConfigRepository _configRepo;
  
  // 会话管理
  final Map<String, AISession> _sessions = {};
  String? _currentSessionId;
  List<ChatSessionHive> _sessionMetadata = [];
  
  // 全局状态
  String _currentMode = 'action';  // 默认行动模式
  bool _disposed = false;
  
  // 配置
  static const int _maxConcurrentSessions = 3;

  AIProvider({
    required AIService aiService,
    required AIToolExecutor toolExecutor, // ⚠️ 保留参数以向后兼容，但不再使用（已改用注册表）
    required AIContextBuilder contextBuilder,
    required ChatHistoryRepository historyRepo,
    required ChatSessionRepository sessionRepo,
    required AIConfigRepository configRepo,
  })  : _aiService = aiService,
        _contextBuilder = contextBuilder,
        _historyRepo = historyRepo,
        _sessionRepo = sessionRepo,
        _configRepo = configRepo {
    _loadSessions();
    _loadPersistedMode();
  }

  // ==================== Getters ====================

  /// 获取当前会话的消息
  List<ChatMessageHive> get messages {
    if (_currentSessionId == null) return [];
    final session = _sessions[_currentSessionId];
    return session?.messages ?? [];
  }

  /// 当前会话是否正在思考
  bool get isThinking {
    if (_currentSessionId == null) return false;
    return _sessions[_currentSessionId]?.isThinking ?? false;
  }

  /// 错误信息
  String? get errorMessage {
    if (_currentSessionId == null) return null;
    return _sessions[_currentSessionId]?.errorMessage;
  }

  /// 是否已配置AI
  bool get isConfigured => _configRepo.hasValidConfig();
  
  /// 当前会话ID
  String? get currentSessionId => _currentSessionId;
  
  /// 当前AI工作模式
  String get currentMode => _currentMode;
  
  /// 是否为思考模式
  bool get isThinkingMode => _currentMode == 'thinking';
  
  /// 是否为行动模式
  bool get isActionMode => _currentMode == 'action';
  
  /// 所有会话列表
  List<ChatSessionHive> get sessions => _sessionMetadata;
  
  /// 当前会话
  ChatSessionHive? get currentSession => 
      _currentSessionId != null ? _sessionRepo.getSession(_currentSessionId!) : null;
  
  /// 检查指定会话是否正在生成
  bool isSessionGenerating(String sessionId) {
    return _sessions[sessionId]?.isThinking ?? false;
  }
  
  /// 获取正在生成的会话数量
  int get generatingSessionsCount {
    return _sessions.values.where((s) => s.isThinking).length;
  }
  
  /// 获取当前会话的流式输出 Stream（供 UI 的 StreamBuilder 使用）
  Stream<String>? get currentMessageStream {
    if (_currentSessionId == null) return null;
    final session = _sessions[_currentSessionId];
    return session?.currentMessageStream;
  }
  
  /// 获取当前会话正在流式生成的消息ID
  String? get currentStreamingMessageId {
    if (_currentSessionId == null) return null;
    final session = _sessions[_currentSessionId];
    return session?.currentStreamingMessageId;
  }
  
  /// 获取当前会话的消息版本号
  int get messagesVersion {
    if (_currentSessionId == null) return 0;
    final session = _sessions[_currentSessionId];
    return session?.messagesVersion ?? 0;
  }
  
  /// 清除错误消息
  void clearError() {
    if (_currentSessionId != null) {
      final session = _sessions[_currentSessionId];
      if (session != null) {
        session.errorMessage = null;
        _safeNotifyListeners();
      }
    }
  }

  // ==================== 会话管理 ====================
  
  /// 获取或创建会话实例
  AISession _getOrCreateSession(String sessionId) {
    if (!_sessions.containsKey(sessionId)) {
      print('[AI Provider] 🆕 创建会话实例: $sessionId');
      
      // 创建会话实例（先创建，因为工具编排器需要引用会话的模式方法）
      late AISession session;
      
      // 创建工具编排器（🎯 使用会话的锁定模式）
      // ✅ 不再需要 toolExecutor，直接使用注册表
      final toolOrchestrator = AIToolCallOrchestrator(
        aiService: _aiService,
        contextBuilder: _contextBuilder,
        getCurrentMode: () => session.getActiveMode(),  // 使用会话的锁定模式
      );
      
      // 初始化会话实例
      session = AISession(
        sessionId: sessionId,
        aiService: _aiService,
        toolOrchestrator: toolOrchestrator,
        contextBuilder: _contextBuilder,
        historyRepo: _historyRepo,
        getCurrentMode: () => _currentMode,  // 获取全局模式
        onStateChanged: () {
          // 当会话状态变化时，如果是当前会话，通知UI更新
          if (_currentSessionId == sessionId && !_disposed) {
    _safeNotifyListeners();
          }
        },
      );
      
      _sessions[sessionId] = session;
      
      // 加载历史消息
      session.loadHistory();
    }
    
    return _sessions[sessionId]!;
  }
  
  /// 加载所有会话
  Future<void> _loadSessions() async {
    _sessionMetadata = _sessionRepo.getAllSessions();
    
    print('[AI Provider] 📚 加载会话列表: ${_sessionMetadata.length} 个');
    
    // 检查是否有旧消息需要迁移
    final oldMessages = _historyRepo.getAllMessages();
    final hasOldMessages = oldMessages.any((m) => m.sessionId == null);
    
    if (hasOldMessages) {
      print('[AI Provider] 🔄 发现旧消息，开始迁移...');
      
      // 创建默认会话用于存放旧消息
      const defaultSessionId = 'default';
      var defaultSession = _sessionRepo.getSession(defaultSessionId);
      
      if (defaultSession == null) {
        defaultSession = await _sessionRepo.createSession(
          id: defaultSessionId,
          title: '历史对话',
        );
        _sessionMetadata.add(defaultSession);
      }
      
      // 迁移旧消息
      await _historyRepo.migrateOldMessages(defaultSessionId);
      print('[AI Provider] ✅ 已将旧消息迁移到默认会话');
    }
    
    // 如果有会话，选中最新的（最后一个）；否则创建新会话
    if (_sessionMetadata.isNotEmpty) {
      _currentSessionId = _sessionMetadata.last.id;
      _getOrCreateSession(_currentSessionId!);
    } else {
      await createNewSession();
    }
    
    _safeNotifyListeners();
  }
  
  /// 创建新会话
  Future<void> createNewSession() async {
    final id = const Uuid().v4();
    
    print('[AI Provider] ➕ 创建新会话: $id');
    
    final session = await _sessionRepo.createSession(
      id: id,
      title: '新对话',
    );
    
    _sessionMetadata.add(session);  // 添加到列表末尾（右侧）
    _currentSessionId = id;
    _getOrCreateSession(id);  // 创建会话实例
    
    _safeNotifyListeners();
  }
  
  /// 切换会话（✅ 不中断生成）
  Future<void> switchSession(String sessionId) async {
    if (_currentSessionId == sessionId) return;
    
    print('[AI Provider] 📱 切换会话: $_currentSessionId -> $sessionId');
    
    // ✅ 不再停止生成！让后台继续运行
    _currentSessionId = sessionId;
    _getOrCreateSession(sessionId);  // 确保会话实例存在
    
    _safeNotifyListeners();
  }
  
  /// 删除会话
  Future<void> deleteSession(String sessionId) async {
    print('[AI Provider] 🗑️ 删除会话: $sessionId');
    
    // 停止并清理会话实例
    final session = _sessions[sessionId];
    if (session != null) {
      await session.stop();
      session.dispose();
      _sessions.remove(sessionId);
    }
    
    // 删除数据库记录
    await _historyRepo.deleteMessagesBySessionId(sessionId);
    await _sessionRepo.deleteSession(sessionId);
    
    // 删除元数据
    _sessionMetadata.removeWhere((s) => s.id == sessionId);
    
    // 如果删除的是当前会话，切换到其他会话
    if (_currentSessionId == sessionId) {
      if (_sessionMetadata.isNotEmpty) {
        _currentSessionId = _sessionMetadata.last.id;
        _getOrCreateSession(_currentSessionId!);
      } else {
        await createNewSession();
      }
    }
    
    _safeNotifyListeners();
  }
  
  /// 重命名会话
  Future<void> renameSession(String sessionId, String newTitle) async {
    final session = _sessionRepo.getSession(sessionId);
    if (session != null) {
      session.updateTitle(newTitle);
      await _sessionRepo.updateSession(session);
      
      // 刷新会话列表
      _sessionMetadata = _sessionRepo.getAllSessions();
      
      _safeNotifyListeners();
    }
  }

  // ==================== AI模式管理 ====================
  
  /// 设置AI工作模式
  void setMode(String mode) {
    if (mode != 'thinking' && mode != 'action') {
      throw ArgumentError('Invalid mode: $mode. Must be "thinking" or "action"');
    }
    
    _currentMode = mode;
    _safeNotifyListeners();
    
    // 保存到持久化存储
    _saveModeToPersistence(mode);
  }
  
  /// 切换模式（快捷方法）
  void toggleMode() {
    setMode(_currentMode == 'thinking' ? 'action' : 'thinking');
  }
  
  /// 从持久化存储加载模式
  void _loadPersistedMode() {
    final config = _configRepo.getConfig();
    if (config != null && config.aiMode.isNotEmpty) {
      // 验证模式值
      if (config.aiMode == 'thinking' || config.aiMode == 'action') {
        _currentMode = config.aiMode;
      }
    }
  }
  
  /// 保存模式到持久化存储
  Future<void> _saveModeToPersistence(String mode) async {
    final config = _configRepo.getConfig();
    if (config != null) {
      final updatedConfig = config.copyWith(
        aiMode: mode,
        updatedAt: DateTime.now(),
      );
      await _configRepo.saveConfig(updatedConfig);
    }
  }

  // ==================== 核心功能：发送消息 ====================

  /// 发送用户消息（委托给会话实例）
  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;
    if (_currentSessionId == null) return;
    if (!isConfigured) {
      _safeNotifyListeners();
      return;
    }
    
    // 检查并发限制
    if (generatingSessionsCount >= _maxConcurrentSessions) {
      print('[AI Provider] ⚠️ 并发限制: $generatingSessionsCount/$_maxConcurrentSessions');
      _safeNotifyListeners();
      return;
    }
    
    print('[AI Provider] 📩 发送消息到会话: $_currentSessionId');
    
    final session = _getOrCreateSession(_currentSessionId!);
    
    // 委托给会话处理
    await session.sendMessage(content);
    
    // 自动生成会话标题（如果是第一条用户消息）
    final sessionMeta = currentSession;
    if (sessionMeta != null && sessionMeta.title == '新对话') {
      final title = content.length > 20 
          ? '${content.substring(0, 20)}...' 
          : content;
      await renameSession(_currentSessionId!, title);
    }
  }
  
  /// 停止当前会话生成
  Future<void> stopGenerating() async {
    if (_currentSessionId != null) {
      print('[AI Provider] 🛑 停止当前会话生成: $_currentSessionId');
      final session = _sessions[_currentSessionId];
      await session?.stop();
    }
  }
  
  /// 停止指定会话生成
  Future<void> stopSessionGenerating(String sessionId) async {
    print('[AI Provider] 🛑 停止会话生成: $sessionId');
    final session = _sessions[sessionId];
    await session?.stop();
  }

  // ==================== 消息历史管理 ====================

  /// 清除历史（删除当前会话）
  Future<void> clearHistory() async {
    if (_currentSessionId != null) {
      await deleteSession(_currentSessionId!);
    }
  }
  
  /// 总结对话历史（压缩上下文）
  Future<void> summarizeHistory() async {
    // TODO: 实现总结功能
    // 可以使用 AI 来生成对话摘要，然后替换旧消息
    print('[AI Provider] ⚠️ 总结功能待实现');
  }

  /// 开始新对话（归档当前对话）
  Future<void> startNewChat() async {
    await createNewSession();
  }

  // ==================== 清理 ====================
  
  /// 安全地通知监听器（检查是否已 dispose）
  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
      } else {
      print('[AI Provider] ⚠️ notifyListeners() 被跳过（Provider已dispose）');
    }
  }
  
  /// 重写 dispose 方法
  @override
  void dispose() {
    print('[AI Provider] 🔴 dispose() 被调用');
    print('[AI Provider] 🔴 当前会话数: ${_sessions.length}, 正在生成: $generatingSessionsCount');
    
    // 标记为已销毁
    _disposed = true;
    
    // 清理所有会话实例
    for (var session in _sessions.values) {
      session.dispose();
    }
    _sessions.clear();
    
    super.dispose();
  }
}

