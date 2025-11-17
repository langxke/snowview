import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// 自定义标题栏 - 可以随主题切换颜色
class CustomTitleBar extends StatelessWidget {
  const CustomTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark 
        ? const Color(0xFF1E1E1E)  // 深色模式背景
        : Colors.white;             // 浅色模式背景
    final foregroundColor = isDark 
        ? Colors.white 
        : Colors.black;

    return Material(
      color: backgroundColor,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark 
                  ? Colors.white.withOpacity(0.1) 
                  : Colors.black.withOpacity(0.1),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // 左侧：应用图标和标题
            const SizedBox(width: 12),
            Image.asset(
              'assets/icons/app_icon.png',
              width: 20,
              height: 20,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.ac_unit,
                  size: 20,
                  color: foregroundColor.withOpacity(0.7),
                );
              },
            ),
            const SizedBox(width: 8),
            Text(
              '雪象 SnowView',
              style: TextStyle(
                fontSize: 13,
                color: foregroundColor.withOpacity(0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
            
            // 中间：可拖动区域
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanStart: (details) {
                  windowManager.startDragging();
                },
                onDoubleTap: () async {
                  bool isMaximized = await windowManager.isMaximized();
                  if (isMaximized) {
                    windowManager.unmaximize();
                  } else {
                    windowManager.maximize();
                  }
                },
              ),
            ),
            
            // 右侧：窗口控制按钮
            _WindowButton(
              icon: Icons.remove,
              onPressed: () => windowManager.minimize(),
              iconColor: foregroundColor,
            ),
            _WindowButton(
              icon: Icons.crop_square,
              onPressed: () async {
                bool isMaximized = await windowManager.isMaximized();
                if (isMaximized) {
                  windowManager.unmaximize();
                } else {
                  windowManager.maximize();
                }
              },
              iconColor: foregroundColor,
            ),
            _WindowButton(
              icon: Icons.close,
              onPressed: () => windowManager.close(),
              iconColor: foregroundColor,
              isClose: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// 窗口控制按钮
class _WindowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color iconColor;
  final bool isClose;

  const _WindowButton({
    required this.icon,
    required this.onPressed,
    required this.iconColor,
    this.isClose = false,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: 40,
          color: _isHovered
              ? (widget.isClose 
                  ? Colors.red.shade600 
                  : widget.iconColor.withOpacity(0.1))
              : Colors.transparent,
          child: Icon(
            widget.icon,
            size: 16,
            color: _isHovered && widget.isClose
                ? Colors.white
                : widget.iconColor.withOpacity(0.8),
          ),
        ),
      ),
    );
  }
}
