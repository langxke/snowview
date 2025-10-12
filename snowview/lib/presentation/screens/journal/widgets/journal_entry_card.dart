import 'package:flutter/material.dart';
import '../../../../data/models/journal_entry_hive.dart';

/// 记录卡片组件
class JournalEntryCard extends StatelessWidget {
  final JournalEntryHive entry;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTogglePin;

  const JournalEntryCard({
    super.key,
    required this.entry,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.onTogglePin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: entry.isPinned ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: entry.isPinned 
              ? theme.colorScheme.primary.withOpacity(0.3)
              : theme.dividerColor,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 置顶图标
                  if (entry.isPinned)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.push_pin,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  
                  // 标题
                  Expanded(
                    child: Text(
                      entry.displayTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  
                  // 操作菜单
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    padding: EdgeInsets.zero,
                    itemBuilder: (context) => <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'edit',
                        onTap: onEdit,
                        child: const Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 12),
                            Text('编辑'),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'pin',
                        onTap: onTogglePin,
                        child: Row(
                          children: [
                            Icon(
                              entry.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                              size: 18,
                            ),
                            const SizedBox(width: 12),
                            Text(entry.isPinned ? '取消置顶' : '置顶'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem<String>(
                        value: 'delete',
                        onTap: onDelete,
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: theme.colorScheme.error),
                            const SizedBox(width: 12),
                            Text('删除', style: TextStyle(color: theme.colorScheme.error)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              // 日期和类型
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    entry.dateFormatted,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  
                  // 专注时长（如果有）
                  if (entry.dailyFocusMinutes != null) ...[
                    const SizedBox(width: 12),
                    Icon(
                      Icons.timer,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${entry.dailyFocusMinutes}分钟',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  
                  // 心情
                  if (entry.mood != null) ...[
                    const SizedBox(width: 12),
                    Text(
                      entry.mood!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ],
              ),
              
              // 内容摘要
              if (entry.content.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  entry.contentSummary,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              
              // 标签功能暂时移除
              // 如需启用，取消注释以下代码
              /*
              if (entry.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: entry.tags.take(3).map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '#$tag',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              */
            ],
          ),
        ),
      ),
    );
  }
}

