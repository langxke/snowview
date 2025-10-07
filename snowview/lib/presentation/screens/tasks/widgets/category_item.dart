import 'package:flutter/material.dart';
import '../../../../data/models/task_category_hive.dart';

/// 单个类别条目组件
class CategoryItem extends StatelessWidget {
  final TaskCategoryHive? category;
  final String? specialId; // 特殊类别ID（如'all'）
  final String name;
  final IconData? icon;
  final Color? color;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const CategoryItem({
    super.key,
    this.category,
    this.specialId,
    required this.name,
    this.icon,
    this.color,
    required this.count,
    required this.isSelected,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  /// 创建特殊类别（如"全部"）
  factory CategoryItem.special({
    required String id,
    required String name,
    required IconData icon,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return CategoryItem(
      specialId: id,
      name: name,
      icon: icon,
      count: count,
      isSelected: isSelected,
      onTap: onTap,
    );
  }

  /// 创建用户类别
  factory CategoryItem.user({
    Key? key,
    required TaskCategoryHive category,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return CategoryItem(
      key: key,
      category: category,
      name: category.name,
      color: category.color,
      count: count,
      isSelected: isSelected,
      onTap: onTap,
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isUserCategory = category != null;

    return ListTile(
      selected: isSelected,
      leading: _buildLeading(),
      title: Text(
        name,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      trailing: _buildTrailing(context),
      onTap: onTap,
      // 用户类别可以长按显示菜单
      onLongPress: isUserCategory ? () => _showContextMenu(context) : null,
    );
  }

  Widget _buildLeading() {
    if (icon != null) {
      return Icon(icon, size: 20);
    }
    
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget? _buildTrailing(BuildContext context) {
    final List<Widget> children = [];

    // 任务计数
    if (count > 0) {
      children.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.secondary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 12,
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      );
    }

    // 用户类别显示更多按钮
    if (category != null) {
      children.add(
        const SizedBox(width: 4),
      );
      children.add(
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 18),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('编辑'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 18),
                  SizedBox(width: 8),
                  Text('删除'),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'edit' && onEdit != null) {
              onEdit!();
            } else if (value == 'delete' && onDelete != null) {
              onDelete!();
            }
          },
        ),
      );
    }

    if (children.isEmpty) return null;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('编辑类别'),
              onTap: () {
                Navigator.pop(context);
                if (onEdit != null) onEdit!();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除类别'),
              onTap: () {
                Navigator.pop(context);
                if (onDelete != null) onDelete!();
              },
            ),
          ],
        ),
      ),
    );
  }
}

