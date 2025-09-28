// 专注仓库接口
import '../entities/focus_session.dart';

abstract class FocusRepositoryInterface {
  Future<List<FocusSession>> getFocusSessions();
  Future<FocusSession?> getFocusSessionById(int id);
  Future<int> createFocusSession(FocusSession session);
  Future<void> updateFocusSession(FocusSession session);
  Future<void> deleteFocusSession(int id);
  Future<List<FocusSession>> getActiveFocusSessions();
  Future<List<Map<String, dynamic>>> getFocusStats();
  Future<Map<String, dynamic>?> getFocusStatsByDate(String date);
}


