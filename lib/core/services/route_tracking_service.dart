import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/place_model.dart';
import 'location_service.dart';
import 'maps_service.dart';
import 'notification_service.dart';

class RouteTrackingService {
  static final RouteTrackingService _instance =
      RouteTrackingService._internal();
  factory RouteTrackingService() => _instance;
  RouteTrackingService._internal();

  final LocationService _locationService = LocationService();
  final MapsService _mapsService = MapsService();
  final NotificationService _notificationService = NotificationService();

  // Route tracking properties
  List<LatLng> _routePolyline = [];
  List<PlaceModel> _nearbyPlaces = [];
  Set<String> _notifiedPlaceIds = {};
  bool _isTracking = false;
  Timer? _nearbyPlacesTimer;
  final double _notificationRadius = 500; // meters
  final double _routeDeviationThreshold = 200; // meters
  StreamSubscription<Position>? _locationStreamSubscription;
  DateTime? _lastNearbyCheck;
  final Duration _nearbyCheckDebounce = const Duration(seconds: 30);

  // Stream controllers
  final _nearbyPlacesController =
      StreamController<List<PlaceModel>>.broadcast();
  final _routeDeviationController = StreamController<bool>.broadcast();
  final _currentPositionController = StreamController<Position>.broadcast();

  // Getters for streams
  Stream<List<PlaceModel>> get nearbyPlacesStream =>
      _nearbyPlacesController.stream;
  Stream<bool> get routeDeviationStream => _routeDeviationController.stream;
  Stream<Position> get currentPositionStream =>
      _currentPositionController.stream;

  // Getters for current state
  List<LatLng> get routePolyline => _routePolyline;
  List<PlaceModel> get nearbyPlaces => _nearbyPlaces;
  bool get isTracking => _isTracking;

  // Initialize route tracking
  Future<void> initRouteTracking(List<LatLng> routePolyline) async {
    _routePolyline = routePolyline;
    _nearbyPlaces = [];
    _notifiedPlaceIds = {};
    _isTracking = true;

    // Start location tracking
    await _locationService.startTracking();
    _locationStreamSubscription = _locationService.locationStream.listen(_onPositionUpdate);

    // Start periodic nearby places check
    _nearbyPlacesTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkNearbyPlaces();
    });

    // Initial check for nearby places
    _checkNearbyPlaces();
  }

  // Stop route tracking
  void stopRouteTracking() {
    _isTracking = false;
    _locationService.stopTracking();
    _locationStreamSubscription?.cancel();
    _locationStreamSubscription = null;
    _nearbyPlacesTimer?.cancel();
    _nearbyPlacesTimer = null;
  }

  // Handle position updates
  void _onPositionUpdate(Position position) {
    if (!_isTracking) return;

    // Broadcast current position (guard if controller is closed)
    if (!_currentPositionController.isClosed) {
      _currentPositionController.add(position);
    }

    // Check if user has deviated from route
    final isOnRoute = _isOnRoute(position);
    if (!_routeDeviationController.isClosed) {
      _routeDeviationController.add(!isOnRoute);
    }

    // Check for nearby places when position changes significantly
    _checkNearbyPlaces();
  }

  // Check if user is on route
  bool _isOnRoute(Position position) {
    if (_routePolyline.isEmpty) return true;

    // Find the closest point on the route to the current position
    double minDistance = double.infinity;
    for (final point in _routePolyline) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        point.latitude,
        point.longitude,
      );
      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    // Check if the minimum distance is within the threshold
    return minDistance <= _routeDeviationThreshold;
  }

  // Check for nearby places along the route
  Future<void> _checkNearbyPlaces() async {
    if (!_isTracking) return;
    final now = DateTime.now();
    if (_lastNearbyCheck != null && now.difference(_lastNearbyCheck!) < _nearbyCheckDebounce) {
      return;
    }
    _lastNearbyCheck = now;

    try {
      // Get current position
      final position = await _locationService.getCurrentPosition();
      if (position == null) return;

      // Sample points along the route near current position
      final sampledPoints = _samplePointsNearPosition(
        position,
        _routePolyline,
        5000, // 5km radius for sampling
      );

      // Fetch nearby places for each sampled point
      final allNearbyPlaces = <PlaceModel>[];
      for (final point in sampledPoints) {
        final places = await _mapsService.getNearbyPlaces(
          [LatLng(point.latitude, point.longitude)],
          1500,
          ['point_of_interest'],
        );
        allNearbyPlaces.addAll(places);
      }

      // Remove duplicates
      final uniquePlaces = <PlaceModel>{};
      for (final place in allNearbyPlaces) {
        uniquePlaces.add(place);
      }

      // Update nearby places
      _nearbyPlaces = uniquePlaces.toList();
      if (!_nearbyPlacesController.isClosed) {
        _nearbyPlacesController.add(_nearbyPlaces);
      }

      // Check for places that need notifications
      _checkForNotifications(position);
    } catch (e) {
      if (kDebugMode) {
        print('Error checking nearby places: $e');
      }
    }
  }

  // Sample points along the route near the current position
  List<LatLng> _samplePointsNearPosition(
    Position position,
    List<LatLng> route,
    double radius,
  ) {
    if (route.isEmpty) return [LatLng(position.latitude, position.longitude)];

    // Filter points within radius
    final nearbyPoints = <LatLng>[];
    for (final point in route) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        point.latitude,
        point.longitude,
      );
      if (distance <= radius) {
        nearbyPoints.add(point);
      }
    }

    // If no nearby points, use current position
    if (nearbyPoints.isEmpty) {
      return [LatLng(position.latitude, position.longitude)];
    }

    // Sample points to reduce API calls
    if (nearbyPoints.length <= 3) {
      return nearbyPoints;
    }

    // Take evenly distributed points
    final sampledPoints = <LatLng>[];
    final step = nearbyPoints.length ~/ 3;
    for (int i = 0; i < nearbyPoints.length; i += step) {
      if (sampledPoints.length < 3) {
        sampledPoints.add(nearbyPoints[i]);
      }
    }

    return sampledPoints;
  }

  // Check if notifications should be sent for nearby places
  void _checkForNotifications(Position position) {
    for (final place in _nearbyPlaces) {
      // Skip if already notified
      if (_notifiedPlaceIds.contains(place.placeId)) continue;

      // Calculate distance to place
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        place.location.latitude,
        place.location.longitude,
      );

      // Send notification if within radius
      if (distance <= _notificationRadius) {
        _notificationService.showNearbyPlaceNotification(
          place,
          'You are near ${place.name}. ${place.address}',
        );
        _notifiedPlaceIds.add(place.placeId);
      }
    }
  }

  // Calculate distance between two points
  double calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  // Calculate total route distance
  double calculateRouteDistance(List<LatLng> route) {
    if (route.length < 2) return 0;

    double totalDistance = 0;
    for (int i = 0; i < route.length - 1; i++) {
      totalDistance += calculateDistance(route[i], route[i + 1]);
    }

    return totalDistance;
  }

  // Dispose resources
  void dispose() {
    stopRouteTracking();
    _nearbyPlacesController.close();
    _routeDeviationController.close();
    _currentPositionController.close();
  }
}
