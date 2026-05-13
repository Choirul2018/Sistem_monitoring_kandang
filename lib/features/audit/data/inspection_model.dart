import 'package:hive/hive.dart';
 
@HiveType(typeId: 5)
class InspectionModel extends HiveObject {
  @HiveField(0)
  final String id;
 
  @HiveField(1)
  final String auditId;
 
  @HiveField(2)
  final String category; // infrastructure, safety, utility
 
  @HiveField(3)
  final bool isDefective;
 
  @HiveField(4)
  final String? issueDetails;
 
  @HiveField(5)
  List<String> photoIds;
 
  @HiveField(6)
  final DateTime createdAt;
 
  @HiveField(7)
  bool synced;
 
  InspectionModel({
    required this.id,
    required this.auditId,
    required this.category,
    required this.isDefective,
    this.issueDetails,
    this.photoIds = const [],
    required this.createdAt,
    this.synced = false,
  });
 
  factory InspectionModel.fromJson(Map<String, dynamic> json) {
    return InspectionModel(
      id: json['id'] as String,
      auditId: json['audit_id'] as String,
      category: json['category'] ?? json['animal_type'] as String, // Compatibility with old data
      isDefective: json['is_defective'] ?? json['has_disease'] as bool? ?? false,
      issueDetails: json['issue_details'] ?? json['disease_notes'] as String?,
      photoIds: (json['photo_ids'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: DateTime.parse(json['created_at'] as String),
      synced: true,
    );
  }
 
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'audit_id': auditId,
      'category': category,
      'is_defective': isDefective,
      'issue_details': issueDetails,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
 
class InspectionModelAdapter extends TypeAdapter<InspectionModel> {
  @override
  final int typeId = 5;
 
  @override
  InspectionModel read(BinaryReader reader) {
    return InspectionModel(
      id: reader.read(),
      auditId: reader.read(),
      category: reader.read(),
      isDefective: reader.read(),
      issueDetails: reader.read(),
      photoIds: (reader.read() as List).cast<String>(),
      createdAt: DateTime.parse(reader.read()),
      synced: reader.read(),
    );
  }
 
  @override
  void write(BinaryWriter writer, InspectionModel obj) {
    writer.write(obj.id);
    writer.write(obj.auditId);
    writer.write(obj.category);
    writer.write(obj.isDefective);
    writer.write(obj.issueDetails);
    writer.write(obj.photoIds);
    writer.write(obj.createdAt.toIso8601String());
    writer.write(obj.synced);
  }
}
