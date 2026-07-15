// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'goal_status_history.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GoalStatusHistoryAdapter extends TypeAdapter<GoalStatusHistory> {
  @override
  final int typeId = 7;

  @override
  GoalStatusHistory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GoalStatusHistory(
      id: fields[0] as String,
      goalId: fields[1] as String,
      status: fields[2] as GoalStatus,
      date: fields[3] as DateTime,
      amountAtEvaluation: fields[4] as int,
      acknowledged: fields[5] as bool,
      syncStatus: fields[6] as SyncStatus,
    );
  }

  @override
  void write(BinaryWriter writer, GoalStatusHistory obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.goalId)
      ..writeByte(2)
      ..write(obj.status)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.amountAtEvaluation)
      ..writeByte(5)
      ..write(obj.acknowledged)
      ..writeByte(6)
      ..write(obj.syncStatus);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalStatusHistoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
