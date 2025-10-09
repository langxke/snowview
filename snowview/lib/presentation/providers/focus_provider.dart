import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/focus_session_hive.dart';
import '../../data/models/focus_daily_stats_hive.dart';
import '../../data/repositories/focus_session_repository.dart';
import '../../data/repositories/work_session_repository.dart';
import '../../data/repositories/task_list_repository.dart';
import '../../services/notification_service.dart';
import '../../services/focus_sound_service.dart';

/// 专注功能状态管理
class FocusProvider extends ChangeNotifier {
  final FocusSessionRepository _repository;
  final WorkSessionRepository _workSessionRepo = WorkSessionRepository();
  final TaskListRepository _taskRepo = TaskListRepository();
  final NotificationService _notificationService = NotificationService();
  final FocusSoundService _soundService = FocusSoundService();

  FocusProvider(this._repository) {
    _loadTodayStats();
    _loadRecentSessions();
    _checkAndRecoverActiveSession();
  }

  // === 状态属性 ===

  FocusSessionHive? _currentSession;           // 当前专注会话
  Timer? _timer;                                // 计时器
  int _elapsedSeconds = 0;                     // 已过去的秒数
  bool _isPaused = false;                      // 是否暂停
  DateTime? _backgroundTime;                   // 进入后台的时间

  FocusDailyStatsHive? _todayStats;           // 今日统计
  List<FocusSessionHive> _recentSessions = []; // 最近会话列表
  
  int _consecutivePomodoroCount = 0;           // 连续番茄钟计数

  // === Getters ===
  
  /// 连续番茄钟计数
  int get consecutivePomodoroCount => _consecutivePomodoroCount;

  /// 当前专注会话
  FocusSessionHive? get currentSession => _currentSession;

  /// 是否有活动会话
  bool get isActive => _currentSession != null && 
                       (_currentSession!.status == 'active' || _currentSession!.status == 'paused');

  /// 是否暂停中
  bool get isPaused => _isPaused;

  /// 剩余秒数
  int get remainingSeconds {
    if (_currentSession == null) return 0;
    final remaining = _currentSession!.plannedDuration - _elapsedSeconds;
    return remaining > 0 ? remaining : 0;
  }

  /// 进度（0.0-1.0）
  double get progress {
    if (_currentSession == null || _currentSession!.plannedDuration == 0) {
      return 0.0;
    }
    final p = _elapsedSeconds / _currentSession!.plannedDuration;
    return p > 1.0 ? 1.0 : (p < 0.0 ? 0.0 : p);
  }

  /// 格式化时间显示（如"24:35"）
  String get formattedTime {
    final seconds = remainingSeconds;
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// 今日统计
  FocusDailyStatsHive? get todayStats => _todayStats;

  /// 最近会话列表
  List<FocusSessionHive> get recentSessions => _recentSessions;

  /// 今日专注分钟数
  int get todayFocusMinutes {
    return (_todayStats?.totalFocusSeconds ?? 0) ~/ 60;
  }

  /// 今日番茄钟数量
  int get todayPomodoroCount {
    return _todayStats?.pomodoroCount ?? 0;
  }

  // === 核心方法 - 会话控制 ===

  /// 开始专注会话
  Future<void> startFocusSession({
    required int durationMinutes,
    String? taskId,
    String? workSessionId,
    String sessionType = 'pomodoro',
    bool isBreak = false,
  }) async {
    // 检查是否已有活动会话
    if (_currentSession != null) {
      throw Exception('已有进行中的专注会话，请先完成或取消当前会话');
    }

    // 创建新会话
    final session = FocusSessionHive(
      id: const Uuid().v4(),
      taskId: taskId,
      workSessionId: workSessionId,
      sessionType: sessionType,
      plannedDuration: durationMinutes * 60,
      actualDuration: 0,
      status: 'active',
      startTime: DateTime.now(),
      endTime: null,
      note: null,
      isBreak: isBreak,
      pauseTimestamps: [],
      createdAt: DateTime.now(),
    );

    // 保存到数据库
    await _repository.saveSession(session);

    // 设置当前会话
    _currentSession = session;
    _elapsedSeconds = 0;
    _isPaused = false;

    // 启动计时器
    _startTimer();

    notifyListeners();
  }

  /// 暂停当前会话
  Future<void> pauseCurrentSession() async {
    if (_currentSession == null || _isPaused) return;

    // 停止计时器
    _stopTimer();

    // 更新状态
    _isPaused = true;
    final updatedSession = _currentSession!.copyWith(
      status: 'paused',
      pauseTimestamps: [..._currentSession!.pauseTimestamps, DateTime.now()],
    );

    await _repository.updateSession(updatedSession);
    _currentSession = updatedSession;

    notifyListeners();
  }

  /// 恢复当前会话
  Future<void> resumeCurrentSession() async {
    if (_currentSession == null || !_isPaused) return;

    // 更新状态
    _isPaused = false;
    final updatedSession = _currentSession!.copyWith(status: 'active');

    await _repository.updateSession(updatedSession);
    _currentSession = updatedSession;

    // 重新启动计时器
    _startTimer();

    notifyListeners();
  }

  /// 完成当前会话
  Future<void> completeCurrentSession() async {
    if (_currentSession == null) return;

    // 停止计时器
    _stopTimer();
    
    // 更新连续番茄钟计数
    if (_currentSession!.sessionType == 'pomodoro' && !_currentSession!.isBreak) {
      _consecutivePomodoroCount++;
    }

    // 更新会话状态
    final updatedSession = _currentSession!.copyWith(
      status: 'completed',
      actualDuration: _elapsedSeconds,
      endTime: DateTime.now(),
    );

    await _repository.updateSession(updatedSession);

    // 更新当天的统计
    await _repository.updateDailyStats(_currentSession!.startTime);

    // 更新关联的工作会话
    await _updateWorkSession();

    // 清空当前会话
    _currentSession = null;
    _elapsedSeconds = 0;
    _isPaused = false;

    // 重新加载数据
    await _loadTodayStats();
    await _loadRecentSessions();

    notifyListeners();
  }

  /// 取消当前会话
  Future<void> cancelCurrentSession() async {
    if (_currentSession == null) return;

    // 停止计时器
    _stopTimer();
    
    // 取消番茄钟会重置连续计数
    if (_currentSession!.sessionType == 'pomodoro' && !_currentSession!.isBreak) {
      _consecutivePomodoroCount = 0;
    }

    // 更新会话状态
    final updatedSession = _currentSession!.copyWith(
      status: 'cancelled',
      endTime: DateTime.now(),
    );

    await _repository.updateSession(updatedSession);

    // 清空当前会话
    _currentSession = null;
    _elapsedSeconds = 0;
    _isPaused = false;

    notifyListeners();
  }

  // === 快捷方法 ===

  /// 开始番茄钟（从设置读取时长，默认25分钟）
  Future<void> startPomodoro({String? taskId, String? workSessionId}) async {
    // 从设置读取番茄钟时长
    final prefs = await SharedPreferences.getInstance();
    final duration = prefs.getInt('focus_pomodoro_duration') ?? 25;
    
    await startFocusSession(
      durationMinutes: duration,
      taskId: taskId,
      workSessionId: workSessionId,
      sessionType: 'pomodoro',
      isBreak: false,
    );
  }

  /// 开始自定义时长专注
  Future<void> startCustomSession(int minutes, {String? taskId}) async {
    await startFocusSession(
      durationMinutes: minutes,
      taskId: taskId,
      sessionType: 'custom',
      isBreak: false,
    );
  }

  /// 开始短休息（从设置读取时长，默认5分钟）
  Future<void> startBreak([int? minutes]) async {
    // 如果没有指定时长，从设置读取
    int duration = minutes ?? 5;
    if (minutes == null) {
      final prefs = await SharedPreferences.getInstance();
      duration = prefs.getInt('focus_short_break_duration') ?? 5;
    }
    
    await startFocusSession(
      durationMinutes: duration,
      sessionType: 'break',
      isBreak: true,
    );
  }

  /// 开始长休息（从设置读取时长，默认15分钟）
  Future<void> startLongBreak([int? minutes]) async {
    // 如果没有指定时长，从设置读取
    int duration = minutes ?? 15;
    if (minutes == null) {
      final prefs = await SharedPreferences.getInstance();
      duration = prefs.getInt('focus_long_break_duration') ?? 15;
    }
    
    await startFocusSession(
      durationMinutes: duration,
      sessionType: 'long_break',
      isBreak: true,
    );
    
    // 长休息后重置连续计数
    _consecutivePomodoroCount = 0;
  }

  // === 数据加载 ===

  /// 加载今日统计
  Future<void> _loadTodayStats() async {
    _todayStats = _repository.getStatsForDate(DateTime.now());
    notifyListeners();
  }

  /// 重新加载今日统计（公开方法）
  Future<void> loadTodayStats() async {
    await _loadTodayStats();
  }

  /// 加载最近会话
  Future<void> _loadRecentSessions() async {
    final allSessions = _repository.getAllSessions();
    // 按创建时间倒序，取最近10条
    allSessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _recentSessions = allSessions.take(10).toList();
    notifyListeners();
  }

  /// 重新加载最近会话（公开方法）
  Future<void> loadRecentSessions() async {
    await _loadRecentSessions();
  }

  // === 内部方法 ===

  /// 启动计时器
  void _startTimer() {
    _timer?.cancel(); // 先取消已有的计时器
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _onTimerTick();
    });
  }

  /// 停止计时器
  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// 计时器每秒触发
  void _onTimerTick() {
    if (_currentSession == null || _isPaused) return;

    _elapsedSeconds++;

    // 检查是否到达计划时长
    if (_elapsedSeconds >= _currentSession!.plannedDuration) {
      _onSessionComplete();
    }

    notifyListeners();
  }

  /// 会话完成时调用
  Future<void> _onSessionComplete() async {
    // 获取任务标题用于通知
    String? taskTitle;
    if (_currentSession?.taskId != null) {
      final task = _taskRepo.getTaskById(_currentSession!.taskId!);
      taskTitle = task?.title;
    }
    
    // 播放提示音（如果设置中启用）
    await _playCompleteSoundIfEnabled();
    
    await completeCurrentSession();
    
    // 显示完成通知
    await _showCompleteNotification(taskTitle);
  }

  /// 播放完成提示音（根据设置）
  Future<void> _playCompleteSoundIfEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enableSound = prefs.getBool('focus_enable_sound') ?? false;
      
      if (enableSound) {
        await _soundService.playCompleteSound();
        debugPrint('✅ 播放完成提示音');
      }
    } catch (e) {
      debugPrint('播放提示音失败: $e');
    }
  }

  /// 显示专注完成通知
  Future<void> _showCompleteNotification(String? taskTitle) async {
    try {
      final title = taskTitle != null ? '🎉 专注时间到！' : '✅ 专注完成';
      final body = taskTitle != null 
          ? '任务"$taskTitle"的专注会话已完成，休息一下吧！' 
          : '专注会话已完成，休息一下吧！';
      
      await _notificationService.showFocusCompleteNotification(
        title: title,
        body: body,
      );
      
      debugPrint('专注完成通知: $title');
    } catch (e) {
      // 通知失败不影响核心功能，只记录日志
      debugPrint('显示通知失败（桌面平台可能不支持）: $e');
    }
  }

  /// 更新关联的工作会话
  Future<void> _updateWorkSession() async {
    if (_currentSession?.workSessionId == null) return;

    try {
      final workSession = _workSessionRepo.getSessionById(
        _currentSession!.workSessionId!,
      );

      if (workSession != null) {
        // 更新工作会话状态为已完成
        final updatedWorkSession = workSession.copyWith(status: 'completed');
        await _workSessionRepo.updateSession(updatedWorkSession);
      }
    } catch (e) {
      debugPrint('更新工作会话失败: $e');
    }
  }

  /// 处理应用生命周期变化（后台计时）
  void handleAppLifecycleChange(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _currentSession != null && !_isPaused) {
      // 应用进入后台，记录时间
      _backgroundTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed && _backgroundTime != null) {
      // 应用恢复，累加后台时间
      final backgroundSeconds = DateTime.now().difference(_backgroundTime!).inSeconds;
      _elapsedSeconds += backgroundSeconds;
      _backgroundTime = null;
      notifyListeners();
    }
  }

  /// 检查并恢复活动会话（应用启动时调用）
  Future<void> _checkAndRecoverActiveSession() async {
    try {
      final activeSession = _repository.getActiveSession();
      if (activeSession != null) {
        // 计算已经过去的时间
        final elapsed = DateTime.now().difference(activeSession.startTime).inSeconds;
        
        if (elapsed >= activeSession.plannedDuration) {
          // 如果已经超过计划时长，自动标记为完成
          await _repository.completeSession(activeSession.id, activeSession.plannedDuration);
          await _repository.updateDailyStats(activeSession.startTime);
          await _loadTodayStats();
        } else {
          // 恢复会话状态
          _currentSession = activeSession;
          _elapsedSeconds = elapsed;
          _isPaused = activeSession.status == 'paused';
          
          if (!_isPaused) {
            _startTimer();
          }
          
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('恢复活动会话失败: $e');
    }
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}
