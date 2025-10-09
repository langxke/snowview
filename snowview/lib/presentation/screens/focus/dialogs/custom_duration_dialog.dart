import 'package:flutter/material.dart';

/// 自定义时长对话框
class CustomDurationDialog extends StatefulWidget {
  const CustomDurationDialog({super.key});

  /// 显示对话框
  static Future<int?> show(BuildContext context) {
    return showDialog<int>(
      context: context,
      builder: (context) => const CustomDurationDialog(),
    );
  }

  @override
  State<CustomDurationDialog> createState() => _CustomDurationDialogState();
}

class _CustomDurationDialogState extends State<CustomDurationDialog> {
  double _selectedMinutes = 25.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      title: const Text('选择专注时长'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 时长显示
            Text(
              '${_selectedMinutes.toInt()} 分钟',
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.w300,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            
            // 滑块
            Slider(
              value: _selectedMinutes,
              min: 5,
              max: 120,
              divisions: 23,  // 5, 10, 15, ... 120
              label: '${_selectedMinutes.toInt()}分钟',
              onChanged: (value) {
                setState(() {
                  _selectedMinutes = value;
                });
              },
            ),
            
            // 快捷选项
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildQuickOption(15),
                _buildQuickOption(25),
                _buildQuickOption(30),
                _buildQuickOption(45),
                _buildQuickOption(60),
                _buildQuickOption(90),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(_selectedMinutes.toInt());
          },
          child: const Text('开始'),
        ),
      ],
    );
  }

  /// 快捷选项按钮
  Widget _buildQuickOption(int minutes) {
    final isSelected = _selectedMinutes.toInt() == minutes;
    
    return ChoiceChip(
      label: Text('${minutes}分'),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedMinutes = minutes.toDouble();
          });
        }
      },
    );
  }
}

