import 'package:flutter/material.dart';
import '../../../../data/models/task_category_hive.dart';
import '../widgets/color_picker.dart';

/// 创建/编辑类别对话框
class CategoryDialog extends StatefulWidget {
  final TaskCategoryHive? category; // null表示创建新类别
  final VoidCallback? onDeleted; // 删除回调

  const CategoryDialog({
    super.key,
    this.category,
    this.onDeleted,
  });

  /// 显示创建类别对话框
  static Future<CategoryDialogResult?> showCreate(BuildContext context) {
    return showDialog<CategoryDialogResult>(
      context: context,
      builder: (context) => const CategoryDialog(),
    );
  }

  /// 显示编辑类别对话框
  static Future<CategoryDialogResult?> showEdit(
    BuildContext context,
    TaskCategoryHive category,
    VoidCallback onDeleted,
  ) {
    return showDialog<CategoryDialogResult>(
      context: context,
      builder: (context) => CategoryDialog(
        category: category,
        onDeleted: onDeleted,
      ),
    );
  }

  @override
  State<CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<CategoryDialog> {
  late TextEditingController _nameController;
  late Color _selectedColor;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.category != null;
    _nameController = TextEditingController(
      text: widget.category?.name ?? '',
    );
    _selectedColor = widget.category?.color ?? ColorPicker.categoryColors[0];
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? '编辑类别' : '创建类别'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 名称输入
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '类别名称',
                  hintText: '例如：工作、学习、生活',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.folder_outlined),
                ),
                autofocus: true,
                textCapitalization: TextCapitalization.words,
              ),

              const SizedBox(height: 24),

              // 颜色选择器
              ColorPicker(
                selectedColor: _selectedColor,
                onColorSelected: (color) {
                  setState(() {
                    _selectedColor = color;
                  });
                },
              ),

              // 删除按钮（仅编辑时显示）
              if (_isEditing) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _handleDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('删除此类别'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _handleSave,
          child: Text(_isEditing ? '保存' : '创建'),
        ),
      ],
    );
  }

  void _handleSave() {
    final name = _nameController.text.trim();
    
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入类别名称')),
      );
      return;
    }

    Navigator.pop(
      context,
      CategoryDialogResult(
        action: _isEditing ? CategoryAction.update : CategoryAction.create,
        name: name,
        color: _selectedColor,
      ),
    );
  }

  void _handleDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除类别后，该类别下的所有任务将无法访问。确定要删除吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context); // 关闭确认对话框
              Navigator.pop(context); // 关闭类别对话框
              if (widget.onDeleted != null) {
                widget.onDeleted!();
              }
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
}

/// 类别对话框操作类型
enum CategoryAction {
  create,
  update,
  delete,
}

/// 类别对话框返回结果
class CategoryDialogResult {
  final CategoryAction action;
  final String name;
  final Color color;

  CategoryDialogResult({
    required this.action,
    required this.name,
    required this.color,
  });
}

