// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contribution.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ContributionAdapter extends TypeAdapter<Contribution> {
  @override
  final int typeId = 8;

  @override
  Contribution read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Contribution(
      id: fields[0] as String,
      name: fields[1] as String,
      contributionAmount: fields[2] as int,
      expectedPayoutAmount: fields[3] as int,
      frequency: fields[4] as RecurrenceFrequency,
      interval: fields[5] as int,
      accountId: fields[6] as String,
      startDate: fields[7] as DateTime,
      endDate: fields[8] as DateTime?,
      active: fields[9] as bool,
      createdAt: fields[10] as DateTime,
      updatedAt: fields[11] as DateTime,
      syncStatus: fields[12] as SyncStatus,
    );
  }

  @override
  void write(BinaryWriter writer, Contribution obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.contributionAmount)
      ..writeByte(3)
      ..write(obj.expectedPayoutAmount)
      ..writeByte(4)
      ..write(obj.frequency)
      ..writeByte(5)
      ..write(obj.interval)
      ..writeByte(6)
      ..write(obj.accountId)
      ..writeByte(7)
      ..write(obj.startDate)
      ..writeByte(8)
      ..write(obj.endDate)
      ..writeByte(9)
      ..write(obj.active)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.updatedAt)
      ..writeByte(12)
      ..write(obj.syncStatus);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContributionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
