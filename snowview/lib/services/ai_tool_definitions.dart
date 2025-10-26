import '../data/models/openai/openai_models.dart';
import 'ai_tool_registry.dart';

/// AI工具定义 - 定义所有可用的Function Calling工具
/// 
/// ⚠️ 已重构为使用注册表模式
/// 此类保留用于向后兼容，实际工具定义现在由 AIToolRegistry 管理
/// 
/// 使用方式：
/// ```dart
/// // 获取所有工具定义（用于OpenAI API调用）
/// final tools = AIToolDefinitions.allTools;
/// 
/// // 或直接使用注册表
/// final tools = AIToolRegistry.getAllToolDefinitions();
/// ```
class AIToolDefinitions {
  /// 获取所有工具定义
  /// 
  /// ✅ 现在从注册表中获取，而不是硬编码列表
  static List<OpenAITool> get allTools => AIToolRegistry.getAllToolDefinitions();
  
  /// 获取查询类工具定义（用于思考模式）
  /// 
  /// ✅ 只包含 query_*、get_*、find_* 类工具，不包含执行类工具
  static List<OpenAITool> get queryTools => AIToolRegistry.getQueryToolDefinitions();
}
