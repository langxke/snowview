import 'package:hive_flutter/hive_flutter.dart';
import '../data/models/checklist_task_hive.dart';
import '../data/repositories/task_list_repository.dart';

/// 清单任务数据库服务
class TaskDatabaseService {
  static bool _initialized = false;
  
  /// 初始化Hive数据库
  static Future<void> init() async {
    if (_initialized) return;
    
    // 注册Hive适配器
    if (!Hive.isAdapterRegistered(ChecklistTaskHiveAdapter().typeId)) {
      Hive.registerAdapter(ChecklistTaskHiveAdapter());
    }
    
    // 打开数据库boxes
    await TaskListRepository.init();
    
    _initialized = true;
  }
  
  /// 关闭数据库
  static Future<void> close() async {
    await TaskListRepository.close();
    _initialized = false;
  }
}

