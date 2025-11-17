import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../../data/models/journal_entry_hive.dart';
import 'markdown_editor.dart';

/// 记录详情面板（全屏预览/编辑）
class JournalDetailPanel extends StatefulWidget {
  final JournalEntryHive entry;
  final VoidCallback onClose;
  final Function(JournalEntryHive) onUpdate;
  final VoidCallback onDelete;
  final VoidCallback onTogglePin;

  const JournalDetailPanel({
    super.key,
    required this.entry,
    required this.onClose,
    required this.onUpdate,
    required this.onDelete,
    required this.onTogglePin,
  });

  @override
  State<JournalDetailPanel> createState() => _JournalDetailPanelState();
}

class _JournalDetailPanelState extends State<JournalDetailPanel> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  bool _isEditMode = false;
  String? _editingMood;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.entry.title);
    _contentController = TextEditingController(text: widget.entry.content);
    _editingMood = widget.entry.mood;
  }

  @override
  void didUpdateWidget(JournalDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.id != widget.entry.id) {
      _titleController.text = widget.entry.title;
      _contentController.text = widget.entry.content;
      _editingMood = widget.entry.mood;
      _isEditMode = false;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        children: [
          // 头部操作栏
          _buildHeader(context),

          // 内容区域
          Expanded(
            child: _isEditMode ? _buildEditMode() : _buildPreviewMode(),
          ),

          // 底部信息栏
          _buildFooter(context),
        ],
      ),
    );
  }

  /// 构建头部
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.entry.displayTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // 编辑/保存按钮
          IconButton(
            icon: Icon(_isEditMode ? Icons.check : Icons.edit),
            tooltip: _isEditMode ? '保存' : '编辑',
            onPressed: () {
              if (_isEditMode) {
                _saveChanges();
              } else {
                setState(() {
                  _isEditMode = true;
                });
              }
            },
          ),

          // 置顶按钮
          IconButton(
            icon: Icon(
              widget.entry.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
            ),
            tooltip: widget.entry.isPinned ? '取消置顶' : '置顶',
            onPressed: widget.onTogglePin,
          ),

          // 更多菜单
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18, color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 12),
                    Text('删除', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'delete') {
                widget.onDelete();
              }
            },
          ),

          // 关闭按钮
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: '关闭',
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }

  /// 构建预览模式
  Widget _buildPreviewMode() {
    if (widget.entry.content.trim().isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.edit_note,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无内容',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _isEditMode = true;
                });
              },
              icon: const Icon(Icons.edit),
              label: const Text('开始编辑'),
            ),
          ],
        ),
      );
    }

    return Markdown(
      data: widget.entry.content,
      selectable: true,
      padding: const EdgeInsets.all(24),
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        h1: Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
        h2: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
        p: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }

  /// 构建编辑模式
  Widget _buildEditMode() {
    return Column(
      children: [
        // 标题编辑
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: '标题（可选）',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.title, size: 20),
            ),
          ),
        ),

        // Markdown 编辑器
        Expanded(
          child: MarkdownEditor(controller: _contentController),
        ),
      ],
    );
  }

  /// 构建底部信息栏
  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          // 日期
          Icon(
            Icons.calendar_today,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            widget.entry.dateFormatted,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),

          // 专注时长
          if (widget.entry.dailyFocusMinutes != null) ...[
            const SizedBox(width: 16),
            Icon(
              Icons.timer,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              '${widget.entry.dailyFocusMinutes}分钟',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],

          // 心情
          if (widget.entry.mood != null) ...[
            const SizedBox(width: 16),
            Text(widget.entry.mood!, style: const TextStyle(fontSize: 16)),
          ],

          const Spacer(),

          // 字数统计
          Text(
            '${widget.entry.wordCount} 字',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 保存更改
  void _saveChanges() {
    final updated = widget.entry.copyWith(
      title: _titleController.text,
      content: _contentController.text,
      mood: _editingMood,
      updatedAt: DateTime.now(),
    );

    widget.onUpdate(updated);

    setState(() {
      _isEditMode = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已保存'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}


