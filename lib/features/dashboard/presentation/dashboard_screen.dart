import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../audit/presentation/providers/audit_provider.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../audit/data/audit_model.dart';
import '../../../app/theme/app_colors.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final auditsAsync = ref.watch(auditListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(auditListProvider),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await ref.read(authStateProvider.notifier).signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Welcome Banner ───
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
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selamat Datang,',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          user?.fullName ?? 'Admin',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            user?.role.toUpperCase() ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.dashboard_rounded, color: Colors.white, size: 28),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ─── Stats Grid ───
            auditsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
              data: (List<AuditModel> audits) {
                final totalAudits = audits.length;
                final drafts = audits.where((a) => a.status == 'draft' || a.status == 'in_progress').length;
                final pendingReview = audits.where((a) => a.status == 'pending_review').length;
                final approved = audits.where((a) => a.status == 'approved').length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats
                    Row(
                      children: [
                        _DashboardStat(
                          icon: Icons.assignment_rounded,
                          label: 'Total Audit',
                          value: '$totalAudits',
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        _DashboardStat(
                          icon: Icons.pending_rounded,
                          label: 'Berlangsung',
                          value: '$drafts',
                          color: AppColors.info,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _DashboardStat(
                          icon: Icons.hourglass_top_rounded,
                          label: 'Menunggu Review',
                          value: '$pendingReview',
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 12),
                        _DashboardStat(
                          icon: Icons.check_circle_rounded,
                          label: 'Disetujui',
                          value: '$approved',
                          color: AppColors.success,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ─── Quick Actions ───
                    Text('Aksi Cepat', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionCard(
                            icon: Icons.assignment_outlined,
                            label: 'Audit',
                            onTap: () => context.push('/audits'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ActionCard(
                            icon: Icons.location_on_outlined,
                            label: 'Lokasi',
                            onTap: () => context.push('/locations'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ActionCard(
                            icon: Icons.description_outlined,
                            label: 'Laporan',
                            onTap: () => context.push('/reports'),
                          ),
                        ),
                      ],
                    ),

                    // ─── Pending Review (Kabag/Kadiv) ───
                    if (user?.canReview == true && pendingReview > 0) ...[
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Text('Perlu Review', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.warningLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$pendingReview',
                              style: const TextStyle(
                                color: AppColors.warning,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...audits
                          .where((a) => a.status == 'pending_review')
                          .take(5)
                          .map((audit) => _ReviewCard(
                                audit: audit,
                                onApprove: () async {
                                  final repo = ref.read(auditRepositoryProvider);
                                  await repo.approveAudit(audit.id, user!.id, null);
                                  ref.invalidate(auditListProvider);
                                },
                                onReject: () => _showRejectDialog(context, ref, audit.id, user!.id),
                                onView: () => context.push('/report/${audit.id}'),
                              )),
                    ],

                    // ─── Recent Audits ───
                    const SizedBox(height: 24),
                    Text('Audit Terbaru', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (audits.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'Belum ada audit',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      )
                    else
                      ...audits.take(5).map((audit) => _RecentAuditItem(audit: audit)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRejectDialog(BuildContext context, WidgetRef ref, String auditId, String reviewerId) {
    final notesController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Tolak Audit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Berikan alasan penolakan:'),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Alasan penolakan...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (notesController.text.trim().isEmpty) return;
              final repo = ref.read(auditRepositoryProvider);
              await repo.rejectAudit(auditId, reviewerId, notesController.text.trim());
              ref.invalidate(auditListProvider);
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
  }
}

class _DashboardStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _DashboardStat({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionCard({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary, size: 28),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final AuditModel audit;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onView;

  const _ReviewCard({required this.audit, required this.onApprove, required this.onReject, required this.onView});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.hourglass_top_rounded, color: AppColors.warning, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(audit.locationName ?? 'Lokasi', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      Text('Auditor: ${audit.auditorName ?? "-"}', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                TextButton(onPressed: onView, child: const Text('Lihat', style: TextStyle(fontSize: 12))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      minimumSize: const Size(0, 36),
                    ),
                    child: const Text('Tolak', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      minimumSize: const Size(0, 36),
                    ),
                    child: const Text('Setujui', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentAuditItem extends StatelessWidget {
  final AuditModel audit;
  const _RecentAuditItem({required this.audit});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusText;
    switch (audit.status) {
      case 'in_progress':
        statusColor = AppColors.info;
        statusText = 'Berlangsung';
        break;
      case 'pending_review':
        statusColor = AppColors.warning;
        statusText = 'Review';
        break;
      case 'approved':
        statusColor = AppColors.success;
        statusText = 'Disetujui';
        break;
      case 'rejected':
        statusColor = AppColors.error;
        statusText = 'Ditolak';
        break;
      default:
        statusColor = AppColors.textTertiary;
        statusText = 'Draft';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        onTap: () {
          if (audit.isLocked) {
            context.push('/report/${audit.id}');
          } else {
            context.push('/audit/${audit.id}');
          }
        },
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.assignment_rounded, color: statusColor, size: 20),
        ),
        title: Text(audit.locationName ?? 'Lokasi', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${audit.createdAt.day}/${audit.createdAt.month}/${audit.createdAt.year}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
