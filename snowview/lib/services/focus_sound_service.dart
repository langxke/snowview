import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// 专注音效服务
/// 使用系统默认声音，避免桌面平台兼容性问题
class FocusSoundService {
  static final FocusSoundService _instance = FocusSoundService._internal();
  factory FocusSoundService() => _instance;
  FocusSoundService._internal();

  /// 播放完成提示音
  Future<void> playCompleteSound() async {
    try {
      // 使用系统默认提示音（跨平台支持）
      await SystemSound.play(SystemSoundType.alert);
      debugPrint('✅ 播放完成提示音');
    } catch (e) {
      debugPrint('播放提示音失败: $e');
    }
  }

  /// 播放开始音效
  Future<void> playStartSound() async {
    try {
      await SystemSound.play(SystemSoundType.click);
      debugPrint('✅ 播放开始音效');
    } catch (e) {
      debugPrint('播放提示音失败: $e');
    }
  }

  /// 释放资源（SystemSound 无需释放）
  void dispose() {
    // SystemSound 不需要手动释放资源
  }
}

