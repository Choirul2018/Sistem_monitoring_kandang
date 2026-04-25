import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../audit/data/audit_model.dart';
import '../../audit/data/audit_part_model.dart';
import '../../audit/data/photo_model.dart';

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(ref.read(apiClientProvider));
});

class ApiService {
  final ApiClient _client;

  ApiService(this._client);

  /// Mengirim seluruh data Audit ke Laravel
  Future<bool> sendAuditToLaravel({
    required AuditModel audit,
    required List<AuditPartModel> parts,
    required List<PhotoModel> photos,
  }) async {
    try {
      // 1. Siapkan data parts dengan nested photos info
      final List<Map<String, dynamic>> partsWithPhotos = [];

      final Map<String, dynamic> formDataMap = {};

      for (var part in parts) {
        final partJson = part.toJson();
        
        // Sesuaikan dengan validasi Laravel: status (boolean) dan remarks (string/nullable)
        partJson['status'] = part.condition == 'baik' || part.condition == 'cukup';
        partJson['remarks'] = part.notes;
        
        final partPhotos = photos.where((p) => p.auditPartId == part.id).toList();
        
        final List<Map<String, dynamic>> photoInfos = [];
        
        for (var i = 0; i < partPhotos.length; i++) {
          final photo = partPhotos[i];
          final uploadKey = 'photo_${photo.id}';
          
          photoInfos.add({
            ...photo.toJson(),
            'upload_key': uploadKey,
          });

          final file = File(photo.localPath);
          if (await file.exists()) {
            formDataMap[uploadKey] = await MultipartFile.fromFile(
              file.path,
              filename: '${photo.id}.jpg',
            );
          }
        }

        partJson['photos'] = photoInfos;
        partsWithPhotos.add(partJson);
      }

      // 2. Siapkan Payload Utama
      // Laravel AuditSyncController mengharapkan 'audit' dan 'parts' sebagai JSON string
      formDataMap['audit'] = jsonEncode(audit.toJson());
      formDataMap['parts'] = jsonEncode(partsWithPhotos);

      final formData = FormData.fromMap(formDataMap);

      // 3. Kirim ke Laravel
      final response = await _client.post('/audit/sync', data: formData);

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Error syncing to Laravel: $e');
      return false;
    }
  }

  /// Login ke Laravel
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await _client.post('/login', data: {
        'username': username,
        'password': password,
        'device_name': 'flutter_mobile',
      });

      if (response.statusCode == 200) {
        return response.data; // Mengembalikan { "token": "...", "user": {...} }
      }
      throw Exception('Gagal login: Status ${response.statusCode}');
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        throw Exception('Username atau password salah.');
      }
      rethrow;
    }
  }

  /// Logout dari Laravel
  Future<void> logout() async {
    try {
      await _client.post('/logout');
    } catch (e) {
      print('Logout error: $e');
    }
  }

  /// Ambil daftar lokasi dari Laravel
  Future<List<dynamic>> getLocations() async {
    try {
      final response = await _client.get('/locations');
      if (response.statusCode == 200) {
        // Laravel mengembalikan { "data": [...] }
        return response.data['data'] as List<dynamic>;
      }
      return [];
    } catch (e) {
      print('Get locations error: $e');
      return [];
    }
  }
}
