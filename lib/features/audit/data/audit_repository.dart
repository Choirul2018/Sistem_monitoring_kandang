import 'package:uuid/uuid.dart';
import 'audit_model.dart';
import 'audit_part_model.dart';
import 'photo_model.dart';
import 'livestock_sample_model.dart';
import '../../../local_db/hive_service.dart';

class AuditRepository {
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

    // Save locally (Offline-First)
    // Data akan dikirim ke Laravel via SyncService
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

    return audit;
  }

  // ═══════════════════════════════════════════
  //  GET DATA (Local Only)
  // ═══════════════════════════════════════════

  Future<List<AuditModel>> getAuditsForUser(String userId) async {
    return HiveService.audits.values
        .where((a) => a.auditorId == userId)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<List<AuditModel>> getAllAudits() async {
    return HiveService.audits.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<AuditModel?> getAudit(String auditId) async {
    return HiveService.audits.get(auditId);
  }

  Future<List<AuditPartModel>> getAuditParts(String auditId) async {
    return HiveService.auditParts.values
        .where((p) => p.auditId == auditId)
        .toList()
      ..sort((a, b) => a.partIndex.compareTo(b.partIndex));
  }

  // ═══════════════════════════════════════════
  //  UPDATE DATA
  // ═══════════════════════════════════════════

  Future<void> updateAuditPart(AuditPartModel part) async {
    part.synced = false;
    await HiveService.auditParts.put(part.id, part);
  }

  Future<void> updateAudit(AuditModel audit) async {
    audit.updatedAt = DateTime.now();
    audit.synced = false;
    await HiveService.audits.put(audit.id, audit);
  }

  Future<void> savePhoto(PhotoModel photo) async {
    photo.synced = false;
    await HiveService.photos.put(photo.id, photo);
  }

  Future<List<PhotoModel>> getPhotosForPart(String auditPartId) async {
    return HiveService.photos.values
        .where((p) => p.auditPartId == auditPartId)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  Future<void> saveLivestockSample(LivestockSampleModel sample) async {
    sample.synced = false;
    await HiveService.livestockSamples.put(sample.id, sample);
  }

  Future<List<LivestockSampleModel>> getLivestockSamplesForAudit(String auditId) async {
    return HiveService.livestockSamples.values
        .where((s) => s.auditId == auditId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // ═══════════════════════════════════════════
  //  SUBMIT AUDIT
  // ═══════════════════════════════════════════

  Future<void> submitAudit(String auditId, String signatureData) async {
    final audit = await getAudit(auditId);
    if (audit == null) throw Exception('Audit tidak ditemukan');

    audit.status = 'approved'; 
    audit.signatureData = signatureData;
    audit.synced = false; 
    await updateAudit(audit);
  }

  // ═══════════════════════════════════════════
  //  DRAFT & DELETE
  // ═══════════════════════════════════════════

  Future<AuditModel?> getIncompleteDraft(String userId) async {
    final audits = HiveService.audits.values.where(
      (a) => a.auditorId == userId &&
          (a.status == 'draft' || a.status == 'in_progress'),
    );

    if (audits.isEmpty) return null;
    return audits.first;
  }

  Future<void> deleteAudit(String auditId) async {
    final parts = HiveService.auditParts.values.where((p) => p.auditId == auditId).toList();
    final partIds = parts.map((p) => p.id).toList();

    final photoKeys = HiveService.photos.keys.where((key) {
      final photo = HiveService.photos.get(key);
      return photo != null && partIds.contains(photo.auditPartId);
    }).toList();
    for (final key in photoKeys) await HiveService.photos.delete(key);

    final sampleKeys = HiveService.livestockSamples.keys.where((key) {
      final sample = HiveService.livestockSamples.get(key);
      return sample != null && sample.auditId == auditId;
    }).toList();
    for (final key in sampleKeys) await HiveService.livestockSamples.delete(key);

    for (final partId in partIds) await HiveService.auditParts.delete(partId);
    await HiveService.audits.delete(auditId);
  }
}
