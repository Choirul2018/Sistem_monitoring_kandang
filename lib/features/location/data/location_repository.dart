import 'package:supabase_flutter/supabase_flutter.dart';
import 'location_model.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../local_db/hive_service.dart';

class LocationRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<LocationModel>> getAllLocations() async {
    try {
      final response = await _client
          .from(SupabaseConstants.locationsTable)
          .select()
          .order('name');

      final locations = (response as List)
          .map((json) => LocationModel.fromJson(json))
          .toList();

      // Cache locally
      for (final loc in locations) {
        await HiveService.locations.put(loc.id, loc);
      }

      return locations;
    } catch (_) {
      // Fallback to local
      return HiveService.locations.values.toList();
    }
  }

  Future<LocationModel?> getLocation(String locationId) async {
    // Check local first
    final local = HiveService.locations.get(locationId);
    if (local != null) return local;

    try {
      final response = await _client
          .from(SupabaseConstants.locationsTable)
          .select()
          .eq('id', locationId)
          .single();

      final location = LocationModel.fromJson(response);
      await HiveService.locations.put(locationId, location);
      return location;
    } catch (_) {
      return null;
    }
  }

  Future<LocationModel> createLocation(LocationModel location) async {
    await HiveService.locations.put(location.id, location);

    try {
      await _client
          .from(SupabaseConstants.locationsTable)
          .insert(location.toJson());
    } catch (_) {
      // Will sync later
    }

    return location;
  }

  Future<void> updateLocation(LocationModel location) async {
    await HiveService.locations.put(location.id, location);

    try {
      await _client
          .from(SupabaseConstants.locationsTable)
          .upsert(location.toJson());
    } catch (_) {
      // Will sync later
    }
  }
}
