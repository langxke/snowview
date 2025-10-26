// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message_hive.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChatMessageHiveAdapter extends TypeAdapter<ChatMessageHive> {
  @override
  final int typeId = 10;

  @override
  ChatMessageHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatMessageHive(
      id: fields[0] as String,
      role: fields[1] as String,
      content: fields[2] as String,
      timestamp: fields[3] as DateTime,
      toolCallId: fields[4] as String?,
      toolCalls: (fields[5] as List?)?.cast<String>(),
      sessionId: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ChatMessageHive obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.role)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.toolCallId)
      ..writeByte(5)
      ..write(obj.toolCalls)
      ..writeByte(6)
      ..write(obj.sessionId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessageHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
