import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:http/http.dart' as http;
import '../models/place_model.dart';

/// A service that handles Google Maps API interactions
class MapsService {
  // Singleton instance
  static final MapsService _instance = MapsService._internal();
  factory MapsService() => _instance;
  MapsService._internal();

  // API key from .env file
  String? _apiKey;
  

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
  }

  /// Search for places using the Places API
  Future<List<PlaceModel>> searchPlaces(String query) async {
    try {
      final places = GoogleMapsPlaces(apiKey: _apiKey);
      final response = await places.searchByText(query);

      if (response.status == 'OK') {
        return response.results
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

  /// Get route between origin and destination
  Future<Map<String, dynamic>> getDirections(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
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
    final places = <PlaceModel>{};

    // Sample points along the route to avoid too many API calls
    final sampledPoints = _sampleRoutePoints(routePoints, 500); // Every 500 meters

    // Query nearby places for each sampled point
    for (final point in sampledPoints) {
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

      // Add a delay to avoid hitting API rate limits
      await Future.delayed(const Duration(milliseconds: 200));
    }

    return places.toList();
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