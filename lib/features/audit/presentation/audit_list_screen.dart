import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/audit_provider.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../../app/theme/app_colors.dart';
import '../data/audit_model.dart';

class AuditListScreen extends ConsumerStatefulWidget {
  const AuditListScreen({super.key});

  @override
  ConsumerState<AuditListScreen> createState() => _AuditListScreenState();
}

class _AuditListScreenState extends ConsumerState<AuditListScreen> {
  @override
  void initState() {
    super.initState();
    // Check for incomplete drafts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForDrafts();
    });
  }

  Future<void> _checkForDrafts() async {
    final draft = await ref.read(incompleteDraftProvider.future);
    if (draft != null && mounted) {
      _showDraftDialog(draft.id, draft.locationName ?? 'Unknown');
    }
  }

  void _showDraftDialog(String auditId, String locationName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.warningLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.restore_rounded, color: AppColors.warning, size: 32),
        ),
        title: const Text('Audit Belum Selesai'),
        content: Text(
          'Audit sebelumnya di "$locationName" belum selesai. Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Buat Baru'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/audit/$auditId');
            },
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    );
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
    final auditsAsync = ref.watch(auditListProvider);
    final user = ref.watch(currentUserProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Saya'),
        actions: [
          // Sync indicator
          if (!syncStatus.isFullySynced)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: Badge(
                  label: Text('${syncStatus.totalPending}'),
                  child: Icon(
                    Icons.cloud_upload_outlined,
                    color: AppColors.warning,
                  ),
                ),
                onPressed: () async {
                  final syncService = ref.read(syncServiceProvider);
                  final result = await syncService.syncAll();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(result.message)),
                    );
                  }
                },
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await ref.read(authStateProvider.notifier).signOut();
              if (mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── User Info Banner ───
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.fullName ?? 'Auditor',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        user?.role.toUpperCase() ?? '',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!syncStatus.isFullySynced)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${syncStatus.totalPending}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // ─── Quick Actions ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (user?.canReview ?? false)
                  Expanded(
                    flex: 2,
                    child: _QuickActionCard(
                      icon: Icons.speed_rounded,
                      label: 'Dashboard Review',
                      subtitle: 'Persetujuan Audit',
                      color: AppColors.secondary,
                      onTap: () => context.push('/dashboard'),
                    ),
                  )
                else
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.add_location_alt_rounded,
                      label: 'Mulai Audit',
                      subtitle: 'Pilih Lokasi',
                      color: AppColors.primary,
                      onTap: () => context.push('/locations'),
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.description_rounded,
                    label: 'Laporan',
                    subtitle: 'PDF/Arsip',
                    color: AppColors.success,
                    onTap: () => context.push('/reports'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ─── Section Header ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Riwayat Audit',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => ref.invalidate(auditListProvider),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ),

          // ─── Audit List ───
          Expanded(
            child: auditsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 8),
                    Text('Gagal memuat data: $e'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(auditListProvider),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
              data: (audits) {
                if (audits.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          size: 64,
                          color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Belum ada audit',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Mulai audit baru dengan memilih lokasi',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(auditListProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: audits.length,
                    itemBuilder: (context, index) {
                      final audit = audits[index];
                      return _AuditCard(
                        audit: audit,
                        onDelete: () => _confirmDelete(audit),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/locations'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Audit Baru'),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.7),
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuditCard extends ConsumerWidget {
  final AuditModel audit;
  final VoidCallback onDelete;

  const _AuditCard({
    required this.audit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAdmin = user?.isAdmin ?? false;

    // Only allow deletion for non-approved audits, or if admin
    final canDelete = !audit.isApproved || isAdmin;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (audit.status) {
      case 'draft':
        statusColor = AppColors.textTertiary;
        statusIcon = Icons.edit_outlined;
        statusText = 'Draft';
        break;
      case 'in_progress':
        statusColor = AppColors.info;
        statusIcon = Icons.pending_outlined;
        statusText = 'Berlangsung';
        break;
      case 'pending_review':
        statusColor = AppColors.warning;
        statusIcon = Icons.hourglass_top_rounded;
        statusText = 'Menunggu Review';
        break;
      case 'approved':
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_outline;
        statusText = 'Disetujui';
        break;
      case 'rejected':
        statusColor = AppColors.error;
        statusIcon = Icons.cancel_outlined;
        statusText = 'Ditolak';
        break;
      default:
        statusColor = AppColors.textTertiary;
        statusIcon = Icons.help_outline;
        statusText = audit.status;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => context.push('/audit/${audit.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          audit.locationName ?? 'Lokasi',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${audit.createdAt.day}/${audit.createdAt.month}/${audit.createdAt.year} • ${audit.auditorName ?? 'Auditor'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (canDelete)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 120),
                      onSelected: (value) {
                        if (value == 'delete') {
                          onDelete();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded,
                                  color: AppColors.error, size: 18),
                              SizedBox(width: 8),
                              Text('Hapus Audit',
                                  style: TextStyle(color: AppColors.error, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              if (audit.status == 'in_progress') ...[
                const SizedBox(height: 12),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: audit.progressPercent,
                    backgroundColor: isDark
                        ? AppColors.darkSurfaceVariant
                        : AppColors.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'Progress: ${(audit.progressPercent * 100).toInt()}%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      'Bagian ${audit.currentPartIndex + 1}/${audit.parts.length}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
              if (audit.isApproved || audit.isRejected || audit.isPendingReview) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (!audit.synced)
                      Row(
                        children: [
                          Icon(Icons.cloud_off_rounded, size: 14, color: AppColors.warning),
                          const SizedBox(width: 4),
                          Text(
                            'Belum sinkron',
                            style: TextStyle(
                              color: AppColors.warning,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ] else if (!audit.synced && audit.status != 'in_progress') ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.cloud_off_rounded, size: 14, color: AppColors.warning),
                    const SizedBox(width: 4),
                    Text(
                      'Belum sinkron',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
