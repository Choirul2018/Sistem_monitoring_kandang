import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sistem_monitoring_kandang/features/audit/data/audit_repository.dart';
import 'package:sistem_monitoring_kandang/features/audit/data/audit_model.dart';
import 'package:sistem_monitoring_kandang/features/audit/data/audit_part_model.dart';
import 'package:sistem_monitoring_kandang/features/audit/data/photo_model.dart';
import 'package:sistem_monitoring_kandang/features/audit/data/livestock_sample_model.dart';
import 'package:sistem_monitoring_kandang/features/auth/presentation/auth_provider.dart';
import 'package:sistem_monitoring_kandang/features/location/data/location_repository.dart';
import 'package:sistem_monitoring_kandang/features/location/data/location_model.dart';
import 'package:sistem_monitoring_kandang/core/services/camera_service.dart';
import 'package:sistem_monitoring_kandang/core/services/location_service.dart';
import 'package:sistem_monitoring_kandang/core/services/ai_service.dart';
import 'package:sistem_monitoring_kandang/core/services/sync_service.dart';
import 'package:sistem_monitoring_kandang/core/constants/app_constants.dart';

// ─── Repository Providers ───
final auditRepositoryProvider = Provider((ref) => AuditRepository());
final locationRepositoryProvider = Provider((ref) => LocationRepository());
final cameraServiceProvider = Provider((ref) => CameraService());
final locationServiceProvider = Provider((ref) => LocationService());
final aiServiceProvider = Provider((ref) => AiService());
final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService();
  service.startListening();
  ref.onDispose(() => service.stopListening());
  return service;
});

// ─── Audit List Provider ───
final auditListProvider = FutureProvider<List<AuditModel>>((ref) async {
  final repo = ref.read(auditRepositoryProvider);
  final user = ref.watch(currentUserProvider);

  if (user == null) return [];

  if (user.isAdmin || user.canReview) {
    return repo.getAllAudits();
  }
  return repo.getAuditsForUser(user.id);
});

// ─── Single Audit Provider ───
final auditDetailProvider = FutureProvider.family<AuditModel?, String>(
  (ref, auditId) async {
    final repo = ref.read(auditRepositoryProvider);
    return repo.getAudit(auditId);
  },
);

// ─── Audit Parts Provider ───
final auditPartsProvider = FutureProvider.family<List<AuditPartModel>, String>(
  (ref, auditId) async {
    final repo = ref.read(auditRepositoryProvider);
    return repo.getAuditParts(auditId);
  },
);

// ─── Part Photos Provider ───
final partPhotosProvider = FutureProvider.family<List<PhotoModel>, String>(
  (ref, auditPartId) async {
    final repo = ref.read(auditRepositoryProvider);
    return repo.getPhotosForPart(auditPartId);
  },
);

// ─── Livestock Samples Provider ───
final auditLivestockSamplesProvider = FutureProvider.family<List<LivestockSampleModel>, String>(
  (ref, auditId) async {
    final repo = ref.read(auditRepositoryProvider);
    return repo.getLivestockSamplesForAudit(auditId);
  },
);

// ─── Incomplete Draft Provider ───
final incompleteDraftProvider = FutureProvider<AuditModel?>((ref) async {
  final repo = ref.read(auditRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return repo.getIncompleteDraft(user.id);
});

// ─── Sync Status Provider ───
final syncStatusProvider = Provider<SyncStatus>((ref) {
  final syncService = ref.read(syncServiceProvider);
  return syncService.getSyncStatus();
});

// ─── Auto-Save Timer Provider ───
class AutoSaveNotifier extends StateNotifier<bool> {
  Timer? _timer;
  final AuditRepository _repo;

  AutoSaveNotifier(this._repo) : super(false);

  void startAutoSave(AuditModel audit, List<AuditPartModel> parts) {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: AppConstants.autoSaveIntervalSeconds),
      (_) async {
        state = true;
        try {
          await _repo.updateAudit(audit);
          for (final part in parts) {
            await _repo.updateAuditPart(part);
          }
        } finally {
          state = false;
        }
      },
    );
  }

  void stopAutoSave() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final autoSaveProvider = StateNotifierProvider<AutoSaveNotifier, bool>((ref) {
  return AutoSaveNotifier(ref.read(auditRepositoryProvider));
});

// ─── Location List Provider ───
final locationListProvider = FutureProvider<List<LocationModel>>((ref) async {
  final repo = ref.read(locationRepositoryProvider);
  return repo.getAllLocations();
});
