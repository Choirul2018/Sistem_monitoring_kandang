import 'dart:convert';
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
      id: json['id'].toString(), // Pastikan ID jadi String apapun bentuknya
      name: json['name']?.toString() ?? 'Lokasi Tanpa Nama',
      address: json['address']?.toString(),
      latitude: (json['latitude'] is num) ? (json['latitude'] as num).toDouble() : 0.0,
      longitude: (json['longitude'] is num) ? (json['longitude'] as num).toDouble() : 0.0,
      geofenceRadiusM: int.tryParse(json['geofence_radius_m']?.toString() ?? '500') ?? 500,
      parts: _parseParts(json['parts']),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'].toString()) 
          : DateTime.now(),
    );
  }

  static List<String> _parseParts(dynamic partsJson) {
    if (partsJson == null) return _defaultParts;
    
    try {
      if (partsJson is List) {
        return partsJson.map((e) => e.toString()).toList();
      }
      
      if (partsJson is String) {
        // Jika dikirim sebagai string JSON "[...]"
        if (partsJson.startsWith('[') && partsJson.endsWith(']')) {
          final decoded = json.decode(partsJson);
          if (decoded is List) {
            return decoded.map((e) => e.toString()).toList();
          }
        }
        // Jika dikirim dipisah koma "A,B,C"
        return partsJson.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
    } catch (e) {
      print('Error parsing parts: $e');
    }
    
    return _defaultParts;
  }

  static List<String> get _defaultParts => [
    'Gerbang Utama', 'Area Parkir', 'Gudang Pakan', 'Kandang Utama', 'Pos Jaga'
  ];

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
