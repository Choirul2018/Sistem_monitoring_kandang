import 'package:hive/hive.dart';
import '../../../core/network/api_client.dart';
import 'user_model.dart';

class AuthRepository {
  final ApiClient _apiClient;

  AuthRepository(this._apiClient);

  // ─── Sign In ───
  Future<UserModel> signIn({
    required String username,
    required String password,
  }) async {
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
  Future<UserModel> signUp({
    required String username,
    required String password,
    required String fullName,
    String role = 'auditor',
    String? email,
  }) async {
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
  }

  // ─── Sign Out ───
  Future<void> signOut() async {
    try {
      await _apiClient.post('/logout');
    } catch (_) {}
    
    await _apiClient.storage.delete(key: 'auth_token');
    final box = Hive.box<UserModel>('user');
    await box.clear();
  }

  // ─── Get Current User ───
  Future<UserModel?> getCurrentUser() async {
    final token = await _apiClient.storage.read(key: 'auth_token');
    if (token == null) return null;

    final box = Hive.box<UserModel>('user');
    return box.get('current_user');
  }

  // ─── Check if Logged In ───
  bool get isLoggedIn {
    final box = Hive.box<UserModel>('user');
    return box.containsKey('current_user');
  }
}
