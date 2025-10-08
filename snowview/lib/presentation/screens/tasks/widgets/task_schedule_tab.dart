import 'package:flutter/material.dart';
import '../../../../data/models/work_session_hive.dart';

/// 任务的时间规划标签页
class TaskScheduleTab extends StatelessWidget {
  final String taskId;
  final List<WorkSessionHive> sessions;
  final VoidCallback onAddSession;
  final Function(WorkSessionHive) onEditSession;
  final Function(String) onDeleteSession;
  final Function(String) onMarkComplete;
  final Function(WorkSessionHive) onStartFocus;  // 启动专注功能

  const TaskScheduleTab({
    Key? key,
    required this.taskId,
    required this.sessions,
    required this.onAddSession,
    required this.onEditSession,
    required this.onDeleteSession,
    required this.onMarkComplete,
    required this.onStartFocus,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 按状态分组（只保留：计划中、已完成、已取消）
    final plannedSessions = sessions.where((s) => s.isPlanned).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final completedSessions = sessions.where((s) => s.isCompleted).toList()
      ..sort((a, b) => b.endTime.compareTo(a.endTime));
    final cancelledSessions = sessions.where((s) => s.isCancelled).toList()
      ..sort((a, b) => b.endTime.compareTo(a.endTime));
    
    // 计算统计数据（排除已取消的会话）
    final activeSessions = sessions.where((s) => !s.isCancelled).toList();
    final totalPlanned = activeSessions.fold<int>(0, (sum, s) => sum + s.plannedDuration);
    final sessionCount = activeSessions.length;
    final completedCount = completedSessions.length;
    
    // 计算进度（按会话数量）
    final progress = sessionCount > 0 ? completedCount / sessionCount : 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 统计卡片
        _buildStatisticsCard(
          context,
          sessionCount: sessionCount,
          completedCount: completedCount,
          totalPlanned: totalPlanned,
          progress: progress,
        ),
        
        const SizedBox(height: 16),
        
        // 计划中的会话
        if (plannedSessions.isNotEmpty) ...[
          _buildSectionHeader(context, '计划中', plannedSessions.length),
          const SizedBox(height: 8),
          ...plannedSessions.map((session) => _buildPlannedSessionCard(
            context,
            session,
          )),
          const SizedBox(height: 16),
        ],
        
        // 已完成的会话
        if (completedSessions.isNotEmpty) ...[
          _buildSectionHeader(context, '已完成', completedSessions.length),
          const SizedBox(height: 8),
          ...completedSessions.map((session) => _buildCompletedSessionCard(
            context,
            session,
          )),
          const SizedBox(height: 16),
        ],
        
        // 已取消的会话
        if (cancelledSessions.isNotEmpty) ...[
          _buildSectionHeader(context, '已取消', cancelledSessions.length),
          const SizedBox(height: 8),
          ...cancelledSessions.map((session) => _buildCancelledSessionCard(
            context,
            session,
          )),
          const SizedBox(height: 16),
        ],
        
        // 空状态提示
        if (sessions.isEmpty)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 32),
                Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  '暂无工作会话',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        
        // 添加会话按钮
        FilledButton.icon(
          onPressed: onAddSession,
          icon: const Icon(Icons.add),
          label: const Text('安排工作时间'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildStatisticsCard(
    BuildContext context, {
    required int sessionCount,
    required int completedCount,
    required int totalPlanned,
    required double progress,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.insights,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '完成进度',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 进度条
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 12,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // 统计数据
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  context,
                  label: '已完成',
                  value: '$completedCount/$sessionCount',
                  icon: Icons.check_circle_outline,
                  color: Colors.green,
                ),
                _buildStatItem(
                  context,
                  label: '已安排',
                  value: '$sessionCount 个',
                  icon: Icons.event_available,
                  color: Colors.blue,
                ),
                _buildStatItem(
                  context,
                  label: '计划时长',
                  value: _formatDuration(totalPlanned),
                  icon: Icons.schedule,
                  color: Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 24, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  // 计划中的会话卡片
  Widget _buildPlannedSessionCard(
    BuildContext context,
    WorkSessionHive session,
  ) {
    final startDate = _formatDate(session.startTime);
    final startTime = _formatTime(session.startTime);
    final endTime = _formatTime(session.endTime);
    final duration = session.plannedDuration;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 时间信息行
            Row(
              children: [
                Icon(Icons.schedule, size: 18, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  '$startDate $startTime - $endTime',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Chip(
                  label: Text(
                    _formatDuration(duration),
                    style: const TextStyle(fontSize: 12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            
            // 备注（如有）
            if (session.note != null && session.note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                session.note!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[700],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            
            const SizedBox(height: 12),
            
            // 操作按钮行
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => onStartFocus(session),
                    icon: const Icon(Icons.play_circle, size: 18),
                    label: const Text('开始专注'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => onMarkComplete(session.id),
                  icon: const Icon(Icons.check_circle_outline),
                  tooltip: '标记完成',
                  style: IconButton.styleFrom(
                    side: BorderSide(color: Colors.grey[300]!),
                    foregroundColor: Colors.green,
                  ),
                ),
                IconButton(
                  onPressed: () => onEditSession(session),
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: '编辑',
                  style: IconButton.styleFrom(
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                IconButton(
                  onPressed: () => onDeleteSession(session.id),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: '删除',
                  style: IconButton.styleFrom(
                    side: BorderSide(color: Colors.grey[300]!),
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 已完成的会话卡片
  Widget _buildCompletedSessionCard(
    BuildContext context,
    WorkSessionHive session,
  ) {
    final startDate = _formatDate(session.startTime);
    final startTime = _formatTime(session.startTime);
    final endTime = _formatTime(session.endTime);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      color: Colors.green[50],
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green[100],
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_circle, color: Colors.green[700], size: 20),
        ),
        title: Text(
          '$startDate $startTime - $endTime',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        subtitle: session.focusSessionId != null
            ? Text(
                '已完成（通过专注会话）',
                style: TextStyle(color: Colors.green[700], fontSize: 12),
              )
            : const Text(
                '已完成',
                style: TextStyle(fontSize: 12),
              ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'delete') {
              onDeleteSession(session.id);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('删除', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 已取消的会话卡片
  Widget _buildCancelledSessionCard(
    BuildContext context,
    WorkSessionHive session,
  ) {
    final startDate = _formatDate(session.startTime);
    final startTime = _formatTime(session.startTime);
    final endTime = _formatTime(session.endTime);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.grey[100],
      child: ListTile(
        leading: Icon(Icons.cancel_outlined, color: Colors.grey[600], size: 20),
        title: Text(
          '$startDate $startTime - $endTime',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Colors.grey[600],
            decoration: TextDecoration.lineThrough,
          ),
        ),
        subtitle: Text(
          '已取消',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        trailing: IconButton(
          onPressed: () => onDeleteSession(session.id),
          icon: const Icon(Icons.delete_outline),
          tooltip: '删除',
          color: Colors.grey[600],
        ),
      ),
    );
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes分钟';
    }
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) {
      return '$hours小时';
    }
    return '$hours小时$mins分钟';
  }
  
  String _formatDate(DateTime dateTime) {
    return '${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
  }
  
  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

