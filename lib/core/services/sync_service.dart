import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../local_db/hive_service.dart';
import '../../core/constants/supabase_constants.dart';
import '../../features/audit/data/photo_model.dart';

class SyncService {
  final SupabaseClient _client = Supabase.instance.client;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;

  // ─── Start Listening for Connectivity ───
  void startListening() {
    _connectivitySubscription = _connectivity.onConnectivityChanged
        .listen((results) {
      final hasConnection = results.any(
        (r) => r != ConnectivityResult.none,
      );
      if (hasConnection && !_isSyncing) {
        syncAll();
      }
    });
  }

  // ─── Stop Listening ───
  void stopListening() {
    _connectivitySubscription?.cancel();
  }

  // ─── Check if Online ───
  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  // ─── Sync All Pending Data ───
  Future<SyncResult> syncAll() async {
    if (_isSyncing) return SyncResult(synced: 0, failed: 0, message: 'Sudah sedang sinkronisasi.');
    _isSyncing = true;

    int synced = 0;
    int failed = 0;

    try {
      if (!await isOnline()) {
        return SyncResult(synced: 0, failed: 0, message: 'Tidak ada koneksi internet.');
      }

      // Sync audits
      final unsyncedAudits = HiveService.audits.values.where((a) => !a.synced);
      for (final audit in unsyncedAudits) {
        try {
          await _client
              .from(SupabaseConstants.auditsTable)
              .upsert(audit.toJson());
          audit.synced = true;
          await HiveService.audits.put(audit.id, audit);
          synced++;
        } catch (e) {
          failed++;
        }
      }

      // Sync audit parts
      final unsyncedParts = HiveService.auditParts.values.where((p) => !p.synced);
      for (final part in unsyncedParts) {
        try {
          await _client
              .from(SupabaseConstants.auditPartsTable)
              .upsert(part.toJson());
          part.synced = true;
          await HiveService.auditParts.put(part.id, part);
          synced++;
        } catch (e) {
          failed++;
        }
      }

      // Sync photos (upload file + metadata)
      final unsyncedPhotos = HiveService.photos.values.where((p) => !p.synced);
      for (final photo in unsyncedPhotos) {
        try {
          await _syncPhoto(photo);
          synced++;
        } catch (e) {
          failed++;
        }
      }

      // Clear sync queue for successfully synced items
      final keys = HiveService.syncQueue.keys.toList();
      for (final key in keys) {
        await HiveService.syncQueue.delete(key);
      }
    } finally {
      _isSyncing = false;
    }

    return SyncResult(
      synced: synced,
      failed: failed,
      message: synced > 0
          ? '$synced item berhasil disinkronkan.'
          : 'Semua data sudah tersinkronkan.',
    );
  }

  // ─── Sync Single Photo ───
  Future<void> _syncPhoto(PhotoModel photo) async {
    final file = File(photo.localPath);
    if (!await file.exists()) return;

    // Upload to Supabase Storage
    final remotePath = 'audits/${photo.auditPartId}/${photo.id}.jpg';
    final bytes = await file.readAsBytes();

    await _client.storage
        .from(SupabaseConstants.photosBucket)
        .uploadBinary(
          remotePath,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

    // Update metadata in database
    photo.storagePath = remotePath;
    photo.synced = true;

    await _client
        .from(SupabaseConstants.auditPhotosTable)
        .upsert(photo.toJson());

    await HiveService.photos.put(photo.id, photo);
  }

  // ─── Get Sync Status ───
  SyncStatus getSyncStatus() {
    final unsyncedAudits = HiveService.audits.values.where((a) => !a.synced).length;
    final unsyncedParts = HiveService.auditParts.values.where((p) => !p.synced).length;
    final unsyncedPhotos = HiveService.photos.values.where((p) => !p.synced).length;
    final total = unsyncedAudits + unsyncedParts + unsyncedPhotos;

    return SyncStatus(
      pendingAudits: unsyncedAudits,
      pendingParts: unsyncedParts,
      pendingPhotos: unsyncedPhotos,
      totalPending: total,
      isSyncing: _isSyncing,
    );
  }
}

class SyncResult {
  final int synced;
  final int failed;
  final String message;

  SyncResult({
    required this.synced,
    required this.failed,
    required this.message,
  });
}

class SyncStatus {
  final int pendingAudits;
  final int pendingParts;
  final int pendingPhotos;
  final int totalPending;
  final bool isSyncing;

  SyncStatus({
    required this.pendingAudits,
    required this.pendingParts,
    required this.pendingPhotos,
    required this.totalPending,
    required this.isSyncing,
  });

  bool get isFullySynced => totalPending == 0;
}
