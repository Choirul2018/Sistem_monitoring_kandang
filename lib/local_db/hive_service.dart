import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../features/auth/data/user_model.dart';
import '../features/auth/data/user_model.g.dart';
import '../features/audit/data/audit_model.dart';
import '../features/audit/data/audit_model.g.dart';
import '../features/audit/data/audit_part_model.dart';
import '../features/audit/data/audit_part_model.g.dart';
import '../features/audit/data/photo_model.dart';
import '../features/audit/data/photo_model.g.dart';
import '../features/location/data/location_model.dart';
import '../features/location/data/location_model.g.dart';

class HiveService {
  static const _encryptionKeyName = 'hive_encryption_key';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  // Box names
  static const String userBox = 'user';
  static const String auditsBox = 'audits';
  static const String auditPartsBox = 'audit_parts';
  static const String photosBox = 'photos';
  static const String locationsBox = 'locations';
  static const String syncQueueBox = 'sync_queue';
  static const String settingsBox = 'settings';

  static Future<void> initialize() async {
    // Register adapters
    Hive.registerAdapter(UserModelAdapter());
    Hive.registerAdapter(LocationModelAdapter());
    Hive.registerAdapter(AuditModelAdapter());
    Hive.registerAdapter(AuditPartModelAdapter());
    Hive.registerAdapter(PhotoModelAdapter());

    // Get or create encryption key
    final encryptionKey = await _getEncryptionKey();

    // Open encrypted boxes
    await Hive.openBox<UserModel>(userBox,
        encryptionCipher: HiveAesCipher(encryptionKey));
    await Hive.openBox<AuditModel>(auditsBox,
        encryptionCipher: HiveAesCipher(encryptionKey));
    await Hive.openBox<AuditPartModel>(auditPartsBox,
        encryptionCipher: HiveAesCipher(encryptionKey));
    await Hive.openBox<PhotoModel>(photosBox,
        encryptionCipher: HiveAesCipher(encryptionKey));
    await Hive.openBox<LocationModel>(locationsBox,
        encryptionCipher: HiveAesCipher(encryptionKey));
    await Hive.openBox<Map>(syncQueueBox);
    await Hive.openBox(settingsBox);
  }

  static Future<List<int>> _getEncryptionKey() async {
    final existingKey = await _secureStorage.read(key: _encryptionKeyName);
    if (existingKey != null) {
      return base64Decode(existingKey);
    }

    final newKey = Hive.generateSecureKey();
    await _secureStorage.write(
      key: _encryptionKeyName,
      value: base64Encode(newKey),
    );
    return newKey;
  }

  // ─── Box Accessors ───
  static Box<UserModel> get users => Hive.box<UserModel>(userBox);
  static Box<AuditModel> get audits => Hive.box<AuditModel>(auditsBox);
  static Box<AuditPartModel> get auditParts => Hive.box<AuditPartModel>(auditPartsBox);
  static Box<PhotoModel> get photos => Hive.box<PhotoModel>(photosBox);
  static Box<LocationModel> get locations => Hive.box<LocationModel>(locationsBox);
  static Box<Map> get syncQueue => Hive.box<Map>(syncQueueBox);
  static Box get settings => Hive.box(settingsBox);

  // ─── Clear All Data ───
  static Future<void> clearAll() async {
    await users.clear();
    await audits.clear();
    await auditParts.clear();
    await photos.clear();
    await locations.clear();
    await syncQueue.clear();
  }
}
