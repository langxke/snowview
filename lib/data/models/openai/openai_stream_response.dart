import 'openai_message.dart';

/// OpenAI 流式响应
class OpenAIStreamResponse {
  final String id;
  final String object;
  final int created;
  final String model;
  final List<OpenAIStreamChoice> choices;

  OpenAIStreamResponse({
    required this.id,
    required this.object,
    required this.created,
    required this.model,
    required this.choices,
  });

  factory OpenAIStreamResponse.fromJson(Map<String, dynamic> json) {
    return OpenAIStreamResponse(
      id: json['id'] as String? ?? '',
      object: json['object'] as String? ?? 'chat.completion.chunk',
      created: json['created'] as int? ?? 0,
      model: json['model'] as String? ?? '',
      choices: json['choices'] != null
          ? (json['choices'] as List)
              .map((c) => OpenAIStreamChoice.fromJson(c as Map<String, dynamic>))
              .toList()
          : [],
    );
  }
}

/// 流式选择项
class OpenAIStreamChoice {
  final int index;
  final OpenAIStreamDelta delta;
  final String? finishReason;

  OpenAIStreamChoice({
    required this.index,
    required this.delta,
    this.finishReason,
  });

  factory OpenAIStreamChoice.fromJson(Map<String, dynamic> json) {
    return OpenAIStreamChoice(
      index: json['index'] as int? ?? 0,
      delta: json['delta'] != null
          ? OpenAIStreamDelta.fromJson(json['delta'] as Map<String, dynamic>)
          : OpenAIStreamDelta(role: null, content: null, toolCalls: null),
      finishReason: json['finish_reason'] as String?,
    );
  }
}

/// 流式增量数据
class OpenAIStreamDelta {
  final String? role;
  final String? content;
  final List<OpenAIToolCall>? toolCalls;

  OpenAIStreamDelta({
    this.role,
    this.content,
    this.toolCalls,
  });

  factory OpenAIStreamDelta.fromJson(Map<String, dynamic> json) {
    List<OpenAIToolCall>? toolCalls;
    if (json['tool_calls'] != null) {
      toolCalls = (json['tool_calls'] as List)
          .map((tc) => OpenAIToolCall.fromJson(tc as Map<String, dynamic>))
          .toList();
    }

    return OpenAIStreamDelta(
      role: json['role'] as String?,
      content: json['content'] as String?,
      toolCalls: toolCalls,
    );
  }
}

