import '../data/repositories/ai_config_repository.dart';
import '../data/models/ai_config_hive.dart';
import '../data/models/openai/openai_models.dart';
import 'openai_http_client.dart';

/// AI服务 - 使用 HTTP 直接调用 OpenAI 兼容 API
class AIService {
  final AIConfigRepository _configRepo;
  final OpenAIHttpClient _httpClient;

  AIService(this._configRepo) : _httpClient = OpenAIHttpClient();

  /// 检查配置是否有效
  bool get hasValidConfig => _configRepo.hasValidConfig();

  /// 获取当前配置
  AIConfigHive? get config => _configRepo.getConfig();

  /// 测试API连接
  /// 返回 (成功?, 错误信息?)
  Future<(bool, String?)> testConnection() async {
    try {
      final config = _configRepo.getConfig();
      if (config == null || !config.isValid) {
        return (false, 'AI配置无效');
      }

      // 验证 BaseURL 格式
      if (config.baseUrl != null && config.baseUrl!.isNotEmpty) {
        final baseUrl = config.baseUrl!.trim();
        if (!baseUrl.startsWith('http://') && !baseUrl.startsWith('https://')) {
          return (false, 'BaseURL 格式错误：必须以 http:// 或 https:// 开头');
        }
        try {
          Uri.parse(baseUrl);
        } catch (e) {
          return (false, 'BaseURL 格式错误：请输入有效的URL地址');
        }
      }

    // 配置 HTTP 客户端
    _setupHttpClient(config);

      // 发送测试请求
      final response = await _httpClient.createChatCompletion(
        model: config.model,
        messages: [
          OpenAIChatMessage.text(
            role: OpenAIMessageRole.user,
            content: 'Hello',
          ),
        ],
        maxTokens: 10,
      );

      return (response.choices.isNotEmpty, null);
    } on OpenAIHttpException catch (e) {
      // OpenAI API 错误
      if (e.statusCode == 401) {
        return (false, 'API Key 无效或已过期');
      } else if (e.statusCode == 429) {
        return (false, '请求频率超限，请稍后再试');
      } else if (e.statusCode == 404) {
        return (false, 'API地址不存在（404）\n请检查BaseURL是否正确');
      } else if (e.message.contains('timeout') || e.message.contains('超时')) {
        return (false, '连接超时，请检查网络');
      } else {
        return (false, 'API错误：${e.message}');
      }
    } catch (e) {
      // 其他异常
      final errorStr = e.toString();
      if (errorStr.contains('SocketException')) {
        return (false, '网络连接失败\n请检查网络或BaseURL');
      } else if (errorStr.contains('格式')) {
        return (false, '服务器返回了非JSON内容\n请确认BaseURL是正确的AI服务地址');
      } else {
        return (false, '连接失败：${errorStr.length > 80 ? errorStr.substring(0, 80) : errorStr}');
      }
    }
  }

  /// 发送聊天消息（支持Function Calling）
  Future<OpenAIChatResponse> chat({
    required List<OpenAIChatMessage> messages,
    String? systemPrompt,
    List<OpenAITool>? tools,
    int? maxRetries = 3,
  }) async {
    final config = _configRepo.getConfig();
    if (config == null || !config.isValid) {
      throw Exception('AI配置无效，请先在设置中配置API Key');
    }

    // 配置 HTTP 客户端
    _setupHttpClient(config);

    // 构建完整的消息列表
    final fullMessages = <OpenAIChatMessage>[
      if (systemPrompt != null)
        OpenAIChatMessage.text(
          role: OpenAIMessageRole.system,
          content: systemPrompt,
        ),
      ...messages,
    ];

    // 重试机制
    int retries = 0;
    Exception? lastError;

    while (retries < (maxRetries ?? 3)) {
      try {
        final response = await _httpClient.createChatCompletion(
          model: config.model,
          messages: fullMessages,
          tools: config.enableTools ? tools : null,
          temperature: config.temperature,
          maxTokens: config.maxTokens,
        );

        return response;
      } on OpenAIHttpException catch (e) {
        lastError = e;
        retries++;

        // 如果是速率限制错误，等待后重试
        if (e.statusCode == 429 && retries < (maxRetries ?? 3)) {
          await Future.delayed(Duration(seconds: retries * 2));
          continue;
        }

        rethrow;
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        retries++;

        if (retries >= (maxRetries ?? 3)) {
          rethrow;
        }

        // 等待后重试
        await Future.delayed(Duration(seconds: retries));
      }
    }

    throw lastError ?? Exception('未知错误');
  }

  /// 配置 HTTP 客户端
  void _setupHttpClient(AIConfigHive config) {
    _httpClient.configure(
      apiKey: config.apiKey,
      baseUrl: config.baseUrl,
      timeout: const Duration(seconds: 60),
    );
  }

  /// 流式聊天（用于实时响应）
  Stream<OpenAIStreamResponse> chatStream({
    required List<OpenAIChatMessage> messages,
    String? systemPrompt,
    List<OpenAITool>? tools,
  }) {
    final config = _configRepo.getConfig();
    if (config == null || !config.isValid) {
      throw Exception('AI配置无效，请先在设置中配置API Key');
    }

    // 配置 HTTP 客户端
    _setupHttpClient(config);

    // 构建完整的消息列表
    final fullMessages = <OpenAIChatMessage>[
      if (systemPrompt != null)
        OpenAIChatMessage.text(
          role: OpenAIMessageRole.system,
          content: systemPrompt,
        ),
      ...messages,
    ];

    return _httpClient.createChatCompletionStream(
      model: config.model,
      messages: fullMessages,
      tools: config.enableTools ? tools : null,
      temperature: config.temperature,
      maxTokens: config.maxTokens,
    );
  }
}
