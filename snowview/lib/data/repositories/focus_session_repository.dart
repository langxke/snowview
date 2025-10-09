import 'package:hive/hive.dart';
import '../models/focus_session_hive.dart';
import '../models/focus_daily_stats_hive.dart';

/// 专注会话数据仓库
class FocusSessionRepository {
  static const String _sessionBoxName = 'focus_sessions';
  static const String _statsBoxName = 'focus_daily_stats';

  // 获取Box实例
  Box<FocusSessionHive> get _sessionBox => Hive.box<FocusSessionHive>(_sessionBoxName);
  Box<FocusDailyStatsHive> get _statsBox => Hive.box<FocusDailyStatsHive>(_statsBoxName);

  // === 初始化 ===

  static Future<void> init() async {
    await Hive.openBox<FocusSessionHive>(_sessionBoxName);
    await Hive.openBox<FocusDailyStatsHive>(_statsBoxName);
  }

  // === CRUD 操作 ===

  /// 保存专注会话
  Future<void> saveSession(FocusSessionHive session) async {
    await _sessionBox.put(session.id, session);
  }

  /// 更新专注会话
  Future<void> updateSession(FocusSessionHive session) async {
    await _sessionBox.put(session.id, session);
  }

  /// 删除专注会话
  Future<void> deleteSession(String sessionId) async {
    await _sessionBox.delete(sessionId);
  }

  /// 根据ID获取专注会话
  FocusSessionHive? getSessionById(String sessionId) {
    return _sessionBox.get(sessionId);
  }

  // === 查询方法 ===

  /// 获取所有专注会话
  List<FocusSessionHive> getAllSessions() {
    return _sessionBox.values.toList();
  }

  /// 获取当前活动的专注会话
  FocusSessionHive? getActiveSession() {
    for (final session in _sessionBox.values) {
      if (session.status == 'active' || session.status == 'paused') {
        return session;
      }
    }
    return null;
  }

  /// 获取指定日期的专注会话
  List<FocusSessionHive> getSessionsByDate(DateTime date) {
    final targetDate = DateTime(date.year, date.month, date.day);
    return _sessionBox.values.where((session) {
      final sessionDate = DateTime(
        session.startTime.year,
        session.startTime.month,
        session.startTime.day,
      );
      return sessionDate.isAtSameMomentAs(targetDate);
    }).toList();
  }

  /// 获取指定任务的所有专注会话
  List<FocusSessionHive> getSessionsByTaskId(String taskId) {
    return _sessionBox.values
        .where((session) => session.taskId == taskId)
        .toList();
  }

  /// 获取指定工作会话的所有专注会话
  List<FocusSessionHive> getSessionsByWorkSessionId(String workSessionId) {
    return _sessionBox.values
        .where((session) => session.workSessionId == workSessionId)
        .toList();
  }

  /// 获取时间范围内的专注会话
  List<FocusSessionHive> getSessionsInRange(DateTime start, DateTime end) {
    return _sessionBox.values.where((session) {
      return session.startTime.isAfter(start.subtract(const Duration(days: 1))) &&
             session.startTime.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }

  // === 统计相关 ===

  /// 获取指定日期的统计
  FocusDailyStatsHive? getStatsForDate(DateTime date) {
    final dateKey = _getDateKey(date);
    return _statsBox.get(dateKey);
  }

  /// 更新指定日期的统计数据
  Future<void> updateDailyStats(DateTime date) async {
    final dateKey = _getDateKey(date);
    final sessions = getSessionsByDate(date);
    
    // 筛选已完成的会话
    final completedSessions = sessions.where((s) => s.isCompleted).toList();
    
    if (completedSessions.isEmpty) {
      // 如果没有完成的会话，删除统计（如果存在）
      await _statsBox.delete(dateKey);
      return;
    }

    // 计算统计数据
    int totalFocusSeconds = 0;
    int totalBreakSeconds = 0;
    int pomodoroCount = 0;
    final Set<String> taskIds = {};

    for (final session in completedSessions) {
      if (session.isBreak) {
        totalBreakSeconds += session.actualDuration;
      } else {
        totalFocusSeconds += session.actualDuration;
      }

      if (session.sessionType == 'pomodoro') {
        pomodoroCount++;
      }

      if (session.taskId != null) {
        taskIds.add(session.taskId!);
      }
    }

    // 创建或更新统计
    final stats = FocusDailyStatsHive(
      id: dateKey,
      date: DateTime(date.year, date.month, date.day),
      totalFocusSeconds: totalFocusSeconds,
      completedSessionCount: completedSessions.length,
      pomodoroCount: pomodoroCount,
      totalBreakSeconds: totalBreakSeconds,
      focusedTaskIds: taskIds.toList(),
      createdAt: _statsBox.get(dateKey)?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _statsBox.put(dateKey, stats);
  }

  /// 获取今日专注总秒数
  int getTodayFocusSeconds() {
    final stats = getStatsForDate(DateTime.now());
    return stats?.totalFocusSeconds ?? 0;
  }

  /// 获取本周专注总秒数
  int getWeekFocusSeconds() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    
    int total = 0;
    for (var i = 0; i <= 6; i++) {
      final date = startOfWeek.add(Duration(days: i));
      final stats = getStatsForDate(date);
      total += stats?.totalFocusSeconds ?? 0;
    }
    return total;
  }

  /// 获取今日番茄钟数量
  int getTodayPomodoroCount() {
    final stats = getStatsForDate(DateTime.now());
    return stats?.pomodoroCount ?? 0;
  }

  /// 获取时间范围内的统计
  List<FocusDailyStatsHive> getStatsInRange(DateTime start, DateTime end) {
    return _statsBox.values.where((stats) {
      return !stats.date.isBefore(start) && !stats.date.isAfter(end);
    }).toList();
  }

  // === 业务逻辑 ===

  /// 开始专注会话
  Future<void> startSession(FocusSessionHive session) async {
    await saveSession(session);
  }

  /// 暂停专注会话
  Future<void> pauseSession(String sessionId) async {
    final session = getSessionById(sessionId);
    if (session != null && session.isActive) {
      final updatedSession = session.copyWith(
        status: 'paused',
        pauseTimestamps: [...session.pauseTimestamps, DateTime.now()],
      );
      await updateSession(updatedSession);
    }
  }

  /// 恢复专注会话
  Future<void> resumeSession(String sessionId) async {
    final session = getSessionById(sessionId);
    if (session != null && session.isPaused) {
      final updatedSession = session.copyWith(status: 'active');
      await updateSession(updatedSession);
    }
  }

  /// 完成专注会话
  Future<void> completeSession(String sessionId, int actualDuration) async {
    final session = getSessionById(sessionId);
    if (session != null) {
      final updatedSession = session.copyWith(
        status: 'completed',
        actualDuration: actualDuration,
        endTime: DateTime.now(),
      );
      await updateSession(updatedSession);
      
      // 更新当天的统计
      await updateDailyStats(session.startTime);
    }
  }

  /// 取消专注会话
  Future<void> cancelSession(String sessionId) async {
    final session = getSessionById(sessionId);
    if (session != null) {
      final updatedSession = session.copyWith(
        status: 'cancelled',
        endTime: DateTime.now(),
      );
      await updateSession(updatedSession);
    }
  }

  // === 数据清理 ===

  /// 删除指定任务的所有专注会话
  Future<void> deleteSessionsByTaskId(String taskId) async {
    final sessions = getSessionsByTaskId(taskId);
    for (final session in sessions) {
      await deleteSession(session.id);
    }
  }

  /// 删除旧的专注会话（保留指定天数）
  Future<void> deleteOldSessions(int daysToKeep) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
    final oldSessions = _sessionBox.values.where((session) {
      return session.startTime.isBefore(cutoffDate);
    }).toList();

    for (final session in oldSessions) {
      await deleteSession(session.id);
    }
  }

  // === 辅助方法 ===

  /// 获取日期的键值（用于统计Box）
  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

