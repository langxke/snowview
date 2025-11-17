import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'markdown_toolbar.dart';

/// Markdown 编辑器组件
/// 支持编辑和预览模式切换
class MarkdownEditor extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;

  const MarkdownEditor({
    super.key,
    required this.controller,
    this.hintText = '支持 Markdown 语法\n# 标题\n**粗体** *斜体*\n- 列表\n`代码`',
  });

  @override
  State<MarkdownEditor> createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<MarkdownEditor> {
  bool _isPreviewMode = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 工具栏和切换按钮
        Row(
          children: [
            // Markdown 工具栏
            Expanded(
              child: MarkdownToolbar(controller: widget.controller),
            ),
            
            // 编辑/预览切换
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: Theme.of(context).dividerColor),
                  bottom: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.edit, size: 16),
                    label: Text('编辑', style: TextStyle(fontSize: 12)),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.visibility, size: 16),
                    label: Text('预览', style: TextStyle(fontSize: 12)),
                  ),
                ],
                selected: {_isPreviewMode},
                onSelectionChanged: (Set<bool> newSelection) {
                  setState(() {
                    _isPreviewMode = newSelection.first;
                  });
                },
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
            ),
          ],
        ),

        // 编辑/预览内容区
        Expanded(
          child: _isPreviewMode ? _buildPreview() : _buildEditor(),
        ),
      ],
    );
  }

  /// 构建编辑器
  Widget _buildEditor() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: widget.controller,
        maxLines: null,
        expands: true,
        decoration: InputDecoration(
          hintText: widget.hintText,
          border: InputBorder.none,
          hintStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
        ),
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 15,
          height: 1.5,
        ),
        textAlignVertical: TextAlignVertical.top,
      ),
    );
  }

  /// 构建预览
  Widget _buildPreview() {
    final content = widget.controller.text;

    if (content.trim().isEmpty) {
      return Center(
        child: Text(
          '暂无内容',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Markdown(
        data: content,
        selectable: true,
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
          h1: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          h2: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          h3: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          p: Theme.of(context).textTheme.bodyLarge,
          listBullet: Theme.of(context).textTheme.bodyLarge,
          code: TextStyle(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            fontFamily: 'monospace',
            fontSize: 14,
          ),
          codeblockDecoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

