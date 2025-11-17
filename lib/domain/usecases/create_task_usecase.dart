// 创建任务用例（接口对齐文档结构，具体实现留空）
import '../entities/task.dart';
import '../repositories/task_repository_interface.dart';

class CreateTaskUseCase {
  final TaskRepositoryInterface _repo;
  const CreateTaskUseCase(this._repo);

  Future<int> execute({
    required String title,
    String? description,
    int priority = 1,
    String? category,
    int? estimatedDuration,
    int? parentTaskId,
  }) async {
    final now = DateTime.now();
    final task = Task(
      title: title,
      description: description,
      priority: priority,
      category: category,
      estimatedDuration: estimatedDuration,
      actualDuration: null,
      status: 'pending',
      parentTaskId: parentTaskId,
      createdAt: now,
      updatedAt: now,
    );
    return _repo.createTask(task);
  }
}


