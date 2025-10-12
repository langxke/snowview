import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/journal_entry_hive.dart';
import '../../providers/journal_provider.dart';
import 'widgets/journal_category_sidebar.dart';
import 'widgets/journal_list_panel.dart';
import 'widgets/journal_detail_panel.dart';
import 'dialogs/journal_editor_dialog.dart';

/// 记录主页面（三栏布局）
class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<JournalProvider>(
        builder: (context, provider, child) {
          final selectedEntry = provider.selectedEntry;

          return Row(
            children: [
              // 左：类别栏（200px，始终显示）
              JournalCategorySidebar(
                categories: provider.categories,
                selectedCategoryId: provider.selectedCategoryId,
                entryCountByCategory: provider.entryCountByCategory,
                onCategorySelected: provider.selectCategory,
                onCategoriesChanged: () => _handleCategoryChange(context, provider),
              ),

              // 中：根据状态显示列表或详情（最大化显示）
              Expanded(
                child: selectedEntry == null
                    // 未选中：显示记录列表
                    ? JournalListPanel(
                        entries: provider.entries,
                        selectedEntryId: provider.selectedEntryId,
                        currentCategory: provider.selectedCategory,
                        onEntryTap: provider.selectEntry,
                        onCreateEntry: () => _createEntry(context, provider),
                        onEditEntry: (entry) => _editEntry(context, provider, entry),
                        onDeleteEntry: (entryId) => _deleteEntry(context, provider, entryId),
                        onTogglePin: provider.togglePin,
                      )
                    // 已选中：详情面板最大化显示
                    : JournalDetailPanel(
                        entry: selectedEntry,
                        onClose: () => provider.selectEntry(null),
                        onUpdate: provider.updateEntry,
                        onDelete: () => _deleteEntry(context, provider, selectedEntry.id),
                        onTogglePin: () => provider.togglePin(selectedEntry.id),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 处理类别变更
  Future<void> _handleCategoryChange(
    BuildContext context,
    JournalProvider provider,
  ) async {
    await provider.reload();
  }

  /// 创建记录
  Future<void> _createEntry(
    BuildContext context,
    JournalProvider provider,
  ) async {
    final categoryId = provider.selectedCategoryId == 'all' 
        ? 'note' 
        : provider.selectedCategoryId;

    final result = await JournalEditorDialog.showCreate(context, categoryId);

    if (result != null && result['action'] == 'save') {
      await provider.createEntry(
        categoryId: categoryId,
        title: result['title'] ?? '',
        content: result['content'] ?? '',
        tags: result['tags'] ?? [],
        mood: result['mood'],
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('记录已保存'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  /// 编辑记录（通过对话框）
  Future<void> _editEntry(
    BuildContext context,
    JournalProvider provider,
    JournalEntryHive entry,
  ) async {
    final result = await JournalEditorDialog.showEdit(context, entry);

    if (result == null) return;

    if (result['action'] == 'delete') {
      await _deleteEntry(context, provider, entry.id);
    } else if (result['action'] == 'save') {
      final updated = entry.copyWith(
        title: result['title'] ?? '',
        content: result['content'] ?? '',
        tags: result['tags'] ?? [],
        mood: result['mood'],
      );

      await provider.updateEntry(updated);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('记录已更新'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  /// 删除记录
  Future<void> _deleteEntry(
    BuildContext context,
    JournalProvider provider,
    String entryId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条记录吗？此操作无法撤销。'),
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
      await provider.deleteEntry(entryId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('记录已删除'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }
}
