// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journal_category_hive.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class JournalCategoryHiveAdapter extends TypeAdapter<JournalCategoryHive> {
  @override
  final int typeId = 8;

  @override
  JournalCategoryHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return JournalCategoryHive(
      id: fields[0] as String,
      name: fields[1] as String,
      colorValue: fields[2] as int,
      order: fields[3] as int,
      createdAt: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, JournalCategoryHive obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.colorValue)
      ..writeByte(3)
      ..write(obj.order)
      ..writeByte(4)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JournalCategoryHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
