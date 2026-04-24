import 'package:hive/hive.dart';

// Adapter in user_model.g.dart, registered by HiveService

@HiveType(typeId: 0)
class UserModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String username;

  @HiveField(2)
  final String fullName;

  @HiveField(3)
  final String role; // auditor, kabag, kadiv, admin

  @HiveField(4)
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      username: (json['username'] ?? json['email']) as String, // Compatibility
      fullName: json['full_name'] as String,
      role: json['role'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'role': role,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isAuditor => role == 'auditor';
  bool get isKabag => role == 'kabag';
  bool get isKadiv => role == 'kadiv';
  bool get isAdmin => role == 'admin';
  bool get canReview => isKabag || isKadiv || isAdmin;
  bool get canManage => isAdmin;

  UserModel copyWith({
    String? id,
    String? username,
    String? fullName,
    String? role,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
