/// OpenAI 工具定义
class OpenAITool {
  final String type; // 'function'
  final OpenAIFunction function;

  OpenAITool({
    required this.type,
    required this.function,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'function': function.toJson(),
    };
  }

  factory OpenAITool.fromJson(Map<String, dynamic> json) {
    return OpenAITool(
      type: json['type'] as String,
      function:
          OpenAIFunction.fromJson(json['function'] as Map<String, dynamic>),
    );
  }
}

/// 函数定义
class OpenAIFunction {
  final String name;
  final String description;
  final Map<String, dynamic> parametersSchema;

  OpenAIFunction({
    required this.name,
    required this.description,
    required this.parametersSchema,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'parameters': parametersSchema,
    };
  }

  factory OpenAIFunction.fromJson(Map<String, dynamic> json) {
    return OpenAIFunction(
      name: json['name'] as String,
      description: json['description'] as String,
      parametersSchema: json['parameters'] as Map<String, dynamic>,
    );
  }
}

