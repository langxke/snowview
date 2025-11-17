// 专注数据仓库实现
import '../datasources/local_datasource.dart';
import '../models/focus_session_model.dart';
import '../../domain/entities/focus_session.dart';
import '../../domain/repositories/focus_repository_interface.dart';

class FocusRepositoryImpl implements FocusRepositoryInterface {
  final LocalDataSource _localDataSource;
  
  const FocusRepositoryImpl(this._localDataSource);
  
  @override
  Future<List<FocusSession>> getFocusSessions() async {
    final maps = await _localDataSource.getFocusSessions();
    return maps.map((map) => FocusSessionModel.fromMap(map)).map((m) => FocusSession(
      id: m.id,
      taskId: m.taskId,
      sessionType: m.sessionType,
      duration: m.duration,
      completedDuration: m.completedDuration,
      status: m.status,
      startTime: m.startTime,
      endTime: m.endTime,
      notes: m.notes,
      createdAt: m.createdAt,
    )).toList();
  }

  @override
  Future<FocusSession?> getFocusSessionById(int id) async {
    final map = await _localDataSource.getFocusSessionById(id);
    if (map == null) return null;
    final m = FocusSessionModel.fromMap(map);
    return FocusSession(
      id: m.id,
      taskId: m.taskId,
      sessionType: m.sessionType,
      duration: m.duration,
      completedDuration: m.completedDuration,
      status: m.status,
      startTime: m.startTime,
      endTime: m.endTime,
      notes: m.notes,
      createdAt: m.createdAt,
    );
  }

  @override
  Future<int> createFocusSession(FocusSession session) async {
    final m = FocusSessionModel(
      id: session.id,
      taskId: session.taskId,
      sessionType: session.sessionType,
      duration: session.duration,
      completedDuration: session.completedDuration,
      status: session.status,
      startTime: session.startTime,
      endTime: session.endTime,
      notes: session.notes,
      createdAt: session.createdAt,
    );
    return _localDataSource.insertFocusSession(m.toMap());
  }

  @override
  Future<void> updateFocusSession(FocusSession session) async {
    final m = FocusSessionModel(
      id: session.id,
      taskId: session.taskId,
      sessionType: session.sessionType,
      duration: session.duration,
      completedDuration: session.completedDuration,
      status: session.status,
      startTime: session.startTime,
      endTime: session.endTime,
      notes: session.notes,
      createdAt: session.createdAt,
    );
    await _localDataSource.updateFocusSession(session.id!, m.toMap());
  }

  @override
  Future<void> deleteFocusSession(int id) async {
    await _localDataSource.deleteFocusSession(id);
  }

  @override
  Future<List<FocusSession>> getActiveFocusSessions() async {
    final maps = await _localDataSource.getActiveFocusSessions();
    return maps.map((map) => FocusSessionModel.fromMap(map)).map((m) => FocusSession(
      id: m.id,
      taskId: m.taskId,
      sessionType: m.sessionType,
      duration: m.duration,
      completedDuration: m.completedDuration,
      status: m.status,
      startTime: m.startTime,
      endTime: m.endTime,
      notes: m.notes,
      createdAt: m.createdAt,
    )).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getFocusStats() {
    return _localDataSource.getFocusStats();
  }

  @override
  Future<Map<String, dynamic>?> getFocusStatsByDate(String date) {
    return _localDataSource.getFocusStatsByDate(date);
  }
}


