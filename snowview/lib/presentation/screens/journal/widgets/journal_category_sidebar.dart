import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../data/models/journal_category_hive.dart';
import '../../../providers/journal_provider.dart';
import '../dialogs/journal_category_dialog.dart';

/// 记录类别侧边栏
class JournalCategorySidebar extends StatelessWidget {
  final List<JournalCategoryHive> categories;
  final String selectedCategoryId;
  final Map<String, int> entryCountByCategory;
  final ValueChanged<String> onCategorySelected;
  final VoidCallback onCategoriesChanged;

  const JournalCategorySidebar({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.entryCountByCategory,
    required this.onCategorySelected,
    required this.onCategoriesChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        children: [
          // 头部
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              '记录',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // 类别列表
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                // "全部"特殊类别
                _buildCategoryItem(
                  context,
                  id: 'all',
                  name: '全部',
                  icon: Icons.inbox,
                  count: entryCountByCategory['all'] ?? 0,
                ),

                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),

                // 用户类别
                ...categories.map((category) {
                  return _buildCategoryItem(
                    context,
                    id: category.id,
                    name: category.name,
                    color: category.color,
                    count: entryCountByCategory[category.id] ?? 0,
                    category: category,
                  );
                }),
              ],
            ),
          ),

          // 新建类别按钮
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _createCategory(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('新建类别'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建类别项
  Widget _buildCategoryItem(
    BuildContext context, {
    required String id,
    required String name,
    IconData? icon,
    Color? color,
    required int count,
    JournalCategoryHive? category,
  }) {
    final isSelected = selectedCategoryId == id;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onCategorySelected(id),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primaryContainer.withOpacity(0.5)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                // 图标或颜色点
                if (icon != null)
                  Icon(
                    icon,
                    size: 18,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  )
                else if (color != null)
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),

                const SizedBox(width: 12),

                // 名称
                Expanded(
                  child: Text(
                    name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isSelected
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurface,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // 数量徽章
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

                // 操作菜单（用户类别才有）
                if (category != null)
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_vert, size: 16),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: const Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 12),
                            Text('编辑'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: theme.colorScheme.error),
                            const SizedBox(width: 12),
                            Text('删除', style: TextStyle(color: theme.colorScheme.error)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editCategory(context, category);
                      } else if (value == 'delete') {
                        _deleteCategory(context, category);
                      }
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 创建类别
  Future<void> _createCategory(BuildContext context) async {
    final provider = context.read<JournalProvider>();
    final result = await JournalCategoryDialog.showCreate(context);

    if (result != null && result['action'] == 'save') {
      await provider.createCategory(
        name: result['name'],
        color: result['color'],
      );
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('类别已创建'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  /// 编辑类别
  Future<void> _editCategory(
    BuildContext context,
    JournalCategoryHive category,
  ) async {
    final provider = context.read<JournalProvider>();
    final result = await JournalCategoryDialog.showEdit(context, category);

    if (result != null && result['action'] == 'save') {
      await provider.updateCategory(
        id: category.id,
        name: result['name'],
        color: result['color'],
      );
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('类别已更新'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  /// 删除类别
  Future<void> _deleteCategory(
    BuildContext context,
    JournalCategoryHive category,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除类别「${category.name}」吗？\n该类别下的所有记录仍会保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final provider = context.read<JournalProvider>();
      await provider.deleteCategory(category.id);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('类别已删除'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }
}
