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
      // 1. Siapkan data JSON untuk audit dan bagian-bagiannya
      final Map<String, dynamic> auditData = audit.toJson();
      
      // Tambahkan detail bagian ke dalam payload
      auditData['parts_detail'] = parts.map((p) => p.toJson()).toList();

      // 2. Siapkan Multipart untuk Foto
      final formDataMap = <String, dynamic>{
        'audit': auditData,
      };

      // Tambahkan file foto ke FormData
      for (int i = 0; i < photos.length; i++) {
        final photo = photos[i];
        final file = File(photo.localPath);
        
        if (await file.exists()) {
          formDataMap['photo_$i'] = await MultipartFile.fromFile(
            file.path,
            filename: 'audit_${audit.id}_part_${photo.auditPartId}_$i.jpg',
          );
        }
      }

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
  Future<String?> login(String username, String password) async {
    try {
      final response = await _client.post('/login', data: {
        'username': username,
        'password': password,
      });

      if (response.statusCode == 200) {
        return response.data['token']; // Asumsi Laravel mengembalikan field 'token'
      }
      return null;
    } catch (e) {
      return null;
    }
  /// Ambil daftar lokasi dari Laravel
  Future<List<dynamic>> getLocations() async {
    try {
      final response = await _client.get('/locations');
      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
