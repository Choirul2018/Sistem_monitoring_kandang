import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../audit/presentation/providers/audit_provider.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/location_model.dart';
import '../../../app/theme/app_colors.dart';

class LocationListScreen extends ConsumerWidget {
  const LocationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationsAsync = ref.watch(locationListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Lokasi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(locationListProvider),
          ),
        ],
      ),
      body: locationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 8),
              Text('Error: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(locationListProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
        data: (List<LocationModel> locations) {
          if (locations.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_off_rounded,
                    size: 64,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada lokasi',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hubungi admin untuk menambahkan lokasi',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: locations.length,
            itemBuilder: (context, index) {
              final location = locations[index];
              return _LocationCard(
                location: location,
                onTap: () => _startAudit(context, ref, location),
                onMapTap: () => context.push('/location-map/${location.id}'),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _startAudit(BuildContext context, WidgetRef ref, LocationModel location) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    // Confirm start
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.play_circle_rounded, color: AppColors.primary, size: 32),
        ),
        title: const Text('Mulai Audit?'),
        content: Text(
          'Mulai audit untuk lokasi "${location.name}"?\n\n'
          'Pastikan Anda sudah berada di lokasi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mulai'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Create new audit
    final repo = ref.read(auditRepositoryProvider);
    final audit = await repo.createAudit(
      locationId: location.id,
      auditorId: user.id,
      locationName: location.name,
      auditorName: user.fullName,
      parts: location.parts,
    );

    ref.invalidate(auditListProvider);

    if (context.mounted) {
      context.push('/audit/${audit.id}');
    }
  }
}

class _LocationCard extends StatelessWidget {
  final LocationModel location;
  final VoidCallback onTap;
  final VoidCallback onMapTap;

  const _LocationCard({
    required this.location,
    required this.onTap,
    required this.onMapTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.location_on_rounded, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          location.name,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        if (location.address != null)
                          Text(
                            location.address!,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.map_rounded, color: AppColors.info),
                    onPressed: onMapTap,
                    tooltip: 'Lihat Peta',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Parts preview
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: location.parts.take(5).map((part) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      part,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  );
                }).toList()
                  ..addAll(location.parts.length > 5
                      ? [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primarySurface,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '+${location.parts.length - 5} lainnya',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ]
                      : []),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.gps_fixed, size: 13, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Text(
                    '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
                    style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                  ),
                  const Spacer(),
                  Text(
                    'Radius: ${location.geofenceRadiusM}m',
                    style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
