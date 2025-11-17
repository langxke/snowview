// 日程数据仓库实现
import '../datasources/local_datasource.dart';
import '../models/schedule_model.dart';
import '../../domain/repositories/schedule_repository_interface.dart';
import '../../domain/entities/schedule.dart';

class ScheduleRepository implements ScheduleRepositoryInterface {
  final LocalDataSource _localDataSource;
  
  const ScheduleRepository(this._localDataSource);
  
  @override
  Future<List<Schedule>> getSchedules() async {
    final maps = await _localDataSource.getSchedules();
    return maps.map((map) => ScheduleModel.fromMap(map)).map((m) => Schedule(
      id: m.id,
      taskId: m.taskId,
      startTime: m.startTime,
      endTime: m.endTime,
      status: m.status,
      notes: m.notes,
      createdAt: m.createdAt,
      updatedAt: m.updatedAt,
    )).toList();
  }

  @override
  Future<Schedule?> getScheduleById(int id) async {
    final map = await _localDataSource.getScheduleById(id);
    if (map == null) return null;
    final m = ScheduleModel.fromMap(map);
    return Schedule(
      id: m.id,
      taskId: m.taskId,
      startTime: m.startTime,
      endTime: m.endTime,
      status: m.status,
      notes: m.notes,
      createdAt: m.createdAt,
      updatedAt: m.updatedAt,
    );
  }

  @override
  Future<int> createSchedule(Schedule schedule) async {
    final m = ScheduleModel(
      id: schedule.id,
      taskId: schedule.taskId,
      startTime: schedule.startTime,
      endTime: schedule.endTime,
      status: schedule.status,
      notes: schedule.notes,
      createdAt: schedule.createdAt,
      updatedAt: schedule.updatedAt,
    );
    return _localDataSource.insertSchedule(m.toMap());
  }

  @override
  Future<void> updateSchedule(Schedule schedule) async {
    final m = ScheduleModel(
      id: schedule.id,
      taskId: schedule.taskId,
      startTime: schedule.startTime,
      endTime: schedule.endTime,
      status: schedule.status,
      notes: schedule.notes,
      createdAt: schedule.createdAt,
      updatedAt: schedule.updatedAt,
    );
    await _localDataSource.updateSchedule(schedule.id!, m.toMap());
  }

  @override
  Future<void> deleteSchedule(int id) async {
    await _localDataSource.deleteSchedule(id);
  }

  @override
  Future<List<Schedule>> getSchedulesByDate(DateTime date) async {
    final maps = await _localDataSource.getSchedulesByDate(date);
    return maps.map((map) => ScheduleModel.fromMap(map)).map((m) => Schedule(
      id: m.id,
      taskId: m.taskId,
      startTime: m.startTime,
      endTime: m.endTime,
      status: m.status,
      notes: m.notes,
      createdAt: m.createdAt,
      updatedAt: m.updatedAt,
    )).toList();
  }
}


