// 日程仓库接口（最小实现以匹配当前仓库实现）
import '../entities/schedule.dart';

abstract class ScheduleRepositoryInterface {
  Future<List<Schedule>> getSchedules();
  Future<Schedule?> getScheduleById(int id);
  Future<int> createSchedule(Schedule schedule);
  Future<void> updateSchedule(Schedule schedule);
  Future<void> deleteSchedule(int id);
  Future<List<Schedule>> getSchedulesByDate(DateTime date);
}


