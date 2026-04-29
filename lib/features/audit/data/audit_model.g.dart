// GENERATED CODE - Hive TypeAdapter for AuditModel
import 'package:hive/hive.dart';
import 'audit_model.dart';

class AuditModelAdapter extends TypeAdapter<AuditModel> {
  @override
  final int typeId = 2;

  @override
  AuditModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AuditModel(
      id: fields[0] as String,
      locationId: fields[1] as String,
      auditorId: fields[2] as String,
      status: fields[3] as String,
      currentPartIndex: fields[4] as int,
      signatureData: fields[5] as String?,
      reviewedBy: fields[6] as String?,
      reviewNotes: fields[7] as String?,
      createdAt: fields[8] as DateTime,
      updatedAt: fields[9] as DateTime,
      synced: fields[10] as bool,
      locationName: fields[11] as String?,
      auditorName: fields[12] as String?,
      parts: (fields[13] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, AuditModel obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.locationId)
      ..writeByte(2)
      ..write(obj.auditorId)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.currentPartIndex)
      ..writeByte(5)
      ..write(obj.signatureData)
      ..writeByte(6)
      ..write(obj.reviewedBy)
      ..writeByte(7)
      ..write(obj.reviewNotes)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.updatedAt)
      ..writeByte(10)
      ..write(obj.synced)
      ..writeByte(11)
      ..write(obj.locationName)
      ..writeByte(12)
      ..write(obj.auditorName)
      ..writeByte(13)
      ..write(obj.parts);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuditModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
