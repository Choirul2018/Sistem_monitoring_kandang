import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/audit_provider.dart';
import '../data/audit_part_model.dart';
import '../../../app/theme/app_colors.dart';

class AuditSummaryScreen extends ConsumerWidget {
  final String auditId;
  const AuditSummaryScreen({super.key, required this.auditId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auditAsync = ref.watch(auditDetailProvider(auditId));
    final partsAsync = ref.watch(auditPartsProvider(auditId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Ringkasan Audit')),
      body: auditAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (audit) {
          if (audit == null) return const Center(child: Text('Audit tidak ditemukan'));

          return partsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (parts) {
              final baikCount = parts.where((p) => p.condition == 'baik').length;
              final cukupCount = parts.where((p) => p.condition == 'cukup').length;
              final burukCount = parts.where((p) => p.condition == 'buruk').length;
              final notExistCount = parts.where((p) => !p.partExists).length;
              final totalPhotos = parts.fold<int>(0, (sum, p) => sum + p.photoIds.length);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Summary Header ───
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.summarize_rounded, color: Colors.white, size: 24),
                              const SizedBox(width: 8),
                              Text(
                                audit.locationName ?? 'Lokasi',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Auditor: ${audit.auditorName ?? "-"}',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                          ),
                          Text(
                            'Tanggal: ${audit.createdAt.day}/${audit.createdAt.month}/${audit.createdAt.year}',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _StatChip(label: 'Total Foto', value: '$totalPhotos', color: Colors.white),
                              const SizedBox(width: 8),
                              _StatChip(label: 'Bagian', value: '${parts.length}', color: Colors.white),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text('Kondisi Keseluruhan', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _ConditionCard(label: 'Baik', count: baikCount, color: AppColors.conditionBaik, icon: Icons.check_circle),
                        const SizedBox(width: 8),
                        _ConditionCard(label: 'Cukup', count: cukupCount, color: AppColors.conditionCukup, icon: Icons.warning_rounded),
                        const SizedBox(width: 8),
                        _ConditionCard(label: 'Buruk', count: burukCount, color: AppColors.conditionBuruk, icon: Icons.error_rounded),
                        if (notExistCount > 0) ...[
                          const SizedBox(width: 8),
                          _ConditionCard(label: 'Tidak Ada', count: notExistCount, color: AppColors.textTertiary, icon: Icons.block),
                        ],
                      ],
                    ),

                    const SizedBox(height: 24),

                    Text('Detail Per Bagian', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),

                    ...parts.map((part) => _PartSummaryCard(part: part)),

                    const SizedBox(height: 100),
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
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: () => context.push('/audit/$auditId/signature'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.draw_rounded, size: 20),
                SizedBox(width: 8),
                Text('Tanda Tangan & Kirim'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w700)),
          Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11)),
        ],
      ),
    );
  }
}

class _ConditionCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  const _ConditionCard({required this.label, required this.count, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text('$count', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w700)),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _PartSummaryCard extends StatelessWidget {
  final AuditPartModel part;
  const _PartSummaryCard({required this.part});

  @override
  Widget build(BuildContext context) {
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

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(part.partName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: conditionColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(conditionText, style: TextStyle(color: conditionColor, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            if (part.notes != null && part.notes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(part.notes!, style: Theme.of(context).textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            if (part.photoIds.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.photo_library_outlined, size: 14, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Text('${part.photoIds.length} foto', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
