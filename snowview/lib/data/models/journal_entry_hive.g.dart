// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journal_entry_hive.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class JournalEntryHiveAdapter extends TypeAdapter<JournalEntryHive> {
  @override
  final int typeId = 7;

  @override
  JournalEntryHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return JournalEntryHive(
      id: fields[0] as String,
      title: fields[1] as String,
      content: fields[2] as String,
      categoryId: fields[3] as String,
      createdAt: fields[4] as DateTime,
      updatedAt: fields[5] as DateTime,
      tags: (fields[6] as List).cast<String>(),
      mood: fields[7] as String?,
      relatedTaskIds: (fields[8] as List).cast<String>(),
      dailyFocusMinutes: fields[9] as int?,
      isPinned: fields[10] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, JournalEntryHive obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.categoryId)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.updatedAt)
      ..writeByte(6)
      ..write(obj.tags)
      ..writeByte(7)
      ..write(obj.mood)
      ..writeByte(8)
      ..write(obj.relatedTaskIds)
      ..writeByte(9)
      ..write(obj.dailyFocusMinutes)
      ..writeByte(10)
      ..write(obj.isPinned);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JournalEntryHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
