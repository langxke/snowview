/// OpenAI 聊天消息角色
enum OpenAIMessageRole {
  system,
  user,
  assistant,
  tool;

  String toJson() => name;

  static OpenAIMessageRole fromJson(String value) {
    return OpenAIMessageRole.values.firstWhere(
      (e) => e.name == value,
      orElse: () => OpenAIMessageRole.user,
    );
  }
}

/// OpenAI 聊天消息内容项
class OpenAIMessageContent {
  final String type; // 'text' 或 'image_url'
  final String? text;
  final Map<String, dynamic>? imageUrl;

  OpenAIMessageContent({
    required this.type,
    this.text,
    this.imageUrl,
  });

  factory OpenAIMessageContent.text(String text) {
    return OpenAIMessageContent(type: 'text', text: text);
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      if (text != null) 'text': text,
      if (imageUrl != null) 'image_url': imageUrl,
    };
  }

  factory OpenAIMessageContent.fromJson(Map<String, dynamic> json) {
    return OpenAIMessageContent(
      type: json['type'] as String? ?? 'text',
      text: json['text'] as String?,
      imageUrl: json['image_url'] as Map<String, dynamic>?,
    );
  }
}

/// 工具调用定义
class OpenAIToolCall {
  final int? index; // 流式响应中的索引（用于区分多个工具调用）
  final String id;
  final String type; // 通常是 'function'
  final OpenAIFunctionCall function;

  OpenAIToolCall({
    this.index,
    required this.id,
    required this.type,
    required this.function,
  });

  Map<String, dynamic> toJson() {
    return {
      if (index != null) 'index': index,
      'id': id,
      'type': type,
      'function': function.toJson(),
    };
  }

  factory OpenAIToolCall.fromJson(Map<String, dynamic> json) {
    return OpenAIToolCall(
      index: json['index'] as int?,
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'function',
      function: json['function'] != null
          ? OpenAIFunctionCall.fromJson(json['function'] as Map<String, dynamic>)
          : OpenAIFunctionCall(name: '', arguments: '{}'),
    );
  }
}

/// 函数调用
class OpenAIFunctionCall {
  final String name;
  final String arguments; // JSON 字符串

  OpenAIFunctionCall({
    required this.name,
    required this.arguments,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'arguments': arguments,
    };
  }

  factory OpenAIFunctionCall.fromJson(Map<String, dynamic> json) {
    return OpenAIFunctionCall(
      name: json['name'] as String? ?? '',
      arguments: json['arguments'] as String? ?? '{}',
    );
  }
}

/// OpenAI 聊天消息
class OpenAIChatMessage {
  final OpenAIMessageRole role;
  final List<OpenAIMessageContent>? content;
  final List<OpenAIToolCall>? toolCalls;
  final String? toolCallId; // 用于 tool 角色消息

  OpenAIChatMessage({
    required this.role,
    this.content,
    this.toolCalls,
    this.toolCallId,
  });

  /// 创建文本消息
  factory OpenAIChatMessage.text({
    required OpenAIMessageRole role,
    required String content,
  }) {
    return OpenAIChatMessage(
      role: role,
      content: [OpenAIMessageContent.text(content)],
    );
  }

  /// 创建工具响应消息
  factory OpenAIChatMessage.toolResponse({
    required String toolCallId,
    required String content,
  }) {
    return OpenAIChatMessage(
      role: OpenAIMessageRole.tool,
      content: [OpenAIMessageContent.text(content)],
      toolCallId: toolCallId,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'role': role.toJson(),
    };

    if (content != null && content!.isNotEmpty) {
      // 如果只有一个文本内容，直接使用字符串格式（兼容性更好）
      if (content!.length == 1 && content![0].type == 'text') {
        json['content'] = content![0].text;
      } else {
        json['content'] = content!.map((c) => c.toJson()).toList();
      }
    }

    if (toolCalls != null && toolCalls!.isNotEmpty) {
      json['tool_calls'] = toolCalls!.map((tc) => tc.toJson()).toList();
    }

    if (toolCallId != null) {
      json['tool_call_id'] = toolCallId;
    }

    return json;
  }

  factory OpenAIChatMessage.fromJson(Map<String, dynamic> json) {
    final role = OpenAIMessageRole.fromJson(json['role'] as String);

    List<OpenAIMessageContent>? content;
    if (json['content'] != null) {
      if (json['content'] is String) {
        // 字符串格式
        content = [OpenAIMessageContent.text(json['content'] as String)];
      } else if (json['content'] is List) {
        // 数组格式
        content = (json['content'] as List)
            .map((c) =>
                OpenAIMessageContent.fromJson(c as Map<String, dynamic>))
            .toList();
      }
    }

    List<OpenAIToolCall>? toolCalls;
    if (json['tool_calls'] != null) {
      toolCalls = (json['tool_calls'] as List)
          .map((tc) => OpenAIToolCall.fromJson(tc as Map<String, dynamic>))
          .toList();
    }

    return OpenAIChatMessage(
      role: role,
      content: content,
      toolCalls: toolCalls,
      toolCallId: json['tool_call_id'] as String?,
    );
  }

  /// 获取纯文本内容
  String get textContent {
    if (content == null || content!.isEmpty) return '';
    return content!.map((c) => c.text ?? '').join('');
  }
}

