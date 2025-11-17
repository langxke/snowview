// 日程服务（规划算法占位）
import '../domain/entities/schedule.dart';

abstract class ScheduleService {
	List<Schedule> generateDailyPlan({required DateTime day, required List<int> taskIds});
}
