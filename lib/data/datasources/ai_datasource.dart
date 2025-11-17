// AI 数据源接口（OpenAI API调用抽象）
abstract class AIDatasource {
	Future<List<Map<String, dynamic>>> generateTasksByGoal(String goalText);
}
