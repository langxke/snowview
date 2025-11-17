import 'openai_message.dart';

/// OpenAI Chat 完成响应
class OpenAIChatResponse {
  final String id;
  final String object;
  final int created;
  final String model;
  final List<OpenAIChatChoice> choices;
  final OpenAIUsage? usage;

  OpenAIChatResponse({
    required this.id,
    required this.object,
    required this.created,
    required this.model,
    required this.choices,
    this.usage,
  });

  factory OpenAIChatResponse.fromJson(Map<String, dynamic> json) {
    return OpenAIChatResponse(
      id: json['id'] as String? ?? '',
      object: json['object'] as String? ?? 'chat.completion',
      created: json['created'] as int? ?? 0,
      model: json['model'] as String? ?? '',
      choices: json['choices'] != null
          ? (json['choices'] as List)
              .map((c) => OpenAIChatChoice.fromJson(c as Map<String, dynamic>))
              .toList()
          : [],
      usage: json['usage'] != null
          ? OpenAIUsage.fromJson(json['usage'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// 聊天选择项
class OpenAIChatChoice {
  final int index;
  final OpenAIChatMessage message;
  final String? finishReason;

  OpenAIChatChoice({
    required this.index,
    required this.message,
    this.finishReason,
  });

  factory OpenAIChatChoice.fromJson(Map<String, dynamic> json) {
    return OpenAIChatChoice(
      index: json['index'] as int? ?? 0,
      message: json['message'] != null
          ? OpenAIChatMessage.fromJson(json['message'] as Map<String, dynamic>)
          : OpenAIChatMessage.text(role: OpenAIMessageRole.assistant, content: ''),
      finishReason: json['finish_reason'] as String?,
    );
  }
}

/// Token 使用统计
class OpenAIUsage {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  OpenAIUsage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
  });

  factory OpenAIUsage.fromJson(Map<String, dynamic> json) {
    return OpenAIUsage(
      promptTokens: json['prompt_tokens'] as int? ?? 0,
      completionTokens: json['completion_tokens'] as int? ?? 0,
      totalTokens: json['total_tokens'] as int? ?? 0,
    );
  }
}

