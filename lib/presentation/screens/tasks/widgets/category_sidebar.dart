import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/task_list_provider.dart';
import '../dialogs/category_dialog.dart';
import 'category_item.dart';

/// 左侧类别栏组件
class CategorySidebar extends StatelessWidget {
  const CategorySidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskListProvider>(
      builder: (context, provider, child) {
        return PopupMenuTheme(
          data: PopupMenuThemeData(
            // 禁用动画效果
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
            border: Border(
              right: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              // 头部
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Text(
                      '清单',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              
              // 类别列表
              Expanded(
                child: Column(
                  children: [
                    // "全部"特殊类别
                    CategoryItem.special(
                      id: 'all',
                      name: '全部',
                      icon: Icons.inbox,
                      count: provider.tasks.where((t) => !t.isCompleted).length,
                      isSelected: provider.selectedCategoryId == 'all',
                      onTap: () => provider.selectCategory('all'),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // 用户创建的类别（可拖动排序）
                    Expanded(
                      child: ReorderableListView.builder(
                        itemCount: provider.categories.length,
                        buildDefaultDragHandles: false,
                        onReorder: (oldIndex, newIndex) {
                          provider.reorderCategories(oldIndex, newIndex);
                        },
                        itemBuilder: (context, index) {
                          final category = provider.categories[index];
                          final count = provider.getCategoryTaskCount(category.id);
                          final isSelected = provider.selectedCategoryId == category.id;
                          
                          return ReorderableDragStartListener(
                            key: ValueKey(category.id),
                            index: index,
                            child: GestureDetector(
                              onSecondaryTapDown: (details) {
                                _showContextMenu(context, provider, category, details.globalPosition);
                              },
                              child: Material(
                                color: Colors.transparent,
                                child: ListTile(
                                  selected: isSelected,
                                  leading: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: category.color,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  title: Text(
                                    category.name,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                  trailing: count > 0
                                      ? Container(
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
                                        )
                                      : null,
                                  onTap: () => provider.selectCategory(category.id),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              
              // 底部按钮
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => _handleCreateCategory(context, provider),
                    icon: const Icon(Icons.add),
                    label: const Text('新建类别'),
                  ),
                ),
              ),
            ],
          ),
          ),
        );
      },
    );
  }

  /// 显示右键上下文菜单
  Future<void> _showContextMenu(
    BuildContext context,
    TaskListProvider provider,
    dynamic category,
    Offset position,
  ) async {
    final RenderBox? overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        overlay?.size.width ?? position.dx,
        overlay?.size.height ?? position.dy,
      ),
      items: [
        const PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 18),
              SizedBox(width: 12),
              Text('编辑类别'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18),
              SizedBox(width: 12),
              Text('删除类别'),
            ],
          ),
        ),
      ],
      elevation: 8.0,
      // 禁用动画
      popUpAnimationStyle: AnimationStyle.noAnimation,
    );

    if (!context.mounted) return;

    switch (result) {
      case 'edit':
        _handleEditCategory(context, provider, category);
        break;
      case 'delete':
        _handleDeleteCategory(context, provider, category);
        break;
    }
  }

  /// 处理创建类别
  Future<void> _handleCreateCategory(
    BuildContext context,
    TaskListProvider provider,
  ) async {
    final result = await CategoryDialog.showCreate(context);
    if (result == null || !context.mounted) return;

    try {
      await provider.createCategory(
        name: result.name,
        color: result.color,
      );
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('类别 "${result.name}" 创建成功')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('创建失败: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// 处理编辑类别
  Future<void> _handleEditCategory(
    BuildContext context,
    TaskListProvider provider,
    dynamic category,
  ) async {
    final result = await CategoryDialog.showEdit(
      context,
      category,
      () => _handleDeleteCategory(context, provider, category),
    );
    
    if (result == null || !context.mounted) return;

    try {
      await provider.updateCategory(
        id: category.id,
        name: result.name,
        color: result.color,
      );
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('类别 "${result.name}" 更新成功')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('更新失败: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// 处理删除类别
  Future<void> _handleDeleteCategory(
    BuildContext context,
    TaskListProvider provider,
    dynamic category,
  ) async {
    // 检查是否有任务
    final taskCount = provider.getCategoryTaskCount(category.id);
    
    if (taskCount > 0) {
      if (!context.mounted) return;
      
      // 显示错误提示
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('无法删除'),
          content: Text('该类别下还有 $taskCount 个任务，无法删除。\n请先删除或移动这些任务。'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
      return;
    }

    // 显示确认对话框
    if (!context.mounted) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除类别 "${category.name}" 吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await provider.deleteCategory(category.id);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('类别 "${category.name}" 已删除')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除失败: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
