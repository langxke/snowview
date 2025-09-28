// 任务数据仓库实现
import '../datasources/local_datasource.dart';
import '../models/task_model.dart';
import '../../domain/repositories/task_repository_interface.dart';
import '../../domain/entities/task.dart';

class TaskRepository implements TaskRepositoryInterface {
  final LocalDataSource _localDataSource;
  
  const TaskRepository(this._localDataSource);
  
  @override
  Future<List<Task>> getTasks() async {
    final taskMaps = await _localDataSource.getTasks();
    return taskMaps.map((map) => TaskModel.fromMap(map)).map((m) => Task(
      id: m.id,
      title: m.title,
      description: m.description,
      priority: m.priority,
      category: m.category,
      estimatedDuration: m.estimatedDuration,
      actualDuration: m.actualDuration,
      status: m.status,
      parentTaskId: m.parentTaskId,
      createdAt: m.createdAt,
      updatedAt: m.updatedAt,
    )).toList();
  }

  @override
  Future<Task?> getTaskById(int id) async {
    final taskMap = await _localDataSource.getTaskById(id);
    if (taskMap == null) return null;
    final m = TaskModel.fromMap(taskMap);
    return Task(
      id: m.id,
      title: m.title,
      description: m.description,
      priority: m.priority,
      category: m.category,
      estimatedDuration: m.estimatedDuration,
      actualDuration: m.actualDuration,
      status: m.status,
      parentTaskId: m.parentTaskId,
      createdAt: m.createdAt,
      updatedAt: m.updatedAt,
    );
  }

  @override
  Future<int> createTask(Task task) async {
    final model = TaskModel(
      id: task.id,
      title: task.title,
      description: task.description,
      priority: task.priority,
      category: task.category,
      estimatedDuration: task.estimatedDuration,
      actualDuration: task.actualDuration,
      status: task.status,
      parentTaskId: task.parentTaskId,
      createdAt: task.createdAt,
      updatedAt: task.updatedAt,
    );
    return _localDataSource.insertTask(model.toMap());
  }

  @override
  Future<void> updateTask(Task task) async {
    final model = TaskModel(
      id: task.id,
      title: task.title,
      description: task.description,
      priority: task.priority,
      category: task.category,
      estimatedDuration: task.estimatedDuration,
      actualDuration: task.actualDuration,
      status: task.status,
      parentTaskId: task.parentTaskId,
      createdAt: task.createdAt,
      updatedAt: task.updatedAt,
    );
    await _localDataSource.updateTask(task.id!, model.toMap());
  }

  @override
  Future<void> deleteTask(int id) async {
    await _localDataSource.deleteTask(id);
  }

  @override
  Future<List<Task>> getTasksByStatus(String status) async {
    final maps = await _localDataSource.getTasksByStatus(status);
    return maps.map((map) => TaskModel.fromMap(map)).map((m) => Task(
      id: m.id,
      title: m.title,
      description: m.description,
      priority: m.priority,
      category: m.category,
      estimatedDuration: m.estimatedDuration,
      actualDuration: m.actualDuration,
      status: m.status,
      parentTaskId: m.parentTaskId,
      createdAt: m.createdAt,
      updatedAt: m.updatedAt,
    )).toList();
  }

  @override
  Future<List<Task>> getTasksByCategory(String category) async {
    final maps = await _localDataSource.getTasksByCategory(category);
    return maps.map((map) => TaskModel.fromMap(map)).map((m) => Task(
      id: m.id,
      title: m.title,
      description: m.description,
      priority: m.priority,
      category: m.category,
      estimatedDuration: m.estimatedDuration,
      actualDuration: m.actualDuration,
      status: m.status,
      parentTaskId: m.parentTaskId,
      createdAt: m.createdAt,
      updatedAt: m.updatedAt,
    )).toList();
  }
}


