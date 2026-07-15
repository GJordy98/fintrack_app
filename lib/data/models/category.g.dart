// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CategoryAdapter extends TypeAdapter<Category> {
  @override
  final int typeId = 2;

  @override
  Category read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Category(
      id: fields[0] as String,
      name: fields[1] as String,
      kind: fields[2] as CategoryKind,
      iconCodePoint: fields[3] as int,
      colorValue: fields[4] as int,
      isCustom: fields[5] as bool,
      archived: fields[6] as bool,
      updatedAt: fields[7] as DateTime,
      syncStatus: fields[8] as SyncStatus,
      isFixed: fields[9] == null ? false : fields[9] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Category obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.kind)
      ..writeByte(3)
      ..write(obj.iconCodePoint)
      ..writeByte(4)
      ..write(obj.colorValue)
      ..writeByte(5)
      ..write(obj.isCustom)
      ..writeByte(6)
      ..write(obj.archived)
      ..writeByte(7)
      ..write(obj.updatedAt)
      ..writeByte(8)
      ..write(obj.syncStatus)
      ..writeByte(9)
      ..write(obj.isFixed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CategoryKindAdapter extends TypeAdapter<CategoryKind> {
  @override
  final int typeId = 22;

  @override
  CategoryKind read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return CategoryKind.income;
      case 1:
        return CategoryKind.expense;
      default:
        return CategoryKind.income;
    }
  }

  @override
  void write(BinaryWriter writer, CategoryKind obj) {
    switch (obj) {
      case CategoryKind.income:
        writer.writeByte(0);
        break;
      case CategoryKind.expense:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryKindAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
