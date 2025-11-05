import 'package:flutter_test/flutter_test.dart';
import 'package:tourmate/core/models/enhanced_trip_metrics.dart';
import 'package:tourmate/core/models/auto_trip_model.dart';
import 'package:tourmate/core/models/trip_model.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  group('TripMetrics Tests', () {
    test('Create TripMetrics from AutoTripModel', () {
      // Create a sample AutoTripModel
      final origin = LocationPoint(
        coordinates: const LatLng(11.2588, 75.7804),
        timestamp: DateTime(2025, 1, 14, 8, 30),
        speed: 0.5,
        accuracy: 10.0,
      );

      final destination = LocationPoint(
        coordinates: const LatLng(11.2488, 75.7904),
        timestamp: DateTime(2025, 1, 14, 9, 0),
        speed: 0.3,
        accuracy: 12.0,
      );

      final autoTrip = AutoTripModel(
        id: 'test-trip-1',
        userId: 'user123',
        origin: origin,
        destination: destination,
        startTime: DateTime(2025, 1, 14, 8, 30),
        endTime: DateTime(2025, 1, 14, 9, 0),
        distanceCovered: 5000.0, // 5 km
        averageSpeed: 8.0, // m/s
        maxSpeed: 15.0, // m/s
        routePoints: [origin, destination],
        status: AutoTripStatus.confirmed,
        purpose: 'Work',
        detectedMode: 'Car',
        confirmedMode: 'Car',
        companions: ['John Doe'],
        cost: 50.0,
        notes: 'Morning commute',
        createdAt: DateTime(2025, 1, 14, 8, 30),
        updatedAt: DateTime(2025, 1, 14, 9, 0),
      );

      // Create metrics from auto trip
      final metrics = TripMetrics.fromAutoTrip(autoTrip);

      // Verify basic fields
      expect(metrics.tripId, 'test-trip-1');
      expect(metrics.userId, 'user123');
      expect(metrics.mode, 'Car');
      expect(metrics.purpose, 'Work');
      expect(metrics.distanceKm, 5.0);
      expect(metrics.durationMinutes, 30);
      expect(metrics.companionCount, 1);
      expect(metrics.tripType, 'Auto');
      expect(metrics.isConfirmed, true);

      // Verify time-based metrics
      expect(metrics.hourOfDay, 8);
      expect(metrics.dayOfWeek, 2); // Tuesday
      expect(metrics.isPeakHour, true); // 8 AM is peak hour
      expect(metrics.timeOfDay, 'Morning');

      // Verify environmental metrics
      expect(metrics.estimatedCO2, isNotNull);
      expect(metrics.estimatedCO2! > 0, true);
      expect(metrics.estimatedFuelConsumption, isNotNull);
    });

    test('Create TripMetrics from TripModel', () {
      // Create a sample TripModel
      final trip = TripModel(
        id: 'manual-trip-1',
        tripNumber: 'TRIP-001',
        origin: 'Kozhikode',
        destination: 'Kochi',
        time: DateTime(2025, 1, 14, 17, 30),
        endTime: DateTime(2025, 1, 14, 19, 0),
        mode: 'Bus',
        activities: ['Work', 'Meeting'],
        accompanyingTravellers: [
          TravellerInfo(name: 'Jane Doe', age: 28),
        ],
        userId: 'user123',
        tripType: TripType.past,
        createdAt: DateTime(2025, 1, 14, 17, 30),
        updatedAt: DateTime(2025, 1, 14, 19, 0),
      );

      // Create metrics from manual trip
      final metrics = TripMetrics.fromManualTrip(trip);

      // Verify basic fields
      expect(metrics.tripId, 'manual-trip-1');
      expect(metrics.userId, 'user123');
      expect(metrics.mode, 'Bus');
      expect(metrics.originName, 'Kozhikode');
      expect(metrics.destinationName, 'Kochi');
      expect(metrics.durationMinutes, 90);
      expect(metrics.companionCount, 1);
      expect(metrics.tripType, 'Manual');
      expect(metrics.isConfirmed, true);

      // Verify time-based metrics
      expect(metrics.hourOfDay, 17);
      expect(metrics.isPeakHour, true); // 5 PM is peak hour
      expect(metrics.timeOfDay, 'Evening');
    });

    test('Peak hour detection', () {
      // Morning peak (7-9 AM)
      final morningTrip = AutoTripModel(
        userId: 'user123',
        origin: LocationPoint(
          coordinates: const LatLng(11.2588, 75.7804),
          timestamp: DateTime(2025, 1, 14, 8, 0),
          speed: 0.5,
          accuracy: 10.0,
        ),
        startTime: DateTime(2025, 1, 14, 8, 0),
        distanceCovered: 1000.0,
        averageSpeed: 5.0,
        maxSpeed: 10.0,
        routePoints: [],
        status: AutoTripStatus.confirmed,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final morningMetrics = TripMetrics.fromAutoTrip(morningTrip);
      expect(morningMetrics.isPeakHour, true);

      // Evening peak (5-7 PM)
      final eveningTrip = AutoTripModel(
        userId: 'user123',
        origin: LocationPoint(
          coordinates: const LatLng(11.2588, 75.7804),
          timestamp: DateTime(2025, 1, 14, 18, 0),
          speed: 0.5,
          accuracy: 10.0,
        ),
        startTime: DateTime(2025, 1, 14, 18, 0),
        distanceCovered: 1000.0,
        averageSpeed: 5.0,
        maxSpeed: 10.0,
        routePoints: [],
        status: AutoTripStatus.confirmed,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final eveningMetrics = TripMetrics.fromAutoTrip(eveningTrip);
      expect(eveningMetrics.isPeakHour, true);

      // Off-peak
      final offPeakTrip = AutoTripModel(
        userId: 'user123',
        origin: LocationPoint(
          coordinates: const LatLng(11.2588, 75.7804),
          timestamp: DateTime(2025, 1, 14, 14, 0),
          speed: 0.5,
          accuracy: 10.0,
        ),
        startTime: DateTime(2025, 1, 14, 14, 0),
        distanceCovered: 1000.0,
        averageSpeed: 5.0,
        maxSpeed: 10.0,
        routePoints: [],
        status: AutoTripStatus.confirmed,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final offPeakMetrics = TripMetrics.fromAutoTrip(offPeakTrip);
      expect(offPeakMetrics.isPeakHour, false);
    });

    test('Time of day classification', () {
      final testCases = [
        (7, 'Morning'),
        (10, 'Morning'),
        (12, 'Afternoon'),
        (15, 'Afternoon'),
        (18, 'Evening'),
        (20, 'Evening'),
        (22, 'Night'),
        (2, 'Night'),
      ];

      for (final testCase in testCases) {
        final trip = AutoTripModel(
          userId: 'user123',
          origin: LocationPoint(
            coordinates: const LatLng(11.2588, 75.7804),
            timestamp: DateTime(2025, 1, 14, testCase.$1, 0),
            speed: 0.5,
            accuracy: 10.0,
          ),
          startTime: DateTime(2025, 1, 14, testCase.$1, 0),
          distanceCovered: 1000.0,
          averageSpeed: 5.0,
          maxSpeed: 10.0,
          routePoints: [],
          status: AutoTripStatus.confirmed,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final metrics = TripMetrics.fromAutoTrip(trip);
        expect(metrics.timeOfDay, testCase.$2,
            reason: 'Hour ${testCase.$1} should be ${testCase.$2}');
      }
    });

    test('CO2 estimation for different modes', () {
      final modes = ['Car', 'Bus', 'Motorcycle', 'Walking', 'Cycling'];
      
      for (final mode in modes) {
        final trip = AutoTripModel(
          userId: 'user123',
          origin: LocationPoint(
            coordinates: const LatLng(11.2588, 75.7804),
            timestamp: DateTime.now(),
            speed: 0.5,
            accuracy: 10.0,
          ),
          startTime: DateTime.now(),
          distanceCovered: 10000.0, // 10 km
          averageSpeed: 5.0,
          maxSpeed: 10.0,
          routePoints: [],
          status: AutoTripStatus.confirmed,
          detectedMode: mode,
          confirmedMode: mode,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final metrics = TripMetrics.fromAutoTrip(trip);
        
        if (mode == 'Walking' || mode == 'Cycling') {
          expect(metrics.estimatedCO2, 0.0,
              reason: '$mode should have zero CO2 emissions');
        } else {
          expect(metrics.estimatedCO2! > 0, true,
              reason: '$mode should have positive CO2 emissions');
        }
      }
    });

    test('CSV export format', () {
      final trip = AutoTripModel(
        id: 'test-trip-1',
        userId: 'user123',
        origin: LocationPoint(
          coordinates: const LatLng(11.2588, 75.7804),
          timestamp: DateTime(2025, 1, 14, 8, 30),
          speed: 0.5,
          accuracy: 10.0,
        ),
        destination: LocationPoint(
          coordinates: const LatLng(11.2488, 75.7904),
          timestamp: DateTime(2025, 1, 14, 9, 0),
          speed: 0.3,
          accuracy: 12.0,
        ),
        startTime: DateTime(2025, 1, 14, 8, 30),
        endTime: DateTime(2025, 1, 14, 9, 0),
        distanceCovered: 5000.0,
        averageSpeed: 8.0,
        maxSpeed: 15.0,
        routePoints: [],
        status: AutoTripStatus.confirmed,
        purpose: 'Work',
        detectedMode: 'Car',
        confirmedMode: 'Car',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final metrics = TripMetrics.fromAutoTrip(trip);
      final csvRow = metrics.toCSVRow();

      // Verify CSV row contains expected data
      expect(csvRow.contains('test-trip-1'), true);
      expect(csvRow.contains('user123'), true);
      expect(csvRow.contains('Car'), true);
      expect(csvRow.contains('Work'), true);
      expect(csvRow.contains('5.00'), true); // Distance
    });
  });

  group('TripMetrics Analysis Extensions', () {
    test('Calculate average distance', () {
      final trips = [
        _createMetrics(distanceKm: 5.0),
        _createMetrics(distanceKm: 10.0),
        _createMetrics(distanceKm: 15.0),
      ];

      expect(trips.averageDistance, 10.0);
    });

    test('Calculate mode distribution', () {
      final trips = [
        _createMetrics(mode: 'Car'),
        _createMetrics(mode: 'Car'),
        _createMetrics(mode: 'Bus'),
        _createMetrics(mode: 'Walking'),
      ];

      final distribution = trips.modeDistribution;
      expect(distribution['Car'], 2);
      expect(distribution['Bus'], 1);
      expect(distribution['Walking'], 1);
    });

    test('Filter peak hour trips', () {
      final trips = [
        _createMetrics(hour: 8), // Peak
        _createMetrics(hour: 14), // Off-peak
        _createMetrics(hour: 18), // Peak
        _createMetrics(hour: 22), // Off-peak
      ];

      final peakTrips = trips.peakHourTrips;
      expect(peakTrips.length, 2);
    });

    test('Calculate total CO2', () {
      final trips = [
        _createMetrics(co2: 1.5),
        _createMetrics(co2: 2.0),
        _createMetrics(co2: 0.5),
      ];

      expect(trips.totalCO2, 4.0);
    });
  });
}

// Helper function to create test metrics
TripMetrics _createMetrics({
  double? distanceKm,
  String mode = 'Car',
  int hour = 12,
  double? co2,
}) {
  return TripMetrics(
    tripId: 'test-${DateTime.now().millisecondsSinceEpoch}',
    userId: 'user123',
    startTime: DateTime(2025, 1, 14, hour, 0),
    originName: 'Origin',
    destinationName: 'Destination',
    distanceKm: distanceKm,
    mode: mode,
    hourOfDay: hour,
    dayOfWeek: 2,
    isPeakHour: (hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19),
    timeOfDay: 'Morning',
    companionCount: 0,
    tripType: 'Auto',
    isConfirmed: true,
    estimatedCO2: co2,
  );
}
