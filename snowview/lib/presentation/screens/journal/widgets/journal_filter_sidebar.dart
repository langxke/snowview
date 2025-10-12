import 'package:flutter/material.dart';

/// 记录筛选侧边栏
class JournalFilterSidebar extends StatelessWidget {
  final String selectedType;
  final String? selectedTag;
  final Map<String, int> entryCountByType;
  final List<String> allTags;
  final ValueChanged<String> onTypeSelected;
  final ValueChanged<String?> onTagSelected;

  const JournalFilterSidebar({
    super.key,
    required this.selectedType,
    this.selectedTag,
    required this.entryCountByType,
    required this.allTags,
    required this.onTypeSelected,
    required this.onTagSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 标题
          Text(
            '记录',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // 类型筛选
          _buildFilterItem(
            context,
            icon: Icons.inbox,
            label: '全部',
            type: 'all',
            count: entryCountByType['all'] ?? 0,
          ),
          _buildFilterItem(
            context,
            icon: Icons.book,
            label: '日记',
            type: 'diary',
            count: entryCountByType['diary'] ?? 0,
          ),
          _buildFilterItem(
            context,
            icon: Icons.calendar_view_week,
            label: '周记',
            type: 'weekly',
            count: entryCountByType['weekly'] ?? 0,
          ),
          _buildFilterItem(
            context,
            icon: Icons.lightbulb_outline,
            label: '随笔',
            type: 'note',
            count: entryCountByType['note'] ?? 0,
          ),
          
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          
          // 标签筛选
          Text(
            '标签',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          
          if (allTags.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '暂无标签',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...allTags.map((tag) {
              return _buildTagItem(context, tag);
            }),
        ],
      ),
    );
  }

  /// 构建类型筛选项
  Widget _buildFilterItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String type,
    required int count,
  }) {
    final isSelected = selectedType == type;
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => onTypeSelected(type),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer.withOpacity(0.5)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (count > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isSelected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 构建标签项
  Widget _buildTagItem(BuildContext context, String tag) {
    final isSelected = selectedTag == tag;
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => onTagSelected(isSelected ? null : tag),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.secondaryContainer.withOpacity(0.5)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Text(
              '#',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                tag,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.onSecondaryContainer
                      : theme.colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

