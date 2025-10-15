import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'auto_trip_model.dart';
import 'trip_model.dart';

/// Enhanced metrics for transportation planning analysis
class TripMetrics {
  // Basic trip information
  final String tripId;
  final String userId;
  final DateTime startTime;
  final DateTime? endTime;
  
  // Spatial data
  final LatLng? originCoordinates;
  final LatLng? destinationCoordinates;
  final String originName;
  final String destinationName;
  
  // Trip characteristics
  final double? distanceKm;
  final int? durationMinutes;
  final String mode;
  final String? purpose;
  
  // Speed metrics
  final double? averageSpeedKmh;
  final double? maxSpeedKmh;
  final double? speedVariance;
  
  // Route quality
  final int? routePointCount;
  final double? routeDirectness; // Actual distance / straight-line distance
  final List<LatLng>? routePoints;
  
  // Time-based metrics
  final int hourOfDay;
  final int dayOfWeek; // 1 = Monday, 7 = Sunday
  final bool isPeakHour;
  final String timeOfDay; // Morning, Afternoon, Evening, Night
  
  // Cost and environmental
  final double? tripCost;
  final double? estimatedCO2; // kg CO2
  final double? estimatedFuelConsumption; // liters
  
  // Social aspects
  final int companionCount;
  final List<String>? companionNames;
  
  // Trip context
  final String tripType; // Auto/Manual
  final bool isConfirmed;
  final String? notes;

  TripMetrics({
    required this.tripId,
    required this.userId,
    required this.startTime,
    this.endTime,
    this.originCoordinates,
    this.destinationCoordinates,
    required this.originName,
    required this.destinationName,
    this.distanceKm,
    this.durationMinutes,
    required this.mode,
    this.purpose,
    this.averageSpeedKmh,
    this.maxSpeedKmh,
    this.speedVariance,
    this.routePointCount,
    this.routeDirectness,
    this.routePoints,
    required this.hourOfDay,
    required this.dayOfWeek,
    required this.isPeakHour,
    required this.timeOfDay,
    this.tripCost,
    this.estimatedCO2,
    this.estimatedFuelConsumption,
    required this.companionCount,
    this.companionNames,
    required this.tripType,
    required this.isConfirmed,
    this.notes,
  });

  /// Create metrics from AutoTripModel
  factory TripMetrics.fromAutoTrip(AutoTripModel trip) {
    final hour = trip.startTime.hour;
    final dayOfWeek = trip.startTime.weekday;
    
    return TripMetrics(
      tripId: trip.id ?? '',
      userId: trip.userId,
      startTime: trip.startTime,
      endTime: trip.endTime,
      originCoordinates: trip.origin.coordinates,
      destinationCoordinates: trip.destination?.coordinates,
      originName: _coordinatesToString(trip.origin.coordinates),
      destinationName: trip.destination != null 
          ? _coordinatesToString(trip.destination!.coordinates)
          : 'Unknown',
      distanceKm: trip.distanceKm,
      durationMinutes: trip.durationMinutes,
      mode: trip.confirmedMode ?? trip.detectedMode ?? 'Unknown',
      purpose: trip.purpose,
      averageSpeedKmh: trip.averageSpeedKmh,
      maxSpeedKmh: trip.maxSpeedKmh,
      speedVariance: _calculateSpeedVariance(trip.routePoints),
      routePointCount: trip.routePoints.length,
      routeDirectness: _calculateRouteDirectness(trip),
      routePoints: trip.routePoints.map((p) => p.coordinates).toList(),
      hourOfDay: hour,
      dayOfWeek: dayOfWeek,
      isPeakHour: _isPeakHour(hour),
      timeOfDay: _getTimeOfDay(hour),
      tripCost: trip.cost,
      estimatedCO2: _calculateCO2(trip.distanceKm, trip.confirmedMode ?? trip.detectedMode),
      estimatedFuelConsumption: _calculateFuelConsumption(trip.distanceKm, trip.confirmedMode ?? trip.detectedMode),
      companionCount: trip.companions?.length ?? 0,
      companionNames: trip.companions,
      tripType: 'Auto',
      isConfirmed: trip.status == AutoTripStatus.confirmed,
      notes: trip.notes,
    );
  }

  /// Create metrics from TripModel
  factory TripMetrics.fromManualTrip(TripModel trip) {
    final hour = trip.time.hour;
    final dayOfWeek = trip.time.weekday;
    
    return TripMetrics(
      tripId: trip.id ?? '',
      userId: trip.userId,
      startTime: trip.time,
      endTime: trip.endTime,
      originCoordinates: null,
      destinationCoordinates: null,
      originName: trip.origin,
      destinationName: trip.destination,
      distanceKm: null,
      durationMinutes: trip.endTime != null 
          ? trip.endTime!.difference(trip.time).inMinutes 
          : null,
      mode: trip.mode,
      purpose: null,
      averageSpeedKmh: null,
      maxSpeedKmh: null,
      speedVariance: null,
      routePointCount: null,
      routeDirectness: null,
      routePoints: null,
      hourOfDay: hour,
      dayOfWeek: dayOfWeek,
      isPeakHour: _isPeakHour(hour),
      timeOfDay: _getTimeOfDay(hour),
      tripCost: null,
      estimatedCO2: null,
      estimatedFuelConsumption: null,
      companionCount: trip.accompanyingTravellers.length,
      companionNames: trip.accompanyingTravellers.map((t) => t.name).toList(),
      tripType: 'Manual',
      isConfirmed: true,
      notes: null,
    );
  }

  // Helper methods

  static String _coordinatesToString(LatLng coords) {
    return '${coords.latitude.toStringAsFixed(6)},${coords.longitude.toStringAsFixed(6)}';
  }

  static double _calculateSpeedVariance(List<LocationPoint> points) {
    if (points.length < 2) return 0.0;
    
    final speeds = points.map((p) => p.speed * 3.6).toList(); // Convert to km/h
    final mean = speeds.reduce((a, b) => a + b) / speeds.length;
    final variance = speeds.map((s) => (s - mean) * (s - mean)).reduce((a, b) => a + b) / speeds.length;
    
    return variance;
  }

  static double _calculateRouteDirectness(AutoTripModel trip) {
    if (trip.destination == null) return 1.0;
    
    final straightLineDistance = _haversineDistance(
      trip.origin.coordinates,
      trip.destination!.coordinates,
    );
    
    if (straightLineDistance == 0) return 1.0;
    
    return trip.distanceCovered / 1000 / straightLineDistance;
  }

  static double _haversineDistance(LatLng point1, LatLng point2) {
    const earthRadius = 6371.0; // km
    
    final lat1 = point1.latitude * pi / 180;
    final lat2 = point2.latitude * pi / 180;
    final dLat = (point2.latitude - point1.latitude) * pi / 180;
    final dLon = (point2.longitude - point1.longitude) * pi / 180;
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  static bool _isPeakHour(int hour) {
    // Morning peak: 7-9 AM, Evening peak: 5-7 PM
    return (hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19);
  }

  static String _getTimeOfDay(int hour) {
    if (hour >= 6 && hour < 12) return 'Morning';
    if (hour >= 12 && hour < 17) return 'Afternoon';
    if (hour >= 17 && hour < 21) return 'Evening';
    return 'Night';
  }

  static double? _calculateCO2(double distanceKm, String? mode) {
    if (mode == null) return null;
    
    // CO2 emission factors (kg CO2 per km)
    const emissionFactors = {
      'Car': 0.171,
      'Bus': 0.089,
      'Motorcycle': 0.103,
      'Train': 0.041,
      'Walking': 0.0,
      'Cycling': 0.0,
      'E-Bike': 0.007,
    };
    
    final factor = emissionFactors[mode] ?? 0.1; // Default factor
    return distanceKm * factor;
  }

  static double? _calculateFuelConsumption(double distanceKm, String? mode) {
    if (mode == null) return null;
    
    // Fuel consumption (liters per 100 km)
    const fuelConsumption = {
      'Car': 7.5,
      'Bus': 25.0,
      'Motorcycle': 3.5,
      'Train': 0.0,
      'Walking': 0.0,
      'Cycling': 0.0,
      'E-Bike': 0.0,
    };
    
    final consumption = fuelConsumption[mode] ?? 0.0;
    return distanceKm * consumption / 100;
  }

  /// Convert to Map for export
  Map<String, dynamic> toMap() {
    return {
      'tripId': tripId,
      'userId': userId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'originLat': originCoordinates?.latitude,
      'originLng': originCoordinates?.longitude,
      'originName': originName,
      'destinationLat': destinationCoordinates?.latitude,
      'destinationLng': destinationCoordinates?.longitude,
      'destinationName': destinationName,
      'distanceKm': distanceKm,
      'durationMinutes': durationMinutes,
      'mode': mode,
      'purpose': purpose,
      'averageSpeedKmh': averageSpeedKmh,
      'maxSpeedKmh': maxSpeedKmh,
      'speedVariance': speedVariance,
      'routePointCount': routePointCount,
      'routeDirectness': routeDirectness,
      'hourOfDay': hourOfDay,
      'dayOfWeek': dayOfWeek,
      'isPeakHour': isPeakHour,
      'timeOfDay': timeOfDay,
      'tripCost': tripCost,
      'estimatedCO2': estimatedCO2,
      'estimatedFuelConsumption': estimatedFuelConsumption,
      'companionCount': companionCount,
      'companionNames': companionNames,
      'tripType': tripType,
      'isConfirmed': isConfirmed,
      'notes': notes,
    };
  }

  /// Convert to CSV row
  String toCSVRow() {
    return [
      tripId,
      userId,
      startTime.toIso8601String(),
      endTime?.toIso8601String() ?? '',
      originCoordinates?.latitude.toString() ?? '',
      originCoordinates?.longitude.toString() ?? '',
      originName,
      destinationCoordinates?.latitude.toString() ?? '',
      destinationCoordinates?.longitude.toString() ?? '',
      destinationName,
      distanceKm?.toStringAsFixed(2) ?? '',
      durationMinutes?.toString() ?? '',
      mode,
      purpose ?? '',
      averageSpeedKmh?.toStringAsFixed(2) ?? '',
      maxSpeedKmh?.toStringAsFixed(2) ?? '',
      speedVariance?.toStringAsFixed(2) ?? '',
      routePointCount?.toString() ?? '',
      routeDirectness?.toStringAsFixed(2) ?? '',
      hourOfDay.toString(),
      dayOfWeek.toString(),
      isPeakHour.toString(),
      timeOfDay,
      tripCost?.toString() ?? '',
      estimatedCO2?.toStringAsFixed(2) ?? '',
      estimatedFuelConsumption?.toStringAsFixed(2) ?? '',
      companionCount.toString(),
      companionNames?.join(';') ?? '',
      tripType,
      isConfirmed.toString(),
      notes ?? '',
    ].map(_escapeCsv).join(',');
  }

  static String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static String getCSVHeader() {
    return [
      'Trip ID',
      'User ID',
      'Start Time',
      'End Time',
      'Origin Latitude',
      'Origin Longitude',
      'Origin Name',
      'Destination Latitude',
      'Destination Longitude',
      'Destination Name',
      'Distance (km)',
      'Duration (min)',
      'Mode',
      'Purpose',
      'Avg Speed (km/h)',
      'Max Speed (km/h)',
      'Speed Variance',
      'Route Points',
      'Route Directness',
      'Hour of Day',
      'Day of Week',
      'Is Peak Hour',
      'Time of Day',
      'Trip Cost',
      'Estimated CO2 (kg)',
      'Estimated Fuel (L)',
      'Companion Count',
      'Companions',
      'Trip Type',
      'Is Confirmed',
      'Notes',
    ].join(',');
  }
}

/// Extension methods for trip analysis
extension TripMetricsAnalysis on List<TripMetrics> {
  /// Calculate average trip distance
  double get averageDistance {
    final trips = where((t) => t.distanceKm != null).toList();
    if (trips.isEmpty) return 0.0;
    return trips.map((t) => t.distanceKm!).reduce((a, b) => a + b) / trips.length;
  }

  /// Calculate average trip duration
  double get averageDuration {
    final trips = where((t) => t.durationMinutes != null).toList();
    if (trips.isEmpty) return 0.0;
    return trips.map((t) => t.durationMinutes!.toDouble()).reduce((a, b) => a + b) / trips.length;
  }

  /// Get mode distribution
  Map<String, int> get modeDistribution {
    final distribution = <String, int>{};
    for (var trip in this) {
      distribution[trip.mode] = (distribution[trip.mode] ?? 0) + 1;
    }
    return distribution;
  }

  /// Get purpose distribution
  Map<String, int> get purposeDistribution {
    final distribution = <String, int>{};
    for (var trip in this) {
      final purpose = trip.purpose ?? 'Not Specified';
      distribution[purpose] = (distribution[purpose] ?? 0) + 1;
    }
    return distribution;
  }

  /// Get peak hour trips
  List<TripMetrics> get peakHourTrips => where((t) => t.isPeakHour).toList();

  /// Get trips by time of day
  Map<String, List<TripMetrics>> get tripsByTimeOfDay {
    final grouped = <String, List<TripMetrics>>{};
    for (var trip in this) {
      grouped.putIfAbsent(trip.timeOfDay, () => []).add(trip);
    }
    return grouped;
  }

  /// Calculate total CO2 emissions
  double get totalCO2 {
    return where((t) => t.estimatedCO2 != null)
        .map((t) => t.estimatedCO2!)
        .fold(0.0, (a, b) => a + b);
  }

  /// Calculate total distance
  double get totalDistance {
    return where((t) => t.distanceKm != null)
        .map((t) => t.distanceKm!)
        .fold(0.0, (a, b) => a + b);
  }
}
