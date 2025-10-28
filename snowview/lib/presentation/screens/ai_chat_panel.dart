import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../data/models/chat_message_hive.dart';
import '../../data/models/chat_session_hive.dart';
import '../providers/ai_provider.dart';
import '../providers/navigation_provider.dart';
import '../widgets/common/chat_message_bubble.dart';
import '../widgets/common/chat_session_tab_bar.dart';

/// AI对话面板
class AIChatPanel extends StatefulWidget {
  final VoidCallback onClose;
  
  const AIChatPanel({
    super.key,
    required this.onClose,
  });

  @override
  State<AIChatPanel> createState() => _AIChatPanelState();
}

class _AIChatPanelState extends State<AIChatPanel> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _keyboardListenerFocusNode = FocusNode();
  
  @override
  void initState() {
    super.initState();
    // 监听消息变化，自动滚动到底部
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _keyboardListenerFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 顶部栏 - 只在会话数量变化时重建
        Selector<AIProvider, int>(
          selector: (_, provider) => provider.sessions.length,
          builder: (context, _, __) {
            final aiProvider = context.read<AIProvider>();
            return _buildHeader(context, aiProvider);
          },
        ),
        const Divider(height: 1),
        
        // 会话标签栏 - 只在会话列表或当前会话变化时重建
        Selector<AIProvider, ({List<ChatSessionHive> sessions, String? currentId})>(
          selector: (_, provider) => (
            sessions: provider.sessions,
            currentId: provider.currentSessionId,
          ),
          shouldRebuild: (prev, next) {
            // 🎯 修复：比较列表长度和当前会话ID
            return prev.sessions.length != next.sessions.length || 
                   prev.currentId != next.currentId;
          },
          builder: (context, data, __) {
            final aiProvider = context.read<AIProvider>();
            return ChatSessionTabBar(
              sessions: data.sessions,
              currentSessionId: data.currentId,
              onSessionSelected: (sessionId) {
                aiProvider.switchSession(sessionId);
              },
              onNewSession: () {
                aiProvider.createNewSession();
              },
              onDeleteSession: (sessionId) {
                _confirmDeleteSession(context, aiProvider, sessionId);
              },
              onRenameSession: (sessionId, newTitle) {
                aiProvider.renameSession(sessionId, newTitle);
              },
            );
          },
        ),
        
        // 消息列表 - 只在消息列表变化时重建
        Expanded(
          child: Selector<AIProvider, ({
            List<ChatMessageHive> messages, 
            bool isConfigured, 
            int version,
            String? sessionId  // 🎯 添加会话ID监听
          })>(
            selector: (_, provider) => (
              messages: provider.messages,
              isConfigured: provider.isConfigured,
              version: provider.messagesVersion,
              sessionId: provider.currentSessionId,  // 🎯 监听会话切换
            ),
            shouldRebuild: (prev, next) {
              // 🎯 会话ID变化或版本号变化都重建
              return prev.sessionId != next.sessionId ||
                     prev.version != next.version || 
                     prev.isConfigured != next.isConfigured;
            },
            builder: (context, data, __) {
              return _buildMessageList(data.messages, data.isConfigured);
            },
          ),
        ),
        
        // 错误提示 - 只在错误消息变化时重建
        Selector<AIProvider, String?>(
          selector: (_, provider) => provider.errorMessage,
          builder: (context, errorMessage, __) {
            if (errorMessage == null) return const SizedBox.shrink();
            return _buildErrorBanner(errorMessage);
          },
        ),
        
        const Divider(height: 1),
        
        // 输入框 - 只在 isThinking 或 isConfigured 变化时重建
        Selector<AIProvider, ({bool isThinking, bool isConfigured, String mode})>(
          selector: (_, provider) => (
            isThinking: provider.isThinking,
            isConfigured: provider.isConfigured,
            mode: provider.currentMode,
          ),
          shouldRebuild: (prev, next) {
            // 🎯 修复：明确比较每个字段
            return prev.isThinking != next.isThinking || 
                   prev.isConfigured != next.isConfigured ||
                   prev.mode != next.mode;
          },
          builder: (context, data, __) {
            final aiProvider = context.read<AIProvider>();
            return _buildInputArea(aiProvider);
          },
        ),
      ],
    );
  }

  /// 构建顶部栏
  Widget _buildHeader(BuildContext context, AIProvider aiProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // 标题
          const Text(
            '🐘 雪小象',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          
          const Spacer(),
          
          // 总结对话
          if (aiProvider.messages.length >= 20)
            IconButton(
              tooltip: '总结对话（压缩上下文）',
              icon: const Icon(Icons.summarize_outlined, size: 20),
              onPressed: () => _showSummarizeDialog(context, aiProvider),
            ),
          
          // 删除当前对话
          if (aiProvider.currentSessionId != null && aiProvider.messages.isNotEmpty)
            IconButton(
              tooltip: '删除当前对话',
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () {
                if (aiProvider.currentSessionId != null) {
                  _confirmDeleteSession(
                    context,
                    aiProvider,
                    aiProvider.currentSessionId!,
                  );
                }
              },
            ),
          
          // 关闭按钮
          IconButton(
            tooltip: '关闭对话',
            icon: const Icon(Icons.close, size: 20),
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }

  /// 构建消息列表
  Widget _buildMessageList(List<ChatMessageHive> messages, bool isConfigured) {
    if (!isConfigured) {
      return _buildUnconfiguredPrompt();
    }

    if (messages.isEmpty) {
      return _buildWelcomeMessage();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        // 🎯 核心优化：为正在生成的消息使用 StreamBuilder
        return _buildMessageItem(message);
      },
    );
  }
  
  /// 构建单条消息（支持流式输出）
  Widget _buildMessageItem(ChatMessageHive message) {
    // 获取当前正在流式生成的消息ID
    final streamingMessageId = context.read<AIProvider>().currentStreamingMessageId;
    
    // 🎯 如果是正在流式生成的消息，使用 StreamBuilder
    if (message.id == streamingMessageId) {
      return _buildStreamingMessage(message);
    }
    
    // 普通消息直接显示（增加消息间距）
    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: ChatMessageBubble(message: message),
    );
  }
  
  /// 构建流式生成的消息（使用 StreamBuilder）
  Widget _buildStreamingMessage(ChatMessageHive message) {
    final aiProvider = context.read<AIProvider>();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: StreamBuilder<String>(
        stream: aiProvider.currentMessageStream,
        initialData: message.content,
        builder: (context, snapshot) {
          // 使用 Stream 中的最新内容
          final content = snapshot.data ?? message.content;
          return ChatMessageBubble(
            message: message.copyWith(content: content),
          );
        },
      ),
    );
  }

  /// 构建未配置提示
  Widget _buildUnconfiguredPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.settings_suggest_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'AI未配置',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '请先在设置中配置OpenAI API Key',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                // 跳转到设置页面
                context.read<NavigationProvider>().navigateToSettings();
                // 关闭AI对话框
                widget.onClose();
              },
              icon: const Icon(Icons.settings),
              label: const Text('前往设置'),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建欢迎消息
  Widget _buildWelcomeMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '👋',
              style: TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 16),
            Text(
              '你好！我是雪小象',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '我可以帮你管理任务、安排日程、启动专注等',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildQuickAction('今天做什么？'),
                _buildQuickAction('帮我安排明天'),
                _buildQuickAction('写今天的日记'),
                _buildQuickAction('创建学习任务'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建快捷操作按钮
  Widget _buildQuickAction(String text) {
    return ActionChip(
      label: Text(text),
      onPressed: () {
        _inputController.text = text;
        _sendMessage();
      },
    );
  }

  /// 构建错误提示横幅
  Widget _buildErrorBanner(String errorMessage) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).colorScheme.errorContainer,
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 20,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorMessage,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontSize: 12,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: Theme.of(context).colorScheme.onErrorContainer,
            onPressed: () {
              // 清除错误消息
              context.read<AIProvider>().clearError();
            },
          ),
        ],
      ),
    );
  }

  /// 构建输入区域
  Widget _buildInputArea(AIProvider aiProvider) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: _getModeColor(aiProvider.currentMode, colorScheme).withOpacity(0.3),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 文本输入区
            KeyboardListener(
              focusNode: _keyboardListenerFocusNode,
              onKeyEvent: (event) {
                // 处理键盘事件：回车发送，Shift+回车换行
                if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
                  // 检查是否按下 Shift 键
                  final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
                  
                  if (!isShiftPressed) {
                    // 单独按回车：发送消息
                    _sendMessage();
                    // 阻止默认的换行行为
                  }
                  // Shift+回车：允许换行（默认行为）
                }
              },
              child: TextField(
                controller: _inputController,
                minLines: 4,
                maxLines: 6,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                enabled: !aiProvider.isThinking && aiProvider.isConfigured,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: aiProvider.isConfigured 
                      ? (aiProvider.isThinkingMode 
                          ? '请输入问题，AI将为您规划方案...\n(回车发送，Shift+回车换行)' 
                          : '请输入指令，AI将立即执行...\n(回车发送，Shift+回车换行)')
                      : '请先配置AI',
                  hintStyle: TextStyle(fontSize: 13, color: colorScheme.outline),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                ),
              ),
            ),
            
            // 底部工具栏（模式选择器 + 发送按钮）
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outlineVariant.withOpacity(0.3),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // 左侧：模式选择器
                  _buildModeSelector(aiProvider, colorScheme),
                  
                  const Spacer(),
                  
                  // 右侧：发送/停止按钮（圆形）
                  IconButton(
                    onPressed: !aiProvider.isConfigured
                        ? null
                        : (aiProvider.isThinking 
                            ? () => aiProvider.stopGenerating()
                            : _sendMessage),
                    icon: Icon(
                      aiProvider.isThinking 
                          ? Icons.stop_rounded 
                          : Icons.arrow_upward_rounded,
                      size: 16,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: aiProvider.isThinking
                          ? colorScheme.surfaceContainerHighest
                          : _getModeColor(aiProvider.currentMode, colorScheme),
                      foregroundColor: aiProvider.isThinking
                          ? colorScheme.onSurfaceVariant
                          : Colors.white,
                      disabledBackgroundColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(6),
                      minimumSize: const Size(28, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    tooltip: aiProvider.isThinking ? '停止生成' : '发送',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 构建模式选择器（嵌入输入框底部工具栏）
  Widget _buildModeSelector(AIProvider aiProvider, ColorScheme colorScheme) {
    final modeColor = _getModeColor(aiProvider.currentMode, colorScheme);
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: modeColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: modeColor.withOpacity(0.25),
              width: 1,
            ),
          ),
          child: DropdownButton<String>(
            value: aiProvider.currentMode,
            underline: const SizedBox(),
            icon: Icon(Icons.arrow_drop_down, size: 16, color: modeColor),
            style: TextStyle(fontSize: 12, color: colorScheme.onSurface, fontWeight: FontWeight.w500),
            dropdownColor: colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            isDense: true,
            items: [
              DropdownMenuItem(
                value: 'thinking',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.psychology, size: 14, color: Colors.green[600]),
                    const SizedBox(width: 6),
                    const Text('思考模式', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: 'action',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt, size: 14, color: colorScheme.primary),
                    const SizedBox(width: 6),
                    const Text('行动模式', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
            // 🎯 在 AI 思考时禁用模式切换，避免对话过程中模式不一致
            onChanged: aiProvider.isThinking ? null : (newMode) {
              if (newMode != null) {
                aiProvider.setMode(newMode);
              }
            },
            // 🎯 思考时降低透明度显示禁用状态
            disabledHint: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  aiProvider.currentMode == 'thinking' ? Icons.psychology : Icons.bolt,
                  size: 14,
                  color: modeColor.withOpacity(0.5),
                ),
                const SizedBox(width: 6),
                Text(
                  aiProvider.currentMode == 'thinking' ? '思考模式' : '行动模式',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withOpacity(0.5)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  /// 获取模式对应的颜色
  Color _getModeColor(String mode, ColorScheme colorScheme) {
    return mode == 'thinking' ? Colors.green[600]! : colorScheme.primary;
  }

  /// 发送消息
  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    final aiProvider = context.read<AIProvider>();
    _inputController.clear();
    
    // 清空后再次清空，防止回车键插入的换行符残留
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inputController.clear();
    });
    
    // 发送消息
    aiProvider.sendMessage(text);
    
    // 滚动到底部
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  /// 滚动到底部
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// 显示总结对话对话框
  void _showSummarizeDialog(BuildContext context, AIProvider aiProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('总结对话'),
        content: Text(
          '将前${aiProvider.messages.length - 10}条消息总结为摘要，'
          '保留最近10条原始消息。\n\n这样可以节省上下文空间。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              aiProvider.summarizeHistory();
              Navigator.pop(context);
            },
            child: const Text('总结'),
          ),
        ],
      ),
    );
  }

  /// 确认删除会话
  void _confirmDeleteSession(
    BuildContext context,
    AIProvider aiProvider,
    String sessionId,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除对话'),
        content: const Text('确定要删除这个对话吗？所有消息将被永久删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              aiProvider.deleteSession(sessionId);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
