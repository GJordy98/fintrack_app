// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'income_profile.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class IncomeProfileAdapter extends TypeAdapter<IncomeProfile> {
  @override
  final int typeId = 12;

  @override
  IncomeProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return IncomeProfile(
      id: fields[0] as String,
      label: fields[1] as String,
      amount: fields[2] as int,
      frequency: fields[3] as RecurrenceFrequency,
      active: fields[4] as bool,
      createdAt: fields[5] as DateTime,
      updatedAt: fields[6] as DateTime,
      syncStatus: fields[7] as SyncStatus,
    );
  }

  @override
  void write(BinaryWriter writer, IncomeProfile obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.label)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.frequency)
      ..writeByte(4)
      ..write(obj.active)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.updatedAt)
      ..writeByte(7)
      ..write(obj.syncStatus);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IncomeProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
