import '../data/models/openai/openai_models.dart';

/// AI工具注册表
/// 
/// 职责：
/// - 管理所有AI工具的元数据（名称、定义、执行器）
/// - 提供统一的工具查找、执行、显示接口
/// - 消除硬编码，实现动态工具管理
class AIToolRegistry {
  // 工具注册表（Map: toolName -> ToolMetadata）
  static final Map<String, ToolMetadata> _registry = {};
  
  /// 注册工具
  static void register(ToolMetadata tool) {
    if (_registry.containsKey(tool.name)) {
      throw ArgumentError('工具 "${tool.name}" 已被注册');
    }
    _registry[tool.name] = tool;
  }
  
  /// 批量注册工具
  static void registerAll(List<ToolMetadata> tools) {
    for (final tool in tools) {
      register(tool);
    }
  }
  
  /// 获取所有工具的 OpenAI 定义（用于API调用）
  static List<OpenAITool> getAllToolDefinitions() {
    return _registry.values
        .map((tool) => tool.openAIToolDefinition)
        .toList();
  }
  
  /// 获取查询类工具的 OpenAI 定义（用于思考模式）
  /// 
  /// 只返回查询类工具，不包含执行类工具（create, update, delete, complete, start, batch_等）
  static List<OpenAITool> getQueryToolDefinitions() {
    return _registry.values
        .where((tool) {
          final name = tool.name;
          return name.startsWith('query_') || 
                 name.startsWith('get_') || 
                 name.startsWith('find_');
        })
        .map((tool) => tool.openAIToolDefinition)
        .toList();
  }
  
  /// 检查工具是否存在
  static bool hasToolExecutor(String toolName) {
    return _registry.containsKey(toolName) && 
           _registry[toolName]!.executor != null;
  }
  
  /// 检查工具是否已注册
  static bool isRegistered(String toolName) {
    return _registry.containsKey(toolName);
  }
  
  /// 执行工具
  /// 
  /// 如果工具未注册或没有执行器，返回错误
  static Future<Map<String, dynamic>> execute(
    String toolName,
    Map<String, dynamic> arguments,
  ) async {
    final tool = _registry[toolName];
    
    if (tool == null) {
      return {
        'success': false,
        'error': '未知的工具: $toolName',
      };
    }
    
    if (tool.executor == null) {
      return {
        'success': false,
        'error': '工具 "$toolName" 没有配置执行器',
      };
    }
    
    try {
      return await tool.executor!(arguments);
    } catch (e) {
      return {
        'success': false,
        'error': '工具执行失败: $e',
      };
    }
  }
  
  /// 获取工具的显示名称（中文）
  static String getDisplayName(String toolName) {
    return _registry[toolName]?.displayName ?? toolName;
  }
  
  /// 获取工具的描述
  static String? getDescription(String toolName) {
    return _registry[toolName]?.description;
  }
  
  /// 获取工具的分类
  static String? getCategory(String toolName) {
    return _registry[toolName]?.category;
  }
  
  /// 获取所有已注册的工具名称
  static List<String> getAllToolNames() {
    return _registry.keys.toList();
  }
  
  /// 获取指定分类的工具
  static List<ToolMetadata> getToolsByCategory(String category) {
    return _registry.values
        .where((tool) => tool.category == category)
        .toList();
  }
  
  /// 清空注册表（主要用于测试）
  static void clear() {
    _registry.clear();
  }
  
  /// 获取注册表大小
  static int get size => _registry.length;
}

/// 工具元数据
/// 
/// 封装单个AI工具的所有信息
class ToolMetadata {
  /// 工具名称（英文，API使用）
  final String name;
  
  /// 显示名称（中文，UI显示）
  final String displayName;
  
  /// 工具描述
  final String description;
  
  /// 工具分类（如：任务管理、日历管理）
  final String category;
  
  /// OpenAI 工具定义
  final OpenAITool openAIToolDefinition;
  
  /// 工具执行器（可选，定义阶段可能不需要）
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)? executor;
  
  ToolMetadata({
    required this.name,
    required this.displayName,
    required this.description,
    required this.category,
    required this.openAIToolDefinition,
    this.executor,
  });
  
  /// 复制并设置执行器（用于延迟绑定执行器）
  ToolMetadata withExecutor(
    Future<Map<String, dynamic>> Function(Map<String, dynamic>) executor,
  ) {
    return ToolMetadata(
      name: name,
      displayName: displayName,
      description: description,
      category: category,
      openAIToolDefinition: openAIToolDefinition,
      executor: executor,
    );
  }
  
  @override
  String toString() {
    return 'ToolMetadata(name: $name, displayName: $displayName, category: $category)';
  }
}

/// 工具分类常量
class ToolCategory {
  static const task = '任务管理';
  static const calendar = '日历管理';
  static const focus = '专注管理';
}

