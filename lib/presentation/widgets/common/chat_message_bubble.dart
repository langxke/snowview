import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../data/models/chat_message_hive.dart';
import 'ai_tool_call_widget.dart';

/// 聊天消息气泡组件
class ChatMessageBubble extends StatelessWidget {
  final ChatMessageHive message;

  const ChatMessageBubble({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    // 系统消息（对话摘要）使用特殊样式
    if (message.isSystem) {
      return _buildSystemMessage(context);
    }

    // 工具调用消息不显示（已在工具调用组件中显示）
    if (message.isTool) {
      return const SizedBox.shrink();
    }

    final isUser = message.isUser;
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // 消息内容（条件性气泡包裹）
            // 只有当 content 不为空时才显示
            if (message.content.trim().isNotEmpty)
              _buildMessageContainer(context, isUser, colorScheme),
            
            // 工具调用指示（如果有，放在气泡外部）
            if (message.toolCalls != null && message.toolCalls!.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(
                  top: message.content.trim().isNotEmpty ? 4 : 0,
                ),
                child: AIToolCallWidget(
                  toolCallsJson: message.toolCalls!,
                  toolResults: message.toolResults,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 构建消息内容容器（用户有气泡，AI无气泡）
  Widget _buildMessageContainer(BuildContext context, bool isUser, ColorScheme colorScheme) {
    final content = _buildContent(context, isUser, colorScheme);
    
    if (isUser) {
      // 用户消息：带背景色的气泡框
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: content,
      );
    } else {
      // AI消息：无气泡，直接显示
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: content,
      );
    }
  }

  /// 构建消息内容
  Widget _buildContent(BuildContext context, bool isUser, ColorScheme colorScheme) {
    if (isUser) {
      // 用户消息：使用普通文本
      return SelectableText(
        message.content,
        style: TextStyle(
          color: colorScheme.onPrimaryContainer,
          fontSize: 14,
        ),
      );
    } else {
      // AI消息：使用 Markdown 渲染，支持跨段落选择
      return SelectionArea(
        child: MarkdownBody(
          data: message.content,
          selectable: false, // SelectionArea 会处理选择
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 14,
            ),
            h1: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            h2: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            h3: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            listBullet: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 14,
            ),
            code: TextStyle(
              color: colorScheme.primary,
              backgroundColor: colorScheme.surface,
              fontFamily: 'monospace',
              fontSize: 13,
            ),
            codeblockDecoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: colorScheme.outline.withOpacity(0.3),
              ),
            ),
            blockquote: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.8),
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
            blockquoteDecoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: colorScheme.primary,
                  width: 3,
                ),
              ),
            ),
          ),
        ),
      );
    }
  }

  /// 构建系统消息（对话摘要）
  Widget _buildSystemMessage(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message.content,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSecondaryContainer,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

