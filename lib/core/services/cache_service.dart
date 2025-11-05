import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/place_model.dart';

/// A service that handles caching of map data using Hive
class CacheService {
  // Singleton instance
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  // Box names
  static const String _placesBoxName = 'places_cache';
  static const String _directionsBoxName = 'directions_cache';
  static const String _nearbyPlacesBoxName = 'nearby_places_cache';

  // Cache expiration time (24 hours)
  static const Duration _cacheExpiration = Duration(hours: 24);

  bool _isInitialized = false;

  /// Initialize Hive and open boxes
  Future<void> initialize() async {
    if (_isInitialized) return;

    await Hive.initFlutter();

    // Open boxes with dynamic type for flexibility
    await Hive.openBox(_placesBoxName);
    await Hive.openBox(_directionsBoxName);
    await Hive.openBox(_nearbyPlacesBoxName);

    _isInitialized = true;
  }

  /// Cache place search results
  Future<void> cachePlaces(String query, List<PlaceModel> places) async {
    final box = Hive.box(_placesBoxName);
    final cachedData = {
      'query': query,
      'places': places.map((p) => p.toMap()).toList(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    await box.put(query.toLowerCase(), cachedData);
  }

  /// Get cached place search results
  List<PlaceModel>? getCachedPlaces(String query) {
    final box = Hive.box(_placesBoxName);
    final cachedData = box.get(query.toLowerCase());

    if (cachedData == null) return null;

    try {
      // Check if cache is expired
      final timestamp = DateTime.fromMillisecondsSinceEpoch(cachedData['timestamp'] as int);
      if (DateTime.now().difference(timestamp) > _cacheExpiration) {
        box.delete(query.toLowerCase());
        return null;
      }

      final placesData = cachedData['places'] as List;
      return placesData.map((p) => PlaceModel.fromMap(p as Map<String, dynamic>)).toList();
    } catch (e) {
      // If there's any error parsing cached data, delete it and return null
      box.delete(query.toLowerCase());
      return null;
    }
  }

  /// Cache directions
  Future<void> cacheDirections(
    String key,
    List<LatLng> polylineCoordinates,
    String distance,
    String duration,
  ) async {
    final box = Hive.box(_directionsBoxName);
    final cachedData = {
      'polylineCoordinates': polylineCoordinates.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
      'distance': distance,
      'duration': duration,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    await box.put(key, cachedData);
  }

  /// Get cached directions
  Map<String, dynamic>? getCachedDirections(String key) {
    final box = Hive.box(_directionsBoxName);
    final cachedData = box.get(key);

    if (cachedData == null) return null;

    try {
      // Check if cache is expired
      final timestamp = DateTime.fromMillisecondsSinceEpoch(cachedData['timestamp'] as int);
      if (DateTime.now().difference(timestamp) > _cacheExpiration) {
        box.delete(key);
        return null;
      }

      final polylineData = cachedData['polylineCoordinates'] as List;
      final polylineCoordinates = polylineData.map((p) => LatLng(p['lat'] as double, p['lng'] as double)).toList();

      return {
        'polylineCoordinates': polylineCoordinates,
        'distance': cachedData['distance'] as String,
        'duration': cachedData['duration'] as String,
      };
    } catch (e) {
      box.delete(key);
      return null;
    }
  }

  /// Cache nearby places
  Future<void> cacheNearbyPlaces(String key, List<PlaceModel> places) async {
    final box = Hive.box(_nearbyPlacesBoxName);
    final cachedData = {
      'places': places.map((p) => p.toMap()).toList(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    await box.put(key, cachedData);
  }

  /// Get cached nearby places
  List<PlaceModel>? getCachedNearbyPlaces(String key) {
    final box = Hive.box(_nearbyPlacesBoxName);
    final cachedData = box.get(key);

    if (cachedData == null) return null;

    try {
      // Check if cache is expired
      final timestamp = DateTime.fromMillisecondsSinceEpoch(cachedData['timestamp'] as int);
      if (DateTime.now().difference(timestamp) > _cacheExpiration) {
        box.delete(key);
        return null;
      }

      final placesData = cachedData['places'] as List;
      return placesData.map((p) => PlaceModel.fromMap(p as Map<String, dynamic>)).toList();
    } catch (e) {
      box.delete(key);
      return null;
    }
  }

  /// Clear all caches
  Future<void> clearAllCaches() async {
    await Hive.box(_placesBoxName).clear();
    await Hive.box(_directionsBoxName).clear();
    await Hive.box(_nearbyPlacesBoxName).clear();
  }

  /// Clear expired caches
  Future<void> clearExpiredCaches() async {
    final now = DateTime.now();

    // Clear expired places
    final placesBox = Hive.box(_placesBoxName);
    final expiredPlaceKeys = <dynamic>[];
    for (var key in placesBox.keys) {
      try {
        final cachedData = placesBox.get(key);
        if (cachedData != null) {
          final timestamp = DateTime.fromMillisecondsSinceEpoch(cachedData['timestamp'] as int);
          if (now.difference(timestamp) > _cacheExpiration) {
            expiredPlaceKeys.add(key);
          }
        }
      } catch (e) {
        // If there's an error, mark for deletion
        expiredPlaceKeys.add(key);
      }
    }
    for (var key in expiredPlaceKeys) {
      await placesBox.delete(key);
    }

    // Clear expired directions
    final directionsBox = Hive.box(_directionsBoxName);
    final expiredDirectionKeys = <dynamic>[];
    for (var key in directionsBox.keys) {
      try {
        final cachedData = directionsBox.get(key);
        if (cachedData != null) {
          final timestamp = DateTime.fromMillisecondsSinceEpoch(cachedData['timestamp'] as int);
          if (now.difference(timestamp) > _cacheExpiration) {
            expiredDirectionKeys.add(key);
          }
        }
      } catch (e) {
        expiredDirectionKeys.add(key);
      }
    }
    for (var key in expiredDirectionKeys) {
      await directionsBox.delete(key);
    }

    // Clear expired nearby places
    final nearbyPlacesBox = Hive.box(_nearbyPlacesBoxName);
    final expiredNearbyPlaceKeys = <dynamic>[];
    for (var key in nearbyPlacesBox.keys) {
      try {
        final cachedData = nearbyPlacesBox.get(key);
        if (cachedData != null) {
          final timestamp = DateTime.fromMillisecondsSinceEpoch(cachedData['timestamp'] as int);
          if (now.difference(timestamp) > _cacheExpiration) {
            expiredNearbyPlaceKeys.add(key);
          }
        }
      } catch (e) {
        expiredNearbyPlaceKeys.add(key);
      }
    }
    for (var key in expiredNearbyPlaceKeys) {
      await nearbyPlacesBox.delete(key);
    }
  }

  /// Generate cache key for directions
  String generateDirectionsKey(LatLng origin, LatLng destination) {
    return '${origin.latitude},${origin.longitude}_${destination.latitude},${destination.longitude}';
  }

  /// Generate cache key for nearby places
  String generateNearbyPlacesKey(
    List<LatLng> routePoints,
    double radius,
    List<String> types,
  ) {
    final firstPoint = routePoints.first;
    final lastPoint = routePoints.last;
    final typesStr = types.join(',');
    return '${firstPoint.latitude},${firstPoint.longitude}_${lastPoint.latitude},${lastPoint.longitude}_${radius}_$typesStr';
  }
}
