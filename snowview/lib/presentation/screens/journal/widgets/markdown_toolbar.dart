import 'package:flutter/material.dart';

/// Markdown 格式化工具栏
class MarkdownToolbar extends StatelessWidget {
  final TextEditingController controller;

  const MarkdownToolbar({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Row(
        children: [
          _buildButton(
            context,
            icon: Icons.format_bold,
            tooltip: '粗体 (Ctrl+B)',
            onPressed: _insertBold,
          ),
          _buildButton(
            context,
            icon: Icons.format_italic,
            tooltip: '斜体 (Ctrl+I)',
            onPressed: _insertItalic,
          ),
          _buildButton(
            context,
            icon: Icons.format_list_bulleted,
            tooltip: '列表',
            onPressed: _insertList,
          ),
          _buildButton(
            context,
            icon: Icons.title,
            tooltip: '标题',
            onPressed: _insertHeading,
          ),
          _buildButton(
            context,
            icon: Icons.code,
            tooltip: '代码',
            onPressed: _insertCode,
          ),
          _buildButton(
            context,
            icon: Icons.link,
            tooltip: '链接',
            onPressed: _insertLink,
          ),
        ],
      ),
    );
  }

  Widget _buildButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }

  // === 格式化方法 ===

  /// 插入粗体
  void _insertBold() {
    _wrapSelection('**', '**');
  }

  /// 插入斜体
  void _insertItalic() {
    _wrapSelection('*', '*');
  }

  /// 插入列表
  void _insertList() {
    _insertAtLineStart('- ');
  }

  /// 插入标题
  void _insertHeading() {
    _insertAtLineStart('## ');
  }

  /// 插入代码
  void _insertCode() {
    _wrapSelection('`', '`');
  }

  /// 插入链接
  void _insertLink() {
    _wrapSelection('[', '](url)');
  }

  // === 辅助方法 ===

  /// 包裹选中的文本
  void _wrapSelection(String prefix, String suffix) {
    final selection = controller.selection;
    final text = controller.text;

    if (selection.isValid && !selection.isCollapsed) {
      // 有选中文本：包裹选中内容
      final selectedText = text.substring(selection.start, selection.end);
      final newText = text.replaceRange(
        selection.start,
        selection.end,
        '$prefix$selectedText$suffix',
      );

      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.start + prefix.length + selectedText.length + suffix.length,
        ),
      );
    } else {
      // 无选中文本：插入模板
      final cursorPos = selection.baseOffset;
      final newText = text.substring(0, cursorPos) +
                      '${prefix}文本$suffix' +
                      text.substring(cursorPos);

      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: cursorPos + prefix.length,
        ),
      );
    }
  }

  /// 在行首插入文本
  void _insertAtLineStart(String prefix) {
    final selection = controller.selection;
    final text = controller.text;

    // 找到当前行的起始位置
    int lineStart = selection.start;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }

    // 在行首插入
    final newText = text.substring(0, lineStart) +
                    prefix +
                    text.substring(lineStart);

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: lineStart + prefix.length,
      ),
    );
  }
}

