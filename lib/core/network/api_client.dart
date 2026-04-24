import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

class ApiClient {
  late Dio dio;
  final storage = const FlutterSecureStorage();

  // Alamat backend Laravel. 
  // ---------------------------------------------------------
  static const String baseUrl = 'http://localhost:8000/api'; 
  // static const String baseUrl = 'http://10.0.2.2:8000/api'; // Emulator
  // static const String baseUrl = 'http://192.168.0.104:8000/api'; // HP Fisik

  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Interceptor untuk menambahkan Token JWT dari Laravel Sanctum/Passport
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await storage.read(key: 'auth_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            // Jika tidak diizinkan (401), hapus token agar user bisa login ulang
            await storage.delete(key: 'auth_token');
          }
          return handler.next(e);
        },
      ),
    );
  }

  // Helper untuk GET
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    return await dio.get(path, queryParameters: queryParameters);
  }

  // Helper untuk POST
  Future<Response> post(String path, {dynamic data}) async {
    return await dio.post(path, data: data);
  }

  // Helper untuk Upload File (Multipart)
  Future<Response> upload(String path, FormData formData) async {
    return await dio.post(path, data: formData);
  }
}
