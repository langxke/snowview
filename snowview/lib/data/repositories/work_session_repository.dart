import 'package:hive/hive.dart';
import '../models/work_session_hive.dart';

/// 工作会话数据仓库
class WorkSessionRepository {
  static const String _boxName = 'work_sessions';
  
  /// 获取工作会话Box（安全方式）
  Box<WorkSessionHive>? get _sessionBoxOrNull {
    try {
      if (Hive.isBoxOpen(_boxName)) {
        return Hive.box<WorkSessionHive>(_boxName);
      }
    } catch (e) {
      // Box 未打开
    }
    return null;
  }
  
  /// 获取工作会话Box
  Box<WorkSessionHive> get _sessionBox {
    final box = _sessionBoxOrNull;
    if (box == null) {
      throw HiveError('WorkSession box is not open. Make sure to call initHive() in main.dart');
    }
    return box;
  }
  
  // ==================== CRUD 操作 ====================
  
  /// 保存会话
  Future<void> saveSession(WorkSessionHive session) async {
    await _sessionBox.put(session.id, session);
  }
  
  /// 更新会话
  Future<void> updateSession(WorkSessionHive session) async {
    await _sessionBox.put(session.id, session);
  }
  
  /// 删除会话
  Future<void> deleteSession(String id) async {
    await _sessionBox.delete(id);
  }
  
  /// 根据ID获取会话
  WorkSessionHive? getSessionById(String id) {
    final box = _sessionBoxOrNull;
    if (box == null) return null;
    return box.get(id);
  }
  
  // ==================== 查询方法 ====================
  
  /// 获取所有会话
  List<WorkSessionHive> getAllSessions() {
    final box = _sessionBoxOrNull;
    if (box == null) return [];
    return box.values.toList();
  }
  
  /// 获取任务的所有会话
  List<WorkSessionHive> getSessionsByTaskId(String taskId) {
    final box = _sessionBoxOrNull;
    if (box == null) return [];
    return box.values
        .where((session) => session.taskId == taskId)
        .toList();
  }
  
  /// 获取某天的所有会话
  List<WorkSessionHive> getSessionsByDate(DateTime date) {
    final box = _sessionBoxOrNull;
    if (box == null) return [];
    
    final dateOnly = DateTime(date.year, date.month, date.day);
    return box.values.where((session) {
      // 检查会话是否与指定日期相交
      final sessionStartDate = DateTime(
        session.startTime.year,
        session.startTime.month,
        session.startTime.day,
      );
      final sessionEndDate = DateTime(
        session.endTime.year,
        session.endTime.month,
        session.endTime.day,
      );
      
      // 如果会话的开始日期或结束日期等于目标日期，则包含该会话
      return sessionStartDate.isAtSameMomentAs(dateOnly) ||
             sessionEndDate.isAtSameMomentAs(dateOnly) ||
             (sessionStartDate.isBefore(dateOnly) && sessionEndDate.isAfter(dateOnly));
    }).toList();
  }
  
  /// 获取时间范围内的所有会话
  List<WorkSessionHive> getSessionsInRange(DateTime start, DateTime end) {
    final box = _sessionBoxOrNull;
    if (box == null) return [];
    
    return box.values.where((session) {
      // 检查会话是否与时间范围相交
      // 相交条件：会话开始时间 < 范围结束时间 && 会话结束时间 > 范围开始时间
      return session.startTime.isBefore(end) && 
             session.endTime.isAfter(start);
    }).toList();
  }
  
  // ==================== 业务逻辑 ====================
  
  /// 删除任务的所有会话（级联删除）
  Future<void> deleteSessionsByTaskId(String taskId) async {
    final sessions = getSessionsByTaskId(taskId);
    for (final session in sessions) {
      await deleteSession(session.id);
    }
  }
  
  /// 检测时间冲突
  /// 返回 true 表示有冲突
  bool hasConflict(DateTime start, DateTime end, {String? excludeSessionId}) {
    final box = _sessionBoxOrNull;
    if (box == null) return false;
    
    return box.values.any((session) {
      // 排除指定的会话（用于编辑时）
      if (excludeSessionId != null && session.id == excludeSessionId) {
        return false;
      }
      
      // 检查时间是否重叠
      // 重叠条件：开始时间 < 其他会话结束时间 && 结束时间 > 其他会话开始时间
      return start.isBefore(session.endTime) && 
             end.isAfter(session.startTime);
    });
  }
  
  /// 获取冲突的会话列表
  List<WorkSessionHive> getConflictingSessions(
    DateTime start, 
    DateTime end, 
    {String? excludeSessionId}
  ) {
    final box = _sessionBoxOrNull;
    if (box == null) return [];
    
    return box.values.where((session) {
      // 排除指定的会话
      if (excludeSessionId != null && session.id == excludeSessionId) {
        return false;
      }
      
      // 检查时间是否重叠
      return start.isBefore(session.endTime) && 
             end.isAfter(session.startTime);
    }).toList();
  }
  
  // ==================== 初始化方法 ====================
  
  /// 初始化数据库（已在 main.dart 中打开，此方法保留用于未来扩展）
  static Future<void> init() async {
    // 数据库已在 main.dart 中打开
    // 此处可以添加数据迁移或初始化数据的逻辑
  }
  
  /// 关闭数据库
  static Future<void> close() async {
    await Hive.box<WorkSessionHive>(_boxName).close();
  }
}

