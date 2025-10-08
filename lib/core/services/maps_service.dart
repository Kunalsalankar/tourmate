import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_webservice/places.dart' as places_webservice;
import 'package:http/http.dart' as http;
import '../models/place_model.dart';
import 'cache_service.dart';

// Conditional import for web-specific implementation
import 'maps_service_stub.dart'
    if (dart.library.html) 'maps_service_web.dart';

/// A service that handles Google Maps API interactions
class MapsService {
  // Singleton instance
  static final MapsService _instance = MapsService._internal();
  factory MapsService() => _instance;
  MapsService._internal();

  // API key from .env file
  String? _apiKey;
  
  // Cache service
  final CacheService _cacheService = CacheService();

  /// Initialize the maps service
  Future<void> initialize() async {
    // Only initialize if not already initialized
    if (_apiKey != null) {
      return;
    }
    
    _apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    if (_apiKey?.isEmpty ?? true) {
      throw Exception('Google Maps API key not found in .env file');
    }
    
    // Initialize cache service
    await _cacheService.initialize();
    
    // Clear expired caches on startup
    await _cacheService.clearExpiredCaches();
  }

  /// Search for places using the Places API (for non-autocomplete searches)
  Future<List<PlaceModel>> searchPlaces(String query) async {
    try {
      // Check cache first
      final cachedPlaces = _cacheService.getCachedPlaces(query);
      if (cachedPlaces != null) {
        if (kDebugMode) {
          print('Returning cached places for query: $query');
        }
        return cachedPlaces;
      }

      // Use web-specific implementation on web to avoid CORS
      if (kIsWeb) {
        if (kDebugMode) {
          print('Using web-specific implementation for places search');
        }
        final webService = MapsServiceWeb();
        final results = await webService.searchPlaces(query);
        
        // Cache the results
        if (results.isNotEmpty) {
          await _cacheService.cachePlaces(query, results);
        }
        
        return results;
      }

      // Mobile/Desktop: Use REST API via google_maps_webservice package
      final places = places_webservice.GoogleMapsPlaces(apiKey: _apiKey);
      final response = await places.searchByText(query);

      if (response.status == 'OK') {
        final results = response.results
            .map((result) => PlaceModel(
                  placeId: result.placeId,
                  name: result.name,
                  address: result.formattedAddress ?? '',
                  location: LatLng(
                    result.geometry?.location.lat ?? 0,
                    result.geometry?.location.lng ?? 0,
                  ),
                ))
            .toList();
        
        // Cache the results
        await _cacheService.cachePlaces(query, results);
        
        return results;
      } else {
        if (kDebugMode) {
          print('Places API error: ${response.errorMessage}');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error searching places: $e');
      }
      return [];
    }
  }

  /// Search for places with autocomplete functionality
  Future<List<PlaceModel>> searchPlacesAutocomplete(String query) async {
    try {
      // Check cache first
      final cacheKey = 'autocomplete_$query';
      final cachedPlaces = _cacheService.getCachedPlaces(cacheKey);
      if (cachedPlaces != null) {
        if (kDebugMode) {
          print('Returning cached autocomplete places for query: $query');
        }
        return cachedPlaces;
      }

      // Use web-specific implementation on web to avoid CORS
      if (kIsWeb) {
        if (kDebugMode) {
          print('Using web-specific implementation for autocomplete');
        }
        final webService = MapsServiceWeb();
        final results = await webService.searchPlacesAutocomplete(query);
        
        // Cache the results
        if (results.isNotEmpty) {
          await _cacheService.cachePlaces(cacheKey, results);
        }
        
        return results;
      }

      // Mobile/Desktop: Use REST API
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?'
        'input=$query'
        '&key=$_apiKey',
      );

      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        final predictions = data['predictions'] as List;
        final results = <PlaceModel>[];

        for (final prediction in predictions) {
          // Get place details for each prediction to get coordinates
          final placeDetails = await _getPlaceDetails(prediction['place_id'] as String);
          if (placeDetails != null) {
            results.add(placeDetails);
          }
        }

        // Cache the results
        await _cacheService.cachePlaces(cacheKey, results);

        return results;
      } else {
        if (kDebugMode) {
          print('Places Autocomplete API error: ${data['status']}');
        }
        // Fallback to regular search if autocomplete fails
        return await searchPlaces(query);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in autocomplete search: $e');
      }
      // Fallback to regular search
      return await searchPlaces(query);
    }
  }

  /// Get detailed information about a place by its place ID
  Future<PlaceModel?> _getPlaceDetails(String placeId) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json?'
        'place_id=$placeId'
        '&fields=place_id,name,formatted_address,geometry'
        '&key=$_apiKey',
      );

      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        final result = data['result'];
        final location = result['geometry']['location'];

        return PlaceModel(
          placeId: result['place_id'],
          name: result['name'],
          address: result['formatted_address'] ?? '',
          location: LatLng(location['lat'], location['lng']),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting place details: $e');
      }
    }
    return null;
  }

  /// Get route between origin and destination
  Future<Map<String, dynamic>> getDirections(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      // Generate cache key
      final cacheKey = _cacheService.generateDirectionsKey(origin, destination);
      
      // Check cache first
      final cachedDirections = _cacheService.getCachedDirections(cacheKey);
      if (cachedDirections != null) {
        if (kDebugMode) {
          print('Returning cached directions for route: $cacheKey');
        }
        return cachedDirections;
      }

      // Use web-specific implementation on web to avoid CORS
      if (kIsWeb) {
        if (kDebugMode) {
          print('Using web-specific implementation for directions');
        }
        final webService = MapsServiceWeb();
        final result = await webService.getDirections(origin, destination);
        
        // Cache the results if successful
        if (result.isNotEmpty && result.containsKey('polylineCoordinates')) {
          await _cacheService.cacheDirections(
            cacheKey,
            result['polylineCoordinates'] as List<LatLng>,
            result['distance'] as String,
            result['duration'] as String,
          );
        }
        
        return result;
      }

      // Mobile/Desktop: Use REST API
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&key=$_apiKey',
      );

      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        // Get route polyline points
        final points = PolylinePoints().decodePolyline(
          data['routes'][0]['overview_polyline']['points'],
        );

        // Convert to LatLng list
        final polylineCoordinates = points
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();

        // Get distance and duration
        final distance = data['routes'][0]['legs'][0]['distance']['text'];
        final duration = data['routes'][0]['legs'][0]['duration']['text'];

        // Cache the results
        await _cacheService.cacheDirections(
          cacheKey,
          polylineCoordinates,
          distance,
          duration,
        );

        return {
          'polylineCoordinates': polylineCoordinates,
          'distance': distance,
          'duration': duration,
        };
      } else {
        if (kDebugMode) {
          print('Directions API error: ${data['status']}');
        }
        return {};
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting directions: $e');
      }
      return {};
    }
  }

  /// Get nearby places along a route
  Future<List<PlaceModel>> getNearbyPlaces(
    List<LatLng> routePoints,
    double radius,
    List<String> types,
  ) async {
    // Generate cache key
    final cacheKey = _cacheService.generateNearbyPlacesKey(
      routePoints,
      radius,
      types,
    );
    
    // Check cache first
    final cachedNearbyPlaces = _cacheService.getCachedNearbyPlaces(cacheKey);
    if (cachedNearbyPlaces != null) {
      if (kDebugMode) {
        print('Returning cached nearby places for route');
      }
      return cachedNearbyPlaces;
    }

    final places = <PlaceModel>{};

    // Sample points along the route to avoid too many API calls
    // Increased to 2000 meters (2km) for better performance
    final sampledPoints = _sampleRoutePoints(routePoints, 2000);

    // Limit to maximum 5 API calls to avoid slow loading
    final limitedPoints = sampledPoints.length > 5 
        ? sampledPoints.sublist(0, 5) 
        : sampledPoints;

    // Query nearby places for each sampled point
    for (final point in limitedPoints) {
      try {
        final typeParam = types.isNotEmpty ? '&type=${types.join('|')}' : '';
        
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json?'
          'location=${point.latitude},${point.longitude}'
          '&radius=$radius'
          '$typeParam'
          '&key=$_apiKey',
        );

        final response = await http.get(url);
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          for (final result in data['results']) {
            final place = PlaceModel(
              placeId: result['place_id'],
              name: result['name'],
              address: result['vicinity'] ?? '',
              location: LatLng(
                result['geometry']['location']['lat'],
                result['geometry']['location']['lng'],
              ),
              types: List<String>.from(result['types']),
              rating: result['rating']?.toDouble() ?? 0.0,
            );
            
            // Add to set to avoid duplicates
            places.add(place);
          }
        } else {
          if (kDebugMode) {
            print('Nearby Places API error: ${data['status']}');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error getting nearby places: $e');
        }
      }

      // Reduced delay for faster loading (only 50ms between calls)
      await Future.delayed(const Duration(milliseconds: 50));
    }

    final placesList = places.toList();
    
    // Cache the results
    await _cacheService.cacheNearbyPlaces(cacheKey, placesList);

    return placesList;
  }

  /// Sample points along a route to reduce API calls
  List<LatLng> _sampleRoutePoints(List<LatLng> points, double distanceInterval) {
    if (points.isEmpty) return [];
    if (points.length == 1) return points;

    final sampledPoints = <LatLng>[points.first];
    double accumulatedDistance = 0;
    
    for (int i = 1; i < points.length; i++) {
      final previousPoint = points[i - 1];
      final currentPoint = points[i];
      
      // Calculate distance between consecutive points
      final segmentDistance = _calculateDistance(
        previousPoint.latitude,
        previousPoint.longitude,
        currentPoint.latitude,
        currentPoint.longitude,
      );
      
      accumulatedDistance += segmentDistance;
      
      // If we've traveled the desired interval, add this point
      if (accumulatedDistance >= distanceInterval) {
        sampledPoints.add(currentPoint);
        accumulatedDistance = 0; // Reset accumulated distance
      }
    }
    
    // Always include the last point
    if (sampledPoints.last != points.last) {
      sampledPoints.add(points.last);
    }
    
    return sampledPoints;
  }

  /// Calculate distance between two coordinates using Haversine formula
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295; // Math.PI / 180
    const c = cos;
    final a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)) * 1000; // 2 * R * asin(sqrt(a)) * 1000 to get meters
  }
}