// 校验工具
class ValidationUtils {
  static bool isValidDuration(int minutes) {
    return minutes >= 1 && minutes <= 1440;
  }
}


