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
    debugPrint('定时通知已安排（桌面平台暂不支持）: ${afterSeconds}秒后');
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
    // Windows/macOS/Linux 桌面平台：不支持系统通知，只记录日志
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      debugPrint('✅ 专注完成：$title - $body');
      // 桌面平台暂不显示系统通知，避免错误
      // 用户可以通过UI界面看到专注完成状态
      return;
    }
    
    // Android/iOS 移动平台：使用系统通知
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
      
      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
      );
      
      await _plugin.show(0, title, body, details);
      debugPrint('通知已显示: $title - $body');
    } catch (e) {
      debugPrint('显示通知失败: $e');
    }
  }
}


