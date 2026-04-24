import 'package:hive/hive.dart';
import 'user_model.dart';

class AuthRepository {
  // ─── Sign In (Dummy Bypass) ───
  Future<UserModel> signIn({
    required String username,
    required String password,
  }) async {
    // Delay simulasi jaringan
    await Future.delayed(const Duration(seconds: 1));

    // Validasi dummy
    if (password.length < 6) {
      throw Exception('Password terlalu pendek (minimal 6 karakter).');
    }

    final dummyUser = UserModel(
      id: 'dummy-${DateTime.now().millisecondsSinceEpoch}',
      username: username,
      fullName: username,
      role: 'auditor',
      createdAt: DateTime.now(),
    );

    final box = Hive.box<UserModel>('user');
    await box.put('current_user', dummyUser);

    return dummyUser;
  }

  // ─── Sign Up (Dummy Bypass) ───
  Future<UserModel> signUp({
    required String username,
    required String password,
    required String fullName,
    required String role,
  }) async {
    await Future.delayed(const Duration(seconds: 1));

    final dummyUser = UserModel(
      id: 'dummy-${DateTime.now().millisecondsSinceEpoch}',
      username: username,
      fullName: fullName,
      role: 'auditor',
      createdAt: DateTime.now(),
    );

    final box = Hive.box<UserModel>('user');
    await box.put('current_user', dummyUser);

    return dummyUser;
  }

  // ─── Sign Out ───
  Future<void> signOut() async {
    final box = Hive.box<UserModel>('user');
    await box.clear();
  }

  // ─── Get Current User ───
  Future<UserModel?> getCurrentUser() async {
    final box = Hive.box<UserModel>('user');
    return box.get('current_user');
  }

  // ─── Check if Logged In ───
  bool get isLoggedIn {
    final box = Hive.box<UserModel>('user');
    return box.containsKey('current_user');
  }
}
