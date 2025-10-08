import 'package:flutter/material.dart';
import '../../models.dart';
import '../utils/time_utils.dart';
import 'resize_handle.dart';

/// 日历事件块组件
/// 
/// 显示单个日历事件，支持选中状态、调整大小手柄等
class CalendarEventBlock extends StatelessWidget {
  /// 事件对象
  final CalendarEvent event;
  
  /// 是否被选中
  final bool isSelected;
  
  /// 事件块的高度（像素）
  final double height;
  
  /// 左侧偏移量（像素）
  final double leftOffset;
  
  /// 右侧偏移量（像素），null表示延伸到右边缘
  final double? rightOffset;
  
  /// 宽度（像素），如果指定则覆盖right计算
  final double? width;
  
  /// Y坐标位置（像素）
  final double topPosition;
  
  /// 调整手柄高度
  final double resizeHandleHeight;
  
  /// 是否显示调整手柄
  final bool showResizeHandles;
  
  /// 顶部调整手柄的拖拽回调
  final Function(DragStartDetails)? onTopResizeStart;
  final Function(DragUpdateDetails)? onTopResizeUpdate;
  final Function(DragEndDetails)? onTopResizeEnd;
  
  /// 底部调整手柄的拖拽回调
  final Function(DragStartDetails)? onBottomResizeStart;
  final Function(DragUpdateDetails)? onBottomResizeUpdate;
  final Function(DragEndDetails)? onBottomResizeEnd;

  const CalendarEventBlock({
    super.key,
    required this.event,
    required this.isSelected,
    required this.height,
    required this.leftOffset,
    this.rightOffset,
    this.width,
    required this.topPosition,
    required this.resizeHandleHeight,
    this.showResizeHandles = true,
    this.onTopResizeStart,
    this.onTopResizeUpdate,
    this.onTopResizeEnd,
    this.onBottomResizeStart,
    this.onBottomResizeUpdate,
    this.onBottomResizeEnd,
  });

  @override
  Widget build(BuildContext context) {
    // 判断是否显示调整手柄（需要选中且高度足够）
    // ✅ 降低阈值：只要高度大于一个手柄即可（原来是2倍）
    final bool canShowHandles = showResizeHandles && 
                                 isSelected && 
                                 height > resizeHandleHeight;

    return Positioned(
      left: leftOffset,
      right: width == null ? rightOffset : null,
      width: width,
      top: topPosition,
      height: height,
      child: Stack(
        children: [
          // 主活动块
          _buildMainBlock(),
          
          // 顶部调整手柄
          if (canShowHandles && onTopResizeStart != null)
            EventResizeHandle(
              isTop: true,
              color: event.color,
              handleHeight: resizeHandleHeight,
              onPanStart: onTopResizeStart!,
              onPanUpdate: onTopResizeUpdate ?? (_) {},
              onPanEnd: onTopResizeEnd ?? (_) {},
            ),
          
          // 底部调整手柄
          if (canShowHandles && onBottomResizeStart != null)
            EventResizeHandle(
              isTop: false,
              color: event.color,
              handleHeight: resizeHandleHeight,
              onPanStart: onBottomResizeStart!,
              onPanUpdate: onBottomResizeUpdate ?? (_) {},
              onPanEnd: onBottomResizeEnd ?? (_) {},
            ),
        ],
      ),
    );
  }

  /// 构建主活动块
  Widget _buildMainBlock() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: event.color.withOpacity(isSelected ? 0.4 : 0.3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: event.color.withOpacity(isSelected ? 0.8 : 0.6),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: height <= 30 ? _buildCompactLayout() : _buildExpandedLayout(),
      ),
    );
  }

  /// 构建紧凑布局（高度 <= 30px）
  /// 单行显示标题和时间
  Widget _buildCompactLayout() {
    return Row(
      children: [
        Flexible(
          child: Text(
            '${event.title} ${TimeUtils.formatTime(TimeOfDay.fromDateTime(event.start))}-${TimeUtils.formatTime(TimeOfDay.fromDateTime(event.end))}',
            style: TextStyle(
              fontSize: 11,
              color: event.color.withOpacity(0.9),
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  /// 构建展开布局（高度 > 30px）
  /// 多行显示标题和时间
  Widget _buildExpandedLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          event.title,
          style: TextStyle(
            fontSize: 12,
            color: event.color.withOpacity(0.9),
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        if (height > 30) // 只有足够高度时才显示时间
          Text(
            '${TimeUtils.formatTime(TimeOfDay.fromDateTime(event.start))}-${TimeUtils.formatTime(TimeOfDay.fromDateTime(event.end))}',
            style: TextStyle(
              fontSize: 10,
              color: event.color.withOpacity(0.7),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
      ],
    );
  }
}

