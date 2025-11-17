import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class ThemeProvider extends ChangeNotifier {
	ThemeMode _mode = ThemeMode.system;
	ThemeMode get mode => _mode;
	
	void setMode(ThemeMode m) async {
		_mode = m;
		notifyListeners();
		
		// 同步更新窗口标题栏颜色
		await _updateWindowTitleBarColor(m);
	}
	
	/// 根据主题模式更新窗口标题栏颜色
	Future<void> _updateWindowTitleBarColor(ThemeMode mode) async {
		try {
			// 获取系统亮度（用于 ThemeMode.system）
			final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
			final isDark = mode == ThemeMode.dark || 
			              (mode == ThemeMode.system && brightness == Brightness.dark);
			
			// 在 Windows 上，window_manager 提供了有限的标题栏定制
			// 最佳方案是使用自定义标题栏（隐藏原生标题栏）
			// 这样可以完全控制标题栏的外观和颜色
			
			if (isDark) {
				// 深色模式 - 设置深色标题栏样式
				await windowManager.setTitleBarStyle(
					TitleBarStyle.hidden, // 隐藏原生标题栏，使用自定义标题栏
					windowButtonVisibility: false,
				);
			} else {
				// 浅色模式 - 设置浅色标题栏样式
				await windowManager.setTitleBarStyle(
					TitleBarStyle.hidden, // 隐藏原生标题栏，使用自定义标题栏
					windowButtonVisibility: false,
				);
			}
			
		} catch (e) {
			// 如果窗口管理器操作失败，忽略错误（避免影响主题切换）
			debugPrint('更新窗口标题栏样式失败: $e');
		}
	}
	
	/// 初始化窗口标题栏颜色（应用启动时调用）
	Future<void> initWindowTitleBar() async {
		await _updateWindowTitleBarColor(_mode);
	}
}
