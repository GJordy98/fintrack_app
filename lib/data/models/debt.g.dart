// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'debt.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DebtAdapter extends TypeAdapter<Debt> {
  @override
  final int typeId = 10;

  @override
  Debt read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Debt(
      id: fields[0] as String,
      direction: fields[1] as DebtDirection,
      counterparty: fields[2] as String,
      principal: fields[3] as int,
      reason: fields[4] as String?,
      contractedDate: fields[5] as DateTime,
      accountId: fields[6] as String?,
      status: fields[7] as DebtStatus,
      createdAt: fields[8] as DateTime,
      updatedAt: fields[9] as DateTime,
      syncStatus: fields[10] as SyncStatus,
    );
  }

  @override
  void write(BinaryWriter writer, Debt obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.direction)
      ..writeByte(2)
      ..write(obj.counterparty)
      ..writeByte(3)
      ..write(obj.principal)
      ..writeByte(4)
      ..write(obj.reason)
      ..writeByte(5)
      ..write(obj.contractedDate)
      ..writeByte(6)
      ..write(obj.accountId)
      ..writeByte(7)
      ..write(obj.status)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.updatedAt)
      ..writeByte(10)
      ..write(obj.syncStatus);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DebtAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DebtDirectionAdapter extends TypeAdapter<DebtDirection> {
  @override
  final int typeId = 29;

  @override
  DebtDirection read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return DebtDirection.iOwe;
      case 1:
        return DebtDirection.owedToMe;
      default:
        return DebtDirection.iOwe;
    }
  }

  @override
  void write(BinaryWriter writer, DebtDirection obj) {
    switch (obj) {
      case DebtDirection.iOwe:
        writer.writeByte(0);
        break;
      case DebtDirection.owedToMe:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DebtDirectionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DebtStatusAdapter extends TypeAdapter<DebtStatus> {
  @override
  final int typeId = 30;

  @override
  DebtStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return DebtStatus.active;
      case 1:
        return DebtStatus.settled;
      default:
        return DebtStatus.active;
    }
  }

  @override
  void write(BinaryWriter writer, DebtStatus obj) {
    switch (obj) {
      case DebtStatus.active:
        writer.writeByte(0);
        break;
      case DebtStatus.settled:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DebtStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
