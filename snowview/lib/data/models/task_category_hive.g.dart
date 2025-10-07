// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_category_hive.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TaskCategoryHiveAdapter extends TypeAdapter<TaskCategoryHive> {
  @override
  final int typeId = 1;

  @override
  TaskCategoryHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TaskCategoryHive(
      id: fields[0] as String,
      name: fields[1] as String,
      colorValue: fields[2] as int,
      order: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, TaskCategoryHive obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.colorValue)
      ..writeByte(3)
      ..write(obj.order);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskCategoryHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
