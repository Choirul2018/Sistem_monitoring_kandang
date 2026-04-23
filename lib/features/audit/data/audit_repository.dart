import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'audit_model.dart';
import 'audit_part_model.dart';
import 'photo_model.dart';
import 'livestock_sample_model.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../local_db/hive_service.dart';

class AuditRepository {
  final SupabaseClient _client = Supabase.instance.client;
  static const _uuid = Uuid();

  // ═══════════════════════════════════════════
  //  CREATE AUDIT
  // ═══════════════════════════════════════════

  Future<AuditModel> createAudit({
    required String locationId,
    required String auditorId,
    required String locationName,
    required String auditorName,
    required List<String> parts,
  }) async {
    final now = DateTime.now();
    final auditId = _uuid.v4();

    final audit = AuditModel(
      id: auditId,
      locationId: locationId,
      auditorId: auditorId,
      status: 'in_progress',
      currentPartIndex: 0,
      createdAt: now,
      updatedAt: now,
      synced: false,
      locationName: locationName,
      auditorName: auditorName,
      parts: parts,
    );

    // Save locally first (offline-first)
    await HiveService.audits.put(auditId, audit);

    // Create audit parts
    for (int i = 0; i < parts.length; i++) {
      final partId = _uuid.v4();
      final part = AuditPartModel(
        id: partId,
        auditId: auditId,
        partName: parts[i],
        partIndex: i,
        createdAt: now,
        synced: false,
      );
      await HiveService.auditParts.put(partId, part);
    }

    // Try to sync to server
    try {
      await _client.from(SupabaseConstants.auditsTable).insert(audit.toJson());
      audit.synced = true;
      await HiveService.audits.put(auditId, audit);
    } catch (_) {
      // Will sync later via background sync
      _addToSyncQueue('audit', auditId, 'create');
    }

    return audit;
  }

  // ═══════════════════════════════════════════
  //  GET AUDITS
  // ═══════════════════════════════════════════

  Future<List<AuditModel>> getAuditsForUser(String userId) async {
    // Try server first
    try {
      final response = await _client
          .from(SupabaseConstants.auditsTable)
          .select()
          .eq('auditor_id', userId)
          .order('updated_at', ascending: false);

      final audits = (response as List)
          .map((json) => AuditModel.fromJson(json))
          .toList();

      // Cache locally
      for (final audit in audits) {
        await HiveService.audits.put(audit.id, audit);
      }

      return audits;
    } catch (_) {
      // Fallback to local
      return HiveService.audits.values
          .where((a) => a.auditorId == userId)
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
  }

  Future<List<AuditModel>> getAllAudits() async {
    try {
      final response = await _client
          .from(SupabaseConstants.auditsTable)
          .select()
          .order('updated_at', ascending: false);

      final audits = (response as List)
          .map((json) => AuditModel.fromJson(json))
          .toList();

      for (final audit in audits) {
        await HiveService.audits.put(audit.id, audit);
      }

      return audits;
    } catch (_) {
      return HiveService.audits.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
  }

  Future<AuditModel?> getAudit(String auditId) async {
    // Check local first
    final local = HiveService.audits.get(auditId);
    if (local != null) return local;

    try {
      final response = await _client
          .from(SupabaseConstants.auditsTable)
          .select()
          .eq('id', auditId)
          .single();

      final audit = AuditModel.fromJson(response);
      await HiveService.audits.put(auditId, audit);
      return audit;
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════
  //  GET AUDIT PARTS
  // ═══════════════════════════════════════════

  Future<List<AuditPartModel>> getAuditParts(String auditId) async {
    // Check local first
    final localParts = HiveService.auditParts.values
        .where((p) => p.auditId == auditId)
        .toList()
      ..sort((a, b) => a.partIndex.compareTo(b.partIndex));

    if (localParts.isNotEmpty) return localParts;

    try {
      final response = await _client
          .from(SupabaseConstants.auditPartsTable)
          .select()
          .eq('audit_id', auditId)
          .order('part_index');

      final parts = (response as List)
          .map((json) => AuditPartModel.fromJson(json))
          .toList();

      for (final part in parts) {
        await HiveService.auditParts.put(part.id, part);
      }

      return parts;
    } catch (_) {
      return localParts;
    }
  }

  // ═══════════════════════════════════════════
  //  UPDATE AUDIT PART
  // ═══════════════════════════════════════════

  Future<void> updateAuditPart(AuditPartModel part) async {
    part.synced = false;
    await HiveService.auditParts.put(part.id, part);

    try {
      await _client
          .from(SupabaseConstants.auditPartsTable)
          .upsert(part.toJson());
      part.synced = true;
      await HiveService.auditParts.put(part.id, part);
    } catch (_) {
      _addToSyncQueue('audit_part', part.id, 'update');
    }
  }

  // ═══════════════════════════════════════════
  //  UPDATE AUDIT
  // ═══════════════════════════════════════════

  Future<void> updateAudit(AuditModel audit) async {
    audit.updatedAt = DateTime.now();
    audit.synced = false;
    await HiveService.audits.put(audit.id, audit);

    try {
      await _client
          .from(SupabaseConstants.auditsTable)
          .upsert(audit.toJson());
      audit.synced = true;
      await HiveService.audits.put(audit.id, audit);
    } catch (_) {
      _addToSyncQueue('audit', audit.id, 'update');
    }
  }

  // ═══════════════════════════════════════════
  //  PHOTOS
  // ═══════════════════════════════════════════

  Future<void> savePhoto(PhotoModel photo) async {
    await HiveService.photos.put(photo.id, photo);

    try {
      await _client
          .from(SupabaseConstants.auditPhotosTable)
          .upsert(photo.toJson());
      photo.synced = true;
      await HiveService.photos.put(photo.id, photo);
    } catch (_) {
      _addToSyncQueue('photo', photo.id, 'create');
    }
  }

  Future<List<PhotoModel>> getPhotosForPart(String auditPartId) async {
    return HiveService.photos.values
        .where((p) => p.auditPartId == auditPartId)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  // ═══════════════════════════════════════════
  //  LIVESTOCK SAMPLES
  // ═══════════════════════════════════════════

  Future<void> saveLivestockSample(LivestockSampleModel sample) async {
    sample.synced = false;
    await HiveService.livestockSamples.put(sample.id, sample);

    try {
      await _client
          .from(SupabaseConstants.auditLivestockSamplesTable)
          .upsert(sample.toJson());
      sample.synced = true;
      await HiveService.livestockSamples.put(sample.id, sample);
    } catch (_) {
      _addToSyncQueue('livestock_sample', sample.id, 'create');
    }
  }

  Future<List<LivestockSampleModel>> getLivestockSamplesForAudit(String auditId) async {
    // Local first
    final local = HiveService.livestockSamples.values
        .where((s) => s.auditId == auditId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (local.isNotEmpty) return local;

    try {
      final response = await _client
          .from(SupabaseConstants.auditLivestockSamplesTable)
          .select()
          .eq('audit_id', auditId);

      final samples = (response as List)
          .map((json) => LivestockSampleModel.fromJson(json))
          .toList();

      for (final sample in samples) {
        await HiveService.livestockSamples.put(sample.id, sample);
      }

      return samples;
    } catch (_) {
      return local;
    }
  }

  // ═══════════════════════════════════════════
  //  SUBMIT & REVIEW
  // ═══════════════════════════════════════════

  Future<void> submitForReview(String auditId, String signatureData) async {
    final audit = await getAudit(auditId);
    if (audit == null) throw Exception('Audit tidak ditemukan');

    audit.status = 'pending_review';
    audit.signatureData = signatureData;
    await updateAudit(audit);
  }

  Future<void> approveAudit(String auditId, String reviewerId, String? notes) async {
    final audit = await getAudit(auditId);
    if (audit == null) throw Exception('Audit tidak ditemukan');

    audit.status = 'approved';
    audit.reviewedBy = reviewerId;
    audit.reviewNotes = notes;
    await updateAudit(audit);
  }

  Future<void> rejectAudit(String auditId, String reviewerId, String notes) async {
    final audit = await getAudit(auditId);
    if (audit == null) throw Exception('Audit tidak ditemukan');

    audit.status = 'rejected';
    audit.reviewedBy = reviewerId;
    audit.reviewNotes = notes;
    await updateAudit(audit);
  }

  // ═══════════════════════════════════════════
  //  DRAFT MANAGEMENT
  // ═══════════════════════════════════════════

  Future<AuditModel?> getIncompleteDraft(String userId) async {
    final audits = HiveService.audits.values.where(
      (a) => a.auditorId == userId &&
          (a.status == 'draft' || a.status == 'in_progress'),
    );

    if (audits.isEmpty) return null;
    return audits.first;
  }

  // ═══════════════════════════════════════════
  //  SYNC QUEUE
  // ═══════════════════════════════════════════

  void _addToSyncQueue(String type, String id, String action) {
    final key = '${type}_${id}_$action';
    HiveService.syncQueue.put(key, {
      'type': type,
      'id': id,
      'action': action,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map>> getPendingSyncItems() async {
    return HiveService.syncQueue.values.toList();
  }

  Future<void> removeSyncItem(String key) async {
    await HiveService.syncQueue.delete(key);
  }
}
