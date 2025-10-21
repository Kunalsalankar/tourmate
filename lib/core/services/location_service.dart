import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// A service that manages location tracking and permissions
class LocationService {
  // Singleton instance
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // Stream controller for location updates (recoverable)
  StreamController<Position>? _locationController;
  Stream<Position> get locationStream {
    _ensureController();
    return _locationController!.stream;
  }

  void _ensureController() {
    _locationController ??= StreamController<Position>.broadcast();
    if (_locationController!.isClosed) {
      _locationController = StreamController<Position>.broadcast();
    }
  }

  // Current position
  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;

  // Location tracking status
  bool _isTracking = false;
  bool get isTracking => _isTracking;

  // Stream subscription for location updates
  StreamSubscription<Position>? _positionStreamSubscription;

  /// Initialize the location service
  Future<void> initialize() async {
    await _checkPermissions();
  }

  /// Check and request location permissions
  Future<bool> _checkPermissions() async {
    // Check location permission
    final status = await Permission.location.status;
    
    if (status.isGranted) {
      return true;
    }
    
    // Request permission
    final result = await Permission.location.request();
    return result.isGranted;
  }

  /// Get the current position once
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await _checkPermissions();
      
      if (!hasPermission) {
        return null;
      }
      
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      _currentPosition = position;
      return position;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting current position: $e');
      }
      return null;
    }
  }

  /// Start tracking location
  Future<bool> startTracking() async {
    if (_isTracking) return true;
    
    try {
      final hasPermission = await _checkPermissions();
      
      if (!hasPermission) {
        return false;
      }
      
      // Get current position first
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      // Add to stream
      if (_currentPosition != null) {
        _ensureController();
        _locationController!.add(_currentPosition!);
      }
      
      // Start listening to position updates
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        ),
      ).listen((Position position) {
        _currentPosition = position;
        _ensureController();
        _locationController!.add(position);
      });
      
      _isTracking = true;
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error starting location tracking: $e');
      }
      return false;
    }
  }

  /// Stop tracking location
  void stopTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _isTracking = false;
  }

  /// Calculate distance between two positions in meters
  double calculateDistance(Position position1, Position position2) {
    return Geolocator.distanceBetween(
      position1.latitude,
      position1.longitude,
      position2.latitude,
      position2.longitude,
    );
  }

  /// Dispose resources
  void dispose() {
    stopTracking();
    // Do not close the broadcast controller here to allow re-use across app services
  }
}