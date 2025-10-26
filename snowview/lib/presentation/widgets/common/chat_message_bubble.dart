import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 消息内容 - 支持 Markdown
                  if (isUser)
                    // 用户消息：使用普通文本
                    SelectableText(
                      message.content,
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontSize: 14,
                      ),
                    )
                  else
                    // AI消息：使用 Markdown 渲染，支持跨段落选择
                    SelectionArea(
                      child: MarkdownBody(
                        data: message.content,
                        selectable: false, // SelectionArea 会处理选择
                        styleSheet: MarkdownStyleSheet(
                          p: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                          h1: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          h2: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          h3: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          listBullet: TextStyle(
                            color: colorScheme.onSurfaceVariant,
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
                            color: colorScheme.onSurfaceVariant.withOpacity(0.8),
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
                    ),
                  
                  // 工具调用指示（如果有）
                  if (message.toolCalls != null && message.toolCalls!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: AIToolCallWidget(toolCallsJson: message.toolCalls!),
                    ),
                ],
              ),
            ),
            
            // 时间戳
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 12, right: 12),
              child: Text(
                _formatTimestamp(message.timestamp),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.outline,
                      fontSize: 11,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
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

  /// 格式化时间戳
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inDays < 1) {
      return DateFormat('HH:mm').format(timestamp);
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return DateFormat('MM-dd HH:mm').format(timestamp);
    }
  }
}

