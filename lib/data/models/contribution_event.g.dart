// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contribution_event.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ContributionEventAdapter extends TypeAdapter<ContributionEvent> {
  @override
  final int typeId = 9;

  @override
  ContributionEvent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ContributionEvent(
      id: fields[0] as String,
      contributionId: fields[1] as String,
      date: fields[2] as DateTime,
      kind: fields[3] as ContributionEventKind,
      amount: fields[4] as int,
      status: fields[5] as EventStatus,
      transactionId: fields[6] as String?,
      updatedAt: fields[7] as DateTime,
      syncStatus: fields[8] as SyncStatus,
    );
  }

  @override
  void write(BinaryWriter writer, ContributionEvent obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.contributionId)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.kind)
      ..writeByte(4)
      ..write(obj.amount)
      ..writeByte(5)
      ..write(obj.status)
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
      other is ContributionEventAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ContributionEventKindAdapter extends TypeAdapter<ContributionEventKind> {
  @override
  final int typeId = 27;

  @override
  ContributionEventKind read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ContributionEventKind.contribute;
      case 1:
        return ContributionEventKind.receive;
      default:
        return ContributionEventKind.contribute;
    }
  }

  @override
  void write(BinaryWriter writer, ContributionEventKind obj) {
    switch (obj) {
      case ContributionEventKind.contribute:
        writer.writeByte(0);
        break;
      case ContributionEventKind.receive:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContributionEventKindAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class EventStatusAdapter extends TypeAdapter<EventStatus> {
  @override
  final int typeId = 28;

  @override
  EventStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return EventStatus.upcoming;
      case 1:
        return EventStatus.done;
      case 2:
        return EventStatus.missed;
      default:
        return EventStatus.upcoming;
    }
  }

  @override
  void write(BinaryWriter writer, EventStatus obj) {
    switch (obj) {
      case EventStatus.upcoming:
        writer.writeByte(0);
        break;
      case EventStatus.done:
        writer.writeByte(1);
        break;
      case EventStatus.missed:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
