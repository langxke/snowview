// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_event_hive.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CalendarEventHiveAdapter extends TypeAdapter<CalendarEventHive> {
  @override
  final int typeId = 0;

  @override
  CalendarEventHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CalendarEventHive(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String,
      allDay: fields[3] as bool,
      start: fields[4] as DateTime,
      end: fields[5] as DateTime,
      colorValue: fields[6] as int,
    );
  }

  @override
  void write(BinaryWriter writer, CalendarEventHive obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.allDay)
      ..writeByte(4)
      ..write(obj.start)
      ..writeByte(5)
      ..write(obj.end)
      ..writeByte(6)
      ..write(obj.colorValue);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarEventHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
