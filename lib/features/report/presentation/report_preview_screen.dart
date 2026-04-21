import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../audit/presentation/providers/audit_provider.dart';
import '../../audit/data/audit_model.dart';
import '../../audit/data/audit_part_model.dart';
import '../../../core/utils/pdf_exporter.dart';
import '../../../app/theme/app_colors.dart';

class ReportPreviewScreen extends ConsumerStatefulWidget {
  final String auditId;
  const ReportPreviewScreen({super.key, required this.auditId});

  @override
  ConsumerState<ReportPreviewScreen> createState() => _ReportPreviewScreenState();
}

class _ReportPreviewScreenState extends ConsumerState<ReportPreviewScreen> {
  bool _isExporting = false;

  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);

    try {
      final AuditModel? audit = await ref.read(auditDetailProvider(widget.auditId).future);
      final List<AuditPartModel> parts = await ref.read(auditPartsProvider(widget.auditId).future);

      if (audit == null) throw Exception('Audit tidak ditemukan');

      // Collect photos for each part
      final allPhotos = <String, List<dynamic>>{};
      for (final part in parts) {
        final photos = await ref.read(partPhotosProvider(part.id).future);
        allPhotos[part.id] = photos;
      }

      final pdfFile = await PdfExporter.generateReport(
        audit: audit,
        parts: parts,
        photos: allPhotos,
      );

      await Share.shareXFiles(
        [XFile(pdfFile.path)],
        text: 'Laporan Audit - ${audit.locationName}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auditAsync = ref.watch(auditDetailProvider(widget.auditId));
    final partsAsync = ref.watch(auditPartsProvider(widget.auditId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview Laporan'),
        actions: [
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_rounded),
            onPressed: _isExporting ? null : _exportPdf,
            tooltip: 'Export PDF',
          ),
        ],
      ),
      body: auditAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (AuditModel? audit) {
          if (audit == null) return const Center(child: Text('Tidak ditemukan'));

          return partsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (List<AuditPartModel> parts) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('LAPORAN AUDIT',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                          const Divider(height: 24),
                          _InfoRow(label: 'Lokasi', value: audit.locationName ?? '-'),
                          _InfoRow(label: 'Auditor', value: audit.auditorName ?? '-'),
                          _InfoRow(label: 'Tanggal', value: '${audit.createdAt.day}/${audit.createdAt.month}/${audit.createdAt.year}'),
                          _InfoRow(label: 'Status', value: audit.status.toUpperCase()),
                          _InfoRow(label: 'Total Bagian', value: '${parts.length}'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Parts detail
                    Text('Detail Per Bagian', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),

                    ...parts.map((part) {
                      Color conditionColor = AppColors.textTertiary;
                      String conditionText = 'Tidak ada';
                      if (part.partExists && part.condition != null) {
                        switch (part.condition) {
                          case 'baik':
                            conditionColor = AppColors.conditionBaik;
                            conditionText = 'Baik';
                            break;
                          case 'cukup':
                            conditionColor = AppColors.conditionCukup;
                            conditionText = 'Cukup';
                            break;
                          case 'buruk':
                            conditionColor = AppColors.conditionBuruk;
                            conditionText = 'Buruk';
                            break;
                        }
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: conditionColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(part.partName,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: conditionColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(conditionText,
                                      style: TextStyle(
                                          color: conditionColor, fontSize: 11, fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                            if (part.notes != null && part.notes!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text('Catatan: ${part.notes}',
                                  style: Theme.of(context).textTheme.bodySmall),
                            ],
                            if (part.photoIds.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text('${part.photoIds.length} foto terlampir',
                                  style: TextStyle(fontSize: 12, color: AppColors.info)),
                            ],
                          ],
                        ),
                      );
                    }),

                    // Signature
                    if (audit.signatureData != null) ...[
                      const SizedBox(height: 20),
                      Text('Tanda Tangan Auditor', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Image.memory(
                          base64Decode(audit.signatureData!),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _isExporting ? null : _exportPdf,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Export PDF'),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Text(': ', style: Theme.of(context).textTheme.bodySmall),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
