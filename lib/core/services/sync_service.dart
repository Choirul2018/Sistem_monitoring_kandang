import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../local_db/hive_service.dart';
import '../../features/sync/data/api_service.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ref.read(apiServiceProvider));
});

class SyncService {
  final ApiService _apiService;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;

  SyncService(this._apiService);

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

  void stopListening() {
    _connectivitySubscription?.cancel();
  }

  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  // ─── Sync All Pending Data to Laravel ───
  Future<SyncResult> syncAll() async {
    if (_isSyncing) return SyncResult(synced: 0, failed: 0, message: 'Sudah sedang sinkronisasi.');
    _isSyncing = true;

    int synced = 0;
    int failed = 0;

    try {
      if (!await isOnline()) {
        return SyncResult(synced: 0, failed: 0, message: 'Tidak ada koneksi internet.');
      }

      // ─── LARAVEL SYNC ───
      final unsyncedAudits = HiveService.audits.values.where((a) => !a.synced);
      
      for (final audit in unsyncedAudits) {
        // Hapus syarat 'approved', sehingga semua audit akan sinkron
        // if (audit.status != 'approved') continue;

        try {
          // Cari bagian dan foto terkait audit ini
          final parts = HiveService.auditParts.values.where((p) => p.auditId == audit.id).toList();
          
          final partIds = parts.map((p) => p.id).toSet();
          final photos = HiveService.photos.values
              .where((ph) => partIds.contains(ph.auditPartId))
              .toList();
          
          final samples = HiveService.livestockSamples.values
              .where((s) => s.auditId == audit.id)
              .toList();

          final success = await _apiService.sendAuditToLaravel(
            audit: audit,
            parts: parts,
            photos: photos,
            samples: samples,
          );

          if (success) {
            audit.synced = true;
            await HiveService.audits.put(audit.id, audit);
            
            // Tandai bagian, foto, dan sampel sebagai tersinkronisasi juga
            for (var p in parts) { p.synced = true; await HiveService.auditParts.put(p.id, p); }
            for (var ph in photos) { ph.synced = true; await HiveService.photos.put(ph.id, ph); }
            for (var s in samples) { s.synced = true; await HiveService.livestockSamples.put(s.id, s); }
            
            synced++;
          } else {
            failed++;
          }
        } catch (e) {
          failed++;
        }
      }
    } finally {
      _isSyncing = false;
    }

    return SyncResult(
      synced: synced,
      failed: failed,
      message: synced > 0
          ? '$synced audit berhasil dikirim ke server Laravel.'
          : 'Semua data sudah tersinkronkan.',
    );
  }

  SyncStatus getSyncStatus() {
    final unsyncedAudits = HiveService.audits.values.where((a) => !a.synced).length;
    final total = unsyncedAudits;

    return SyncStatus(
      pendingAudits: unsyncedAudits,
      totalPending: total,
      isSyncing: _isSyncing,
    );
  }
}

class SyncResult {
  final int synced;
  final int failed;
  final String message;
  SyncResult({required this.synced, required this.failed, required this.message});
}

class SyncStatus {
  final int pendingAudits;
  final int totalPending;
  final bool isSyncing;
  SyncStatus({required this.pendingAudits, required this.totalPending, required this.isSyncing});
  bool get isFullySynced => totalPending == 0;
}
