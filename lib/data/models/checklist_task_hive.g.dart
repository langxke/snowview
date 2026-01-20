// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checklist_task_hive.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChecklistTaskHiveAdapter extends TypeAdapter<ChecklistTaskHive> {
  @override
  final int typeId = 3;

  @override
  ChecklistTaskHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChecklistTaskHive(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String?,
      isCompleted: fields[3] as bool,
      dueDate: fields[4] as DateTime?,
      remindAt: fields[5] as DateTime?,
      createdAt: fields[6] as DateTime,
      completedAt: fields[7] as DateTime?,
      order: fields[8] as int,
      isLongTerm: fields[9] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ChecklistTaskHive obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.isCompleted)
      ..writeByte(4)
      ..write(obj.dueDate)
      ..writeByte(5)
      ..write(obj.remindAt)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.completedAt)
      ..writeByte(8)
      ..write(obj.order)
      ..writeByte(9)
      ..write(obj.isLongTerm);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChecklistTaskHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
