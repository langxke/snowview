import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models.dart';
import '../utils/time_utils.dart';
import 'resize_handle.dart';
import '../../../../providers/pending_time_block_provider.dart';

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

    final bool isPending = context.select<PendingTimeBlockProvider, bool>(
      (p) => p.isPending(event.id),
    );

    // 判断是否为过期未完成事件（询问态不算未完成）
    final bool isExpiredIncomplete = !event.isCompleted && !isPending && event.end.isBefore(DateTime.now());

    final handleColor = isExpiredIncomplete ? Colors.grey : event.color;

    return Positioned(
      left: leftOffset,
      right: width == null ? rightOffset : null,
      width: width,
      top: topPosition,
      height: height,
      child: Stack(
        children: [
          // 主活动块
          _buildMainBlock(isExpiredIncomplete, isPending),
          
          // 顶部调整手柄
          if (canShowHandles && onTopResizeStart != null)
            EventResizeHandle(
              isTop: true,
              color: handleColor,
              handleHeight: resizeHandleHeight,
              onPanStart: onTopResizeStart!,
              onPanUpdate: onTopResizeUpdate ?? (_) {},
              onPanEnd: onTopResizeEnd ?? (_) {},
            ),
          
          // 底部调整手柄
          if (canShowHandles && onBottomResizeStart != null)
            EventResizeHandle(
              isTop: false,
              color: handleColor,
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
  Widget _buildMainBlock(bool isExpiredIncomplete, bool isPending) {
    // 根据状态决定颜色
    final bgColor = isExpiredIncomplete 
        ? Colors.grey.withOpacity(0.1) // 极浅灰背景
        : event.color.withOpacity(isSelected ? 0.4 : 0.3);
        
    final borderColor = isExpiredIncomplete
        ? Colors.grey.withOpacity(0.3) // 低对比度边框
        : event.color.withOpacity(isSelected ? 0.8 : 0.6);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: borderColor,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: height <= 30 
            ? _buildCompactLayout(isExpiredIncomplete, isPending) 
            : _buildExpandedLayout(isExpiredIncomplete, isPending),
      ),
    );
  }

  /// 构建紧凑布局（高度 <= 30px）
  /// 单行显示标题和时间
  Widget _buildCompactLayout(bool isExpiredIncomplete, bool isPending) {
    final textColor = isExpiredIncomplete
        ? Colors.grey.withOpacity(0.7)
        : event.color.withOpacity(0.9);

    return Row(
      children: [
        if (event.isCompleted) ...[
          Icon(Icons.check_circle, size: 12, color: event.color),
          const SizedBox(width: 4),
        ] else if (isPending) ...[
          Icon(Icons.help_outline, size: 12, color: event.color),
          const SizedBox(width: 4),
        ] else if (isExpiredIncomplete) ...[
          Icon(Icons.cancel, size: 12, color: textColor),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            '${event.title} ${TimeUtils.formatTime(TimeOfDay.fromDateTime(event.start))}-${TimeUtils.formatTime(TimeOfDay.fromDateTime(event.end))}',
            style: TextStyle(
              fontSize: 11,
              color: textColor,
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
  Widget _buildExpandedLayout(bool isExpiredIncomplete, bool isPending) {
    final titleColor = isExpiredIncomplete
        ? Colors.grey.withOpacity(0.7)
        : event.color.withOpacity(0.9);
        
    final timeColor = isExpiredIncomplete
        ? Colors.grey.withOpacity(0.5)
        : event.color.withOpacity(0.7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (event.isCompleted) ...[
              Icon(Icons.check_circle, size: 14, color: event.color),
              const SizedBox(width: 4),
            ] else if (isPending) ...[
              Icon(Icons.help_outline, size: 14, color: event.color),
              const SizedBox(width: 4),
            ] else if (isExpiredIncomplete) ...[
              Icon(Icons.cancel, size: 14, color: titleColor),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                event.title,
                style: TextStyle(
                  fontSize: 12,
                  color: titleColor,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        if (height > 30) // 只有足够高度时才显示时间
          Text(
            '${TimeUtils.formatTime(TimeOfDay.fromDateTime(event.start))}-${TimeUtils.formatTime(TimeOfDay.fromDateTime(event.end))}',
            style: TextStyle(
              fontSize: 10,
              color: timeColor,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
      ],
    );
  }
}

