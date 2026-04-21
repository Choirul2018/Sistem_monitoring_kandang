import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';
import 'user_model.dart';
import '../../../core/constants/supabase_constants.dart';

class AuthRepository {
  final SupabaseClient _client = Supabase.instance.client;

  // ─── Sign In (Dummy Bypass) ───
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    // Delay simulasi jaringan
    await Future.delayed(const Duration(seconds: 1));

    // Validasi dummy
    if (password.length < 6) {
      throw Exception('Password terlalu pendek (minimal 6 karakter).');
    }

    // Role berdasarkan email
    String role = 'auditor';
    if (email.contains('kabag')) role = 'kabag';
    if (email.contains('kadiv')) role = 'kadiv';
    if (email.contains('admin')) role = 'admin';

    final dummyUser = UserModel(
      id: 'dummy-${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      fullName: 'Dummy ${role.toUpperCase()}',
      role: role,
      createdAt: DateTime.now(),
    );

    final box = Hive.box<UserModel>('user');
    await box.put('current_user', dummyUser);

    return dummyUser;
  }

  // ─── Sign Up (Dummy Bypass) ───
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) async {
    await Future.delayed(const Duration(seconds: 1));

    final dummyUser = UserModel(
      id: 'dummy-${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      fullName: fullName,
      role: role,
      createdAt: DateTime.now(),
    );

    final box = Hive.box<UserModel>('user');
    await box.put('current_user', dummyUser);

    return dummyUser;
  }

  // ─── Sign Out (Dummy Bypass) ───
  Future<void> signOut() async {
    final box = Hive.box<UserModel>('user');
    await box.clear();
  }

  // ─── Get Current User (Dummy Bypass) ───
  Future<UserModel?> getCurrentUser() async {
    final box = Hive.box<UserModel>('user');
    return box.get('current_user');
  }

  // ─── Fetch Profile ───
  Future<UserModel> _fetchProfile(String userId) async {
    // Dipanggil hanya via Supabase normalnya. 
    // Untuk dummy, kita return user dummy.
    final box = Hive.box<UserModel>('user');
    return box.get('current_user')!;
  }

  // ─── Get All Users (Dummy Admin) ───
  Future<List<UserModel>> getAllUsers() async {
    return [
      UserModel(id: '1', email: 'auditor1@test.com', fullName: 'Auditor Satu', role: 'auditor', createdAt: DateTime.now()),
      UserModel(id: '2', email: 'kabag@test.com', fullName: 'Kabag Dummy', role: 'kabag', createdAt: DateTime.now()),
    ];
  }

  // ─── Auth State Stream ───
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // ─── Check if Logged In (Dummy Bypass) ───
  bool get isLoggedIn {
    final box = Hive.box<UserModel>('user');
    return box.containsKey('current_user');
  }
}
