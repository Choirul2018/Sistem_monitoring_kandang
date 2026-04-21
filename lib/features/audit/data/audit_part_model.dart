import 'package:hive/hive.dart';

// Adapter in audit_part_model.g.dart, registered by HiveService

@HiveType(typeId: 3)
class AuditPartModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String auditId;

  @HiveField(2)
  final String partName;

  @HiveField(3)
  final int partIndex;

  @HiveField(4)
  bool partExists;

  @HiveField(5)
  String? condition; // baik, cukup, buruk

  @HiveField(6)
  String? notes;

  @HiveField(7)
  bool completed;

  @HiveField(8)
  final DateTime createdAt;

  @HiveField(9)
  bool synced;

  @HiveField(10)
  List<String> photoIds; // references to PhotoModel ids

  AuditPartModel({
    required this.id,
    required this.auditId,
    required this.partName,
    required this.partIndex,
    this.partExists = true,
    this.condition,
    this.notes,
    this.completed = false,
    required this.createdAt,
    this.synced = false,
    this.photoIds = const [],
  });

  factory AuditPartModel.fromJson(Map<String, dynamic> json) {
    return AuditPartModel(
      id: json['id'] as String,
      auditId: json['audit_id'] as String,
      partName: json['part_name'] as String,
      partIndex: json['part_index'] as int,
      partExists: json['part_exists'] as bool? ?? true,
      condition: json['condition'] as String?,
      notes: json['notes'] as String?,
      completed: json['completed'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      synced: true,
      photoIds: (json['photo_ids'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'audit_id': auditId,
      'part_name': partName,
      'part_index': partIndex,
      'part_exists': partExists,
      'condition': condition,
      'notes': notes,
      'completed': completed,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isValid {
    if (!partExists) {
      return notes != null && notes!.isNotEmpty;
    }
    if (condition == null) return false;
    if (condition == 'buruk' && (notes == null || notes!.isEmpty)) return false;
    if (photoIds.isEmpty) return false;
    return true;
  }

  bool get needsNotes => !partExists || condition == 'buruk';
}
