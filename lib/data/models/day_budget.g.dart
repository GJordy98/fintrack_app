// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'day_budget.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DayBudgetAdapter extends TypeAdapter<DayBudget> {
  @override
  final int typeId = 13;

  @override
  DayBudget read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DayBudget(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      planned: fields[2] as int,
      actual: fields[3] as int?,
      note: fields[4] as String?,
      settled: fields[5] as bool,
      updatedAt: fields[6] as DateTime,
      syncStatus: fields[7] as SyncStatus,
    );
  }

  @override
  void write(BinaryWriter writer, DayBudget obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.planned)
      ..writeByte(3)
      ..write(obj.actual)
      ..writeByte(4)
      ..write(obj.note)
      ..writeByte(5)
      ..write(obj.settled)
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
      other is DayBudgetAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
