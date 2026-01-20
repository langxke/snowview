import 'package:hive_flutter/hive_flutter.dart';
import '../models/daily_plan_hive.dart';

class DailyPlanRepository {
  static const String boxName = 'daily_plans';

  Box<DailyPlanHive> get _box => Hive.box<DailyPlanHive>(boxName);

  /// 获取指定日期的计划
  /// 如果不存在，返回 null (不自动创建，留给 Provider 处理逻辑)
  DailyPlanHive? getPlan(String dateKey) {
    if (_box.containsKey(dateKey)) {
      return _box.get(dateKey);
    }
    return null;
  }

  /// 获取或创建计划
  Future<DailyPlanHive> getOrCreatePlan(String dateKey) async {
    if (_box.containsKey(dateKey)) {
      return _box.get(dateKey)!;
    }
    final plan = DailyPlanHive(dateKey: dateKey);
    await _box.put(dateKey, plan);
    return plan;
  }

  /// 保存/更新计划
  Future<void> savePlan(DailyPlanHive plan) async {
    await _box.put(plan.dateKey, plan);
  }

  /// 删除计划
  Future<void> deletePlan(String dateKey) async {
    await _box.delete(dateKey);
  }

  /// 获取所有计划
  List<DailyPlanHive> getAllPlans() {
    return _box.values.toList();
  }
}
