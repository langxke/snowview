// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_config_hive.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AIConfigHiveAdapter extends TypeAdapter<AIConfigHive> {
  @override
  final int typeId = 9;

  @override
  AIConfigHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AIConfigHive(
      provider: fields[0] as String,
      apiKey: fields[1] as String,
      baseUrl: fields[2] as String?,
      model: fields[3] as String,
      temperature: fields[4] as double,
      maxTokens: fields[5] as int,
      enableTools: fields[6] as bool,
      createdAt: fields[7] as DateTime,
      updatedAt: fields[8] as DateTime,
      aiMode: fields[9] == null ? 'action' : fields[9] as String,
      maxJsonParseRetries: fields[10] == null ? 3 : fields[10] as int,
    );
  }

  @override
  void write(BinaryWriter writer, AIConfigHive obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.provider)
      ..writeByte(1)
      ..write(obj.apiKey)
      ..writeByte(2)
      ..write(obj.baseUrl)
      ..writeByte(3)
      ..write(obj.model)
      ..writeByte(4)
      ..write(obj.temperature)
      ..writeByte(5)
      ..write(obj.maxTokens)
      ..writeByte(6)
      ..write(obj.enableTools)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt)
      ..writeByte(9)
      ..write(obj.aiMode)
      ..writeByte(10)
      ..write(obj.maxJsonParseRetries);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIConfigHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
