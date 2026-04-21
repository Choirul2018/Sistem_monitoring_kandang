import 'package:hive/hive.dart';

// Adapter in photo_model.g.dart, registered by HiveService

@HiveType(typeId: 4)
class PhotoModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String auditPartId;

  @HiveField(2)
  final String localPath; // local file path

  @HiveField(3)
  String? storagePath; // remote storage path

  @HiveField(4)
  final DateTime timestamp;

  @HiveField(5)
  final double? gpsLatitude;

  @HiveField(6)
  final double? gpsLongitude;

  @HiveField(7)
  final String userId;

  @HiveField(8)
  final String locationId;

  @HiveField(9)
  final String partName;

  @HiveField(10)
  final double? blurScore;

  @HiveField(11)
  final double? exposureScore;

  @HiveField(12)
  bool aiValid;

  @HiveField(13)
  String? aiMessage;

  @HiveField(14)
  final String qrCodeId;

  @HiveField(15)
  bool synced;

  @HiveField(16)
  final String? metadataHash; // SHA256 hash for tamper detection

  PhotoModel({
    required this.id,
    required this.auditPartId,
    required this.localPath,
    this.storagePath,
    required this.timestamp,
    this.gpsLatitude,
    this.gpsLongitude,
    required this.userId,
    required this.locationId,
    required this.partName,
    this.blurScore,
    this.exposureScore,
    this.aiValid = true,
    this.aiMessage,
    required this.qrCodeId,
    this.synced = false,
    this.metadataHash,
  });

  factory PhotoModel.fromJson(Map<String, dynamic> json) {
    return PhotoModel(
      id: json['id'] as String,
      auditPartId: json['audit_part_id'] as String,
      localPath: json['local_path'] as String? ?? '',
      storagePath: json['storage_path'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      gpsLatitude: (json['gps_latitude'] as num?)?.toDouble(),
      gpsLongitude: (json['gps_longitude'] as num?)?.toDouble(),
      userId: json['user_id'] as String,
      locationId: json['location_id'] as String? ?? '',
      partName: json['part_name'] as String? ?? '',
      blurScore: (json['blur_score'] as num?)?.toDouble(),
      exposureScore: (json['exposure_score'] as num?)?.toDouble(),
      aiValid: json['ai_valid'] as bool? ?? true,
      aiMessage: json['ai_message'] as String?,
      qrCodeId: json['qr_code_id'] as String,
      synced: true,
      metadataHash: json['metadata_hash'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'audit_part_id': auditPartId,
      'storage_path': storagePath ?? '',
      'timestamp': timestamp.toIso8601String(),
      'gps_latitude': gpsLatitude,
      'gps_longitude': gpsLongitude,
      'user_id': userId,
      'blur_score': blurScore,
      'exposure_score': exposureScore,
      'ai_valid': aiValid,
      'qr_code_id': qrCodeId,
      'metadata_hash': metadataHash,
    };
  }

  String get coordinatesString {
    if (gpsLatitude == null || gpsLongitude == null) return 'GPS tidak tersedia';
    return '${gpsLatitude!.toStringAsFixed(6)}, ${gpsLongitude!.toStringAsFixed(6)}';
  }
}
