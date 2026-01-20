import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import '../data/models/openai/openai_models.dart';

/// OpenAI HTTP 客户端异常
class OpenAIHttpException implements Exception {
  final int? statusCode;
  final String message;
  final Map<String, dynamic>? errorData;

  OpenAIHttpException({
    this.statusCode,
    required this.message,
    this.errorData,
  });

  @override
  String toString() {
    if (statusCode != null) {
      return 'OpenAIHttpException [$statusCode]: $message';
    }
    return 'OpenAIHttpException: $message';
  }
}

/// OpenAI HTTP 客户端
class OpenAIHttpClient {
  Dio? _dio;
  String? _apiKey;
  String? _baseUrl;
  Duration _timeout;

  OpenAIHttpClient({
    String? apiKey,
    String? baseUrl,
    Duration timeout = const Duration(seconds: 60),
  })  : _apiKey = apiKey,
        _baseUrl = baseUrl,
        _timeout = timeout {
    _initDio();
  }

  /// 初始化 Dio
  void _initDio() {
    _dio = Dio(BaseOptions(
      connectTimeout: _timeout,
      receiveTimeout: _timeout,
      sendTimeout: _timeout,
      validateStatus: (status) => true, // 手动处理状态码
      // ✅ 启用持久连接，利用连接池提升性能
      persistentConnection: true,
      followRedirects: true,
      maxRedirects: 5,
    ));

    // ✅ 配置连接池参数
    (_dio!.httpClientAdapter as IOHttpClientAdapter).onHttpClientCreate = (client) {
      // 每个主机的最大连接数
      client.maxConnectionsPerHost = 8;
      
      // 空闲连接保持时间（允许连接复用）
      client.idleTimeout = Duration(seconds: 15);
      
      // 建立连接的超时时间
      client.connectionTimeout = Duration(seconds: 10);
      
      // 自动解压缩响应
      client.autoUncompress = true;
      
      return client;
    };

    // 添加请求拦截器
    _dio!.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // 添加认证头
        if (_apiKey != null && _apiKey!.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $_apiKey';
        }
        options.headers['Content-Type'] = 'application/json';
        // 添加用户代理，有些服务器要求
        options.headers['User-Agent'] = 'SnowView/1.0.0';
        // ✅ 启用 keep-alive，允许连接复用
        options.headers['Connection'] = 'keep-alive';

        return handler.next(options);
      },
      onResponse: (response, handler) {
        return handler.next(response);
      },
      onError: (error, handler) {
        return handler.next(error);
      },
    ));
  }

  /// 配置客户端
  void configure({
    required String apiKey,
    String? baseUrl,
    Duration? timeout,
  }) {
    _apiKey = apiKey;
    _baseUrl = baseUrl;
    if (timeout != null) {
      _timeout = timeout;
      _initDio(); // 重新初始化以应用新超时
    }
  }

  /// 获取完整的 API URL
  /// 直接使用用户配置的 BaseURL，不追加任何路径
  String _getApiUrl() {
    // 用户输入的地址应该是完整的端点 URL
    // 例如：https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions
    // 或者：https://api.openai.com/v1/chat/completions
    return _baseUrl ?? 'https://api.openai.com/v1/chat/completions';
  }

  /// 聊天完成 API
  Future<OpenAIChatResponse> createChatCompletion({
    required String model,
    required List<OpenAIChatMessage> messages,
    List<OpenAITool>? tools,
    double? temperature,
    int? maxTokens,
  }) async {
    final url = _getApiUrl();

    final body = {
      'model': model,
      'messages': messages.map((m) => m.toJson()).toList(),
      if (tools != null && tools.isNotEmpty)
        'tools': tools.map((t) => t.toJson()).toList(),
      if (temperature != null) 'temperature': temperature,
      if (maxTokens != null) 'max_tokens': maxTokens,
    };

    try {
      final response = await _dio!.post(url, data: body);

      if (response.statusCode == 200) {
        return OpenAIChatResponse.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw _handleErrorResponse(response);
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// 流式聊天完成 API
  Stream<OpenAIStreamResponse> createChatCompletionStream({
    required String model,
    required List<OpenAIChatMessage> messages,
    List<OpenAITool>? tools,
    double? temperature,
    int? maxTokens,
  }) async* {
    final url = _getApiUrl();

    final body = {
      'model': model,
      'messages': messages.map((m) => m.toJson()).toList(),
      'stream': true,
      if (tools != null && tools.isNotEmpty)
        'tools': tools.map((t) => t.toJson()).toList(),
      if (temperature != null) 'temperature': temperature,
      if (maxTokens != null) 'max_tokens': maxTokens,
    };

    try {
      final response = await _dio!.post<ResponseBody>(
        url,
        data: body,
        options: Options(responseType: ResponseType.stream),
      );

      if (response.statusCode != 200) {
        throw OpenAIHttpException(
          statusCode: response.statusCode,
          message: '流式请求失败',
        );
      }

      // 处理 SSE 流
      await for (final chunk in response.data!.stream) {
        final text = utf8.decode(chunk);
        final lines = text.split('\n');
        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6).trim();
            if (data == '[DONE]') {
              return;
            }
            try {
              final json = jsonDecode(data) as Map<String, dynamic>;
              yield OpenAIStreamResponse.fromJson(json);
            } catch (e) {
              // 忽略解析错误
            }
          }
        }
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// 处理错误响应
  OpenAIHttpException _handleErrorResponse(Response response) {
    final statusCode = response.statusCode ?? 0;
    String message = '请求失败';
    Map<String, dynamic>? errorData;

    try {
      if (response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        if (data.containsKey('error')) {
          final error = data['error'];
          if (error is Map) {
            message = error['message'] ?? message;
            errorData = error as Map<String, dynamic>;
          } else if (error is String) {
            message = error;
          }
        }
      }
    } catch (e) {
      // 忽略解析错误
    }

    return OpenAIHttpException(
      statusCode: statusCode,
      message: message,
      errorData: errorData,
    );
  }

  /// 处理 Dio 异常
  OpenAIHttpException _handleDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return OpenAIHttpException(message: '连接超时，请检查网络设置');
        
      case DioExceptionType.connectionError:
        // 检查是否是DNS查找失败
        final errorMsg = e.error?.toString() ?? '';
        if (errorMsg.contains('SocketException') || errorMsg.contains('Failed host lookup')) {
          return OpenAIHttpException(
            message: 'DNS查找失败\n请检查URL格式是否正确\n当前URL: ${_baseUrl ?? "未设置"}',
          );
        }
        return OpenAIHttpException(message: '网络连接失败，请检查网络状态');
        
      case DioExceptionType.badResponse:
        return _handleErrorResponse(e.response!);
        
      case DioExceptionType.cancel:
        return OpenAIHttpException(message: '请求已取消');
        
      case DioExceptionType.badCertificate:
        return OpenAIHttpException(message: 'SSL证书验证失败');
        
      case DioExceptionType.unknown:
        // 尝试从错误对象中获取更多信息
        final errorMsg = e.error?.toString() ?? '';
        
        // SSL 握手异常
        if (errorMsg.contains('HandshakeException')) {
          return OpenAIHttpException(
            message: 'SSL 握手失败\n\n可能原因：\n• 网络连接不稳定\n• 连接被中断\n• 代理或防火墙问题\n\n建议：稍后重试或检查网络设置',
          );
        }
        
        // Socket 异常
        if (errorMsg.contains('SocketException')) {
          return OpenAIHttpException(
            message: '网络错误：无法连接到服务器\n\n请检查：\n• URL 是否正确\n• 网络连接是否正常',
          );
        }
        
        // 证书验证异常
        if (errorMsg.contains('CertificateException')) {
          return OpenAIHttpException(
            message: 'SSL 证书验证失败\n\n可能原因：\n• 服务器证书无效\n• 系统时间不正确',
          );
        }
        
        return OpenAIHttpException(message: '未知错误: ${e.message ?? errorMsg}');
    }
  }
}

