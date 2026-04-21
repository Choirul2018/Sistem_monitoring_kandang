import 'package:hive/hive.dart';

// Adapter in location_model.g.dart, registered by HiveService

@HiveType(typeId: 1)
class LocationModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? address;

  @HiveField(3)
  final double latitude;

  @HiveField(4)
  final double longitude;

  @HiveField(5)
  final int geofenceRadiusM;

  @HiveField(6)
  final List<String> parts;

  @HiveField(7)
  final DateTime createdAt;

  LocationModel({
    required this.id,
    required this.name,
    this.address,
    required this.latitude,
    required this.longitude,
    this.geofenceRadiusM = 500,
    required this.parts,
    required this.createdAt,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      geofenceRadiusM: json['geofence_radius_m'] as int? ?? 500,
      parts: (json['parts'] as List<dynamic>?)?.cast<String>() ??
          ['Gerbang', 'Jalan Masuk', 'Area Kantor/Pos', 'Gudang',
           'Tempat Pakan', 'Tempat Minum', 'Kandang 1', 'Kandang 2'],
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'geofence_radius_m': geofenceRadiusM,
      'parts': parts,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
