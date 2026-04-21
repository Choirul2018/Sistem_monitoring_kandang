import 'package:hive/hive.dart';

// Adapter in audit_model.g.dart, registered by HiveService

@HiveType(typeId: 2)
class AuditModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String locationId;

  @HiveField(2)
  final String auditorId;

  @HiveField(3)
  String status; // draft, in_progress, pending_review, approved, rejected

  @HiveField(4)
  int currentPartIndex;

  @HiveField(5)
  String? signatureData; // base64 PNG

  @HiveField(6)
  String? reviewedBy;

  @HiveField(7)
  String? reviewNotes;

  @HiveField(8)
  final DateTime createdAt;

  @HiveField(9)
  DateTime updatedAt;

  @HiveField(10)
  bool synced;

  @HiveField(11)
  String? locationName; // cached for offline display

  @HiveField(12)
  String? auditorName; // cached for offline display

  @HiveField(13)
  List<String> parts; // ordered part names

  AuditModel({
    required this.id,
    required this.locationId,
    required this.auditorId,
    this.status = 'draft',
    this.currentPartIndex = 0,
    this.signatureData,
    this.reviewedBy,
    this.reviewNotes,
    required this.createdAt,
    required this.updatedAt,
    this.synced = false,
    this.locationName,
    this.auditorName,
    this.parts = const [],
  });

  factory AuditModel.fromJson(Map<String, dynamic> json) {
    return AuditModel(
      id: json['id'] as String,
      locationId: json['location_id'] as String,
      auditorId: json['auditor_id'] as String,
      status: json['status'] as String? ?? 'draft',
      currentPartIndex: json['current_part_index'] as int? ?? 0,
      signatureData: json['signature_data'] as String?,
      reviewedBy: json['reviewed_by'] as String?,
      reviewNotes: json['review_notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      synced: true,
      locationName: json['location_name'] as String?,
      auditorName: json['auditor_name'] as String?,
      parts: (json['parts'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'location_id': locationId,
      'auditor_id': auditorId,
      'status': status,
      'current_part_index': currentPartIndex,
      'signature_data': signatureData,
      'reviewed_by': reviewedBy,
      'review_notes': reviewNotes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isDraft => status == 'draft';
  bool get isInProgress => status == 'in_progress';
  bool get isPendingReview => status == 'pending_review';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isCompleted => isApproved;
  bool get isLocked => isApproved;

  double get progressPercent {
    if (parts.isEmpty) return 0;
    return currentPartIndex / parts.length;
  }
}
