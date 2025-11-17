import 'package:flutter/material.dart';
import '../../models.dart';
import '../utils/event_utils.dart';
import 'editable_text_field.dart';

/// 事件右键上下文菜单系统
class EventContextMenu {
  // 私有构造函数，防止实例化
  EventContextMenu._();

  /// 显示事件上下文菜单
  /// 
  /// [context] - BuildContext
  /// [position] - 菜单显示位置（全局坐标）
  /// [event] - 选中的事件
  /// [onUpdateEvent] - 事件更新回调
  /// [onDeleteEvent] - 事件删除回调
  /// [onAddEvent] - 事件添加回调（用于粘贴和创建副本）
  /// [targetDate] - 目标日期（用于粘贴）
  /// [selectedStartQuarter] - 选中的开始15分钟段（用于粘贴）
  /// [selectedEndQuarter] - 选中的结束15分钟段（用于粘贴）
  static void show({
    required BuildContext context,
    required Offset position,
    required CalendarEvent event,
    required Function(CalendarEvent, CalendarEvent)? onUpdateEvent,
    required VoidCallback onDeleteEvent,
    required Function(CalendarEvent) onAddEvent,
    required DateTime targetDate,
    int? selectedStartQuarter,
    int? selectedEndQuarter,
  }) {
    final colorOptions = eventColors;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Stack(
          children: [
            Positioned(
              left: position.dx,
              top: position.dy,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 280),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 颜色选项行
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: colorOptions.map((color) {
                            final isSelected = event.color == color;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.of(dialogContext).pop();
                                  EventUtils.updateColor(
                                    originalEvent: event,
                                    newColor: color,
                                    onUpdateEvent: onUpdateEvent,
                                  );
                                },
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? Colors.black : Colors.grey.withOpacity(0.3),
                                      width: isSelected ? 3 : 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 2,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const Divider(height: 1),
                      // 修改名称输入框
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.edit, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: EventEditableTextField(
                                initialText: event.title,
                                event: event,
                                onUpdateEvent: onUpdateEvent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // 其他操作按钮
                      _buildMenuButton(Icons.copy, '复制', () {
                        Navigator.of(dialogContext).pop();
                        EventUtils.copyToClipboard(event, context);
                      }),
                      _buildMenuButton(Icons.paste, '粘贴', () {
                        Navigator.of(dialogContext).pop();
                        EventUtils.pasteFromClipboard(
                          context: context,
                          date: targetDate,
                          selectedStartQuarter: selectedStartQuarter,
                          selectedEndQuarter: selectedEndQuarter,
                          onAddEvent: onAddEvent,
                        );
                      }),
                      _buildMenuButton(Icons.content_copy, '创建副本', () {
                        Navigator.of(dialogContext).pop();
                        EventUtils.createDuplicate(
                          event: event,
                          context: context,
                          onAddEvent: onAddEvent,
                        );
                      }),
                      const Divider(height: 1),
                      _buildMenuButton(Icons.delete, '删除', () {
                        Navigator.of(dialogContext).pop();
                        onDeleteEvent();
                      }, color: Colors.red),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 构建菜单按钮
  static Widget _buildMenuButton(
    IconData icon,
    String text,
    VoidCallback onTap, {
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

