import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io' show Platform;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // Windows/Linux 平台初始化设置
      const LinuxInitializationSettings linuxInit = LinuxInitializationSettings(
        defaultActionName: 'Open notification',
      );
      
      const InitializationSettings initSettings = InitializationSettings(
        android: androidInit,
        linux: linuxInit,
      );

      await _plugin.initialize(initSettings);
      _initialized = true;
    } catch (e) {
      debugPrint('通知服务初始化失败（可能是桌面平台不支持）: $e');
      _initialized = false;
    }
  }

  Future<void> showImmediate({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      await initialize();
      
      if (!_initialized) {
        debugPrint('通知服务未初始化，跳过通知显示');
        return;
      }
      
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'default_channel',
        '默认通知',
        channelDescription: '通用通知渠道',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );
      const LinuxNotificationDetails linuxDetails = LinuxNotificationDetails();
      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        linux: linuxDetails,
      );
      
      if (Platform.isWindows) {
        // Windows 上直接调用 show，无需特殊 details (插件会自动处理)
        // 注意：Windows 上需要在 Runner/Main.cpp 或 Package Manifest 中配置 GUID 才能显示（如果插件内部没做 fallback）
        // flutter_local_notifications 默认应该能工作
      }
      
      await _plugin.show(id, title, body, details);
    } catch (e) {
      debugPrint('显示通知失败: $e');
    }
  }

  // ========== 专注功能通知 ==========

  /// 安排专注完成通知
  /// 注意：桌面平台暂不支持定时通知，此方法预留
  Future<void> scheduleFocusCompleteNotification({
    required int afterSeconds,
    required String sessionId,
    String? taskTitle,
  }) async {
    // 桌面平台暂不实现定时通知
    // 移动平台可以使用 zonedSchedule 实现
    // TODO: 后续集成 timezone 包支持定时通知
    debugPrint('定时通知已安排（桌面平台暂不支持）: $afterSeconds秒后');
  }

  /// 取消专注通知
  Future<void> cancelFocusNotification(String sessionId) async {
    try {
      if (_initialized) {
        await _plugin.cancel(sessionId.hashCode);
      }
    } catch (e) {
      debugPrint('取消通知失败: $e');
    }
  }

  /// 显示专注完成通知（立即显示）
  Future<void> showFocusCompleteNotification({
    required String title,
    required String body,
  }) async {
    // 尝试在所有平台（包括 Windows/Linux/MacOS）都显示通知
    try {
      await initialize();
      
      if (!_initialized) {
        debugPrint('通知服务未初始化，跳过通知显示');
        return;
      }
      
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'focus_channel',
        '专注提醒',
        channelDescription: '专注会话完成提醒',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );
      
      // 桌面平台通常不需要复杂的 Details，或者使用默认值即可
      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
      );
      
      await _plugin.show(0, title, body, details);
      debugPrint('通知已发送: $title - $body');
    } catch (e) {
      debugPrint('显示通知失败: $e');
    }
  }
}


