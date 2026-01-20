import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../../data/models/chat_session_hive.dart';

/// AI对话会话标签栏
/// 横向滚动显示所有对话会话
class ChatSessionTabBar extends StatefulWidget {
  final List<ChatSessionHive> sessions;
  final String? currentSessionId;
  final Function(String) onSessionSelected;
  final VoidCallback onNewSession;
  final Function(String)? onDeleteSession;
  final Function(String sessionId, String newTitle)? onRenameSession;

  const ChatSessionTabBar({
    super.key,
    required this.sessions,
    required this.currentSessionId,
    required this.onSessionSelected,
    required this.onNewSession,
    this.onDeleteSession,
    this.onRenameSession,
  });

  @override
  State<ChatSessionTabBar> createState() => _ChatSessionTabBarState();
}

class _ChatSessionTabBarState extends State<ChatSessionTabBar> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      // 监听鼠标滚轮事件，实现横向滚动
      onPointerSignal: (pointerSignal) {
        if (pointerSignal is PointerScrollEvent) {
          // 获取当前滚动位置
          final currentOffset = _scrollController.offset;
          // 计算新的滚动位置（将纵向滚动转换为横向滚动）
          final newOffset = currentOffset + pointerSignal.scrollDelta.dy;
          
          // 限制在有效范围内
          final maxScroll = _scrollController.position.maxScrollExtent;
          final clampedOffset = newOffset.clamp(0.0, maxScroll);
          
          // 跳转到新位置
          _scrollController.jumpTo(clampedOffset);
        }
      },
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
        ),
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true, // 始终显示滚动条
          thickness: 4, // 滚动条粗细
          radius: const Radius.circular(2),
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            itemCount: widget.sessions.length + 1, // +1 为新建按钮
            itemBuilder: (context, index) {
              // 新建按钮
              if (index == widget.sessions.length) {
                return _buildNewSessionButton(context);
              }

              // 会话标签
              final session = widget.sessions[index];
              final isActive = session.id == widget.currentSessionId;

              return _buildSessionTab(context, session, isActive);
            },
          ),
        ),
      ),
    );
  }

  /// 构建会话标签
  Widget _buildSessionTab(
    BuildContext context,
    ChatSessionHive session,
    bool isActive,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => widget.onSessionSelected(session.id),
      onLongPress: () => _showSessionOptions(context, session),
      // 右键点击显示菜单
      onSecondaryTapDown: (details) {
        _showContextMenu(context, session, details.globalPosition);
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                session.title,
                style: TextStyle(
                  color: isActive
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isActive)
              Icon(
                Icons.check_circle,
                size: 14,
                color: colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  /// 构建新建会话按钮
  Widget _buildNewSessionButton(BuildContext context) {
    return GestureDetector(
      onTap: widget.onNewSession,
      child: Container(
        width: 50,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary,
            width: 1,
          ),
        ),
        child: Icon(
          Icons.add,
          color: Theme.of(context).colorScheme.primary,
          size: 24,
        ),
      ),
    );
  }

  /// 显示会话操作菜单
  void _showSessionOptions(BuildContext context, ChatSessionHive session) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('重命名'),
            onTap: () {
              Navigator.pop(context);
              _showRenameDialog(context, session);
            },
          ),
          if (widget.onDeleteSession != null)
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                widget.onDeleteSession?.call(session.id);
              },
            ),
        ],
      ),
    );
  }

  /// 显示重命名对话框
  void _showRenameDialog(BuildContext context, ChatSessionHive session) {
    final controller = TextEditingController(text: session.title);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名对话'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '对话标题',
            hintText: '请输入对话标题',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                Navigator.pop(context);
                widget.onRenameSession?.call(session.id, newTitle);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 显示右键上下文菜单
  void _showContextMenu(
    BuildContext context,
    ChatSessionHive session,
    Offset position,
  ) async {
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        const PopupMenuItem<String>(
          value: 'rename',
          child: Row(
            children: [
              Icon(Icons.edit, size: 18),
              SizedBox(width: 8),
              Text('重命名'),
            ],
          ),
        ),
        if (widget.onDeleteSession != null)
          const PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, size: 18, color: Colors.red),
                SizedBox(width: 8),
                Text('删除', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
      ],
    );

    // 根据选择执行操作
    if (result == 'rename') {
      _showRenameDialog(context, session);
    } else if (result == 'delete') {
      widget.onDeleteSession?.call(session.id);
    }
  }
}

