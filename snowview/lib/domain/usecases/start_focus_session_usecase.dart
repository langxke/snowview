// 开始专注会话用例
import '../entities/focus_session.dart';
import '../repositories/focus_repository_interface.dart';
import '../../core/utils/validation_utils.dart';
import '../../core/errors/exceptions.dart';

class StartFocusSessionUseCase {
  final FocusRepositoryInterface _focusRepository;
  
  const StartFocusSessionUseCase(this._focusRepository);
  
  Future<int> execute({
    int? taskId,
    required String sessionType,
    required int duration,
    String? notes,
  }) async {
    if (!ValidationUtils.isValidDuration(duration)) {
      throw const ValidationException('会话时长必须在1-1440分钟之间');
    }
    
    if (!_isValidSessionType(sessionType)) {
      throw const ValidationException('无效的会话类型');
    }
    
    final activeSessions = await _focusRepository.getActiveFocusSessions();
    if (activeSessions.isNotEmpty) {
      throw const ValidationException('已有活跃的专注会话，请先完成或暂停当前会话');
    }
    
    final now = DateTime.now();
    final session = FocusSession(
      taskId: taskId,
      sessionType: sessionType,
      duration: duration,
      completedDuration: 0,
      status: 'active',
      startTime: now,
      notes: notes?.trim(),
      createdAt: now,
    );
    
    try {
      return await _focusRepository.createFocusSession(session);
    } catch (e) {
      throw Exception('开始专注会话失败: $e');
    }
  }
  
  bool _isValidSessionType(String sessionType) {
    const validTypes = ['pomodoro', 'custom', 'break'];
    return validTypes.contains(sessionType);
  }
}


