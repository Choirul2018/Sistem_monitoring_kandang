import 'location_model.dart';
import '../../../local_db/hive_service.dart';
import '../../sync/data/api_service.dart';

class LocationRepository {
  final ApiService _apiService;

  LocationRepository(this._apiService);

  Future<List<LocationModel>> getAllLocations() async {
    try {
      final response = await _apiService.getLocations();
      
      final locations = response
          .map((json) => LocationModel.fromJson(json))
          .toList();

      // Cache locally
      for (final loc in locations) {
        await HiveService.locations.put(loc.id, loc);
      }

      return locations;
    } catch (_) {
      // Fallback to local
      final locals = HiveService.locations.values.toList();
      if (locals.isEmpty) {
        // Data Default (Offline First)
        final List<LocationModel> dummies = [
          LocationModel(
            id: 'loc-1',
            name: 'Kandang Ayam Boiler A',
            address: 'PPMK 2, Zona 1',
            latitude: -7.7872319,
            longitude: 112.1918656,
            geofenceRadiusM: 200,
            parts: ['Gerbang', 'Jalan Masuk', 'Gudang', 'Kandang 1', 'Kandang 2'],
            createdAt: DateTime.now(),
          ),
          LocationModel(
            id: 'loc-2',
            name: 'Kandang Ayam Boiler B',
            address: 'PPMK, Zona 2',
            latitude: -7.7872319,
            longitude: 112.1918656,
            geofenceRadiusM: 200,
            parts: ['Gerbang', 'Jalan Masuk', 'Gudang', 'Tempat Pakan', 'Tempat Minum'],
            createdAt: DateTime.now(),
          ),
        ];
        
        for (final loc in dummies) {
          await HiveService.locations.put(loc.id, loc);
        }
        return dummies;
      }
      return locals;
    }
  }

  Future<LocationModel?> getLocation(String locationId) async {
    // Check local first (Always check local to be fast)
    final local = HiveService.locations.get(locationId);
    if (local != null) return local;

    // If not in local, try fetching all to refresh cache
    final all = await getAllLocations();
    try {
      return all.firstWhere((l) => l.id == locationId);
    } catch (_) {
      return null;
    }
  }

  Future<LocationModel> createLocation(LocationModel location) async {
    // Lokasi baru biasanya dibuat di Laravel Dashboard, 
    // tapi ini tetap disimpan di local jika perlu.
    await HiveService.locations.put(location.id, location);
    return location;
  }

  Future<void> updateLocation(LocationModel location) async {
    await HiveService.locations.put(location.id, location);
  }
}
