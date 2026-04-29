import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../audit/presentation/providers/audit_provider.dart';
import '../../audit/data/audit_model.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/sync_service.dart' show SyncStatus, SyncResult;

class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  bool _isSyncing = false;

  Future<void> _handleSyncAll() async {
    setState(() => _isSyncing = true);
    
    try {
      // Use the provider from audit_provider (which is what we watch in list screen)
      final syncService = ref.read(syncServiceProvider);
      final result = await syncService.syncAll();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.failed > 0 ? AppColors.error : AppColors.success,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal sinkronisasi: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
        ref.invalidate(auditListProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auditsAsync = ref.watch(auditListProvider);
    
    // Calculate unsynced directly here to be reactive
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sinkronisasi Data'),
      ),
      body: auditsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Terjadi kesalahan: $e'),
              TextButton(
                onPressed: () => ref.invalidate(auditListProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
        data: (audits) {
          final unsynced = audits.where((a) => !a.synced).toList();
          
          if (unsynced.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_done_rounded, size: 80, color: AppColors.success),
                  const SizedBox(height: 16),
                  Text(
                    'Semua Data Tersinkron',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text('Tidak ada audit yang perlu dikirim.'),
                ],
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: _isSyncing ? null : _handleSyncAll,
                  icon: _isSyncing 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.sync_rounded),
                  label: const Text('Kirim Semua Data Sekarang'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: unsynced.length,
                  itemBuilder: (context, index) {
                    final audit = unsynced[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.cloud_upload_outlined, color: AppColors.warning),
                        ),
                        title: Text(audit.locationName ?? 'Lokasi Tidak Diketahui', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Selesai pada: ${audit.createdAt.day}/${audit.createdAt.month}/${audit.createdAt.year}'),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
