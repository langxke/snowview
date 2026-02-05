import 'package:hive/hive.dart';

part 'ai_config_hive.g.dart';

/// AI配置数据模型（Hive）
/// TypeId: 9
@HiveType(typeId: 9)
class AIConfigHive extends HiveObject {
  /// AI服务提供商：'openai' | 'claude' | 'custom'
  @HiveField(0)
  String provider;

  /// API密钥
  @HiveField(1)
  String apiKey;

  /// 自定义Base URL（可选）
  @HiveField(2)
  String? baseUrl;

  /// 模型名称（如 gpt-4, gpt-3.5-turbo等）
  @HiveField(3)
  String model;

  /// 温度参数（0.0-2.0），控制回复的随机性
  @HiveField(4)
  double temperature;

  /// 最大Token数
  @HiveField(5)
  int maxTokens;

  /// 是否启用工具调用（Function Calling）
  @HiveField(6)
  bool enableTools;

  /// 创建时间
  @HiveField(7)
  DateTime createdAt;

  /// 更新时间
  @HiveField(8)
  DateTime updatedAt;

  /// AI工作模式：'thinking'（思考模式）| 'action'（行动模式）
  @HiveField(9, defaultValue: 'action')
  String aiMode;

  /// AI输出解析错误的最大重试次数（用于 JSON/schema 解析失败的重试）
  @HiveField(10, defaultValue: 3)
  int maxJsonParseRetries;

  AIConfigHive({
    required this.provider,
    required this.apiKey,
    this.baseUrl,
    required this.model,
    required this.temperature,
    required this.maxTokens,
    required this.enableTools,
    required this.createdAt,
    required this.updatedAt,
    this.aiMode = 'action', // 默认行动模式
    this.maxJsonParseRetries = 3,
  });

  /// 创建默认配置
  factory AIConfigHive.defaultConfig() {
    final now = DateTime.now();
    return AIConfigHive(
      provider: 'openai',
      apiKey: '',
      baseUrl: null,
      model: 'gpt-3.5-turbo',
      temperature: 0.7,
      maxTokens: 2000,
      enableTools: true,
      createdAt: now,
      updatedAt: now,
      aiMode: 'action', // 默认行动模式
      maxJsonParseRetries: 3,
    );
  }

  /// 检查配置是否有效
  bool get isValid {
    // API Key 不能为空
    if (apiKey.trim().isEmpty) return false;
    
    // 模型名称不能为空
    if (model.trim().isEmpty) return false;
    
    // 如果有 BaseURL，必须是有效的 URL 格式
    if (baseUrl != null && baseUrl!.isNotEmpty) {
      final url = baseUrl!.trim();
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        return false;
      }
      try {
        Uri.parse(url);
      } catch (e) {
        return false;
      }
    }
    
    return true;
  }

  /// 创建副本
  AIConfigHive copyWith({
    String? provider,
    String? apiKey,
    Object? baseUrl = _undefined,
    String? model,
    double? temperature,
    int? maxTokens,
    bool? enableTools,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? aiMode,
    int? maxJsonParseRetries,
  }) {
    return AIConfigHive(
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl == _undefined ? this.baseUrl : baseUrl as String?,
      model: model ?? this.model,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      enableTools: enableTools ?? this.enableTools,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      aiMode: aiMode ?? this.aiMode,
      maxJsonParseRetries: maxJsonParseRetries ?? this.maxJsonParseRetries,
    );
  }

  @override
  String toString() {
    return 'AIConfigHive{provider: $provider, model: $model, enableTools: $enableTools, aiMode: $aiMode, maxJsonParseRetries: $maxJsonParseRetries}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AIConfigHive &&
        other.provider == provider &&
        other.apiKey == apiKey &&
        other.model == model;
  }

  @override
  int get hashCode => Object.hash(provider, apiKey, model);
}

// 用于区分"未传值"和"传null"的哨兵值
const Object _undefined = Object();

