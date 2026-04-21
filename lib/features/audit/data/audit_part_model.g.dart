// GENERATED CODE - Hive TypeAdapter for AuditPartModel
import 'package:hive/hive.dart';
import 'audit_part_model.dart';

class AuditPartModelAdapter extends TypeAdapter<AuditPartModel> {
  @override
  final int typeId = 3;

  @override
  AuditPartModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AuditPartModel(
      id: fields[0] as String,
      auditId: fields[1] as String,
      partName: fields[2] as String,
      partIndex: fields[3] as int,
      partExists: fields[4] as bool,
      condition: fields[5] as String?,
      notes: fields[6] as String?,
      completed: fields[7] as bool,
      createdAt: fields[8] as DateTime,
      synced: fields[9] as bool,
      photoIds: (fields[10] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, AuditPartModel obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.auditId)
      ..writeByte(2)
      ..write(obj.partName)
      ..writeByte(3)
      ..write(obj.partIndex)
      ..writeByte(4)
      ..write(obj.partExists)
      ..writeByte(5)
      ..write(obj.condition)
      ..writeByte(6)
      ..write(obj.notes)
      ..writeByte(7)
      ..write(obj.completed)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.synced)
      ..writeByte(10)
      ..write(obj.photoIds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuditPartModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
