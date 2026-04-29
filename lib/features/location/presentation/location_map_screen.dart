import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../audit/presentation/providers/audit_provider.dart';
import '../data/location_model.dart';
import '../../../app/theme/app_colors.dart';

class LocationMapScreen extends ConsumerStatefulWidget {
  final String locationId;
  const LocationMapScreen({super.key, required this.locationId});

  @override
  ConsumerState<LocationMapScreen> createState() => _LocationMapScreenState();
}

class _LocationMapScreenState extends ConsumerState<LocationMapScreen> {
  double? _userLat;
  double? _userLng;
  bool _isInsideGeofence = false;
  String _distanceText = 'Menghitung...';

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final locationService = ref.read(locationServiceProvider);
      final position = await locationService.getCurrentPosition();
      final location = await ref.read(locationRepositoryProvider).getLocation(widget.locationId);

      if (location != null) {
        final distance = locationService.calculateDistance(
          position.latitude,
          position.longitude,
          location.latitude,
          location.longitude,
        );

        setState(() {
          _userLat = position.latitude;
          _userLng = position.longitude;
          _isInsideGeofence = distance <= location.geofenceRadiusM;
          _distanceText = locationService.formatDistance(distance);
        });
      }
    } catch (e) {
      setState(() => _distanceText = 'GPS Error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationAsync = ref.watch(
      FutureProvider((ref) => ref.read(locationRepositoryProvider).getLocation(widget.locationId)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Peta Lokasi')),
      body: locationAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (LocationModel? location) {
          if (location == null) return const Center(child: Text('Lokasi tidak ditemukan'));

          final center = LatLng(location.latitude, location.longitude);

          return Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 16.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.sistem_monitoring_kandang',
                  ),
                  // Geofence circle
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: center,
                        radius: location.geofenceRadiusM.toDouble(),
                        useRadiusInMeter: true,
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderStrokeWidth: 2,
                        borderColor: AppColors.primary.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                  // Location marker
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: center,
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.location_on, color: Colors.white, size: 24),
                        ),
                      ),
                      // User position (blue dot)
                      if (_userLat != null && _userLng != null)
                        Marker(
                          point: LatLng(_userLat!, _userLng!),
                          width: 24,
                          height: 24,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.info,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.info.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              // Info overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  location.name,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                if (location.address != null)
                                  Text(
                                    location.address!,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _isInsideGeofence
                                  ? AppColors.successLight
                                  : AppColors.errorLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isInsideGeofence ? Icons.check_circle : Icons.error,
                                  size: 16,
                                  color: _isInsideGeofence ? AppColors.success : AppColors.error,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _distanceText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _isInsideGeofence ? AppColors.success : AppColors.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.radar_rounded, size: 14, color: AppColors.textTertiary),
                          const SizedBox(width: 4),
                          Text(
                            'Radius geofence: ${location.geofenceRadiusM} m',
                            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
