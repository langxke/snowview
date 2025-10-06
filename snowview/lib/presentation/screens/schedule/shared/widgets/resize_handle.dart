import 'package:flutter/material.dart';

/// 事件调整大小手柄组件
/// 
/// 显示在事件块顶部或底部，允许用户通过拖拽调整事件的时间长度
class EventResizeHandle extends StatelessWidget {
  /// 手柄位置（true=顶部，false=底部）
  final bool isTop;
  
  /// 事件颜色
  final Color color;
  
  /// 手柄高度
  final double handleHeight;
  
  /// 开始拖拽回调
  final Function(DragStartDetails) onPanStart;
  
  /// 拖拽更新回调
  final Function(DragUpdateDetails) onPanUpdate;
  
  /// 拖拽结束回调
  final Function(DragEndDetails) onPanEnd;

  const EventResizeHandle({
    super.key,
    required this.isTop,
    required this.color,
    required this.handleHeight,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: isTop ? 0 : null,
      bottom: isTop ? null : 0,
      left: 0,
      right: 0,
      height: handleHeight,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeUpDown,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: onPanStart,
          onPanUpdate: onPanUpdate,
          onPanEnd: onPanEnd,
          child: Container(
            color: Colors.transparent,
            child: Center(
              child: Container(
                width: 30,
                height: 3,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

