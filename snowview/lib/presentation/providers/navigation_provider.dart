import 'package:flutter/foundation.dart';

/// 主导航状态管理
class NavigationProvider extends ChangeNotifier {
  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  /// 切换导航
  void navigateTo(int index) {
    if (_currentIndex != index) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  /// 跳转到清单页面
  void navigateToTodo() {
    navigateTo(0);
  }

  /// 跳转到日历页面
  void navigateToCalendar() {
    navigateTo(1);
  }

  /// 跳转到专注页面
  void navigateToFocus() {
    navigateTo(2); // 清单(0)、日历(1)、专注(2)、记录(3)、设置(4)
  }

  /// 跳转到记录页面
  void navigateToJournal() {
    navigateTo(3);
  }

  /// 跳转到设置页面
  void navigateToSettings() {
    navigateTo(4);
  }
}

