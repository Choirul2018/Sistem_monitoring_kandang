import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../audit/presentation/providers/audit_provider.dart';
import '../../audit/data/audit_model.dart';
import '../../../app/theme/app_colors.dart';

class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auditsAsync = ref.watch(auditListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Laporan Audit')),
      body: auditsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (List<AuditModel> audits) {
          final completedAudits = audits
              .where((a) => a.status == 'approved' || a.status == 'pending_review')
              .toList();

          if (completedAudits.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.description_outlined, size: 64, color: AppColors.textTertiary),
                  const SizedBox(height: 16),
                  Text('Belum ada laporan', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Laporan akan muncul setelah audit diselesaikan',
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: completedAudits.length,
            itemBuilder: (context, index) {
              final audit = completedAudits[index];
              final isApproved = audit.status == 'approved';

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () => context.push('/report/${audit.id}'),
                  contentPadding: const EdgeInsets.all(14),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: (isApproved ? AppColors.success : AppColors.warning).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isApproved ? Icons.verified_rounded : Icons.pending_actions_rounded,
                      color: isApproved ? AppColors.success : AppColors.warning,
                    ),
                  ),
                  title: Text(
                    audit.locationName ?? 'Lokasi',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Text(
                        'Auditor: ${audit.auditorName ?? "-"}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        '${audit.createdAt.day}/${audit.createdAt.month}/${audit.createdAt.year}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (isApproved ? AppColors.success : AppColors.warning).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isApproved ? 'Final' : 'Review',
                          style: TextStyle(
                            color: isApproved ? AppColors.success : AppColors.warning,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Icon(Icons.chevron_right_rounded, size: 20),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
