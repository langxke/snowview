// 根据任务生成日程（简化占位实现，修复 final 变量重复赋值问题）
import '../entities/schedule.dart';

class GenerateScheduleUseCase {
  List<Schedule> generate({
    required DateTime day,
    required List<int> taskIds,
  }) {
    final List<Schedule> schedules = [];
    DateTime currentStart = DateTime(day.year, day.month, day.day, 9, 0);

    for (final taskId in taskIds) {
      final DateTime taskStartTime = currentStart;
      final DateTime taskEndTime = taskStartTime.add(const Duration(minutes: 30));

      schedules.add(Schedule(
        taskId: taskId,
        startTime: taskStartTime,
        endTime: taskEndTime,
        status: 'scheduled',
        notes: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      currentStart = taskEndTime.add(const Duration(minutes: 10));
    }

    return schedules;
  }
}


