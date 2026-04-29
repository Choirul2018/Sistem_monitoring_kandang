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

      // Bersihkan cache lama dan ganti dengan data baru dari Laravel
      await HiveService.locations.clear();
      for (final loc in locations) {
        await HiveService.locations.put(loc.id, loc);
      }

      return locations;
    } catch (e) {
      print('LocationRepository Error: $e');
      
      // Jika internet/API gagal, baru ambil dari cache lokal
      final locals = HiveService.locations.values.toList();
      if (locals.isNotEmpty) return locals;
      
      // Jika local juga kosong, lempar error agar user tahu
      rethrow;
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
