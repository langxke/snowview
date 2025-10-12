import 'package:flutter/material.dart';
import '../../../../data/models/journal_entry_hive.dart';
import '../../../../data/models/journal_category_hive.dart';
import 'journal_entry_card.dart';

/// 记录列表面板
class JournalListPanel extends StatelessWidget {
  final List<JournalEntryHive> entries;
  final String? selectedEntryId;
  final JournalCategoryHive? currentCategory;
  final ValueChanged<String> onEntryTap;
  final VoidCallback onCreateEntry;
  final Function(JournalEntryHive) onEditEntry;
  final Function(String) onDeleteEntry;
  final Function(String) onTogglePin;

  const JournalListPanel({
    super.key,
    required this.entries,
    this.selectedEntryId,
    this.currentCategory,
    required this.onEntryTap,
    required this.onCreateEntry,
    required this.onEditEntry,
    required this.onDeleteEntry,
    required this.onTogglePin,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 头部
        _buildHeader(context),

        // 列表
        Expanded(
          child: entries.isEmpty
              ? _buildEmptyState(context)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return JournalEntryCard(
                      entry: entry,
                      onTap: () => onEntryTap(entry.id),
                      onEdit: () => onEditEntry(entry),
                      onDelete: () => onDeleteEntry(entry.id),
                      onTogglePin: () => onTogglePin(entry.id),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// 构建头部
  Widget _buildHeader(BuildContext context) {
    final categoryName = currentCategory?.name ?? '全部';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Text(
            categoryName,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),

          // 新建按钮
          FilledButton.icon(
            onPressed: onCreateEntry,
            icon: const Icon(Icons.add, size: 20),
            label: const Text('新建'),
          ),
        ],
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(BuildContext context) {
    final categoryName = currentCategory?.name ?? '该类别';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_stories_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
          ),
          const SizedBox(height: 24),
          Text(
            '$categoryName暂无记录',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右上角"新建"开始记录',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }
}


