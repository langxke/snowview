import 'package:hive/hive.dart';
import '../models/ai_config_hive.dart';

/// AI配置数据仓库
class AIConfigRepository {
  static const String _boxName = 'ai_config';
  static const String _configKey = 'current_config';

  /// 获取配置Box（安全方式）
  Box<AIConfigHive> get _box {
    if (!Hive.isBoxOpen(_boxName)) {
      throw HiveError('AI配置Box未打开，请先调用 AIConfigRepository.init()');
    }
    return Hive.box<AIConfigHive>(_boxName);
  }

  /// 保存配置
  Future<void> saveConfig(AIConfigHive config) async {
    final updatedConfig = config.copyWith(
      updatedAt: DateTime.now(),
    );
    await _box.put(_configKey, updatedConfig);
  }

  /// 获取配置
  AIConfigHive? getConfig() {
    return _box.get(_configKey);
  }

  /// 更新配置
  Future<void> updateConfig(AIConfigHive config) async {
    final updatedConfig = config.copyWith(
      updatedAt: DateTime.now(),
    );
    await _box.put(_configKey, updatedConfig);
  }

  /// 删除配置
  Future<void> deleteConfig() async {
    await _box.delete(_configKey);
  }

  /// 检查是否已配置
  bool hasValidConfig() {
    final config = getConfig();
    return config != null && config.isValid;
  }

  /// 获取或创建默认配置
  AIConfigHive getOrCreateDefault() {
    var config = getConfig();
    if (config == null) {
      config = AIConfigHive.defaultConfig();
      saveConfig(config);
    }
    return config;
  }

  /// 更新API Key
  Future<void> updateApiKey(String apiKey) async {
    var config = getOrCreateDefault();
    config = config.copyWith(
      apiKey: apiKey,
      updatedAt: DateTime.now(),
    );
    await saveConfig(config);
  }

  /// 更新模型
  Future<void> updateModel(String model) async {
    var config = getOrCreateDefault();
    config = config.copyWith(
      model: model,
      updatedAt: DateTime.now(),
    );
    await saveConfig(config);
  }

  /// 更新Base URL
  Future<void> updateBaseUrl(String? baseUrl) async {
    var config = getOrCreateDefault();
    config = config.copyWith(
      baseUrl: baseUrl,
      updatedAt: DateTime.now(),
    );
    await saveConfig(config);
  }

  /// 更新温度参数
  Future<void> updateTemperature(double temperature) async {
    var config = getOrCreateDefault();
    config = config.copyWith(
      temperature: temperature,
      updatedAt: DateTime.now(),
    );
    await saveConfig(config);
  }

  /// 更新最大Token数
  Future<void> updateMaxTokens(int maxTokens) async {
    var config = getOrCreateDefault();
    config = config.copyWith(
      maxTokens: maxTokens,
      updatedAt: DateTime.now(),
    );
    await saveConfig(config);
  }

  /// 切换工具调用功能
  Future<void> toggleEnableTools(bool enable) async {
    var config = getOrCreateDefault();
    config = config.copyWith(
      enableTools: enable,
      updatedAt: DateTime.now(),
    );
    await saveConfig(config);
  }

  // ==================== 初始化方法 ====================

  /// 初始化数据库（打开Box）
  static Future<void> init() async {
    await Hive.openBox<AIConfigHive>(_boxName);
  }

  /// 关闭数据库
  static Future<void> close() async {
    await Hive.box<AIConfigHive>(_boxName).close();
  }
}

