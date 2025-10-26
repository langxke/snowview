// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_session_hive.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChatSessionHiveAdapter extends TypeAdapter<ChatSessionHive> {
  @override
  final int typeId = 11;

  @override
  ChatSessionHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatSessionHive(
      id: fields[0] as String,
      title: fields[1] as String,
      createdAt: fields[2] as DateTime,
      updatedAt: fields[3] as DateTime,
      messageIds: (fields[4] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, ChatSessionHive obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.updatedAt)
      ..writeByte(4)
      ..write(obj.messageIds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatSessionHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
