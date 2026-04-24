import 'package:hive/hive.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../sync/data/api_service.dart';
import 'user_model.dart';

class AuthRepository {
  final ApiService _apiService;
  
  AuthRepository(this._apiService);

  // ─── Sign In (Real API) ───
  Future<UserModel> signIn({
    required String username,
    required String password,
  }) async {
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
  Future<UserModel> signUp({
    required String username,
    required String password,
    required String fullName,
    required String role,
  }) async {
    throw Exception('Pendaftaran mandiri belum tersedia. Silakan hubungi admin.');
  }

  // ─── Sign Out ───
  Future<void> signOut() async {
    try {
      await _apiService.logout();
    } catch (_) {}
    
    const storage = FlutterSecureStorage();
    await storage.delete(key: 'auth_token');
    
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
