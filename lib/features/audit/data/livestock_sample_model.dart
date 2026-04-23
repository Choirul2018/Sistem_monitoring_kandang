import 'package:hive/hive.dart';

@HiveType(typeId: 5) // Diubah dari 4 ke 5 agar tidak bentrok dengan PhotoModel
class LivestockSampleModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String auditId;

  @HiveField(2)
  final String animalType; // ayam, bebek

  @HiveField(3)
  final bool hasDisease;

  @HiveField(4)
  final String? diseaseNotes;

  @HiveField(5)
  final List<String> photoIds;

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  bool synced;

  LivestockSampleModel({
    required this.id,
    required this.auditId,
    required this.animalType,
    required this.hasDisease,
    this.diseaseNotes,
    this.photoIds = const [],
    required this.createdAt,
    this.synced = false,
  });

  factory LivestockSampleModel.fromJson(Map<String, dynamic> json) {
    return LivestockSampleModel(
      id: json['id'] as String,
      auditId: json['audit_id'] as String,
      animalType: json['animal_type'] as String,
      hasDisease: json['has_disease'] as bool? ?? false,
      diseaseNotes: json['disease_notes'] as String?,
      photoIds: (json['photo_ids'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: DateTime.parse(json['created_at'] as String),
      synced: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'audit_id': auditId,
      'animal_type': animalType,
      'has_disease': hasDisease,
      'disease_notes': diseaseNotes,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class LivestockSampleModelAdapter extends TypeAdapter<LivestockSampleModel> {
  @override
  final int typeId = 5; // Samakan dengan di atas

  @override
  LivestockSampleModel read(BinaryReader reader) {
    return LivestockSampleModel(
      id: reader.read(),
      auditId: reader.read(),
      animalType: reader.read(),
      hasDisease: reader.read(),
      diseaseNotes: reader.read(),
      photoIds: (reader.read() as List).cast<String>(),
      createdAt: DateTime.parse(reader.read()),
      synced: reader.read(),
    );
  }

  @override
  void write(BinaryWriter writer, LivestockSampleModel obj) {
    writer.write(obj.id);
    writer.write(obj.auditId);
    writer.write(obj.animalType);
    writer.write(obj.hasDisease);
    writer.write(obj.diseaseNotes);
    writer.write(obj.photoIds);
    writer.write(obj.createdAt.toIso8601String());
    writer.write(obj.synced);
  }
}
