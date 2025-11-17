import 'package:flutter/material.dart';
import '../../../../data/models/journal_category_hive.dart';
import '../../../screens/tasks/widgets/color_picker.dart';

/// 记录类别对话框
class JournalCategoryDialog extends StatefulWidget {
  final JournalCategoryHive? category;

  const JournalCategoryDialog({
    super.key,
    this.category,
  });

  /// 显示创建对话框
  static Future<Map<String, dynamic>?> showCreate(BuildContext context) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const JournalCategoryDialog(),
    );
  }

  /// 显示编辑对话框
  static Future<Map<String, dynamic>?> showEdit(
    BuildContext context,
    JournalCategoryHive category,
  ) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => JournalCategoryDialog(category: category),
    );
  }

  @override
  State<JournalCategoryDialog> createState() => _JournalCategoryDialogState();
}

class _JournalCategoryDialogState extends State<JournalCategoryDialog> {
  late TextEditingController _nameController;
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _selectedColor = widget.category?.color ?? Colors.blue;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.category != null;

    return AlertDialog(
      title: Text(isEditing ? '编辑类别' : '创建类别'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 名称输入
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '类别名称',
                hintText: '如：工作日志、学习笔记',
                prefixIcon: Icon(Icons.folder_outlined),
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 20),

            // 颜色选择
            ColorPicker(
              selectedColor: _selectedColor,
              onColorSelected: (color) {
                setState(() {
                  _selectedColor = color;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        // 取消
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),

        // 保存/创建
        FilledButton(
          onPressed: () {
            if (_nameController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请输入类别名称')),
              );
              return;
            }

            Navigator.of(context).pop({
              'action': 'save',
              'name': _nameController.text.trim(),
              'color': _selectedColor,
            });
          },
          child: Text(isEditing ? '保存' : '创建'),
        ),
      ],
    );
  }
}


