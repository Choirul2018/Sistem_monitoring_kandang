// GENERATED CODE - Hive TypeAdapter for PhotoModel
import 'package:hive/hive.dart';
import 'photo_model.dart';

class PhotoModelAdapter extends TypeAdapter<PhotoModel> {
  @override
  final int typeId = 4;

  @override
  PhotoModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PhotoModel(
      id: fields[0] as String,
      auditPartId: fields[1] as String,
      localPath: fields[2] as String,
      storagePath: fields[3] as String?,
      timestamp: fields[4] as DateTime,
      gpsLatitude: fields[5] as double?,
      gpsLongitude: fields[6] as double?,
      userId: fields[7] as String,
      locationId: fields[8] as String,
      partName: fields[9] as String,
      blurScore: fields[10] as double?,
      exposureScore: fields[11] as double?,
      aiValid: fields[12] as bool,
      aiMessage: fields[13] as String?,
      qrCodeId: fields[14] as String,
      synced: fields[15] as bool,
      metadataHash: fields[16] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PhotoModel obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.auditPartId)
      ..writeByte(2)
      ..write(obj.localPath)
      ..writeByte(3)
      ..write(obj.storagePath)
      ..writeByte(4)
      ..write(obj.timestamp)
      ..writeByte(5)
      ..write(obj.gpsLatitude)
      ..writeByte(6)
      ..write(obj.gpsLongitude)
      ..writeByte(7)
      ..write(obj.userId)
      ..writeByte(8)
      ..write(obj.locationId)
      ..writeByte(9)
      ..write(obj.partName)
      ..writeByte(10)
      ..write(obj.blurScore)
      ..writeByte(11)
      ..write(obj.exposureScore)
      ..writeByte(12)
      ..write(obj.aiValid)
      ..writeByte(13)
      ..write(obj.aiMessage)
      ..writeByte(14)
      ..write(obj.qrCodeId)
      ..writeByte(15)
      ..write(obj.synced)
      ..writeByte(16)
      ..write(obj.metadataHash);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
