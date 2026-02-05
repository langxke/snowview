// 日期工具
class DateUtilsEx {
  static String formatDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  static DateTime floorToMinute(DateTime d) {
    return DateTime(d.year, d.month, d.day, d.hour, d.minute);
  }

  static DateTime ceilToMinute(DateTime d) {
    final floored = floorToMinute(d);
    if (d.isAtSameMomentAs(floored)) return d;
    return floored.add(const Duration(minutes: 1));
  }

  // 判断闰年
  static bool isLeapYear(int year) {
    return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
  }

  // 指定年份与月份有多少天（1-12）
  static int daysInMonth(int year, int month) {
    assert(month >= 1 && month <= 12);
    // Dart DateTime 支持 month+1, day=0 取上个月最后一天
    return DateTime(year, month + 1, 0).day;
  }

  // 指定年份每个月的天数（从1月到12月）
  static List<int> daysPerMonth(int year) {
    return List<int>.generate(12, (index) => daysInMonth(year, index + 1));
  }

  // 当年每个月的天数
  static List<int> currentYearDaysPerMonth() {
    return daysPerMonth(DateTime.now().year);
  }
}


