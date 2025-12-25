import 'package:flutter/foundation.dart';

/// 主导航状态管理
class NavigationProvider extends ChangeNotifier {
  int _currentIndex = 1;
  bool _isCalendarChecklistExpanded = false;
  double _calendarChecklistWidth = 280.0;

  static const double calendarChecklistMinWidth = 220.0;
  static const double calendarChecklistMaxWidth = 520.0;

  int get currentIndex => _currentIndex;
  bool get isCalendarChecklistExpanded => _isCalendarChecklistExpanded;
  double get calendarChecklistWidth => _calendarChecklistWidth;

  /// 切换导航
  void navigateTo(int index) {
    if (_currentIndex != index) {
      _currentIndex = index;
      if (_currentIndex != 1) {
        _isCalendarChecklistExpanded = false;
      }
      notifyListeners();
    }
  }

  void toggleCalendarChecklist() {
    if (_currentIndex != 1) return;
    _isCalendarChecklistExpanded = !_isCalendarChecklistExpanded;
    notifyListeners();
  }

  void setCalendarChecklistWidth(double width) {
    final clamped = width.clamp(calendarChecklistMinWidth, calendarChecklistMaxWidth);
    if (clamped == _calendarChecklistWidth) return;
    _calendarChecklistWidth = clamped;
    notifyListeners();
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
    navigateTo(2); // 清单(0)、日历(1)、专注(2)、设置(3)
  }

  /// 跳转到设置页面
  void navigateToSettings() {
    navigateTo(3);
  }
}

