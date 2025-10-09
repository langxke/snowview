// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'focus_session_hive.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FocusSessionHiveAdapter extends TypeAdapter<FocusSessionHive> {
  @override
  final int typeId = 5;

  @override
  FocusSessionHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FocusSessionHive(
      id: fields[0] as String,
      taskId: fields[1] as String?,
      workSessionId: fields[2] as String?,
      sessionType: fields[3] as String,
      plannedDuration: fields[4] as int,
      actualDuration: fields[5] as int,
      status: fields[6] as String,
      startTime: fields[7] as DateTime,
      endTime: fields[8] as DateTime?,
      note: fields[9] as String?,
      isBreak: fields[10] as bool,
      pauseTimestamps: (fields[11] as List).cast<DateTime>(),
      createdAt: fields[12] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, FocusSessionHive obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.taskId)
      ..writeByte(2)
      ..write(obj.workSessionId)
      ..writeByte(3)
      ..write(obj.sessionType)
      ..writeByte(4)
      ..write(obj.plannedDuration)
      ..writeByte(5)
      ..write(obj.actualDuration)
      ..writeByte(6)
      ..write(obj.status)
      ..writeByte(7)
      ..write(obj.startTime)
      ..writeByte(8)
      ..write(obj.endTime)
      ..writeByte(9)
      ..write(obj.note)
      ..writeByte(10)
      ..write(obj.isBreak)
      ..writeByte(11)
      ..write(obj.pauseTimestamps)
      ..writeByte(12)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FocusSessionHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
