import 'package:flutter/material.dart';
import '../../../../data/models/work_session_hive.dart';
import '../../../../data/models/subtask_hive.dart';

/// 工作会话结果数据
class WorkSessionResult {
  final DateTime startTime;
  final DateTime endTime;
  final String? subTaskId;
  final String? note;

  WorkSessionResult({
    required this.startTime,
    required this.endTime,
    this.subTaskId,
    this.note,
  });
}

/// 工作会话编辑对话框
class WorkSessionDialog extends StatefulWidget {
  final String taskId;
  final List<SubTaskHive> subTasks;
  final DateTime? initialDate;
  final WorkSessionHive? editingSession;  // 编辑模式

  const WorkSessionDialog({
    Key? key,
    required this.taskId,
    required this.subTasks,
    this.initialDate,
    this.editingSession,
  }) : super(key: key);

  /// 显示对话框
  static Future<WorkSessionResult?> show(
    BuildContext context, {
    required String taskId,
    required List<SubTaskHive> subTasks,
    DateTime? initialDate,
    WorkSessionHive? editingSession,
  }) {
    return showDialog<WorkSessionResult>(
      context: context,
      builder: (context) => WorkSessionDialog(
        taskId: taskId,
        subTasks: subTasks,
        initialDate: initialDate,
        editingSession: editingSession,
      ),
    );
  }

  @override
  State<WorkSessionDialog> createState() => _WorkSessionDialogState();
}

class _WorkSessionDialogState extends State<WorkSessionDialog> {
  late DateTime _selectedDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  String? _selectedSubTaskId;
  final _noteController = TextEditingController();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    
    if (widget.editingSession != null) {
      // 编辑模式：使用现有数据
      final session = widget.editingSession!;
      _selectedDate = DateTime(
        session.startTime.year,
        session.startTime.month,
        session.startTime.day,
      );
      _startTime = TimeOfDay.fromDateTime(session.startTime);
      _endTime = TimeOfDay.fromDateTime(session.endTime);
      _selectedSubTaskId = session.subTaskId;
      _noteController.text = session.note ?? '';
    } else {
      // 新建模式：使用初始值或默认值
      _selectedDate = widget.initialDate ?? DateTime.now();
      final now = DateTime.now();
      // 默认开始时间：下一个整点
      final nextHour = now.add(const Duration(hours: 1));
      _startTime = TimeOfDay(hour: nextHour.hour, minute: 0);
      // 默认结束时间：开始后1小时
      _endTime = TimeOfDay(hour: (nextHour.hour + 1) % 24, minute: 0);
      _noteController.text = '';
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  bool _validateTimes() {
    final start = _combineDateAndTime(_selectedDate, _startTime);
    final end = _combineDateAndTime(_selectedDate, _endTime);
    
    if (!end.isAfter(start)) {
      setState(() {
        _errorMessage = '结束时间必须晚于开始时间';
      });
      return false;
    }
    
    setState(() {
      _errorMessage = null;
    });
    return true;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _validateTimes();
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    
    if (picked != null) {
      setState(() {
        _startTime = picked;
      });
      _validateTimes();
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    
    if (picked != null) {
      setState(() {
        _endTime = picked;
      });
      _validateTimes();
    }
  }

  void _submit() {
    if (!_validateTimes()) {
      return;
    }
    
    final result = WorkSessionResult(
      startTime: _combineDateAndTime(_selectedDate, _startTime),
      endTime: _combineDateAndTime(_selectedDate, _endTime),
      subTaskId: _selectedSubTaskId,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
    );
    
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.editingSession != null;
    
    return AlertDialog(
      title: Text(isEditing ? '编辑工作会话' : '新建工作会话'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日期选择
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('日期'),
              subtitle: Text(_formatDate(_selectedDate)),
              onTap: _pickDate,
              contentPadding: EdgeInsets.zero,
            ),
            
            const SizedBox(height: 8),
            
            // 时间范围
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    leading: const Icon(Icons.access_time),
                    title: const Text('开始'),
                    subtitle: Text(_formatTime(_startTime)),
                    onTap: _pickStartTime,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('-'),
                const SizedBox(width: 8),
                Expanded(
                  child: ListTile(
                    title: const Text('结束'),
                    subtitle: Text(_formatTime(_endTime)),
                    onTap: _pickEndTime,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            
            // 错误提示
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // 子步骤选择
            if (widget.subTasks.isNotEmpty) ...[
              const Text('关联到', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                value: _selectedSubTaskId,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('整个任务'),
                  ),
                  ...widget.subTasks.map((subTask) => DropdownMenuItem<String?>(
                    value: subTask.id,
                    child: Text(subTask.title),
                  )),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedSubTaskId = value;
                  });
                },
              ),
              const SizedBox(height: 16),
            ],
            
            // 备注输入
            const Text('备注', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '添加备注（可选）',
                contentPadding: EdgeInsets.all(12),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(isEditing ? '保存' : '创建'),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

