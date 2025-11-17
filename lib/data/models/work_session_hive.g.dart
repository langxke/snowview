// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'work_session_hive.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WorkSessionHiveAdapter extends TypeAdapter<WorkSessionHive> {
  @override
  final int typeId = 4;

  @override
  WorkSessionHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkSessionHive(
      id: fields[0] as String,
      taskId: fields[1] as String,
      subTaskId: fields[2] as String?,
      startTime: fields[3] as DateTime,
      endTime: fields[4] as DateTime,
      status: fields[5] as String,
      note: fields[6] as String?,
      focusSessionId: fields[10] as String?,
      createdAt: fields[11] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, WorkSessionHive obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.taskId)
      ..writeByte(2)
      ..write(obj.subTaskId)
      ..writeByte(3)
      ..write(obj.startTime)
      ..writeByte(4)
      ..write(obj.endTime)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.note)
      ..writeByte(10)
      ..write(obj.focusSessionId)
      ..writeByte(11)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkSessionHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
