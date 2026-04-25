import 'package:hive/hive.dart';
<<<<<<< Updated upstream
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../sync/data/api_service.dart';
import 'user_model.dart';

class AuthRepository {
  final ApiService _apiService;
  
  AuthRepository(this._apiService);

  // ─── Sign In (Real API) ───
=======
import '../../../core/network/api_client.dart';
import 'user_model.dart';

class AuthRepository {
  final ApiClient _apiClient;

  AuthRepository(this._apiClient);

  // ─── Sign In ───
>>>>>>> Stashed changes
  Future<UserModel> signIn({
    required String username,
    required String password,
  }) async {
<<<<<<< Updated upstream
    // 1. Panggil API Login
    final response = await _apiService.login(username, password);
    
    // 2. Ambil data user dan token dari response
    final userData = response['user'];
    final token = response['token'];

    // 3. Simpan token ke SecureStorage
    const storage = FlutterSecureStorage();
    await storage.write(key: 'auth_token', value: token);

    // 4. Map ke UserModel
    final user = UserModel(
      id: userData['id'].toString(),
      username: userData['username'],
      fullName: userData['name'] ?? userData['username'], // Cocokkan dengan field 'name' di Laravel
      role: userData['role'] ?? 'auditor',
      createdAt: DateTime.now(),
    );

    // 5. Simpan info user ke Hive
    final box = Hive.box<UserModel>('user');
    await box.put('current_user', user);

    return user;
  }

  // ─── Sign Up (Placeholder) ───
=======
    try {
      final response = await _apiClient.post('/login', data: {
        'username': username,
        'password': password,
        'device_name': 'flutter-app',
      });

      final data = response.data;
      final token = data['token'];
      final userJson = data['user'];

      // Simpan token ke secure storage via ApiClient
      await _apiClient.storage.write(key: 'auth_token', value: token);

      // Map Laravel user to UserModel
      final user = UserModel(
        id: userJson['id'].toString(),
        username: userJson['username'],
        fullName: userJson['name'], // Laravel 'name' -> Flutter 'fullName'
        role: userJson['role'] ?? 'auditor', // Fallback role
        createdAt: DateTime.parse(userJson['created_at']),
      );

      final box = Hive.box<UserModel>('user');
      await box.put('current_user', user);

      return user;
    } catch (e) {
      rethrow;
    }
  }

  // ─── Sign Up ───
>>>>>>> Stashed changes
  Future<UserModel> signUp({
    required String username,
    required String password,
    required String fullName,
    String role = 'auditor',
    String? email,
  }) async {
<<<<<<< Updated upstream
    throw Exception('Pendaftaran mandiri belum tersedia. Silakan hubungi admin.');
=======
    try {
      final response = await _apiClient.post('/register', data: {
        'name': fullName,
        'username': username,
        'email': email ?? '$username@example.com', // Fallback if email not provided
        'password': password,
        'device_name': 'flutter-app',
      });

      final data = response.data;
      final token = data['token'];
      final userJson = data['user'];

      await _apiClient.storage.write(key: 'auth_token', value: token);

      final user = UserModel(
        id: userJson['id'].toString(),
        username: userJson['username'],
        fullName: userJson['name'],
        role: userJson['role'] ?? 'auditor',
        createdAt: DateTime.parse(userJson['created_at']),
      );

      final box = Hive.box<UserModel>('user');
      await box.put('current_user', user);

      return user;
    } catch (e) {
      rethrow;
    }
>>>>>>> Stashed changes
  }

  // ─── Sign Out ───
  Future<void> signOut() async {
    try {
<<<<<<< Updated upstream
      await _apiService.logout();
    } catch (_) {}
    
    const storage = FlutterSecureStorage();
    await storage.delete(key: 'auth_token');
    
=======
      await _apiClient.post('/logout');
    } catch (_) {}
    
    await _apiClient.storage.delete(key: 'auth_token');
>>>>>>> Stashed changes
    final box = Hive.box<UserModel>('user');
    await box.clear();
  }

  // ─── Get Current User ───
  Future<UserModel?> getCurrentUser() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'auth_token');
    
    // Jika token tidak ada (misal setelah refresh), maka paksa login ulang
    if (token == null) return null;

    final box = Hive.box<UserModel>('user');
    return box.get('current_user');
  }

  // ─── Check if Logged In ───
  Future<bool> get isLoggedIn async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'auth_token');
    return token != null;
  }
}
