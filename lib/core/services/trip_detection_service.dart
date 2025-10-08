import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/auto_trip_model.dart';

/// Configuration for trip detection thresholds
class TripDetectionConfig {
  // Speed thresholds (in m/s)
  static const double idleSpeedThreshold = 1.0; // Below this = stationary
  static const double movementSpeedThreshold = 2.0; // Above this = moving
  
  // Distance thresholds (in meters)
  static const double minimumTripDistance = 300.0; // Minimum distance for a valid trip
  static const double significantMovementDistance = 50.0; // Distance to confirm movement
  
  // Time thresholds (in seconds)
  static const int movementConfirmationDuration = 180; // 3 minutes of movement to start trip
  static const int stationaryConfirmationDuration = 300; // 5 minutes stationary to end trip
  static const int locationUpdateInterval = 30; // Update location every 30 seconds
  
  // Mode detection speed ranges (in km/h)
  static const double walkingMaxSpeed = 7.0;
  static const double cyclingMaxSpeed = 25.0;
  static const double bikeMaxSpeed = 60.0;
  static const double carMaxSpeed = 120.0;
}

/// Service for automatic trip detection using GPS and sensors
class TripDetectionService {
  // Singleton instance
  static final TripDetectionService _instance = TripDetectionService._internal();
  factory TripDetectionService() => _instance;
  TripDetectionService._internal();

  // Current trip being tracked
  AutoTripModel? _currentTrip;
  AutoTripModel? get currentTrip => _currentTrip;

  // Detection state
  bool _isDetecting = false;
  bool get isDetecting => _isDetecting;

  // Location tracking
  StreamSubscription<Position>? _positionSubscription;
  DateTime? _lastMovementTime;
  DateTime? _lastStationaryTime;
  
  // Trip data accumulation
  final List<LocationPoint> _routePoints = [];
  double _totalDistance = 0.0;
  double _maxSpeed = 0.0;
  List<double> _speeds = [];

  // Stream controllers
  final StreamController<AutoTripModel> _tripStartController = 
      StreamController<AutoTripModel>.broadcast();
  final StreamController<AutoTripModel> _tripEndController = 
      StreamController<AutoTripModel>.broadcast();
  final StreamController<AutoTripModel> _tripUpdateController = 
      StreamController<AutoTripModel>.broadcast();

  Stream<AutoTripModel> get onTripStart => _tripStartController.stream;
  Stream<AutoTripModel> get onTripEnd => _tripEndController.stream;
  Stream<AutoTripModel> get onTripUpdate => _tripUpdateController.stream;

  /// Start trip detection
  Future<bool> startDetection(String userId) async {
    if (_isDetecting) {
      if (kDebugMode) print('[TripDetection] Already detecting');
      return true;
    }

    try {
      // Check location permission
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        if (kDebugMode) print('[TripDetection] Location permission denied');
        return false;
      }

      // Start listening to location updates
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
          timeLimit: Duration(seconds: TripDetectionConfig.locationUpdateInterval),
        ),
      ).listen(
        (Position position) => _handleLocationUpdate(position, userId),
        onError: (error) {
          if (kDebugMode) print('[TripDetection] Error: $error');
        },
      );

      _isDetecting = true;
      if (kDebugMode) print('[TripDetection] Started detection for user: $userId');
      return true;
    } catch (e) {
      if (kDebugMode) print('[TripDetection] Failed to start: $e');
      return false;
    }
  }

  /// Stop trip detection
  void stopDetection() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _isDetecting = false;
    
    // If there's an active trip, end it
    if (_currentTrip != null && _currentTrip!.status == AutoTripStatus.detecting) {
      _endTrip();
    }
    
    if (kDebugMode) print('[TripDetection] Stopped detection');
  }

  /// Handle location update
  void _handleLocationUpdate(Position position, String userId) {
    final now = DateTime.now();
    final speed = position.speed; // in m/s
    
    if (kDebugMode) {
      print('[TripDetection] Location update: speed=${speed.toStringAsFixed(2)} m/s, '
            'accuracy=${position.accuracy.toStringAsFixed(2)}m');
    }

    // Create location point
    final locationPoint = LocationPoint(
      coordinates: LatLng(position.latitude, position.longitude),
      timestamp: now,
      speed: speed,
      accuracy: position.accuracy,
    );

    // Check if user is moving or stationary
    final isMoving = speed > TripDetectionConfig.movementSpeedThreshold;
    final isStationary = speed < TripDetectionConfig.idleSpeedThreshold;
    if (_currentTrip == null) {
      // No active trip - check if trip should start
      _checkTripStart(locationPoint, isMoving, now, userId);
    } else {
      // Active trip - update and check if trip should end
      _updateActiveTrip(locationPoint, isStationary, now);
    }
  }

  /// Check if a trip should start
  void _checkTripStart(LocationPoint locationPoint, bool isMoving, DateTime now, String userId) {
    if (isMoving) {
      // User is moving
      if (_lastMovementTime == null) {
        _lastMovementTime = now;
        if (kDebugMode) print('[TripDetection] Movement detected, starting timer');
      } else {
        // Check if movement has been sustained
        final movementDuration = now.difference(_lastMovementTime!).inSeconds;
        if (movementDuration >= TripDetectionConfig.movementConfirmationDuration) {
          // Start trip
          _startTrip(locationPoint, userId);
        }
      }
      _lastStationaryTime = null;
    } else {
      // User is stationary
      _lastMovementTime = null;
    }
  }

  /// Start a new trip
  void _startTrip(LocationPoint origin, String userId) {
    final now = DateTime.now();
    
    _currentTrip = AutoTripModel(
      userId: userId,
      origin: origin,
      startTime: origin.timestamp,
      distanceCovered: 0.0,
      averageSpeed: 0.0,
      maxSpeed: 0.0,
      routePoints: [origin],
      status: AutoTripStatus.detecting,
      createdAt: now,
      updatedAt: now,
    );

    _routePoints.clear();
    _routePoints.add(origin);
    _totalDistance = 0.0;
    _maxSpeed = 0.0;
    _speeds = [origin.speed];

    _tripStartController.add(_currentTrip!);
    
    if (kDebugMode) {
      print('[TripDetection] ✅ Trip started at ${origin.coordinates}');
    }
  }

  /// Update active trip with new location
  void _updateActiveTrip(LocationPoint locationPoint, bool isStationary, DateTime now) {
    if (_currentTrip == null) return;

    // Add location point to route
    _routePoints.add(locationPoint);
    _speeds.add(locationPoint.speed);

    // Calculate distance from last point
    if (_routePoints.length > 1) {
      final lastPoint = _routePoints[_routePoints.length - 2];
      final distance = _calculateDistance(
        lastPoint.coordinates,
        locationPoint.coordinates,
      );
      _totalDistance += distance;
    }

    // Update max speed
    if (locationPoint.speed > _maxSpeed) {
      _maxSpeed = locationPoint.speed;
    }

    // Calculate average speed
    final avgSpeed = _speeds.isNotEmpty 
        ? _speeds.reduce((a, b) => a + b) / _speeds.length 
        : 0.0;

    // Detect travel mode based on speed patterns
    final detectedMode = _detectTravelMode();

    // Update trip
    _currentTrip = _currentTrip!.copyWith(
      distanceCovered: _totalDistance,
      averageSpeed: avgSpeed,
      maxSpeed: _maxSpeed,
      routePoints: List.from(_routePoints),
      detectedMode: detectedMode,
      updatedAt: now,
    );

    _tripUpdateController.add(_currentTrip!);

    // Check if trip should end
    if (isStationary) {
      if (_lastStationaryTime == null) {
        _lastStationaryTime = now;
        if (kDebugMode) print('[TripDetection] User stopped, starting timer');
      } else {
        final stationaryDuration = now.difference(_lastStationaryTime!).inSeconds;
        if (stationaryDuration >= TripDetectionConfig.stationaryConfirmationDuration) {
          // End trip
          _endTrip();
        }
      }
      _lastMovementTime = null;
    } else {
      // Still moving
      _lastStationaryTime = null;
    }
  }

  /// End the current trip
  void _endTrip() {
    if (_currentTrip == null) return;

    final now = DateTime.now();
    final lastPoint = _routePoints.isNotEmpty 
        ? _routePoints.last 
        : _currentTrip!.origin;

    // Only save trip if it meets minimum distance requirement
    if (_totalDistance < TripDetectionConfig.minimumTripDistance) {
      if (kDebugMode) {
        print('[TripDetection] ❌ Trip too short (${_totalDistance.toStringAsFixed(0)}m), discarding');
      }
      _resetTripData();
      return;
    }

    // Update trip with final data
    _currentTrip = _currentTrip!.copyWith(
      destination: lastPoint,
      endTime: now,
      status: AutoTripStatus.detected,
      updatedAt: now,
    );

    _tripEndController.add(_currentTrip!);
    
    if (kDebugMode) {
      print('[TripDetection] ✅ Trip ended: '
            'distance=${_currentTrip!.distanceKm.toStringAsFixed(2)}km, '
            'duration=${_currentTrip!.durationMinutes}min, '
            'mode=${_currentTrip!.detectedMode}');
    }

    _resetTripData();
  }

  /// Reset trip tracking data
  void _resetTripData() {
    _currentTrip = null;
    _routePoints.clear();
    _totalDistance = 0.0;
    _maxSpeed = 0.0;
    _speeds.clear();
    _lastMovementTime = null;
    _lastStationaryTime = null;
  }

  /// Calculate distance between two coordinates using Haversine formula
  double _calculateDistance(LatLng point1, LatLng point2) {
    const earthRadius = 6371000.0; // meters

    final lat1 = point1.latitude * pi / 180;
    final lat2 = point2.latitude * pi / 180;
    final dLat = (point2.latitude - point1.latitude) * pi / 180;
    final dLon = (point2.longitude - point1.longitude) * pi / 180;

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// Detect travel mode based on speed patterns
  String _detectTravelMode() {
    if (_speeds.isEmpty) return 'Unknown';

    // Calculate speed statistics
    final avgSpeedKmh = (_speeds.reduce((a, b) => a + b) / _speeds.length) * 3.6;
    final maxSpeedKmh = _maxSpeed * 3.6;

    // Detect mode based on speed ranges
    if (maxSpeedKmh <= TripDetectionConfig.walkingMaxSpeed) {
      return 'Walking';
    } else if (maxSpeedKmh <= TripDetectionConfig.cyclingMaxSpeed) {
      return avgSpeedKmh < 12 ? 'Cycling' : 'E-Bike';
    } else if (maxSpeedKmh <= TripDetectionConfig.bikeMaxSpeed) {
      return 'Motorcycle';
    } else if (maxSpeedKmh <= TripDetectionConfig.carMaxSpeed) {
      // Distinguish between car and bus based on speed patterns
      // Bus typically has more stops and lower average speed
      final speedVariance = _calculateSpeedVariance();
      return speedVariance > 15 ? 'Bus' : 'Car';
    } else {
      return 'Train/Fast Transit';
    }
  }

  /// Calculate variance in speed to help distinguish modes
  double _calculateSpeedVariance() {
    if (_speeds.length < 2) return 0.0;

    final mean = _speeds.reduce((a, b) => a + b) / _speeds.length;
    final variance = _speeds
        .map((speed) => pow(speed - mean, 2))
        .reduce((a, b) => a + b) / _speeds.length;
    
    return sqrt(variance) * 3.6; // Convert to km/h
  }

  /// Get summary of current trip
  String getCurrentTripSummary() {
    if (_currentTrip == null) return 'No active trip';
    
    return 'Distance: ${_currentTrip!.distanceKm.toStringAsFixed(2)}km, '
           'Duration: ${_currentTrip!.durationMinutes}min, '
           'Avg Speed: ${_currentTrip!.averageSpeedKmh.toStringAsFixed(1)}km/h, '
           'Mode: ${_currentTrip!.detectedMode ?? "Detecting..."}';
  }

  /// Dispose resources
  void dispose() {
    stopDetection();
    _tripStartController.close();
    _tripEndController.close();
    _tripUpdateController.close();
  }
}
