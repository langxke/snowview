import 'package:flutter/material.dart';

/// 颜色选择器组件
class ColorPicker extends StatelessWidget {
  final Color selectedColor;
  final ValueChanged<Color> onColorSelected;

  const ColorPicker({
    super.key,
    required this.selectedColor,
    required this.onColorSelected,
  });

  /// 预设颜色列表
  static const List<Color> categoryColors = [
    Color(0xFFEF5350), // 红色
    Color(0xFFFF7043), // 橙色
    Color(0xFFFFA726), // 深橙色
    Color(0xFFFFEE58), // 黄色
    Color(0xFF66BB6A), // 绿色
    Color(0xFF26A69A), // 青色
    Color(0xFF42A5F5), // 蓝色
    Color(0xFF5C6BC0), // 靛蓝色
    Color(0xFF7E57C2), // 紫色
    Color(0xFFEC407A), // 粉色
    Color(0xFF8D6E63), // 棕色
    Color(0xFF78909C), // 蓝灰色
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '选择颜色',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: categoryColors.map((color) {
            final isSelected = color.value == selectedColor.value;
            return _ColorItem(
              color: color,
              isSelected: isSelected,
              onTap: () => onColorSelected(color),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// 单个颜色项
class _ColorItem extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorItem({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 3,
                )
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: isSelected
            ? const Icon(
                Icons.check,
                color: Colors.white,
                size: 24,
              )
            : null,
      ),
    );
  }
}

