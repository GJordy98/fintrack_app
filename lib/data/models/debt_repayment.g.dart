// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'debt_repayment.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DebtRepaymentAdapter extends TypeAdapter<DebtRepayment> {
  @override
  final int typeId = 11;

  @override
  DebtRepayment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DebtRepayment(
      id: fields[0] as String,
      debtId: fields[1] as String,
      dueDate: fields[2] as DateTime,
      amount: fields[3] as int,
      status: fields[4] as RepaymentStatus,
      paidDate: fields[5] as DateTime?,
      transactionId: fields[6] as String?,
      updatedAt: fields[7] as DateTime,
      syncStatus: fields[8] as SyncStatus,
    );
  }

  @override
  void write(BinaryWriter writer, DebtRepayment obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.debtId)
      ..writeByte(2)
      ..write(obj.dueDate)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.paidDate)
      ..writeByte(6)
      ..write(obj.transactionId)
      ..writeByte(7)
      ..write(obj.updatedAt)
      ..writeByte(8)
      ..write(obj.syncStatus);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DebtRepaymentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RepaymentStatusAdapter extends TypeAdapter<RepaymentStatus> {
  @override
  final int typeId = 31;

  @override
  RepaymentStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return RepaymentStatus.planned;
      case 1:
        return RepaymentStatus.paid;
      case 2:
        return RepaymentStatus.late_;
      default:
        return RepaymentStatus.planned;
    }
  }

  @override
  void write(BinaryWriter writer, RepaymentStatus obj) {
    switch (obj) {
      case RepaymentStatus.planned:
        writer.writeByte(0);
        break;
      case RepaymentStatus.paid:
        writer.writeByte(1);
        break;
      case RepaymentStatus.late_:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RepaymentStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
