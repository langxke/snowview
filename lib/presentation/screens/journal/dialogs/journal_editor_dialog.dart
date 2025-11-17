import 'package:flutter/material.dart';
import '../../../../data/models/journal_entry_hive.dart';
import '../widgets/markdown_editor.dart';
// import '../widgets/tag_selector.dart';  // 暂时不使用
import '../widgets/mood_selector.dart';

/// 记录编辑对话框
class JournalEditorDialog extends StatefulWidget {
  final String categoryId;  // 类别ID
  final JournalEntryHive? editingEntry;  // 如果是编辑模式

  const JournalEditorDialog({
    super.key,
    required this.categoryId,
    this.editingEntry,
  });

  /// 显示创建对话框
  static Future<Map<String, dynamic>?> showCreate(
    BuildContext context,
    String categoryId,
  ) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => JournalEditorDialog(categoryId: categoryId),
    );
  }

  /// 显示编辑对话框
  static Future<Map<String, dynamic>?> showEdit(
    BuildContext context,
    JournalEntryHive entry,
  ) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => JournalEditorDialog(
        categoryId: entry.categoryId,
        editingEntry: entry,
      ),
    );
  }

  @override
  State<JournalEditorDialog> createState() => _JournalEditorDialogState();
}

class _JournalEditorDialogState extends State<JournalEditorDialog> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late List<String> _selectedTags;
  String? _selectedMood;

  @override
  void initState() {
    super.initState();
    
    // 初始化控制器
    _titleController = TextEditingController(
      text: widget.editingEntry?.title ?? '',
    );
    _contentController = TextEditingController(
      text: widget.editingEntry?.content ?? _getDefaultTemplate(),
    );
    _selectedTags = widget.editingEntry?.tags.toList() ?? [];
    _selectedMood = widget.editingEntry?.mood;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  /// 获取默认模板
  String _getDefaultTemplate() {
    // 根据类别ID提供默认模板
    switch (widget.categoryId) {
      case 'daily':
        return '''# ${_getFormattedDate(DateTime.now())} 日记

## 今日完成
- 

## 收获和感悟
- 

## 明天计划
- 
''';
      case 'weekly':
        return '''# 第${_getWeekNumber()}周周记

## 本周成就
- 

## 遇到的挑战
- 

## 下周重点
- 
''';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.editingEntry != null;
    final title = isEditing ? '编辑${_getTypeName()}' : '新建${_getTypeName()}';

    return Dialog(
      child: Container(
        width: 800,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            Row(
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 标题输入框
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: '标题（可选）',
                hintText: '留空将使用默认标题',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.title, size: 20),
              ),
            ),
            const SizedBox(height: 16),

            // Markdown 编辑器
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: MarkdownEditor(
                  controller: _contentController,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 标签选择器（暂时隐藏）
            // TagSelector(
            //   selectedTags: _selectedTags,
            //   onTagsChanged: (tags) {
            //     setState(() {
            //       _selectedTags = tags;
            //     });
            //   },
            // ),
            // const SizedBox(height: 16),

            // 心情选择器
            MoodSelector(
              selectedMood: _selectedMood,
              onMoodChanged: (mood) {
                setState(() {
                  _selectedMood = mood;
                });
              },
            ),
            const SizedBox(height: 24),

            // 操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isEditing)
                  TextButton.icon(
                    onPressed: _confirmDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('删除'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _save,
                  child: Text(isEditing ? '保存' : '创建'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 保存
  void _save() {
    final result = {
      'action': 'save',
      'title': _titleController.text,
      'content': _contentController.text,
      'tags': _selectedTags,
      'mood': _selectedMood,
    };
    Navigator.of(context).pop(result);
  }

  /// 确认删除
  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条记录吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(); // 关闭确认对话框
              Navigator.of(context).pop({'action': 'delete'}); // 返回删除动作
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  /// 获取类型名称
  String _getTypeName() {
    // 简化为"记录"（类别名称会在主页面显示）
    return '记录';
  }

  /// 获取格式化日期
  String _getFormattedDate(DateTime date) {
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// 获取周数
  int _getWeekNumber() {
    final now = DateTime.now();
    final firstDayOfYear = DateTime(now.year, 1, 1);
    final daysSinceFirstDay = now.difference(firstDayOfYear).inDays;
    return (daysSinceFirstDay / 7).ceil() + 1;
  }
}

