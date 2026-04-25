import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/audit_provider.dart';
import '../data/audit_part_model.dart';
import '../data/audit_model.dart';
import '../../../app/theme/app_colors.dart';

class AuditDetailScreen extends ConsumerStatefulWidget {
  final String auditId;
  const AuditDetailScreen({super.key, required this.auditId});

  @override
  ConsumerState<AuditDetailScreen> createState() => _AuditDetailScreenState();
}

class _AuditDetailScreenState extends ConsumerState<AuditDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Pre-start camera hardware for faster capture
    _startCameraSession();
  }

  Future<void> _startCameraSession() async {
    await ref.read(cameraServiceProvider).startSession();
  }

  @override
  void dispose() {
    // Release camera hardware when leaving audit flow
    ref.read(cameraServiceProvider).stopSession();
    super.dispose();
  }

  Future<void> _confirmDelete(AuditModel audit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Audit?'),
        content: Text(
          'Apakah Anda yakin ingin menghapus audit di "${audit.locationName ?? 'Lokasi'}"? '
          'Semua data terkait termasuk foto akan dihapus permanen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final repo = ref.read(auditRepositoryProvider);
        await repo.deleteAudit(audit.id);
        ref.invalidate(auditListProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Audit berhasil dihapus')),
          );
          context.go('/home'); // Go back to home
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus audit: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auditAsync = ref.watch(auditDetailProvider(widget.auditId));
    final partsAsync = ref.watch(auditPartsProvider(widget.auditId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Audit'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          auditAsync.when(
            data: (audit) => audit != null && !audit.isLocked
                ? IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                    tooltip: 'Hapus Audit',
                    onPressed: () => _confirmDelete(audit),
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: auditAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (audit) {
          if (audit == null) {
            return const Center(child: Text('Audit tidak ditemukan'));
          }

          return Column(
            children: [
              // ─── Audit Header ───
              Container(
                margin: const EdgeInsets.all(16),
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
                        const Icon(Icons.location_on_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            audit.locationName ?? 'Lokasi',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: audit.progressPercent,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Progress: ${(audit.progressPercent * 100).toInt()}% — '
                      '${audit.currentPartIndex}/${audit.parts.length} bagian selesai',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text('Bagian Audit', style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    Text(
                      'Wajib berurutan',
                      style: TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ─── Parts List ───
              Expanded(
                child: partsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (parts) {
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: parts.length,
                      itemBuilder: (context, index) {
                        final part = parts[index];
                        final isCurrent = index == audit.currentPartIndex;
                        final isCompleted = part.completed;
                        final isLocked = index > audit.currentPartIndex;

                        return _PartStepperItem(
                          part: part,
                          index: index,
                          totalParts: parts.length,
                          isCurrent: isCurrent,
                          isCompleted: isCompleted,
                          isLocked: isLocked,
                          isAuditLocked: audit.isLocked,
                          onTap: isLocked 
                            ? null 
                            : () => context.push('/audit/${widget.auditId}/part/$index'),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: auditAsync.when(
        loading: () => null,
        error: (_, __) => null,
        data: (audit) {
          if (audit == null || audit.isLocked) return null;
          final allDone = audit.currentPartIndex >= audit.parts.length;

          return SafeArea(
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
                onPressed: allDone
                    ? () => context.push('/audit/${widget.auditId}/summary')
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: allDone ? AppColors.success : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(allDone ? Icons.check_circle_rounded : Icons.lock_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(allDone ? 'Lihat Ringkasan & Kirim' : 'Selesaikan semua bagian dahulu'),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PartStepperItem extends StatelessWidget {
  final AuditPartModel part;
  final int index;
  final int totalParts;
  final bool isCurrent;
  final bool isCompleted;
  final bool isLocked;
  final bool isAuditLocked;
  final VoidCallback? onTap;

  const _PartStepperItem({
    required this.part,
    required this.index,
    required this.totalParts,
    required this.isCurrent,
    required this.isCompleted,
    required this.isLocked,
    required this.isAuditLocked,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color circleColor;
    IconData circleIcon;

    if (isCompleted) {
      circleColor = AppColors.success;
      circleIcon = Icons.check_rounded;
    } else if (isCurrent) {
      circleColor = AppColors.primary;
      circleIcon = Icons.play_arrow_rounded;
    } else {
      circleColor = isDark ? AppColors.darkTextTertiary : AppColors.textTertiary;
      circleIcon = Icons.lock_rounded;
    }

    Color? conditionColor;
    if (part.partExists && part.condition != null) {
      switch (part.condition) {
        case 'baik':
          conditionColor = AppColors.conditionBaik;
          break;
        case 'cukup':
          conditionColor = AppColors.conditionCukup;
          break;
        case 'buruk':
          conditionColor = AppColors.conditionBuruk;
          break;
      }
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: circleColor,
                      shape: BoxShape.circle,
                      boxShadow: isCurrent
                          ? [BoxShadow(color: circleColor.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2))]
                          : null,
                    ),
                    child: Icon(circleIcon, color: Colors.white, size: 18),
                  ),
                  if (index < totalParts - 1)
                    Container(
                      width: 2,
                      height: 40,
                      color: isCompleted
                          ? AppColors.success.withValues(alpha: 0.5)
                          : (isDark ? AppColors.darkDivider : AppColors.divider),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? AppColors.primary.withValues(alpha: 0.06)
                      : (isDark ? AppColors.darkSurface : AppColors.surface),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCurrent
                        ? AppColors.primary.withValues(alpha: 0.3)
                        : (isDark ? AppColors.darkDivider : AppColors.divider).withValues(alpha: 0.5),
                    width: isCurrent ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            part.partName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: isLocked
                                  ? (isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)
                                  : null,
                            ),
                          ),
                          if (!part.partExists)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text('Tidak ada', style: TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w500)),
                            ),
                          if (part.photoIds.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text('${part.photoIds.length} foto', style: Theme.of(context).textTheme.bodySmall),
                            ),
                        ],
                      ),
                    ),
                    if (conditionColor != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: conditionColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          part.condition!.toUpperCase(),
                          style: TextStyle(color: conditionColor, fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Icon(
                      isLocked ? Icons.lock_outline_rounded : Icons.chevron_right_rounded,
                      color: isLocked
                          ? (isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)
                          : AppColors.primary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
