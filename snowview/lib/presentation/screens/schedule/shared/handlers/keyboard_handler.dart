import 'package:flutter/services.dart';
import '../../models.dart';

/// 键盘处理器
/// 
/// 负责处理日历视图的键盘事件
class CalendarKeyboardHandler {
  // 私有构造函数，防止实例化
  CalendarKeyboardHandler._();

  /// 处理键盘事件
  /// 
  /// [event] 键盘事件
  /// [selectedEvent] 当前选中的事件
  /// [onDelete] 删除事件的回调
  /// 
  /// 返回是否处理了该事件
  static bool handleKeyEvent({
    required KeyEvent event,
    required CalendarEvent? selectedEvent,
    required VoidCallback? onDelete,
  }) {
    if (event is KeyDownEvent) {
      // Delete键：删除选中的事件
      if (event.logicalKey == LogicalKeyboardKey.delete) {
        if (selectedEvent != null && onDelete != null) {
          onDelete();
          return true;
        }
      }
      
      // Escape键：可以用于清除选择（由视图自行处理）
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        return true;
      }
    }
    
    return false;
  }

  /// 检查是否应该删除事件
  /// 
  /// [selectedEvent] 选中的事件
  /// [onDeleteEvent] 删除回调
  /// 
  /// 返回是否可以删除
  static bool canDeleteEvent({
    required CalendarEvent? selectedEvent,
    required Function(CalendarEvent)? onDeleteEvent,
  }) {
    return selectedEvent != null && onDeleteEvent != null;
  }

  /// 执行删除事件
  /// 
  /// [selectedEvent] 要删除的事件
  /// [onDeleteEvent] 删除回调
  /// [onClearSelection] 清除选择的回调
  static void deleteEvent({
    required CalendarEvent selectedEvent,
    required Function(CalendarEvent) onDeleteEvent,
    required VoidCallback onClearSelection,
  }) {
    onDeleteEvent(selectedEvent);
    onClearSelection();
  }

  /// 获取支持的键盘快捷键说明
  /// 
  /// 返回快捷键说明列表
  static List<({String key, String description})> getKeyboardShortcuts() {
    return [
      (key: 'Delete', description: '删除选中的事件'),
      (key: 'Escape', description: '清除选择'),
    ];
  }
}

