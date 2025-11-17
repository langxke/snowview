// 用户偏好数据模型
class UserPreferencesModel {
  final int? id;
  final String workStartTime; // HH:MM
  final String workEndTime;   // HH:MM
  final String? weekendWorkStartTime; // HH:MM or null
  final String? weekendWorkEndTime;   // HH:MM or null
  final String workDays; // '1,2,3,4,5'
  final int breakDuration; // minutes
  final int pomodoroDuration; // minutes
  final String themeMode; // light/dark/auto
  final String language; // zh_CN/en_US
  final DateTime createdAt;
  final DateTime? updatedAt;

  const UserPreferencesModel({
    this.id,
    required this.workStartTime,
    required this.workEndTime,
    this.weekendWorkStartTime,
    this.weekendWorkEndTime,
    this.workDays = '1,2,3,4,5',
    this.breakDuration = 5,
    this.pomodoroDuration = 25,
    this.themeMode = 'light',
    this.language = 'zh_CN',
    required this.createdAt,
    this.updatedAt,
  });

  factory UserPreferencesModel.fromMap(Map<String, dynamic> map) {
    return UserPreferencesModel(
      id: map['id'],
      workStartTime: map['work_start_time'],
      workEndTime: map['work_end_time'],
      weekendWorkStartTime: map['weekend_work_start_time'],
      weekendWorkEndTime: map['weekend_work_end_time'],
      workDays: map['work_days'] ?? '1,2,3,4,5',
      breakDuration: map['break_duration'] ?? 5,
      pomodoroDuration: map['pomodoro_duration'] ?? 25,
      themeMode: map['theme_mode'] ?? 'light',
      language: map['language'] ?? 'zh_CN',
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'work_start_time': workStartTime,
      'work_end_time': workEndTime,
      'weekend_work_start_time': weekendWorkStartTime,
      'weekend_work_end_time': weekendWorkEndTime,
      'work_days': workDays,
      'break_duration': breakDuration,
      'pomodoro_duration': pomodoroDuration,
      'theme_mode': themeMode,
      'language': language,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}


