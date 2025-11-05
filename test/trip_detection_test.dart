import 'package:flutter_test/flutter_test.dart';
import 'package:tourmate/core/models/auto_trip_model.dart';
import 'package:tourmate/core/services/trip_detection_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  group('AutoTripModel Tests', () {
    test('Create AutoTripModel with valid data', () {
      final origin = LocationPoint(
        coordinates: const LatLng(11.2588, 75.7804),
        timestamp: DateTime.now(),
        speed: 0.5,
        accuracy: 10.0,
      );

      final trip = AutoTripModel(
        userId: 'test_user',
        origin: origin,
        startTime: DateTime.now(),
        distanceCovered: 5000.0,
        averageSpeed: 5.0,
        maxSpeed: 10.0,
        routePoints: [origin],
        status: AutoTripStatus.detecting,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(trip.userId, 'test_user');
      expect(trip.distanceKm, 5.0);
      expect(trip.averageSpeedKmh, 18.0); // 5 m/s = 18 km/h
      expect(trip.status, AutoTripStatus.detecting);
    });

    test('Calculate trip duration correctly', () {
      final startTime = DateTime(2025, 10, 8, 8, 0);
      final endTime = DateTime(2025, 10, 8, 8, 35);

      final origin = LocationPoint(
        coordinates: const LatLng(11.2588, 75.7804),
        timestamp: startTime,
        speed: 0.5,
        accuracy: 10.0,
      );

      final trip = AutoTripModel(
        userId: 'test_user',
        origin: origin,
        startTime: startTime,
        endTime: endTime,
        distanceCovered: 8200.0,
        averageSpeed: 6.5,
        maxSpeed: 15.0,
        routePoints: [origin],
        status: AutoTripStatus.detected,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(trip.durationMinutes, 35);
    });

    test('Convert to/from Map correctly', () {
      final origin = LocationPoint(
        coordinates: const LatLng(11.2588, 75.7804),
        timestamp: DateTime.now(),
        speed: 0.5,
        accuracy: 10.0,
      );

      final trip = AutoTripModel(
        userId: 'test_user',
        origin: origin,
        startTime: DateTime.now(),
        distanceCovered: 5000.0,
        averageSpeed: 5.0,
        maxSpeed: 10.0,
        routePoints: [origin],
        status: AutoTripStatus.confirmed,
        purpose: 'Work',
        confirmedMode: 'Bus',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final map = trip.toMap();
      expect(map['userId'], 'test_user');
      expect(map['distanceCovered'], 5000.0);
      expect(map['status'], 'confirmed');
      expect(map['purpose'], 'Work');
    });
  });

  group('TripDetectionConfig Tests', () {
    test('Speed thresholds are correct', () {
      expect(TripDetectionConfig.idleSpeedThreshold, 1.0);
      expect(TripDetectionConfig.movementSpeedThreshold, 2.0);
    });

    test('Distance thresholds are correct', () {
      expect(TripDetectionConfig.minimumTripDistance, 300.0);
      expect(TripDetectionConfig.significantMovementDistance, 50.0);
    });

    test('Time thresholds are correct', () {
      expect(TripDetectionConfig.movementConfirmationDuration, 180);
      expect(TripDetectionConfig.stationaryConfirmationDuration, 300);
    });

    test('Mode detection speed ranges are correct', () {
      expect(TripDetectionConfig.walkingMaxSpeed, 7.0);
      expect(TripDetectionConfig.cyclingMaxSpeed, 25.0);
      expect(TripDetectionConfig.bikeMaxSpeed, 60.0);
      expect(TripDetectionConfig.carMaxSpeed, 120.0);
    });
  });

  group('LocationPoint Tests', () {
    test('Create LocationPoint with valid data', () {
      final point = LocationPoint(
        coordinates: const LatLng(11.2588, 75.7804),
        timestamp: DateTime.now(),
        speed: 5.0,
        accuracy: 10.0,
      );

      expect(point.coordinates.latitude, 11.2588);
      expect(point.coordinates.longitude, 75.7804);
      expect(point.speed, 5.0);
      expect(point.accuracy, 10.0);
    });

    test('Convert LocationPoint to/from Map', () {
      final timestamp = DateTime.now();
      final point = LocationPoint(
        coordinates: const LatLng(11.2588, 75.7804),
        timestamp: timestamp,
        speed: 5.0,
        accuracy: 10.0,
      );

      final map = point.toMap();
      expect(map['latitude'], 11.2588);
      expect(map['longitude'], 75.7804);
      expect(map['speed'], 5.0);
      expect(map['accuracy'], 10.0);

      final reconstructed = LocationPoint.fromMap(map);
      expect(reconstructed.coordinates.latitude, 11.2588);
      expect(reconstructed.coordinates.longitude, 75.7804);
      expect(reconstructed.speed, 5.0);
    });
  });

  group('AutoTripStatus Tests', () {
    test('All status values exist', () {
      expect(AutoTripStatus.values.length, 4);
      expect(AutoTripStatus.values.contains(AutoTripStatus.detecting), true);
      expect(AutoTripStatus.values.contains(AutoTripStatus.detected), true);
      expect(AutoTripStatus.values.contains(AutoTripStatus.confirmed), true);
      expect(AutoTripStatus.values.contains(AutoTripStatus.rejected), true);
    });
  });

  group('Trip Statistics Tests', () {
    test('Calculate distance in kilometers', () {
      final origin = LocationPoint(
        coordinates: const LatLng(11.2588, 75.7804),
        timestamp: DateTime.now(),
        speed: 0.5,
        accuracy: 10.0,
      );

      final trip = AutoTripModel(
        userId: 'test_user',
        origin: origin,
        startTime: DateTime.now(),
        distanceCovered: 8200.0, // meters
        averageSpeed: 6.5,
        maxSpeed: 15.0,
        routePoints: [origin],
        status: AutoTripStatus.detected,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(trip.distanceKm, 8.2);
    });

    test('Calculate speed in km/h', () {
      final origin = LocationPoint(
        coordinates: const LatLng(11.2588, 75.7804),
        timestamp: DateTime.now(),
        speed: 0.5,
        accuracy: 10.0,
      );

      final trip = AutoTripModel(
        userId: 'test_user',
        origin: origin,
        startTime: DateTime.now(),
        distanceCovered: 5000.0,
        averageSpeed: 5.0, // m/s
        maxSpeed: 10.0, // m/s
        routePoints: [origin],
        status: AutoTripStatus.detected,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(trip.averageSpeedKmh, 18.0); // 5 * 3.6
      expect(trip.maxSpeedKmh, 36.0); // 10 * 3.6
    });
  });

  group('Trip CopyWith Tests', () {
    test('CopyWith creates new instance with updated values', () {
      final origin = LocationPoint(
        coordinates: const LatLng(11.2588, 75.7804),
        timestamp: DateTime.now(),
        speed: 0.5,
        accuracy: 10.0,
      );

      final trip1 = AutoTripModel(
        userId: 'test_user',
        origin: origin,
        startTime: DateTime.now(),
        distanceCovered: 5000.0,
        averageSpeed: 5.0,
        maxSpeed: 10.0,
        routePoints: [origin],
        status: AutoTripStatus.detecting,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final trip2 = trip1.copyWith(
        status: AutoTripStatus.confirmed,
        purpose: 'Work',
        confirmedMode: 'Bus',
      );

      expect(trip2.status, AutoTripStatus.confirmed);
      expect(trip2.purpose, 'Work');
      expect(trip2.confirmedMode, 'Bus');
      expect(trip2.userId, trip1.userId); // Unchanged
      expect(trip2.distanceCovered, trip1.distanceCovered); // Unchanged
    });
  });
}
