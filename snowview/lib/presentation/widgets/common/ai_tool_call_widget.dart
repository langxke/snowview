import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../services/ai_tool_registry.dart';

/// AI工具调用可视化组件
/// 显示AI正在执行的工具调用，支持折叠/展开
class AIToolCallWidget extends StatefulWidget {
  final List<String> toolCallsJson;

  const AIToolCallWidget({
    super.key,
    required this.toolCallsJson,
  });

  @override
  State<AIToolCallWidget> createState() => _AIToolCallWidgetState();
}

class _AIToolCallWidgetState extends State<AIToolCallWidget> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    if (widget.toolCallsJson.isEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题和折叠按钮
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    Icons.settings_suggest,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '执行了 ${widget.toolCallsJson.length} 个操作',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
          
          // 工具列表（可折叠）
          if (_isExpanded) ...[
            const SizedBox(height: 8),
            ...widget.toolCallsJson.asMap().entries.map((entry) {
              final index = entry.key;
              final toolCallJson = entry.value;
              
              try {
                final toolCall = jsonDecode(toolCallJson);
                final functionName = toolCall['function']?['name'] ?? '未知操作';
                final arguments = toolCall['function']?['arguments'];
                
                return Padding(
                  padding: const EdgeInsets.only(left: 4, top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 序号（多个工具时）或图标（单个工具时）
                      widget.toolCallsJson.length > 1
                        ? Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: colorScheme.onPrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          )
                        : Icon(
                            Icons.build,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                      const SizedBox(width: 8),
                      
                      // 操作名称和参数
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatToolName(functionName),
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (arguments != null && arguments.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  _formatArguments(arguments),
                                  style: TextStyle(
                                    color: colorScheme.onSurface.withOpacity(0.6),
                                    fontSize: 10,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                      
                      // 完成图标
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: colorScheme.tertiary,
                      ),
                    ],
                  ),
                );
              } catch (e) {
                return const SizedBox.shrink();
              }
            }).toList(),
          ],
        ],
      ),
    );
  }
  
  /// 格式化参数显示
  String _formatArguments(dynamic arguments) {
    try {
      // 处理不同类型的 arguments
      Map<String, dynamic> args;
      
      if (arguments is Map) {
        // 如果已经是 Map，直接使用
        args = Map<String, dynamic>.from(arguments);
      } else if (arguments is String) {
        // 如果是字符串，尝试解析
        if (arguments.trim().isEmpty || arguments.trim() == '}' || arguments.trim() == '{') {
          return ''; // 空字符串或无效字符串
        }
        args = jsonDecode(arguments) as Map<String, dynamic>;
      } else {
        return ''; // 其他类型直接返回空
      }
      
      final parts = <String>[];
      
      if (args.containsKey('title')) {
        parts.add('标题: ${args['title']}');
      }
      if (args.containsKey('taskId')) {
        parts.add('任务: ${args['taskId']}');
      }
      if (args.containsKey('eventId')) {
        parts.add('事件: ${args['eventId']}');
      }
      if (args.containsKey('date')) {
        parts.add('日期: ${args['date']}');
      }
      if (args.containsKey('startTime')) {
        parts.add('时间: ${args['startTime']}');
      }
      
      return parts.isEmpty ? '' : parts.join(', ');
    } catch (e) {
      // 解析失败，返回空字符串
      print('[AIToolCallWidget] 参数解析失败: $arguments');
      print('[AIToolCallWidget] 错误: $e');
      return '';
    }
  }

  /// 格式化工具名称为中文
  /// 
  /// ✅ 现在从注册表获取显示名称，不再硬编码
  String _formatToolName(String toolName) {
    return AIToolRegistry.getDisplayName(toolName);
  }
}

