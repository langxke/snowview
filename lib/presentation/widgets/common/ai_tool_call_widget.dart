import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import '../../../services/ai_tool_registry.dart';
import '../../../data/models/calendar_event_hive.dart';
import '../../../data/repositories/task_list_repository.dart';

/// AI工具调用可视化组件
/// 显示AI正在执行的工具调用，支持折叠/展开
class AIToolCallWidget extends StatefulWidget {
  final List<String> toolCallsJson;
  final String? toolResults;

  const AIToolCallWidget({
    super.key,
    required this.toolCallsJson,
    this.toolResults,
  });

  @override
  State<AIToolCallWidget> createState() => _AIToolCallWidgetState();
}

class _AIToolCallWidgetState extends State<AIToolCallWidget> {
  bool _isExpanded = false; // 改为默认折叠

  @override
  Widget build(BuildContext context) {
    if (widget.toolCallsJson.isEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final mutedColor = colorScheme.onSurface.withOpacity(0.5);
    
    // 单个工具且不是批量操作时，直接显示一行，不可展开
    if (widget.toolCallsJson.length == 1 && !_isBatchOperation()) {
      return _buildSimpleToolDisplay(colorScheme, mutedColor);
    }

    // 单个批量操作或多个工具时，显示可展开的列表
    return _buildExpandableToolDisplay(colorScheme, mutedColor);
  }
  
  /// 判断是否是批量操作
  bool _isBatchOperation() {
    try {
      final toolCall = jsonDecode(widget.toolCallsJson.first);
      final functionName = toolCall['function']?['name'] ?? '';
      
      final batchTools = <String>{
        'batch_create_tasks',
        'batch_delete_tasks',
        'batch_create_calendar_events',
        'batch_delete_calendar_events',
      };
      
      return batchTools.contains(functionName);
    } catch (e) {
      return false;
    }
  }
  
  /// 构建可展开的工具显示
  Widget _buildExpandableToolDisplay(ColorScheme colorScheme, Color mutedColor) {
    // 如果是单个批量操作，获取汇总信息
    String summaryText;
    if (widget.toolCallsJson.length == 1) {
      try {
        final toolCall = jsonDecode(widget.toolCallsJson.first);
        final functionName = toolCall['function']?['name'] ?? '';
        final arguments = toolCall['function']?['arguments'];
        final toolName = _formatToolName(functionName);
        final inlineArgs = _formatInlineArguments(arguments);
        summaryText = '$toolName$inlineArgs';
      } catch (e) {
        summaryText = 'Used 1 tool';
      }
    } else {
      summaryText = 'Used ${widget.toolCallsJson.length} tools';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 精简的标题栏（灰色小字，可点击）
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.functions,
                  size: 14,
                  color: mutedColor,
                ),
                const SizedBox(width: 4),
                Text(
                  summaryText,
                  style: TextStyle(
                    fontSize: 12,
                    color: mutedColor,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 16,
                  color: mutedColor,
                ),
              ],
            ),
          ),
          
          // 展开的工具列表（纯文字，无装饰）
          if (_isExpanded) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _buildExpandedToolList(colorScheme, mutedColor),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  /// 构建单个工具的单行显示
  Widget _buildSimpleToolDisplay(ColorScheme colorScheme, Color mutedColor) {
    try {
      final toolCall = jsonDecode(widget.toolCallsJson.first);
      final functionName = toolCall['function']?['name'] ?? '未知操作';
      final arguments = toolCall['function']?['arguments'];
      
      final toolName = _formatToolName(functionName);
      final inlineArgs = _formatInlineArguments(arguments);
      
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        child: Text(
          '$toolName$inlineArgs',
          style: TextStyle(
            fontSize: 12,
            color: mutedColor,
            fontWeight: FontWeight.normal,
          ),
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  /// 构建展开后的工具列表（极简风格）
  List<Widget> _buildExpandedToolList(ColorScheme colorScheme, Color mutedColor) {
    // 如果是单个批量操作，展开显示每个项目
    if (widget.toolCallsJson.length == 1) {
      try {
        final toolCall = jsonDecode(widget.toolCallsJson.first);
        final functionName = toolCall['function']?['name'] ?? '';
        
        final batchTools = <String>{
          'batch_create_tasks',
          'batch_delete_tasks',
          'batch_create_calendar_events',
          'batch_delete_calendar_events',
        };
        
        if (batchTools.contains(functionName)) {
          return _buildBatchOperationDetails(context, toolCall, colorScheme, mutedColor);
        }
      } catch (e) {
        // 解析失败，继续使用普通显示
      }
    }
    
    // 普通工具列表显示
    return widget.toolCallsJson.asMap().entries.map((entry) {
      final toolCallJson = entry.value;
      
      try {
        final toolCall = jsonDecode(toolCallJson);
        final functionName = toolCall['function']?['name'] ?? '未知操作';
        final arguments = toolCall['function']?['arguments'];
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 小圆点（替代序号）
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              
              // 工具名 + 参数（单行）
              Expanded(
                child: Text(
                  '${_formatToolName(functionName)}${_formatInlineArguments(arguments)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withOpacity(0.7),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      } catch (e) {
        return const SizedBox.shrink();
      }
    }).toList();
  }
  
  /// 构建批量操作的详细列表
  List<Widget> _buildBatchOperationDetails(BuildContext context, Map<String, dynamic> toolCall, ColorScheme colorScheme, Color mutedColor) {
    final widgets = <Widget>[];
    
    try {
      final functionName = toolCall['function']?['name'] ?? '';
      final arguments = toolCall['function']?['arguments'];
      
      Map<String, dynamic> args;
      if (arguments is Map) {
        args = Map<String, dynamic>.from(arguments);
      } else if (arguments is String) {
        args = jsonDecode(arguments) as Map<String, dynamic>;
      } else {
        return [const SizedBox.shrink()];
      }
      
      // 批量创建任务
      if (functionName == 'batch_create_tasks' && args.containsKey('tasks')) {
        final tasks = args['tasks'] as List;
        for (var i = 0; i < tasks.length; i++) {
          final task = tasks[i] as Map<String, dynamic>;
          final title = task['title'] ?? '未命名任务';
          final date = task['date'] != null ? ' · ${task['date']}' : '';
          widgets.add(_buildBatchItem(colorScheme, mutedColor, title + date));
        }
      }
      
      // 批量删除任务
      else if (functionName == 'batch_delete_tasks' && args.containsKey('taskIds')) {
        final taskIds = args['taskIds'] as List;
        final taskRepository = context.read<TaskListRepository>();
        
        for (var i = 0; i < taskIds.length; i++) {
          final taskId = taskIds[i].toString();
          final task = taskRepository.getTaskById(taskId);
          final displayText = task != null ? task.title : '任务 ${i + 1}';
          widgets.add(_buildBatchItem(colorScheme, mutedColor, displayText));
        }
      }
      
      // 批量创建日程
      else if (functionName == 'batch_create_calendar_events' && args.containsKey('events')) {
        final events = args['events'] as List;
        for (var i = 0; i < events.length; i++) {
          final event = events[i] as Map<String, dynamic>;
          final title = event['title'] ?? '未命名日程';
          final date = event['date'] != null ? ' · ${event['date']}' : '';
          final time = event['startTime'] != null ? ' ${event['startTime']}' : '';
          widgets.add(_buildBatchItem(colorScheme, mutedColor, title + date + time));
        }
      }
      
      // 批量删除日程
      else if (functionName == 'batch_delete_calendar_events' && args.containsKey('eventIds')) {
        final eventIds = args['eventIds'] as List;
        final eventBox = Hive.box<CalendarEventHive>('calendar_events');
        
        for (var i = 0; i < eventIds.length; i++) {
          final eventId = eventIds[i].toString();
          final event = eventBox.get(eventId);
          if (event != null) {
            final dateStr = event.start.toString().split(' ')[0];
            widgets.add(_buildBatchItem(colorScheme, mutedColor, '${event.title} ($dateStr)'));
          } else {
            widgets.add(_buildBatchItem(colorScheme, mutedColor, '日程 ${i + 1}'));
          }
        }
      }
    } catch (e) {
      return [const SizedBox.shrink()];
    }
    
    return widgets.isEmpty ? [const SizedBox.shrink()] : widgets;
  }
  
  /// 构建批量操作的单个项目
  Widget _buildBatchItem(ColorScheme colorScheme, Color mutedColor, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 小圆点
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          
          // 项目内容
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withOpacity(0.7),
                height: 1.4,
              ),
            ),
          ),
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
      
      // 任务相关
      if (args.containsKey('title')) {
        parts.add(args['title']);
      }
      if (args.containsKey('description') && args['description']?.toString().isNotEmpty == true) {
        final desc = args['description'].toString();
        if (desc.length > 30) {
          parts.add('${desc.substring(0, 30)}...');
        } else {
          parts.add(desc);
        }
      }
      
      // 日期时间相关
      if (args.containsKey('date')) {
        parts.add(args['date']);
      }
      if (args.containsKey('startTime')) {
        parts.add(args['startTime']);
      }
      if (args.containsKey('duration')) {
        parts.add('${args['duration']}分钟');
      }
      
      // 专注相关
      if (args.containsKey('mode')) {
        final mode = args['mode'];
        if (mode == 'work') parts.add('工作模式');
        if (mode == 'rest') parts.add('休息模式');
        if (mode == 'deep') parts.add('深度专注');
      }
      
      // 批量操作相关
      if (args.containsKey('taskIds') && args['taskIds'] is List) {
        final count = (args['taskIds'] as List).length;
        parts.add('$count个任务');
      }
      if (args.containsKey('eventIds') && args['eventIds'] is List) {
        final count = (args['eventIds'] as List).length;
        parts.add('$count个日程');
      }
      if (args.containsKey('tasks') && args['tasks'] is List) {
        final count = (args['tasks'] as List).length;
        parts.add('$count个任务');
      }
      if (args.containsKey('events') && args['events'] is List) {
        final count = (args['events'] as List).length;
        parts.add('$count个日程');
      }
      
      return parts.isEmpty ? '' : parts.join(' · ');
    } catch (e) {
      // 解析失败，返回空字符串
      return '';
    }
  }

  /// 格式化参数为单行显示（用于简单工具）
  String _formatInlineArguments(dynamic arguments) {
    final formatted = _formatArguments(arguments);
    return formatted.isEmpty ? '' : ': $formatted';
  }

  /// 格式化工具名称为中文
  /// 
  /// ✅ 现在从注册表获取显示名称，不再硬编码
  String _formatToolName(String toolName) {
    return AIToolRegistry.getDisplayName(toolName);
  }
}

