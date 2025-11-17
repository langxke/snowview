// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'focus_daily_stats_hive.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FocusDailyStatsHiveAdapter extends TypeAdapter<FocusDailyStatsHive> {
  @override
  final int typeId = 6;

  @override
  FocusDailyStatsHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FocusDailyStatsHive(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      totalFocusSeconds: fields[2] as int,
      completedSessionCount: fields[3] as int,
      pomodoroCount: fields[4] as int,
      totalBreakSeconds: fields[5] as int,
      focusedTaskIds: (fields[6] as List).cast<String>(),
      createdAt: fields[7] as DateTime,
      updatedAt: fields[8] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, FocusDailyStatsHive obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.totalFocusSeconds)
      ..writeByte(3)
      ..write(obj.completedSessionCount)
      ..writeByte(4)
      ..write(obj.pomodoroCount)
      ..writeByte(5)
      ..write(obj.totalBreakSeconds)
      ..writeByte(6)
      ..write(obj.focusedTaskIds)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FocusDailyStatsHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
